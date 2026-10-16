"""Offline structural/behavioral checks; does not contact Azure or Azure DevOps.

Run beside the two YAML files: python validate.py
Requires PyYAML and Bash (for syntax checks), not Azure credentials.
"""

import itertools
import re
import shutil
import subprocess
from pathlib import Path

import yaml


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    root = Path(__file__).resolve().parent
    pipeline = yaml.safe_load((root / "azure-pipelines.yml").read_text(encoding="utf-8"))
    template_text = (root / "deploy-stage.yml").read_text(encoding="utf-8")
    template = yaml.safe_load(template_text)
    stage = template["stages"][0]
    for field in ("stage", "dependsOn", "condition"):
        check(stage[field] == "${{ parameters." + field + " }}",
              f"Stage template must forward {field}")
    deployment = stage["jobs"][0]
    check(deployment["environment"] == "${{ parameters.environment }}",
          "A deployment job must reference the protected Environment")
    check(deployment["pool"] == {"name": "${{ parameters.pool }}"},
          "Self-hosted deployment must use pool.name")
    check(stage["variables"] == [{"group": "${{ parameters.variableGroup }}"}],
          "Secret group must be scoped to its stage")
    check(pipeline["trigger"] == "none" and pipeline["pr"] == "none",
          "Example must not automatically deploy unreviewed changes")

    results = ("Succeeded", "SucceededWithIssues", "Failed", "Canceled", "Skipped")
    cases = 0
    for index, name in enumerate(("DEV", "TEST", "PROD"), start=1):
        entry = pipeline["stages"][index]
        check(entry["template"] == "deploy-stage.yml", "Template must resolve locally")
        parameters = entry["parameters"]
        check(parameters["stage"] == name, "Unexpected promotion order")
        check(parameters["environment"] == f"agentlz-{name.lower()}"
              and parameters["variableGroup"] == f"agentlz-{name.lower()}-secrets",
              "Use consistent Agent Landing Zone environment and group names")
        expected_dependencies = ["CI", "DEV", "TEST"][:index]
        check(parameters["dependsOn"] == expected_dependencies,
              f"{name} must depend on every preceding stage")
        expression = parameters["condition"]
        # Deliberately accept only this fail-closed grammar, not arbitrary ADO expressions.
        guards = [f"eq(dependencies.{dep}.result, 'Succeeded')"
                  for dep in expected_dependencies]
        check(expression == "and(succeeded(), " + ", ".join(guards) + ")",
              f"{name} must require succeeded() and exact Succeeded results")
        parsed_guards = re.findall(r"eq\(dependencies\.(\w+)\.result, '(\w+)'\)", expression)
        for combination in itertools.product(results, repeat=index):
            observed = dict(zip(expected_dependencies, combination))
            for run_succeeded in (True, False):  # False includes a canceled parent/run.
                actual = run_succeeded and all(observed[dep] == value
                                               for dep, value in parsed_guards)
                expected = run_succeeded and set(combination) == {"Succeeded"}
                check(actual == expected, f"Unsafe promotion: {name} {observed}")
                cases += 1
        settings = parameters["settings"]
        check(settings["AZURE_ENV_NAME"] == f"agentlz-{name.lower()}",
              "Use the reviewed azd environment name")
        if settings["DEPLOYMENT_TOPOLOGY"] != "classic":
            scope = settings.get("HOSTED_AGENT_RESOURCE_SCOPE", "")
            check(scope.startswith("REPLACE_") or scope.endswith("/.default"),
                  "Hosted modes need an explicit delegated scope before first provision")
        check(settings["AZURE_PRINCIPAL_TYPE"] == "ServicePrincipal", "Wrong principal type")
        check(settings["NETWORK_ISOLATION"] == "true", "Example must default to private")
        check(settings["RUN_FROM_JUMPBOX"] == "true", "Post-provision must not be deferred")
        check(settings["AZURE_SKIP_NETWORK_ISOLATION_WARNING"] == "false",
              "The example must not bypass the legacy warning by default")

    ci_steps = pipeline["stages"][0]["jobs"][0]["steps"]
    deploy_steps = deployment["strategy"]["runOnce"]["deploy"]["steps"]
    scripts = []
    python_blocks = 0
    bash = shutil.which("bash")
    check(bash is not None, "Install Bash for offline syntax checks")
    for label, steps in (("CI", ci_steps), ("deployment", deploy_steps)):
        check(any(s.get("task") == "UsePythonVersion@0"
                  and s["inputs"]["versionSpec"] == "3.12" for s in steps),
              f"{label} needs Python 3.12 in its own job")
        checkout = next(s for s in steps if s.get("checkout") == "self")
        check(checkout["persistCredentials"] is False and checkout["clean"] is True,
              f"{label} must not persist Git credentials")
        body = "\n".join(s.get("bash", s.get("inputs", {}).get("inlineScript", ""))
                         for s in steps)
        check('git rev-parse HEAD' in body and "$EXPECTED_COMMIT" in body,
              f"{label} must verify the queued commit")
        check("source \"$VENV/bin/activate\"" in body
              and "pip install -r config/requirements.txt" in body,
              f"{label} needs an active Python environment with hook dependencies")
        for step in steps:
            for key in ("VENV", "AZD_CONFIG_DIR", "GIT_CONFIG_GLOBAL"):
                if key in step.get("env", {}):
                    check("/agentlz-" in step["env"][key],
                          f"{key} needs a job-specific Agent Landing Zone name")
            script = step.get("bash", step.get("inputs", {}).get("inlineScript"))
            if script:
                subprocess.run([bash, "-n"], input=script, text=True, check=True)
                scripts.append(script)
                for block in re.findall(r"python - <<'PY'\n(.*?)\nPY", script, re.S):
                    compile(block, "<inline pipeline Python>", "exec")
                    python_blocks += 1
    task = next(s for s in deploy_steps if s.get("task") == "AzureCLI@2")
    check(task["env"]["SECRET_SETTINGS_JSON"] == "$(AGENTLZ_SECRET_SETTINGS_JSON)",
          "Use the documented secret variable-group input")
    check(task["inputs"]["useGlobalConfig"] is False, "Azure CLI config must be isolated")
    body = task["inputs"]["inlineScript"]
    check("azd config set auth.useAzCliAuth true" in body, "Missing Azure CLI auth handoff")
    check("azd env refresh" in body and "|| true" not in body, "Refresh must fail closed")
    check("azd hooks run preup" in body, "Validate binding before standalone provision")
    check(body.index("azd provision") < body.index("prepareHostedDeployment.sh")
          < body.rindex("azd provision") < body.index("azd deploy"),
          "First hosted deployment needs provision/prepare/provision/deploy")
    check(python_blocks == 1, "Expected to syntax-check the settings Python block")
    cleanup = deploy_steps[-1]
    check(cleanup["condition"] == "always()", "Runtime-state cleanup must run after failure")
    # Intercept rm: verify every deletion target without deleting any real files.
    fixture_parent = "/agentlz-test/workspace/s"
    temporary_paths = ["/agentlz-test/temp/python", "/agentlz-test/temp/azd",
                       "/agentlz-test/temp/git"]
    fixture = (
        "rm() { printf '%s\\0' \"$@\"; }\n"
        f"SOURCE_PARENT='{fixture_parent}'\n"
        f"VENV='{temporary_paths[0]}'\n"
        f"AZD_CONFIG_DIR='{temporary_paths[1]}'\n"
        f"GIT_CONFIG_GLOBAL='{temporary_paths[2]}'\n"
    )
    result = subprocess.run([bash], input=fixture + cleanup["bash"],
                            text=True, capture_output=True, check=True)
    targets = [arg for arg in result.stdout.split("\0") if arg and not arg.startswith("-")]
    expected_state = [
        f"{fixture_parent}/{component}/{state_dir}"
        for component in ("agent-landing-zone", "agent-landing-zone/hosted-agent",
                          "agent-app-ui", "agent-app-orchestrator", "agent-app-ingestion")
        for state_dir in (".azure", ".logs")
    ]
    check(targets == expected_state + temporary_paths,
          "Cleanup must target only 10 known state directories and 3 temporary paths")
    print(f"PASS: 2 YAML files, {cases} promotion cases, "
          f"{len(scripts)} Bash scripts, {python_blocks} Python block and "
          f"{len(targets)} exact cleanup targets (rm intercepted); no cloud calls")


if __name__ == "__main__":
    main()
