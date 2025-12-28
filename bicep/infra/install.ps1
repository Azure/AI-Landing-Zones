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

Start-Transcript -Path C:\WindowsAzure\Logs\AI-Landing-Zones_CustomScriptExtension.txt -Append

[Net.ServicePointManager]::SecurityProtocol = "tls12"

Write-Host "`n==================== PARAMETERS ====================" -ForegroundColor Cyan
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    $name = $_.Key
    $value = if ([string]::IsNullOrWhiteSpace($_.Value)) { "<empty>" } else { $_.Value }
    Write-Host ("{0,-25}: {1}" -f $name, $value)
}
Write-Host "====================================================`n" -ForegroundColor Cyan


# ------------------------------
# Install Chocolatey
# ------------------------------
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

$env:Path += ";C:\ProgramData\chocolatey\bin"


# ------------------------------
# Install tooling
# ------------------------------
write-host "Installing Visual Studio Code"
choco upgrade vscode -y --ignoredetectedreboot --force

write-host "Installing Azure CLI"
choco install azure-cli -y --ignoredetectedreboot --force

# Add Azure CLI to PATH immediately
$env:PATH = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin;$env:PATH"


write-host "Installing Git"
choco upgrade git -y --ignoredetectedreboot --force
$env:PATH = "C:\Program Files\Git\cmd;$env:PATH"


write-host "Installing Python 3.11"
choco install python311 -y --ignoredetectedreboot --force

Write-Host "Installing AZD..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"

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


# ------------------------------
# Install PowerShell Core, Notepad++, WSL, Docker
# ------------------------------
write-host "Installing PowerShell Core"
choco install powershell-core -y --ignoredetectedreboot --force

write-host "Installing Notepad++"
choco install notepadplusplus -y --ignoredetectedreboot --force


# WSL Setup
write-host "Enabling WSL features"
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

write-host "Updating WSL"
Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile ".\wsl_update_x64.msi"
Start-Process "msiexec.exe" -ArgumentList "/i .\wsl_update_x64.msi /quiet" -NoNewWindow -Wait
wsl.exe --update
wsl.exe --set-default-version 2


# Docker
write-host "Installing Docker Desktop"
choco install docker-desktop -y --ignoredetectedreboot --force


# ------------------------------
# Clone AI-Landing-Zones repo
# ------------------------------
write-host "Cloning AI-Landing-Zones repo"
mkdir C:\github -ea SilentlyContinue
cd C:\github
if (Test-Path "C:\github\AI-Landing-Zones") {
    write-host "Existing repo folder found; deleting for a clean clone"
    Remove-Item -Recurse -Force "C:\github\AI-Landing-Zones"
}

git clone https://github.com/Azure/AI-Landing-Zones -b $release --depth 1


# ------------------------------
# Azure Login (best-effort)
# ------------------------------
write-host "Logging into Azure (managed identity)"
try {
    az login --identity | Out-Null
} catch {
    Write-Host "WARNING: 'az login --identity' failed (no managed identity or blocked egress). Continuing." -ForegroundColor Yellow
}

write-host "Logging into AZD (managed identity)"
try {
    & $azdExe auth login --managed-identity | Out-Null
} catch {
    Write-Host "WARNING: 'azd auth login --managed-identity' failed. Continuing." -ForegroundColor Yellow
}


# ------------------------------
# AZD initialization (best-effort)
# ------------------------------
cd C:\github\AI-Landing-Zones\
write-host "Initializing AZD environment (best-effort)"

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


git config --global --add safe.directory "C:/github/AI-Landing-Zones"

# Always reboot to complete Docker Desktop and WSL2 setup
write-host "Installation completed successfully!";
write-host "Rebooting in 30 seconds to complete setup...";
$runTime = (Get-Date).AddMinutes(1).ToString("HH:mm")
schtasks /create /tn "FinishSetupReboot" /sc once /st $runTime /tr "shutdown /r /t 0 /c 'Rebooting after CSE setup'" /ru SYSTEM /f

Stop-Transcript
