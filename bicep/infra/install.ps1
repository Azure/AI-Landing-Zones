<#
        AI-Landing-Zones Jumpbox Setup Script – Custom Script Extension (CSE)

        Notes:
            - Always pulls the latest from the specified branch (default: main)
            - Does not use tags/manifests
            - Managed identity login is best-effort (continues if MI isn't available)
#>

Param (
    [string] $release = "main",

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
$stage2Marker = Join-Path $stateRoot 'stage2.completed'
$dockerOkMarker = Join-Path $stateRoot 'docker.engine.ok'
$persistedScriptPath = Join-Path $stateRoot 'install.ps1'
$postRebootTaskName = 'AI-Landing-Zones-PostReboot'

New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null

function Write-InstallState([string] $message) {
    $ts = (Get-Date).ToString('s')
    $line = "$ts $message"
    try { Add-Content -Path (Join-Path $stateRoot 'install.state.log') -Value $line -Encoding UTF8 } catch { }
    Write-Host $line
}

function Save-SelfToPersistentPath {
    try {
        $self = $MyInvocation.MyCommand.Path
        if (-not [string]::IsNullOrWhiteSpace($self) -and (Test-Path $self)) {
            Copy-Item -Path $self -Destination $persistedScriptPath -Force
        }
    } catch {
        Write-Host "WARNING: Failed to persist install.ps1 for post-reboot continuation: $_" -ForegroundColor Yellow
    }
}

function Register-PostRebootTask {
    param(
        [Parameter(Mandatory = $true)] [string] $ScriptPath
    )

    $argList = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $ScriptPath + '"'),
        '-release', ('"' + $release + '"'),
        '-azureTenantID', ('"' + $azureTenantID + '"'),
        '-azureSubscriptionID', ('"' + $azureSubscriptionID + '"'),
        '-AzureResourceGroupName', ('"' + $AzureResourceGroupName + '"'),
        '-azureLocation', ('"' + $azureLocation + '"'),
        '-AzdEnvName', ('"' + $AzdEnvName + '"'),
        '-resourceToken', ('"' + $resourceToken + '"'),
        '-useUAI', ('"' + $useUAI + '"')
    )

    $cmd = 'powershell.exe ' + ($argList -join ' ')

    try {
        schtasks /delete /tn $postRebootTaskName /f | Out-Null
    } catch { }

    schtasks /create /tn $postRebootTaskName /sc onstart /tr $cmd /ru SYSTEM /rl HIGHEST /f | Out-Null
    Write-InstallState "Registered post-reboot task: $postRebootTaskName"
}

function Unregister-PostRebootTask {
    try {
        schtasks /delete /tn $postRebootTaskName /f | Out-Null
        Write-InstallState "Removed post-reboot task: $postRebootTaskName"
    } catch { }
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

function Ensure-WindowsInstallerAvailable {
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
    $isStage2 = Test-Path $stage1Marker
    if ($isStage2 -and -not (Test-Path $stage2Marker)) {
        Write-InstallState "Entering post-reboot continuation (stage 2)."

        Add-ToPathIfExists -Paths @(
            (Join-Path $env:ProgramData 'chocolatey\bin'),
            'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin',
            'C:\Program Files\Git\cmd',
            'C:\Python311',
            'C:\Python311\Scripts',
            'C:\Program Files\PowerShell\7'
        )

        Write-Section "WSL finalize"
        try {
            Write-Host "Installing WSL (no distro) if needed (best-effort)"
            & wsl.exe --install --no-distribution 2>&1 | Out-String | Write-Host
        } catch {
            Write-Host "WARNING: wsl --install failed: $_" -ForegroundColor Yellow
        }

        try {
            Write-Host "Updating WSL (best-effort)"
            & wsl.exe --update 2>&1 | Out-String | Write-Host
            & wsl.exe --set-default-version 2 2>&1 | Out-String | Write-Host
        } catch {
            Write-Host "WARNING: WSL update/default-version failed: $_" -ForegroundColor Yellow
        }

        Write-Section "Docker finalize"
        try {
            Start-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
        } catch { }

        # Attempt to start Docker Desktop backend. Even if it can't show UI, this can initialize the engine.
        $dockerDesktopExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        if (Test-Path $dockerDesktopExe) {
            try { Start-Process -FilePath $dockerDesktopExe -WindowStyle Hidden | Out-Null } catch { }
        }

        $engineUp = Wait-ForDockerEngine -TimeoutSeconds 420
        if (-not $engineUp) {
            Write-Host "ERROR: Docker Engine did not become ready (\\\\.\\pipe\\docker_engine not found)." -ForegroundColor Red
            try { & docker version 2>&1 | Out-String | Write-Host } catch { }
            throw "Docker Engine not ready after reboot continuation."
        }

        try {
            & docker info 2>&1 | Out-String | Write-Host
        } catch {
            Write-Host "ERROR: docker info failed after engine pipe appeared: $_" -ForegroundColor Red
            throw
        }

        New-Item -ItemType File -Path $dockerOkMarker -Force | Out-Null
        New-Item -ItemType File -Path $stage2Marker -Force | Out-Null
        Unregister-PostRebootTask

        Write-InstallState "Stage 2 complete. Docker engine OK."
        return
    }

    if (Test-Path $stage2Marker) {
        Write-InstallState "Stage 2 already completed previously. Nothing to do."
        return
    }

    Write-InstallState "Entering initial run (stage 1)."

    Write-Section "Chocolatey"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    $chocoExe = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
    if (-not (Test-Path $chocoExe)) {
        throw "Chocolatey install completed but choco.exe was not found at $chocoExe."
    }

    Add-ToPathIfExists -Paths @(
        (Join-Path $env:ProgramData 'chocolatey\bin')
    )

    Write-Section "Tooling"

            'C:\\Program Files\\PowerShell\\7',
            'C:\\Program Files\\Docker\\Docker\\resources\\bin'
    Add-ToPathIfExists -Paths @(
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin',
        'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin'
    )
    Assert-CommandExists -CommandName 'az' -What 'Azure CLI'

    Invoke-CheckedCommand -FilePath $chocoExe -ArgumentList @('upgrade', 'git', '-y', '--ignoredetectedreboot', '--force', '--no-progress') -Description 'Installing/Upgrading Git'
    Add-ToPathIfExists -Paths @(
        'C:\Program Files\Git\cmd',
        'C:\Program Files\Git\bin'
    )
    Assert-CommandExists -CommandName 'git' -What 'Git'

    Write-Host "Ensuring Windows Installer service is available"
    Ensure-WindowsInstallerAvailable

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
    Write-Host "Dumping filesystem search for troubleshooting..."
    Get-ChildItem -Path "C:\" -Recurse -Filter "azd.exe" -ErrorAction SilentlyContinue | Select-Object FullName
    exit 1
} else {
    Write-Host "AZD successfully located at: $azdExe" -ForegroundColor Green
}

# Add to PATH for immediate use
$env:PATH = "$(Split-Path $azdExe);$env:PATH"
Write-Host "Updated PATH for this session: $env:PATH"

$azdDir = Split-Path $azdExe

try {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$azdDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$azdDir", "Machine")
        Write-Host "Added $azdDir to MACHINE Path"
    } else {
        Write-Host "AZD directory already present in MACHINE Path"
    }
} catch {
    Write-Host "Failed to update MACHINE Path: $_" -ForegroundColor Yellow
}

try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -and $userPath -notlike "*$azdDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$azdDir", "User")
        Write-Host "Added $azdDir to USER Path"
    } elseif (-not $userPath) {
        [Environment]::SetEnvironmentVariable("Path", $azdDir, "User")
        Write-Host "Initialized USER Path with AZD directory"
    } else {
        Write-Host "AZD directory already present in USER Path"
    }
} catch {
    Write-Host "Failed to update USER Path: $_" -ForegroundColor Yellow
}

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


    Write-Section "Repo"
    Write-Host "Cloning AI-Landing-Zones repo"
    New-Item -ItemType Directory -Path 'C:\github' -Force | Out-Null
    Set-Location 'C:\github'

    if (Test-Path "C:\github\AI-Landing-Zones") {
        Write-Host "Existing repo folder found; deleting for a clean clone"
        Remove-Item -Recurse -Force "C:\github\AI-Landing-Zones"
    }

    Invoke-CheckedCommand -FilePath 'git' -ArgumentList @('clone', 'https://github.com/Azure/AI-Landing-Zones', '-b', $release, '--depth', '1') -Description "git clone (branch: $release)"


    Write-Section "Azure Login (best-effort)"
    Write-Host "Logging into Azure (managed identity)"
    try {
        az login --identity | Out-Null
    } catch {
        Write-Host "WARNING: 'az login --identity' failed (no managed identity or blocked egress). Continuing." -ForegroundColor Yellow
    }

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

    Write-Section "Sanity Checks"
    Write-Host ("az version: {0}" -f ((az version | ConvertTo-Json -Compress) | Out-String))
    Invoke-CheckedCommand -FilePath 'git' -ArgumentList @('--version') -Description 'git --version'
    Invoke-CheckedCommand -FilePath 'python' -ArgumentList @('--version') -Description 'python --version'
    Invoke-CheckedCommand -FilePath $azdExe -ArgumentList @('version') -Description 'azd version'
    Invoke-CheckedCommand -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()') -Description 'pwsh version'

    Write-Section "Post-reboot continuation"
    Save-SelfToPersistentPath
    if (-not (Test-Path $persistedScriptPath)) {
        throw "Failed to persist install.ps1 to $persistedScriptPath for post-reboot continuation."
    }
    Register-PostRebootTask -ScriptPath $persistedScriptPath
    New-Item -ItemType File -Path $stage1Marker -Force | Out-Null

    Write-Section "Finish (stage 1)"
    Write-Host "Stage 1 completed. Rebooting in 60 seconds to finalize WSL + Docker Engine..."
    shutdown /r /t 60 /c "Rebooting to finalize WSL + Docker Desktop" | Out-Null
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
