<#
        AI-Landing-Zones Jumpbox Setup Script – Custom Script Extension (CSE)

        Notes:
            - Always pulls the latest from the specified branch (default: main)
            - Does not use tags/manifests
            - Managed identity login is best-effort (continues if MI isn't available)
#>

Param (
    [string] $release = "main",

        # Defaults tuned for Azure VM Custom Script Extension (CSE): install tools and exit successfully.
        # Set to $false only if you explicitly want the old multi-stage reboot/WSL finalize flow.
        [bool] $skipReboot = $true,
        [bool] $skipRepoClone = $true,
        [bool] $skipAzdInit = $true,

  [string] $azureTenantID,
  [string] $azureSubscriptionID,
  [string] $AzureResourceGroupName,
  [string] $azureLocation,
  [string] $AzdEnvName,
  [string] $resourceToken,
  [string] $useUAI 
)

$stateRoot = 'C:\ProgramData\AI-Landing-Zones'
$stage1Marker = Join-Path $stateRoot 'stage1.completed'

New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null

function Write-InstallState([string] $message) {
    $ts = (Get-Date).ToString('s')
    $line = "$ts $message"
    try { Add-Content -Path (Join-Path $stateRoot 'install.state.log') -Value $line -Encoding UTF8 } catch { }
    Write-Host $line
}

function Unregister-PostRebootTask {
    # Reboots/post-reboot continuation are intentionally disabled.
    # Keep as a no-op to avoid breaking older code paths.
    return
}

function Wait-ForDockerEngine {
    param(
        [int] $TimeoutSeconds = 300
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path '\\.\pipe\docker_engine') {
            return $true
        }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Wait-ForDockerInfo {
    param(
        [int] $TimeoutSeconds = 600
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $last = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $last = (& docker info 2>&1 | Out-String)
            if ($LASTEXITCODE -eq 0) {
                return $last
            }
        } catch {
            $last = $_.ToString()
        }

        Start-Sleep -Seconds 10
    }

    throw "docker info did not succeed within ${TimeoutSeconds}s. Last output: $last"
}

function Install-WslKernelUpdateBestEffort {
    try {
        Write-Host "Installing WSL kernel update MSI (best-effort)"
        $wslMsi = Join-Path $env:TEMP 'wsl_update_x64.msi'
        Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile $wslMsi -UseBasicParsing
        $wslProc = Start-Process "msiexec.exe" -ArgumentList "/i `"$wslMsi`" /quiet /norestart" -NoNewWindow -Wait -PassThru
        Write-Host "WSL MSI exit code: $($wslProc.ExitCode)"
        Remove-Item -Force $wslMsi -ErrorAction SilentlyContinue
    } catch {
        Write-Host "WARNING: WSL kernel update MSI install failed: $_" -ForegroundColor Yellow
    }
}

function Install-WslMsiFromGitHubBestEffort {
    try {
        Write-Host "Installing WSL MSI from GitHub Releases (best-effort)"
        $wslMsiUrl = 'https://github.com/microsoft/WSL/releases/latest/download/wsl.msi'
        $wslMsiPath = Join-Path $env:TEMP 'wsl.msi'

        Invoke-WebRequest -Uri $wslMsiUrl -OutFile $wslMsiPath -UseBasicParsing
        $proc = Start-Process "msiexec.exe" -ArgumentList "/i `"$wslMsiPath`" /quiet /norestart" -NoNewWindow -Wait -PassThru
        Write-Host "WSL MSI (GitHub) exit code: $($proc.ExitCode)"

        Remove-Item -Force $wslMsiPath -ErrorAction SilentlyContinue
    } catch {
        Write-Host "WARNING: WSL MSI (GitHub) install failed: $_" -ForegroundColor Yellow
    }
}

function Test-WslInstalled {
    try {
        $txt = (& wsl.exe --status 2>&1 | Out-String)
        $txt = $txt -replace "`0", ''
        if ($txt -match 'not installed') {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

Start-Transcript -Path C:\WindowsAzure\Logs\AI-Landing-Zones_CustomScriptExtension.txt -Append

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Section([string] $title) {
    Write-Host "\n==================== $title ====================" -ForegroundColor Cyan
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)] [string] $FilePath,
        [Parameter(Mandatory = $true)] [string[]] $ArgumentList,
        [Parameter(Mandatory = $true)] [string] $Description
    )

    Write-Host $Description
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed (exit code: $LASTEXITCODE)."
    }
}

function Invoke-BestEffortCommand {
    param(
        [Parameter(Mandatory = $true)] [string] $FilePath,
        [Parameter(Mandatory = $true)] [string[]] $ArgumentList,
        [Parameter(Mandatory = $true)] [string] $Description
    )

    try {
        Write-Host $Description
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "$Description failed (exit code: $LASTEXITCODE)."
        }
        return $true
    } catch {
        Write-Host "WARNING: $Description failed: $_" -ForegroundColor Yellow
        try {
            $chocoLog = Join-Path $env:ProgramData 'chocolatey\logs\chocolatey.log'
            if (Test-Path $chocoLog) {
                Write-Host "\n---- Tail of Chocolatey log ($chocoLog) ----" -ForegroundColor Yellow
                Get-Content -Path $chocoLog -Tail 120 -ErrorAction SilentlyContinue
                Write-Host "---- End Chocolatey log ----\n" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "WARNING: Failed to dump Chocolatey logs: $_" -ForegroundColor Yellow
        }
        return $false
    }
}

function Assert-CommandExists {
    param(
        [Parameter(Mandatory = $true)] [string] $CommandName,
        [Parameter(Mandatory = $true)] [string] $What
    )

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Required tool missing after install: $What (command '$CommandName' not found on PATH)."
    }
}

function Assert-PathExists {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $What
    )

    if (-not (Test-Path $Path)) {
        throw "Required component missing after install: $What (expected path not found: $Path)."
    }
}

function Add-ToPathIfExists {
    param([string[]] $Paths)

    foreach ($p in $Paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-Path $p) {
            if ($env:PATH -notlike "*$p*") {
                $env:PATH = "$p;$env:PATH"
            }
        }
    }
}

function Update-ProcessPathFromRegistry {
    try {
        $machinePath = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path' -ErrorAction SilentlyContinue).Path
        $userPath = (Get-ItemProperty -Path 'HKCU:\Environment' -Name 'Path' -ErrorAction SilentlyContinue).Path

        $combined = @()
        if (-not [string]::IsNullOrWhiteSpace($machinePath)) { $combined += $machinePath }
        if (-not [string]::IsNullOrWhiteSpace($userPath)) { $combined += $userPath }

        if ($combined.Count -gt 0) {
            $env:Path = ($combined -join ';')
        }
    } catch {
        Write-Host "WARNING: Failed to refresh PATH from registry: $_" -ForegroundColor Yellow
    }
}

function Resolve-AzureCliPath {
    $cmd = Get-Command 'az' -ErrorAction SilentlyContinue
    if ($cmd) {
        if ($cmd.PSObject.Properties.Match('Path').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($cmd.Path)) {
            return $cmd.Path
        }
        return 'az'
    }

    $candidatePaths = @(
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd',
        'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd',
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.ps1',
        'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.ps1'
    )

    foreach ($p in $candidatePaths) {
        if (Test-Path $p) {
            return $p
        }
    }

    return $null
}

function Assert-AzureCliAvailable {
    param([Parameter(Mandatory = $true)] [string] $What)

    Update-ProcessPathFromRegistry
    Add-ToPathIfExists -Paths @(
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin',
        'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin'
    )

    $azPath = Resolve-AzureCliPath
    if (-not $azPath) {
        throw "Required tool missing after install: $What (Azure CLI not found on PATH and not found in known install locations)."
    }

    return $azPath
}

function Add-ToEnvironmentPath {
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('Machine', 'User')] [string] $Scope,
        [Parameter(Mandatory = $true)] [string[]] $Paths
    )

    foreach ($p in $Paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (-not (Test-Path $p)) { continue }

        try {
            $existing = [Environment]::GetEnvironmentVariable('Path', $Scope)
            if ([string]::IsNullOrWhiteSpace($existing)) {
                [Environment]::SetEnvironmentVariable('Path', $p, $Scope)
                continue
            }

            if ($existing -notlike "*$p*") {
                [Environment]::SetEnvironmentVariable('Path', "$existing;$p", $Scope)
            }
        } catch {
            Write-Host "WARNING: Failed to update $Scope PATH with '$p': $_" -ForegroundColor Yellow
        }
    }
}

function Enable-WindowsInstallerAvailable {
    try {
        $svc = Get-Service -Name 'msiserver' -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.StartType -eq 'Disabled') {
                sc.exe config msiserver start= demand | Out-Null
            }
            if ($svc.Status -ne 'Running') {
                Start-Service -Name 'msiserver' -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        }
    } catch {
        Write-Host "WARNING: Failed to start Windows Installer service (msiserver): $_" -ForegroundColor Yellow
    }

    # If Python (and other installers) still fail with 1601, attempt a light re-registration.
    try {
        & msiexec.exe /regserver | Out-Null
    } catch {
        Write-Host "WARNING: Failed to re-register Windows Installer: $_" -ForegroundColor Yellow
    }
}

Write-Host "`n==================== PARAMETERS ====================" -ForegroundColor Cyan
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    $name = $_.Key
    $value = if ([string]::IsNullOrWhiteSpace($_.Value)) { "<empty>" } else { $_.Value }
    Write-Host ("{0,-25}: {1}" -f $name, $value)
}
Write-Host "====================================================`n" -ForegroundColor Cyan
try {
    if (Test-Path $stage1Marker) {
        Write-InstallState "Stage 1 already completed previously. Nothing to do."
        return
    }

    Write-InstallState "Entering initial run (stage 1)."

    Write-Section "Chocolatey"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    $chocoExe = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
    if (-not (Test-Path $chocoExe)) {
        throw "Chocolatey install completed but choco.exe was not found at $chocoExe."
    }

    Add-ToPathIfExists -Paths @(
        (Join-Path $env:ProgramData 'chocolatey\bin')
    )

    Write-Section "Tooling"

    # MSI-based installs (Azure CLI, Python, Docker Desktop, etc.) can fail if Windows Installer is disabled.
    Write-Host "Ensuring Windows Installer service is available"
    Enable-WindowsInstallerAvailable

    Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'azure-cli', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading Azure CLI'
    try {
        $script:AzCliPath = Assert-AzureCliAvailable -What 'Azure CLI'
    } catch {
        Write-Host "WARNING: Azure CLI not detected immediately after install (PATH propagation in CSE can lag). Continuing." -ForegroundColor Yellow
        $script:AzCliPath = Resolve-AzureCliPath
    }
    Add-ToEnvironmentPath -Scope Machine -Paths @(
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin',
        'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin'
    )
    Add-ToEnvironmentPath -Scope User -Paths @(
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin',
        'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin'
    )
    Update-ProcessPathFromRegistry

    Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'git', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading Git'
    Add-ToPathIfExists -Paths @(
        'C:\Program Files\Git\cmd',
        'C:\Program Files\Git\bin'
    )
    Assert-CommandExists -CommandName 'git' -What 'Git'

    $pythonExe = 'C:\Python311\python.exe'
    if (Test-Path $pythonExe) {
        Write-Host "Python already present at $pythonExe; skipping Chocolatey python311 install."
        Add-ToPathIfExists -Paths @(
            'C:\Python311',
            'C:\Python311\Scripts'
        )
        Assert-CommandExists -CommandName 'python' -What 'Python'
    } else {
        Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'python311', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading Python 3.11'
        Add-ToPathIfExists -Paths @(
            'C:\Python311',
            'C:\Python311\Scripts'
        )
        Assert-CommandExists -CommandName 'python' -What 'Python'
    }

    Add-ToEnvironmentPath -Scope Machine -Paths @('C:\Python311', 'C:\Python311\Scripts')
    Add-ToEnvironmentPath -Scope User -Paths @('C:\Python311', 'C:\Python311\Scripts')
    Update-ProcessPathFromRegistry

    Write-Section "AZD"
    Write-Host "Installing AZD..."
    $azdMsiUrl = 'https://github.com/Azure/azure-dev/releases/latest/download/azd-windows-amd64.msi'
    $azdMsiPath = Join-Path $env:TEMP 'azd-windows-amd64.msi'

    Write-Host "Downloading AZD MSI from GitHub Releases: $azdMsiUrl"
    Invoke-WebRequest -Uri $azdMsiUrl -OutFile $azdMsiPath -UseBasicParsing

    Write-Host "Installing AZD MSI..."
    $azdProc = Start-Process "msiexec.exe" -ArgumentList "/i `"$azdMsiPath`" /quiet /norestart" -NoNewWindow -Wait -PassThru
    if ($azdProc.ExitCode -ne 0) {
        throw "AZD MSI installation failed (exit code: $($azdProc.ExitCode))."
    }
    Remove-Item -Force $azdMsiPath -ErrorAction SilentlyContinue

Write-Host "Searching for installed AZD executable..."

$possibleAzdLocations = @(
    "C:\Program Files\Azure Dev CLI\azd.exe",
    "C:\Program Files (x86)\Azure Dev CLI\azd.exe",
    "C:\ProgramData\azd\bin\azd.exe",
    "C:\Windows\System32\azd.exe",
    "C:\Windows\azd.exe",
    "C:\Users\testvmuser\.azure-dev\bin\azd.exe",
    "$env:LOCALAPPDATA\Programs\Azure Dev CLI\azd.exe",
    "$env:LOCALAPPDATA\Azure Dev CLI\azd.exe"
)

$azdExe = $null

foreach ($path in $possibleAzdLocations) {
    if (Test-Path $path) {
        $azdExe = $path
        break
    }
}

if (-not $azdExe) {
    Write-Host "ERROR: azd.exe not found after installation. Installation path changed or MSI failed." -ForegroundColor Red
    Write-Host "Searched these locations:" -ForegroundColor Yellow
    $possibleAzdLocations | ForEach-Object { Write-Host (" - {0}" -f $_) -ForegroundColor Yellow }
    exit 1
} else {
    Write-Host "AZD successfully located at: $azdExe" -ForegroundColor Green
}

$azdDir = Split-Path $azdExe

# Ensure azd is available both in this run and for interactive sessions.
Add-ToEnvironmentPath -Scope Machine -Paths @($azdDir)
Add-ToEnvironmentPath -Scope User -Paths @($azdDir)
Add-ToPathIfExists -Paths @($azdDir)
Update-ProcessPathFromRegistry

    Write-Section "More Tools (best-effort)"

    Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'vscode', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading Visual Studio Code'
    Assert-PathExists -Path 'C:\Program Files\Microsoft VS Code\Code.exe' -What 'Visual Studio Code'

    Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'powershell-core', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading PowerShell Core'
    Add-ToPathIfExists -Paths @('C:\Program Files\PowerShell\7')
    Assert-CommandExists -CommandName 'pwsh' -What 'PowerShell Core (pwsh)'

    Write-Section "WSL prerequisites"
    try {
        Write-Host "Enabling WSL features (requires reboot to take effect)"
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null

        Write-Host "Installing WSL update MSI (best-effort)"
        $wslMsi = Join-Path $env:TEMP 'wsl_update_x64.msi'
        Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile $wslMsi -UseBasicParsing
        $wslProc = Start-Process "msiexec.exe" -ArgumentList "/i `"$wslMsi`" /quiet /norestart" -NoNewWindow -Wait -PassThru
        if ($wslProc.ExitCode -ne 0) {
            throw "WSL MSI installation failed (exit code: $($wslProc.ExitCode))."
        }
        Remove-Item -Force $wslMsi -ErrorAction SilentlyContinue
    } catch {
        Write-Host "WARNING: WSL prerequisites setup failed: $_" -ForegroundColor Yellow
    }

    Write-Section "Docker Desktop"
    Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'docker-desktop', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading Docker Desktop'
    Assert-PathExists -Path 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -What 'Docker Desktop'

    # Ensure docker CLI is available for interactive sessions.
    Add-ToEnvironmentPath -Scope Machine -Paths @('C:\Program Files\Docker\Docker\resources\bin')
    Add-ToEnvironmentPath -Scope User -Paths @('C:\Program Files\Docker\Docker\resources\bin')
    Add-ToPathIfExists -Paths @('C:\Program Files\Docker\Docker\resources\bin')
    Update-ProcessPathFromRegistry


    if (-not $skipRepoClone) {
        Write-Section "Repo"
        Write-Host "Cloning AI-Landing-Zones repo"
        New-Item -ItemType Directory -Path 'C:\github' -Force | Out-Null
        Set-Location 'C:\github'

        if (Test-Path "C:\github\AI-Landing-Zones") {
            Write-Host "Existing repo folder found; deleting for a clean clone"
            Remove-Item -Recurse -Force "C:\github\AI-Landing-Zones"
        }

        Invoke-CheckedCommand -FilePath 'git' -ArgumentList @('clone', 'https://github.com/Azure/AI-Landing-Zones', '-b', $release, '--depth', '1') -Description "git clone (branch: $release)"
    } else {
        Write-Host "Skipping repo clone (skipRepoClone=true)." -ForegroundColor Yellow
    }


    if (-not $skipAzdInit -and -not $skipRepoClone) {
        Write-Section "Azure Login (best-effort)"
        Write-Host "Logging into Azure (managed identity)"
        $azCli = if ($script:AzCliPath) { $script:AzCliPath } else { 'az' }
        Invoke-BestEffortCommand -FilePath $azCli -ArgumentList @('login', '--identity', '--allow-no-subscriptions') -Description "az login --identity --allow-no-subscriptions"

        Write-Host "Logging into AZD (managed identity)"
        try {
            & $azdExe auth login --managed-identity | Out-Null
        } catch {
            Write-Host "WARNING: 'azd auth login --managed-identity' failed. Continuing." -ForegroundColor Yellow
        }

        Write-Section "AZD init (best-effort)"
        Set-Location 'C:\github\AI-Landing-Zones'
        Write-Host "Initializing AZD environment (best-effort)"

        try {
            & $azdExe init -e $AzdEnvName --subscription $azureSubscriptionID --location $azureLocation | Out-Null
            & $azdExe env set AZURE_TENANT_ID $azureTenantID | Out-Null
            & $azdExe env set AZURE_RESOURCE_GROUP $AzureResourceGroupName | Out-Null
            & $azdExe env set AZURE_SUBSCRIPTION_ID $azureSubscriptionID | Out-Null
            & $azdExe env set AZURE_LOCATION $azureLocation | Out-Null
            & $azdExe env set RESOURCE_TOKEN $resourceToken | Out-Null
        } catch {
            Write-Host "WARNING: azd init/env set failed. Continuing." -ForegroundColor Yellow
        }

        Invoke-CheckedCommand -FilePath 'git' -ArgumentList @('config', '--global', '--add', 'safe.directory', 'C:/github/AI-Landing-Zones') -Description 'Configuring git safe.directory'
    } else {
        Write-Host "Skipping Azure login + azd init (skipAzdInit=true)." -ForegroundColor Yellow
    }

    Write-Section "Sanity Checks"
    try {
        $azCli = if ($script:AzCliPath) { $script:AzCliPath } else { 'az' }
        $azVersionRaw = & $azCli 'version' 2>&1 | Out-String
        Write-Host ("az version (raw): {0}" -f $azVersionRaw.Trim())
    } catch {
        Write-Host "WARNING: Failed to print az version: $_" -ForegroundColor Yellow
    }
    Invoke-BestEffortCommand -FilePath 'git' -ArgumentList @('--version') -Description 'git --version'
    Invoke-BestEffortCommand -FilePath 'python' -ArgumentList @('--version') -Description 'python --version'
    Invoke-BestEffortCommand -FilePath $azdExe -ArgumentList @('version') -Description 'azd version'
    Invoke-BestEffortCommand -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()') -Description 'pwsh version'

    New-Item -ItemType File -Path $stage1Marker -Force | Out-Null
    Write-InstallState "Install completed (stage 1 only). No reboot is performed by this script."
    Write-Host "Manual next steps (if you need Docker/WSL): enable WSL features, reboot the VM, then start Docker Desktop and validate 'docker info'." -ForegroundColor Yellow
    return
} catch {
    Write-Host "FATAL: install.ps1 failed: $_" -ForegroundColor Red
    try {
        $chocoLog = Join-Path $env:ProgramData 'chocolatey\logs\chocolatey.log'
        if (Test-Path $chocoLog) {
            Write-Host "\n---- Tail of Chocolatey log ($chocoLog) ----" -ForegroundColor Yellow
            Get-Content -Path $chocoLog -Tail 200 -ErrorAction SilentlyContinue
            Write-Host "---- End Chocolatey log ----\n" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WARNING: Failed to dump Chocolatey logs: $_" -ForegroundColor Yellow
    }

    throw
} finally {
    try { Stop-Transcript | Out-Null } catch { }
}
