# Tests & quality checks

Use these checks when contributing to an application component. Behavioral
tests exercise expected and denied outcomes. Static quality checks inspect
source, types, imports, and exception handling without proving that an Azure
deployment is ready.

Commands below run from the named repository's root unless stated otherwise.
Use Python 3.12 and its own virtual environment, as in
[Run locally](local-development.md). Development tools are separate from
`requirements.txt` and are not an additional runtime dependency manifest.

## Select the source and protected base

The platform [manifest](https://github.com/Azure/agent-landing-zone/blob/main/manifest.json)
at your platform release selects the compatible product revisions.
The commands here follow the **current contributor workflows in component
repository `main`**, which may contain newer quality-tooling patches.
They do not adopt newer runtime behavior into the umbrella application.
When working on another revision, inspect its own workflow and tool arguments.

For ordinary contributions targeting `develop`:

```powershell
git fetch origin develop
$Base = git merge-base HEAD origin/develop
```

For release-target or explicitly authorized other work, use the actual fetched
target's immutable base SHA instead. A protected base supplies the trusted
policy and evaluator. Do not substitute candidate HEAD or a convenient base
to suppress findings.

## Orchestrator

Prepare tools, run behavioral tests, and bind their JUnit results to the
quality evaluation:

```powershell
python -m pip install -r requirements.txt
python -m pip install pytest pytest-asyncio pytest-mock jsonschema
python -m pip install -r requirements-quality.txt
python -m pytest -q --junitxml=.artifacts/pytest.xml
python -I -S .github/scripts/check-quality.py --check all --base-ref $Base --test-results .artifacts/pytest.xml --report .artifacts/quality.json
```

Use `-I -S` for this repository's checker and aggregate entrypoint.
These Python options isolate interpreter startup and skip automatic site
initialization. Static tools analyze fresh source-only snapshots with installed
wheel paths exposed without executing `.pth` startup hooks.
Candidate packages are analyzed, not imported. This is not an OS sandbox.
Executable mypy plugins and custom Import Linter contracts are rejected.

Useful focused behavioral checks include:

```text
python -m pytest -q tests/test_conversation_ownership.py tests/test_conversation_persistence_boundaries.py
python -m pytest -q tests/test_hosted_responses.py tests/test_hosted_strategies.py
python -m pytest -q tests/test_quality_policy.py
```

Use Node 20 for the dashboard. From `frontend/`, matching current CI:

```text
npm install --no-audit --no-fund
npm run build
```

`npm run lint` is also available locally. There is no `npm test` script in
this dashboard. Do not invent a frontend test gate.

The PR workflow's `tests` job produces same-run JUnit evidence.
Its quality matrix uses the protected target's evaluator, configuration, and
runtime/tool requirements rather than installing candidate runtime dependencies
in static jobs. `quality-gate` requires actual successful `tests`, `frontend`,
and `quality` results and fresh reports matching the repository, base, head,
and workflow run. Bootstrap diagnostics are not an activated green policy.

## Ingestion

Run the contributor commands independently from the ingestion root:

```powershell
python -m pip install -r requirements.txt
python -m pip install -r requirements-quality.txt
python -m pip install pytest pytest-asyncio
python -m pytest -q tests/test_quality_policy.py tests/test_jobs_runtime.py
python -m pytest tests -q --junitxml=.artifacts/pytest.xml -o junit_family=legacy
python -I .github/scripts/quality-evidence.py --junit .artifacts/pytest.xml --base-ref $Base --report .artifacts/test-evidence.json
python -I .github/scripts/check-quality.py --check all --base-ref $Base --test-evidence .artifacts/test-evidence.json --report .artifacts/quality.json
```

Use `python -I` for its checker, evidence, and aggregate entrypoints.
`--repository` can select a separate candidate checkout for the protected-base
evaluator. Ordinary contributors can omit it.
The evidence report binds exception and dynamic-import checks to executed tests.
Keep `junit_family=legacy` when generating that evidence.

Useful focused tests include `test_ingest_documents_failures.py`,
`test_search_write_failures.py`, `test_chunking_failure_boundaries.py`,
`test_admin_jobs_queue.py`, `test_admin_config.py`, `test_retrieval.py`,
and `test_panel_operator_auth.py` under `tests/`.
These mock service boundaries. Do not start live scheduled jobs as a shortcut
for an offline test.

Use Node 22. From `frontend/`:

```text
npm ci
npm test
npm run lint
npm run build
```

Do not bypass peer validation. These are the maintained `frontend-checks`
commands, even though the Dockerfile names a Node 20 build stage.
The build produces `static/` for the backend, not a deployment.

The test workflow has `unit-tests`, `frontend-checks`, and five quality checks.
`quality-gate` requires successful same-workflow behavior/frontend jobs plus
fresh matching reports. The protected target owns evaluator and tool pins.
A target without an evaluator deliberately blocks a normal green bootstrap
claim.

## UI

Install the runtime requirements, contributor tools, and editable package:

```text
python -m pip install -r requirements.txt
python -m pip install -r requirements-quality.txt
python -m pip install --no-deps -e .
python -m unittest discover -s tests -v
```

The UI uses standard `unittest`, not a replacement pytest discovery command.
Focused package acceptance:

```text
python -m pip wheel --no-deps --wheel-dir .artifacts/wheel .
python -m unittest discover -s tests -p test_module_compatibility.py -v
python -m unittest discover -s tests -p test_installed_package.py -v
python -m unittest discover -s tests -p test_quality_policy.py -v
```

Installed-package acceptance creates a clean non-editable environment, installs
runtime requirements, runs `pip check`, and verifies canonical and legacy
import origins outside the checkout. It copies tests, not runtime sources.
This can install dependencies and needs package-feed access. It does not prove
a Linux container or Azure integration.

For protected quality checks, create one run ID and use the evidence runner:

```powershell
$env:QUALITY_RUN_ID = [guid]::NewGuid().ToString()
python .github/scripts/run-unittest.py --base-ref $Base --report .artifacts/unittest.json
python .github/scripts/check-quality.py --check all --base-ref $Base --test-evidence .artifacts/unittest.json --report .artifacts/quality.json
```

Set `QUALITY_RUN_ID` once per local run in other shells too.
The receipt binds exact test methods, source fingerprints, base/head, and run
context. Local `--pattern` supports focused execution.
CI aggregation requires full `test_*.py` discovery.
Skipped, expected-failure, stale, and failed evidence cannot validate an
exception site. Running the checker without this receipt is not a complete
exception/dynamic-import check.

For protected-source recovery and downloads:

```text
python -m unittest discover -s tests -p test_auth_recovery.py -v
python -m unittest discover -s tests -p test_native_downloads.py -v
```

`tests/auth_recovery_browser.html` exercises the bundled helper with synthetic
MSAL and fetch boundaries and makes no application Azure requests. It does not
prove live Entra Conditional Access, browser, or proxy behavior.

CI evaluates quality in a separate environment using protected requirements
and tool pins without installing candidate application code there.
`quality-gate` requires real unit-test, quality-matrix, and `container-tests`
results plus fresh bound reports and the unittest receipt. `container-tests`
builds an ephemeral Linux image and runs `tests/container_smoke.py` with no
network and read-only mounted tests. It checks installed imports, staged
resources, startup, and offline behavior. It publishes and deploys no image.

## Quality policy and evidence

All three checkers support `all`, `lint`, `typing`, `architecture`, `exceptions`,
and `policy`. Exit `0` means passed, `1` means violations, and `2` means invalid
inputs or incomplete execution. Missing reports and nonzero results are not
success. Checkers create reports, not source fixes or rewritten baselines.

The policies inventory runtime modules, import directions, public/private
surfaces, type coverage, dynamic imports, and broad exception handlers.
New runtime modules enter the applicable quality scope automatically.
Imported out-of-scope type diagnostics can remain visible without being
blocking. Keep the distinction between those diagnostics and enforced scope.

- Orchestrator's protected `module-surfaces.json` records module ownership and
  public exports. Its initial debt baseline is empty and findings are matched
  by source, symbol, diagnostic, and multiplicity, not a total count.
- Ingestion's initial blocking type scope includes
  `telemetry/audit_contract.py`, `telemetry/audit_sanitizer.py`, and
  `jobs/runtime.py`.
- UI's `.quality/migration.json` preserves supported legacy exports while
  `.quality/policy.json` tracks canonical modules and adapters.

An exception record is an exact, bounded allowance, not a blanket waiver for
a category of handlers. Preserve source/handler fingerprints, protected-base
metadata, expiry, stage, and passing same-run evidence as required by the
owning checker. UI `active` records are eligible for technical validation, not
human approval. Logging and rethrowing do not automatically waive a handler
check. Do not grow baselines, add suppressions, weaken policy, or fabricate
evidence to turn a candidate green. Protected checker/tool/workflow changes
require explicit maintainer authorization.

Missing, skipped, cancelled, failed, stale, or mismatched CI results do not
authorize a merge. The shared repository standard requires PRs and successful
quality and behavior/frontend or container checks on both `develop` and `main`.
The required approving-review count is zero. Code-owner and latest-head
approvals are not mandatory, and maintainers may merge their own passing PRs.
An authorized administrative exception is temporary, not a permanent bypass
or a successful failed check.

Workflow YAML and local commands do not activate or certify live branch
protection. Administrators verify those settings separately.
Unprivileged quality workflows and the separate `pull_request_target`
main-branch naming guard have different purposes.
For engineering-asset changes, also run the owning repository's
`python .github/scripts/validate-agentic-assets.py`.

## What local checks do not prove

Keep a handoff with the exact source/base, commands, results, and unperformed
checks. Offline tests do not certify Azure role assignments, source ACLs,
delegated token passthrough, model availability, private DNS, successful
indexing, or cross-component readiness.

Test API payloads, headers, bounded retries/timeouts, cancellation, record-level
failures, and persistence acknowledgements. Security changes need negative
tests for expired, unauthorized, cross-session, cross-origin, and cross-user
access. Presentation changes need light/dark, keyboard/focus, responsive, and
authenticated/anonymous checks.

Any live validation is a separately authorized task. Follow
[Sign-in & access](application-auth.md), [Conversations & files](conversations.md),
[Jobs & schedules](ingestion-jobs.md), and
[Monitoring & audit](application-monitoring.md) for their operational boundaries.
Code reverts do not restore deleted documents or reverse persisted settings.
Data recovery and reingestion require their own plan.

## Optional workload evaluation

Consider the [AgentOps Accelerator](agentops.md) to evaluate, ship, and operate
your Agent Landing Zone workload. The orchestrator's deprecated `evaluations/`
folder contains no maintained standalone runner. Linking to AgentOps does not
integrate it automatically or enable an evaluation or pull-request gate.
