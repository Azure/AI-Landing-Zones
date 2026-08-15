# Validation Notebook Setup Guide

This guide sets up an isolated Python environment for the notebooks in this directory. It assumes you have not created a Python virtual environment before.

The finished setup has four parts that must agree:

1. The repository has a `.venv` virtual environment.
2. Python packages are installed through that environment's Python executable.
3. VS Code uses that Python executable as the notebook kernel.
4. Notebooks run with `validation` as their working directory.

## Why Use a Virtual Environment?

A virtual environment is a private Python installation for one repository. Packages installed in `.venv` do not modify your system Python or another project's packages.

`pip` installs packages for a particular Python interpreter. A bare command such as `pip install requests` can target the wrong interpreter. This guide therefore uses the `.venv` Python executable explicitly:

```powershell
.\.venv\Scripts\python.exe -m pip <command>
```

That form is the most reliable way to guarantee that packages are installed in this repository's `.venv`.

## Prerequisites

Install the following before continuing:

- Python 3.11. The complete validation dependency set is not compatible with Python 3.14. Dependency backtracking can select native packages such as `pydantic-core` whose PyO3 build supports only through Python 3.13.
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

`azd` is optional when you set `init_from_azd = False` and provide notebook configuration manually.

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

### 2. Create `.venv`

From the repository root, run:

```powershell
py -3.11 -m venv .venv
```

Using `py -3.11` is intentional. A generic `py -m venv .venv` selects the launcher's default version, which may be too new for the complete dependency set.

The repository's `.gitignore` already excludes `.venv`, so the environment will not be committed.

### 3. Verify the environment before installing

You do not need to activate the environment when you use its Python executable explicitly:

```powershell
.\.venv\Scripts\python.exe -c "import sys; print(sys.executable)"
.\.venv\Scripts\python.exe --version
.\.venv\Scripts\python.exe -m pip --version
az --version
azd version
```

The Python executable and pip paths must contain the repository path followed by `.venv`, and the Python version must be 3.11. Stop and recreate the environment if any check differs. `az` and `azd` are separate command-line tools, so their paths are not expected to be inside `.venv`.

### 4. Upgrade Python packaging tools

```powershell
.\.venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
```

### 5. Install the baseline notebook dependencies

From the repository root, first ask pip to resolve the complete dependency set without installing it:

```powershell
.\.venv\Scripts\python.exe -m pip install --dry-run -r .\validation\requirements.txt
```

If the dry run finishes without `ERROR:`, install the dependencies. A dry run checks dependency resolution but does not compile native packages, which is why using Python 3.11 remains mandatory:

```powershell
.\.venv\Scripts\python.exe -m pip install -r .\validation\requirements.txt
.\.venv\Scripts\python.exe -m pip install ipykernel
```

The first installation can take several minutes because the requirements file includes several AI frameworks with large dependency trees. Azure CLI is intentionally installed separately as a system tool; the notebooks invoke the external `az` command rather than importing it as a Python package.

Do not replace these commands with bare `pip install` commands. Using `.venv\Scripts\python.exe -m pip` makes the installation target unambiguous even when another Python environment is activated.

### Optional: activate `.venv`

Activation makes `python` resolve to `.venv` for the current terminal session:

```powershell
.\.venv\Scripts\Activate.ps1
```

The prompt normally begins with `(.venv)`. Verify it instead of relying only on the prompt:

```powershell
python -c "import sys; print(sys.executable)"
python -m pip --version
```

Both paths must contain `.venv`. Even after activation, prefer `python -m pip` over bare `pip`.

If PowerShell blocks `Activate.ps1`, either continue using the explicit `.venv\Scripts\python.exe` commands or permit local scripts for your Windows user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Open a new PowerShell terminal after changing the policy. Do not change the machine-wide policy for this setup.

## First-Time Setup on macOS or Linux

From the repository root:

```bash
python3.11 -m venv .venv
.venv/bin/python -m pip install --upgrade pip setuptools wheel
.venv/bin/python -m pip install -r validation/requirements.txt
.venv/bin/python -m pip install ipykernel
```

If `python3.11` is unavailable, use `python3` after confirming it is Python 3.10 or newer:

```bash
python3 --version
```

Optional activation and verification:

```bash
source .venv/bin/activate
python -c 'import sys; print(sys.executable)'
python -m pip --version
```

## Verify the Installation

Run these commands from the repository root.

Windows PowerShell:

```powershell
.\.venv\Scripts\python.exe -c "import sys; print('Python:', sys.executable)"
.\.venv\Scripts\python.exe -c "import requests; print('requests:', requests.__file__)"
.\.venv\Scripts\python.exe -c "import azure.identity; import azure.mgmt.apimanagement; import openai; print('Baseline imports: OK')"
.\.venv\Scripts\python.exe -m pip check
```

macOS or Linux:

```bash
.venv/bin/python -c "import sys; print('Python:', sys.executable)"
.venv/bin/python -c "import requests; print('requests:', requests.__file__)"
.venv/bin/python -c "import azure.identity; import azure.mgmt.apimanagement; import openai; print('Baseline imports: OK')"
.venv/bin/python -m pip check
```

Expected results:

- The Python executable path contains `.venv`.
- The Python version is 3.11.
- The `requests` path is under `.venv`.
- The baseline import command prints `Baseline imports: OK`.
- `pip check` prints `No broken requirements found`.

`pip check` only evaluates packages that are already installed. It can report success after a failed requirements installation if the failing packages were never installed, so always run the import checks too.

`Get-Command python` and `where.exe python` are useful diagnostics after activation, but the printed `sys.executable` path is the authoritative check.

## Select `.venv` as the VS Code Notebook Kernel

Installing packages in `.venv` does not automatically switch an already-open notebook to that environment.

1. Open a notebook under `validation`.
2. Select the kernel name in the upper-right corner of the notebook editor.
3. Choose **Select Another Kernel** if necessary.
4. Choose **Python Environments**.
5. Select the interpreter whose path ends with `.venv\Scripts\python.exe` on Windows or `.venv/bin/python` on macOS/Linux.
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

- `Python` contains `.venv`.
- `requests` is loaded from `.venv`.
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
3. Select the repository's `.venv` kernel.
4. Check `os.getcwd()` with the preflight cell.

If the working directory is the repository root, change it once at the start of the notebook session:

```python
import os

if os.path.basename(os.getcwd()) != "validation":
    os.chdir("validation")

print(os.getcwd())
```

Do not run this cell repeatedly after the directory already ends with `validation`, or it will try to enter a nested directory.

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

For notebooks with `init_from_azd = True`, select the deployment environment first:

```powershell
azd env list
azd env select <environment-name>
azd env get-values
```

Never place access tokens, API keys, client secrets, or provider credentials in terminal history. Follow each notebook's secret-storage instructions, particularly its Azure Key Vault guidance.

## Baseline and Notebook-Specific Dependencies

`validation/requirements.txt` is the baseline dependency set for this validation suite. Some specialized notebooks intentionally install or upgrade additional packages in a setup cell:

- The agent-framework notebook uses `%pip` to install current framework-specific packages.
- The PII notebook can install `azure-cosmos` through `sys.executable -m pip` when its optional Cosmos DB section is used.

`%pip` installs into the active notebook kernel. Before running such a cell, confirm that `sys.executable` points to `.venv`. Restart the kernel after a package installation or upgrade, then rerun the notebook from the beginning.

## Normal Workflow After Initial Setup

You only create `.venv` and install the baseline requirements once. For later sessions:

1. Open the repository root in VS Code.
2. Optionally activate `.venv` in the terminal.
3. Run `az login` if your Azure session has expired.
4. Select the appropriate `azd` environment when the notebook uses it.
5. Open a notebook under `validation`.
6. Confirm its kernel is `.venv`.
7. Run the preflight cell and confirm the working directory.
8. Run notebook cells in order.

## Troubleshooting

### `ModuleNotFoundError: No module named 'requests'`

First inspect the active notebook kernel:

```python
import sys
print(sys.executable)
```

If the path does not contain `.venv`, select the `.venv` kernel. If it does contain `.venv`, install and verify through that exact interpreter from the repository root:

```powershell
.\.venv\Scripts\python.exe -m pip install requests
.\.venv\Scripts\python.exe -c "import requests; print(requests.__file__)"
```

Restart the notebook kernel afterward.

### `pip install -r requirements.txt` fails

Avoid bare `pip` and first confirm the environment:

```powershell
.\.venv\Scripts\python.exe -m pip --version
.\.venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
.\.venv\Scripts\python.exe -m pip install -r .\validation\requirements.txt
```

Read the first `ERROR:` line in the pip output. Common causes include an unsupported Python version, a corporate proxy or package-index restriction, unavailable build tools, or a package-version conflict. Capture the complete command output when asking for help; an exit code alone does not identify the failed package.

Check the environment's Python version directly:

```powershell
.\.venv\Scripts\python.exe --version
```

If it reports anything other than Python 3.11, install Python 3.11 and recreate `.venv` using the commands in **Recreate a damaged environment**. A virtual environment cannot be changed to another Python version in place.

#### `Failed to build 'pymsalruntime'`

`pymsalruntime` is a native dependency used by the pip-distributed Azure CLI. Its older source uses Python APIs removed in Python 3.12 and later, producing errors such as `Py_UNICODE* has been removed` or an incompatible `MSALRUNTIME_LOG_CALLBACK_ROUTINE`.

The validation notebooks do not need Azure CLI installed as a Python package. They execute the separately installed `az` command. The repository requirements therefore exclude `azure-cli` and treat it as a system prerequisite.

If this error occurred before that change, verify that the requirements file no longer contains an active `azure-cli` line:

```powershell
Select-String -Path .\validation\requirements.txt -Pattern '^azure-cli$'
.\.venv\Scripts\python.exe --version
```

The first command should return no match. Then rerun the requirements installation; pip can continue using the existing environment because the failed `pymsalruntime` build did not install that package:

```powershell
.\.venv\Scripts\python.exe -m pip install --dry-run -r .\validation\requirements.txt
.\.venv\Scripts\python.exe -m pip install -r .\validation\requirements.txt
.\.venv\Scripts\python.exe -m pip install ipykernel
```

If the dry run fails on another package, follow **Recreate a damaged environment** with Python 3.11. Confirm the external CLI independently:

```powershell
az --version
az account show --output table
```

#### `Failed building wheel for pydantic-core` or `Python 3.14 is newer than PyO3's maximum supported version`

This confirms that `.venv` was created with Python 3.14. The resolver selected a `pydantic-core` release whose native PyO3 layer supports Python only through 3.13. Installing Rust or setting `PYO3_USE_ABI3_FORWARD_COMPATIBILITY` is not the supported fix for this notebook suite.

Install Python 3.11, close any notebook kernel using `.venv`, and recreate the environment with the commands in **Recreate a damaged environment**. Verify the new interpreter before installing packages:

```powershell
.\.venv\Scripts\python.exe --version
```

It must report `Python 3.11.x`.

### A package installed successfully but the notebook cannot import it

The terminal and notebook are using different Python interpreters. Compare:

```powershell
.\.venv\Scripts\python.exe -c "import sys; print(sys.executable)"
```

with:

```python
import sys
print(sys.executable)
```

Both paths must identify the same `.venv` Python executable. Then restart the kernel.

### `No module named 'utils'` or `No module named 'apimtools'`

Check the notebook working directory:

```python
import os
print(os.getcwd())
```

It must end with `validation` because the notebooks add `../shared` to `sys.path`.

### PowerShell cannot run `Activate.ps1`

Activation is optional. Use `.\.venv\Scripts\python.exe -m pip` directly, or apply the current-user execution policy described earlier in this guide.

### `az` or `azd` is not recognized

Install the missing CLI, close all terminals, open a new terminal, and rerun `az --version` or `azd version`. `azd` is unnecessary when `init_from_azd = False`.

### Recreate a damaged environment

Virtual environments are disposable. Close notebooks and terminals using `.venv`, then remove and recreate it.

PowerShell from the repository root:

```powershell
Remove-Item -Recurse -Force .venv
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
.\.venv\Scripts\python.exe -m pip install -r .\validation\requirements.txt
.\.venv\Scripts\python.exe -m pip install ipykernel
```

Do not copy a `.venv` from another computer or repository. Recreate it from the requirements file.

## Maintaining the Environment

Use the environment's interpreter for all package operations:

```powershell
.\.venv\Scripts\python.exe -m pip list
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -m pip install --upgrade <package-name>
```

Avoid these patterns:

- `pip install ...` without verifying which Python owns `pip`.
- `py -m pip install ...` after `.venv` exists; the Python launcher can target global Python.
- `pip install --user ...` for notebook dependencies.
- Running notebook-specific `%pip` cells before selecting the `.venv` kernel.
- Committing `.venv`, generated credentials, or notebook secrets.