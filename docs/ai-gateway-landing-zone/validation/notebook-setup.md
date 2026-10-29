---
render_macros: false
---

# Validation Notebook Setup Guide

This guide sets up an isolated Python environment for the notebooks in this directory. It assumes you have not created a Python virtual environment before.

**Start with [Validation Environment Setup](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-environment-setup.ipynb).** It installs and verifies the shared dependency set for all 15 active scenario notebooks directly in `validation`, including the Foundry HR Web Search Chat and Self-hosted Gateway validation. The terminal instructions below are an alternative installation route, followed by the same notebook verification. Archived notebooks and other validation directories are outside this environment's scope.

**Use the dedicated `.venv-validation-local` environment.** Keep an existing repository `.venv` for other labs unchanged. Installing a requirements file does not uninstall packages omitted from it, so reusing a broader environment can leave incompatible, unrelated frameworks installed. The setup notebook deliberately rejects the old `.venv` kernel.

The finished setup has four parts that must agree:

1. The repository has a `.venv-validation-local` virtual environment.
2. Python packages are installed through that environment's Python executable.
3. VS Code uses that Python executable as the notebook kernel.
4. Notebooks run with `validation` as their working directory.

After setup, use **Run All** from a fresh kernel. The selected azd environment
supplies deployment settings and models; required deployments default to allowed.
Edit the configuration only for optional overrides or genuinely external inputs
that are absent from azd. Every step shows a blue INFO section before execution and a
green/amber/red RESULT section afterwards. Required parameters left blank or
containing `REPLACE` stop initialization before deployment/testing, with all
missing parameter names listed. Secrets must already be available through the
documented environment/secret-store inputs; scenario execution does not prompt.
Access Contracts requires explicit Key Vault and Foundry targets by default,
unless their scenarios are explicitly disabled. See the
[execution guide](notebooks-bicep.md#step-output-and-fail-fast-initialization).
Use `skipped_models = ["mini", "legacy"]` to exclude case-insensitive model-name
substrings from validation without removing models from backend deployment.

## Why Use a Virtual Environment?

A virtual environment is a private Python installation for one repository. Packages installed in `.venv-validation-local` do not modify your system Python or another project's packages.

`pip` installs packages for a particular Python interpreter. A bare command such as `pip install requests` can target the wrong interpreter. This guide therefore uses the `.venv-validation-local` Python executable explicitly:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip <command>
```

That form is the most reliable way to guarantee that packages are installed in this repository's `.venv-validation-local`.

## Prerequisites

Install the following before continuing:

- Python 3.11 (latest available patch release). This is the supported setup target for the pinned dependency set; other Python minor versions are not validated by this workflow. Native packages can fail to build on newer interpreters.
- [Visual Studio Code](https://code.visualstudio.com/).
- The Microsoft **Python** and **Jupyter** VS Code extensions.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) for Azure access used by the notebooks.
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) when using notebook settings loaded from an `azd` environment.

Open PowerShell and verify the command-line tools:

```powershell
py -0p
py -3.11 --version
az --version
azd version
```

`py -0p` lists the installed Python runtimes. Continue only when `py -3.11 --version` succeeds. If it fails, install the current Python 3.11 release from [python.org](https://www.python.org/downloads/) and open a new terminal. Do not use the launcher's default Python 3.14 for this environment.

`azd` is optional when you set `from_azd = False` and provide notebook configuration manually.

## First-Time Setup on Windows

### 1. Open the repository in VS Code

Open the repository root, not only the `validation` directory:

```text
ai-hub-gateway-solution-accelerator
```

In VS Code, open **Terminal > New Terminal**. Confirm that PowerShell is at the repository root:

```powershell
Get-Location
```

The final directory name should be `ai-hub-gateway-solution-accelerator`.

### 2. Create `.venv-validation-local`

From the repository root, run:

```powershell
py -3.11 -m venv .venv-validation-local
```

Using `py -3.11` is intentional. A generic `py -m venv .venv-validation-local` selects the launcher's default version, which may be too new for the complete dependency set.

The repository's `.gitignore` already excludes `.venv-validation-local`, so the environment will not be committed.

### 3. Verify the environment before installing

You do not need to activate the environment when you use its Python executable explicitly:

```powershell
.\.venv-validation-local\Scripts\python.exe -c "import sys; print(sys.executable)"
.\.venv-validation-local\Scripts\python.exe --version
.\.venv-validation-local\Scripts\python.exe -m pip --version
az --version
azd version
```

The Python executable and pip paths must contain the repository path followed by `.venv-validation-local`, and the Python version must be 3.11. Stop and recreate the environment if any check differs. `az` and `azd` are separate command-line tools, so their paths are not expected to be inside `.venv-validation-local`.

### 4. Upgrade Python packaging tools

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
```

### 5. Install all active notebook dependencies

From the repository root, first ask pip to resolve the complete dependency set without installing it:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip install --dry-run --ignore-installed -r .\validation\requirements.txt
```

Only continue if the dry run exits successfully. It checks the entire dependency graph independently of installed packages, but does not compile native packages or prove runtime API compatibility:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip install -r .\validation\requirements.txt
```

The first installation can take several minutes. Install the complete requirements in one pip invocation so its resolver checks the frameworks together. `ipykernel` is included; no separate unpinned install is needed for the terminal-only route. Azure CLI is intentionally installed separately as a system tool; the notebooks invoke the external `az` command rather than importing it as a Python package.

For the notebook-first route, bootstrap `ipykernel==7.3.0` into `.venv-validation-local`, select that kernel, then run the setup notebook's resolution and installation cells instead. After either route, restart the kernel, rerun setup **step 1**, then run **step 4** to verify all direct versions and required SDK APIs.

Do not replace these commands with bare `pip install` commands. Using `.venv-validation-local\Scripts\python.exe -m pip` makes the installation target unambiguous even when another Python environment is activated.

### Optional: activate `.venv-validation-local`

Activation makes `python` resolve to `.venv-validation-local` for the current terminal session:

```powershell
.\.venv-validation-local\Scripts\Activate.ps1
```

The prompt normally begins with `(.venv-validation-local)`. Verify it instead of relying only on the prompt:

```powershell
python -c "import sys; print(sys.executable)"
python -m pip --version
```

Both paths must contain `.venv-validation-local`. Even after activation, prefer `python -m pip` over bare `pip`.

If PowerShell blocks `Activate.ps1`, either continue using the explicit `.venv-validation-local\Scripts\python.exe` commands or permit local scripts for your Windows user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Open a new PowerShell terminal after changing the policy. Do not change the machine-wide policy for this setup.

## First-Time Setup on macOS or Linux

From the repository root:

```bash
python3.11 -m venv .venv-validation-local
.venv-validation-local/bin/python -m pip install --upgrade pip setuptools wheel
.venv-validation-local/bin/python -m pip install --dry-run --ignore-installed -r validation/requirements.txt
.venv-validation-local/bin/python -m pip install -r validation/requirements.txt
```

If `python3.11` is unavailable, install Python 3.11 first. Use `python3` only if the following reports **3.11.x**, not simply any newer Python:

```bash
python3 --version
```

Optional activation and verification:

```bash
source .venv-validation-local/bin/activate
python -c 'import sys; print(sys.executable)'
python -m pip --version
```

## Verify the Installation

Run these commands from the repository root.

Windows PowerShell:

```powershell
.\.venv-validation-local\Scripts\python.exe -c "import sys; print('Python:', sys.executable)"
.\.venv-validation-local\Scripts\python.exe -c "import requests; print('requests:', requests.__file__)"
.\.venv-validation-local\Scripts\python.exe -c "import azure.identity; import azure.mgmt.apimanagement; import openai; print('Baseline imports: OK')"
.\.venv-validation-local\Scripts\python.exe -m pip check
```

macOS or Linux:

```bash
.venv-validation-local/bin/python -c "import sys; print('Python:', sys.executable)"
.venv-validation-local/bin/python -c "import requests; print('requests:', requests.__file__)"
.venv-validation-local/bin/python -c "import azure.identity; import azure.mgmt.apimanagement; import openai; print('Baseline imports: OK')"
.venv-validation-local/bin/python -m pip check
```

Expected results:

- The Python executable path contains `.venv-validation-local`.
- The Python version is 3.11.
- The `requests` path is under `.venv-validation-local`.
- The baseline import command prints `Baseline imports: OK`.
- `pip check` prints `No broken requirements found`.

These terminal commands are quick baseline checks, not the final acceptance check. Open [Validation Environment Setup](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-environment-setup.ipynb), select `.venv-validation-local`, restart, and run **step 1 followed by step 4**. Its verification reports every pinned direct version and checks Agent Framework, Foundry `PromptAgentDefinition`, Key Vault, Cosmos DB, A2A, LangChain, charts, and shared helper imports without making Azure calls.

`pip check` only evaluates packages that are already installed. It can report success after a failed requirements installation if the failing packages were never installed, so always run the import checks too.

`Get-Command python` and `where.exe python` are useful diagnostics after activation, but the printed `sys.executable` path is the authoritative check.

## Select `.venv-validation-local` as the VS Code Notebook Kernel

Installing packages in `.venv-validation-local` does not automatically switch an already-open notebook to that environment.

If the new environment is not listed, run **Python: Select Interpreter** from the Command Palette, choose **Enter interpreter path**, and select `.venv-validation-local\Scripts\python.exe` on Windows or `.venv-validation-local/bin/python` on macOS/Linux. Then reopen the notebook's kernel picker.

1. Open [Validation Environment Setup](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-environment-setup.ipynb) under `validation`.
2. Select the kernel name in the upper-right corner of the notebook editor.
3. Choose **Select Another Kernel** if necessary.
4. Choose **Python Environments**.
5. Select the interpreter whose path ends with `.venv-validation-local\Scripts\python.exe` on Windows or `.venv-validation-local/bin/python` on macOS/Linux.
6. Restart the notebook kernel after changing environments or installing packages.

Run this preflight cell before the notebook's first real cell:

```python
import os
import sys
import requests

print("Python:", sys.executable)
print("Working directory:", os.getcwd())
print("requests:", requests.__file__)
```

Confirm that:

- `Python` contains `.venv-validation-local`.
- `requests` is loaded from `.venv-validation-local`.
- `Working directory` ends with `validation`.

## Notebook Working Directory

The validation notebooks use paths such as:

```python
sys.path.insert(1, "../shared")
```

They also read and generate files under `../bicep`. These paths assume the current working directory is the repository's `validation` directory.

The recommended workflow is:

1. Open the repository root as the VS Code workspace.
2. Open the notebook from the `validation` directory.
3. Select the repository's `.venv-validation-local` kernel.
4. Check `os.getcwd()` with the preflight cell.

If the working directory is the repository root, change it once at the start of the notebook session:

```python
import os
from pathlib import Path

current_dir = Path.cwd().resolve()
validation_dir = current_dir if current_dir.name == "validation" else current_dir / "validation"
if not (validation_dir / "requirements.txt").is_file() or not (validation_dir.parent / "shared" / "utils.py").is_file():
    raise RuntimeError("Run from the repository root or validation.")
os.chdir(validation_dir)
print(Path.cwd())
```

This cell is safe to repeat from either the repository root or `validation`; other locations fail explicitly. Working-directory state is per kernel session, so confirm it in every scenario notebook.

## Azure Authentication and Environment Selection

Most notebooks call Azure CLI from Python. Authenticate before running them:

```powershell
az login
az account show --output table
```

If the wrong subscription is active:

```powershell
az account set --subscription "<subscription-name-or-id>"
az account show --output table
```

For notebooks with `from_azd = True`, select the deployment environment first:

```powershell
azd env list
azd env select <environment-name>
azd env get-values
```

Never place access tokens, API keys, client secrets, or provider credentials in terminal history. Follow each notebook's secret-storage instructions, particularly its Azure Key Vault guidance.

## Shared Dependencies and Version Policy

[requirements.txt](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/requirements.txt) is the single source of truth for all direct dependencies of the 15 active scenario notebooks. [Validation Environment Setup](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/blob/main/validation/citadel-environment-setup.ipynb) owns installation, version reporting, and SDK import/API checks. Agent Frameworks no longer installs packages, and PII analysis no longer upgrades Cosmos DB at runtime. MSAL, Key Vault, Cosmos DB, async support, and A2A are installed up front, including packages used only by optional scenarios.

- **Python:** use Python 3.11. A virtual environment cannot change its base interpreter in place.
- **Direct versions:** every direct dependency uses an exact `==` pin. Rerunning setup does not silently opt into newer SDK releases.
- **Framework components:** the core, OpenAI, and A2A distributions replace the broad `agent-framework` metapackage. Component release numbers differ; their declared constraints, resolved together by pip, determine compatibility.
- **Preview versions:** `agent-framework-a2a==1.0.0b261002` is explicitly pinned. Do not use a global `--pre`, which can admit previews for unrelated dependencies.
- **Transitive versions:** this is **not a complete lockfile**. Pip resolves transitive packages, so those versions can change between installations. `pip check` verifies installed dependency constraints; the setup notebook additionally verifies direct pins and imported SDK APIs.
- **Platform handling:** pip resolves platform-specific dependencies from package metadata. There is no unconditional Windows-only `pywin32` requirement for macOS/Linux users.
- **Updates:** edit central pins as a compatible set, test a fresh Python 3.11 installation, run setup verification and affected scenario notebooks, and commit the requirements and guidance together. Do not fix conflicts with `--no-deps`, individual in-notebook upgrades, or silent fallback downgrades.

For a same-platform record after successful verification, from the repository root:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip freeze > .\.venv-validation-local\validation.freeze.txt
```

On macOS/Linux, use `.venv-validation-local/bin/python -m pip freeze > .venv-validation-local/validation.freeze.txt`. The snapshot stays in the ignored `.venv-validation-local` directory. It captures the resolved environment, not a portable, hash-verified lockfile. Inspect it before sharing; private package URLs can contain sensitive data.

The old all-labs dependency list included unused frameworks. Those and archived notebooks are deliberately outside this active-notebook environment. Do not combine requirements from `validation`, `shared`, or archived labs into this environment without separately validating their constraints.

## Normal Workflow After Initial Setup

You only create `.venv-validation-local` and install the shared requirements once, then reinstall when central pins change. For later sessions:

1. Open the repository root in VS Code.
2. Optionally activate `.venv-validation-local` in the terminal.
3. Run `az login` if your Azure session has expired.
4. Select the appropriate `azd` environment when the notebook uses it.
5. Open a notebook under `validation`.
6. Confirm its kernel is `.venv-validation-local`.
7. Run the preflight cell and confirm the working directory.
8. Run notebook cells in order.

## Troubleshooting

### `pip check` reports dependency conflicts in step 4

Step 4 now captures pip's output explicitly and includes the conflict details in the raised error. A nonzero exit means installed packages have incompatible dependency constraints, not that the notebook's import-check loop is broken.

For example, an older all-labs environment can contain `agent-framework-foundry` requiring `azure-ai-projects<2.8.0`, `openai-agents` requiring `openai<3`, or `semantic-kernel` requiring `pydantic<2.12`. These are not required by the active validation suite. Installing this suite's requirements into that environment does not remove them.

Do not downgrade the central pins or disable `pip check`. Instead:

1. Leave the existing `.venv` and its packages unchanged.
2. Create `.venv-validation-local` from Python 3.11 using the setup commands above.
3. Install the complete shared requirements into that environment.
4. In every validation notebook, use **Select Another Kernel > Python Environments**, then choose `.venv-validation-local`.
5. Restart and run setup **step 1 followed by step 4**. The printed interpreter must point to `.venv-validation-local`, and pip must report `No broken requirements found`.

If the dedicated environment has itself accumulated unrelated packages, use **Recreate a damaged environment** below, targeting only `.venv-validation-local`.

### `ModuleNotFoundError: No module named 'requests'`

First inspect the active notebook kernel:

```python
import sys
print(sys.executable)
```

If the path does not contain `.venv-validation-local`, select the `.venv-validation-local` kernel. If it does contain `.venv-validation-local`, install and verify through that exact interpreter from the repository root:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip install -r .\validation\requirements.txt
.\.venv-validation-local\Scripts\python.exe -c "import requests; print(requests.__file__)"
```

Restart the notebook kernel afterward.

### `pip install -r requirements.txt` fails

Avoid bare `pip` and first confirm the environment:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip --version
.\.venv-validation-local\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
.\.venv-validation-local\Scripts\python.exe -m pip install -r .\validation\requirements.txt
```

Read the first `ERROR:` line in the pip output. Common causes include an unsupported Python version, a corporate proxy or package-index restriction, unavailable build tools, or a package-version conflict. Capture the complete command output when asking for help; an exit code alone does not identify the failed package.

Check the environment's Python version directly:

```powershell
.\.venv-validation-local\Scripts\python.exe --version
```

If it reports anything other than Python 3.11, install Python 3.11 and recreate `.venv-validation-local` using the commands in **Recreate a damaged environment**. A virtual environment cannot be changed to another Python version in place.

#### `Failed to build 'pymsalruntime'`

`pymsalruntime` is a native dependency used by the pip-distributed Azure CLI. Its older source uses Python APIs removed in Python 3.12 and later, producing errors such as `Py_UNICODE* has been removed` or an incompatible `MSALRUNTIME_LOG_CALLBACK_ROUTINE`.

The validation notebooks do not need Azure CLI installed as a Python package. They execute the separately installed `az` command. The repository requirements therefore exclude `azure-cli` and treat it as a system prerequisite.

If this error occurred before that change, verify that the requirements file no longer contains an active `azure-cli` line:

```powershell
Select-String -Path .\validation\requirements.txt -Pattern '^azure-cli$'
.\.venv-validation-local\Scripts\python.exe --version
```

The first command should return no match. Then rerun the requirements installation; pip can continue using the existing environment because the failed `pymsalruntime` build did not install that package:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip install --dry-run --ignore-installed -r .\validation\requirements.txt
.\.venv-validation-local\Scripts\python.exe -m pip install -r .\validation\requirements.txt
```

If the dry run fails on another package, follow **Recreate a damaged environment** with Python 3.11. Confirm the external CLI independently:

```powershell
az --version
az account show --output table
```

#### `Failed building wheel for pydantic-core` or `Python 3.14 is newer than PyO3's maximum supported version`

This can indicate that the environment uses a Python version unsupported by the selected native dependency. Check the actual `.venv-validation-local` version rather than assuming the error identifies it. Installing Rust or setting `PYO3_USE_ABI3_FORWARD_COMPATIBILITY` is not the supported fix for this notebook suite.

Install Python 3.11, close any notebook kernel using `.venv-validation-local`, and recreate the environment with the commands in **Recreate a damaged environment**. Verify the new interpreter before installing packages:

```powershell
.\.venv-validation-local\Scripts\python.exe --version
```

It must report `Python 3.11.x`.

### A package installed successfully but the notebook cannot import it

The terminal and notebook are using different Python interpreters. Compare:

```powershell
.\.venv-validation-local\Scripts\python.exe -c "import sys; print(sys.executable)"
```

with:

```python
import sys
print(sys.executable)
```

Both paths must identify the same `.venv-validation-local` Python executable. Then restart the kernel.

### `No module named 'utils'` or `No module named 'apimtools'`

Check the notebook working directory:

```python
import os
print(os.getcwd())
```

It must end with `validation` because the notebooks add `../shared` to `sys.path`.

### PowerShell cannot run `Activate.ps1`

Activation is optional. Use `.\.venv-validation-local\Scripts\python.exe -m pip` directly, or apply the current-user execution policy described earlier in this guide.

### `az` or `azd` is not recognized

Install the missing CLI, close all terminals, open a new terminal, and rerun `az --version` or `azd version`. `azd` is unnecessary when `from_azd = False`.

### Recreate a damaged environment

Virtual environments are disposable. Close notebooks and terminals using `.venv-validation-local`. Confirm you are at the repository root and that `.venv-validation-local` is the environment you intend to remove before recreating it.

PowerShell from the repository root:

```powershell
Remove-Item -LiteralPath .\.venv-validation-local -Recurse -Force
py -3.11 -m venv .venv-validation-local
.\.venv-validation-local\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
.\.venv-validation-local\Scripts\python.exe -m pip install --dry-run --ignore-installed -r .\validation\requirements.txt
.\.venv-validation-local\Scripts\python.exe -m pip install -r .\validation\requirements.txt
```

Select the new `.venv-validation-local` kernel, restart, then run setup steps 1 and 4. Do not copy a `.venv-validation-local` from another computer or repository; recreate it from requirements.

### Checking Setup Changes

The setup regression tests use the standard library only. From the repository root:

```powershell
.\.venv-validation-local\Scripts\python.exe -m unittest discover -s .\validation\tests -v
```

They check notebook syntax, dependency coverage, kernel/working-directory guards, pip invocation, and failure propagation. They do not install packages, authenticate, or deploy resources. Maintainers must also verify a fresh requirements installation and the setup notebook's version/API checks when updating pins.

## Maintaining the Environment

Use the environment's interpreter for all package operations:

```powershell
.\.venv-validation-local\Scripts\python.exe -m pip list
.\.venv-validation-local\Scripts\python.exe -m pip check
.\.venv-validation-local\Scripts\python.exe -m pip install -r .\validation\requirements.txt
```

Avoid these patterns:

- `pip install ...` without verifying which Python owns `pip`.
- `py -m pip install ...` after `.venv-validation-local` exists; the Python launcher can target global Python.
- `pip install --user ...` for notebook dependencies.
- Upgrading packages individually or enabling global `--pre` instead of updating central pins.
- Running setup installation cells before selecting the `.venv-validation-local` kernel.
- Committing `.venv-validation-local`, generated credentials, or notebook secrets.
