<#
.SYNOPSIS
    Post-provision cleanup script for AI/ML Landing Zone

.DESCRIPTION
    This script removes the deploy directory created during preprovision.

.EXAMPLE
    ./scripts/postprovision.ps1
#>

[CmdletBinding()]
param(
  [string]$BicepRoot = (Resolve-Path "$PSScriptRoot/..").Path,
  [string]$ResourceGroup = $env:AZURE_RESOURCE_GROUP,
  [string]$TemplateSpecRG = $env:AZURE_TS_RG,
  [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID
)

$ErrorActionPreference = 'Stop'

#===============================================================================
# INITIALIZATION & VALIDATION
#===============================================================================

# Validate environment variables
$missingVars = @()
if (-not $ResourceGroup) {
  $missingVars += "AZURE_RESOURCE_GROUP"
}

if ($missingVars.Count -gt 0) {
  Write-Host "[X] Error: Missing required environment variables:" -ForegroundColor Red
  foreach ($var in $missingVars) {
    Write-Host "  - $var" -ForegroundColor Red
  }
  Write-Host ""
  Write-Host "[!] To set them, choose one option:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  Option 1 - Using azd (if using Azure Developer CLI):" -ForegroundColor Cyan
  foreach ($var in $missingVars) {
    Write-Host "    azd env set $var <value>" -ForegroundColor White
  }
  Write-Host ""
  Write-Host "  Option 2 - Using PowerShell environment variables:" -ForegroundColor Cyan
  foreach ($var in $missingVars) {
    Write-Host "    `$env:$var = `"your-value`"" -ForegroundColor White
  }
  Write-Host ""
  exit 1
}

Write-Host ""
Write-Host "[*] AI/ML Landing Zone - Post-Provision Cleanup" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor DarkGray
Write-Host ""

# Set default Template Spec RG if not specified
if (-not $TemplateSpecRG) {
  $TemplateSpecRG = $ResourceGroup
}

Write-Host "[i] Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Template Spec RG: $TemplateSpecRG" -ForegroundColor White
Write-Host ""

#===============================================================================
# AZURE AUTHENTICATION SETUP
#===============================================================================

# Set Azure subscription if specified
if ($SubscriptionId -and ($SubscriptionId.Trim() -ne '')) {
  az account set --subscription $SubscriptionId | Out-Null
  Write-Host "[+] Set subscription: $SubscriptionId" -ForegroundColor Green
}

# Define paths
$deployDir = Join-Path $BicepRoot 'deploy'

#===============================================================================
# STEP 1: TEMPLATE SPEC CLEANUP
#===============================================================================

# Step 1: Clean up Template Specs
Write-Host "[1] Step 1: Cleaning up Template Specs..." -ForegroundColor Cyan

# Only delete Template Specs if they are in the same RG as the deployment
# Don't delete from dedicated Template Spec RGs as they may be shared
if ($TemplateSpecRG -eq $ResourceGroup) {
  try {
    # Extract environment name from ResourceGroup (assumes rg-<envname> pattern, fallback to 'main')
    $envPrefix = if ($ResourceGroup -match '^rg-(.+)$') { $matches[1] } else { 'main' }
    $tsPattern = "ts-$envPrefix-wrp-*"
    
    Write-Host "  [?] Looking for Template Specs with pattern: $tsPattern" -ForegroundColor Gray
    
    # Get all Template Specs matching our pattern
    $templateSpecs = az ts list -g $TemplateSpecRG --query "[?starts_with(name, 'ts-$envPrefix-wrp-')].name" -o tsv 2>$null
    
    if ($templateSpecs -and $templateSpecs.Trim() -ne '') {
      $templateSpecsArray = $templateSpecs -split "`n" | Where-Object { $_.Trim() -ne '' }
      Write-Host "  [i] Found $($templateSpecsArray.Count) Template Specs to remove" -ForegroundColor Yellow
      
      foreach ($tsName in $templateSpecsArray) {
        $tsName = $tsName.Trim()
        if ($tsName) {
          Write-Host "    [X] Removing: $tsName" -ForegroundColor Gray
          try {
            az ts delete -g $TemplateSpecRG -n $tsName --yes --only-show-errors 2>$null
            Write-Host "    [+] Removed: $tsName" -ForegroundColor Green
          } catch {
            Write-Host "    [!] Failed to remove: $tsName" -ForegroundColor Yellow
          }
        }
      }
    } else {
      Write-Host "  [i] No Template Specs found matching pattern: $tsPattern" -ForegroundColor Gray
    }
  } catch {
    Write-Host "  [!] Error during Template Spec cleanup: $($_.Exception.Message)" -ForegroundColor Yellow
  }
} else {
  Write-Host "  [i] Template Specs are in dedicated RG ($TemplateSpecRG), skipping cleanup" -ForegroundColor Gray
  Write-Host "      (Dedicated Template Spec RGs may be shared and should not be auto-cleaned)" -ForegroundColor Gray
}

Write-Host ""

#===============================================================================
# STEP 2: REMOVE TEMPORARY TAGS
#===============================================================================

Write-Host "[2] Step 2: Removing temporary Resource Group tags..." -ForegroundColor Cyan
Write-Host "[i] Removing temporary Resource Group tags..." -ForegroundColor Yellow

try {
  $rgId = az group show --name $ResourceGroup --query id -o tsv
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rgId)) {
    throw "Failed to resolve resource ID for Resource Group: $ResourceGroup"
  }
  az tag update --resource-id $rgId --operation Delete --tags SecurityControl | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to remove tags from Resource Group: $ResourceGroup"
  }
  Write-Host "[+] Removed tags from Resource Group: $ResourceGroup" -ForegroundColor Green
} catch {
  Write-Host "[!] Failed to remove tags from Resource Group: $ResourceGroup" -ForegroundColor Yellow
  Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($TemplateSpecRG -and ($TemplateSpecRG -ne $ResourceGroup)) {
  try {
    $tsRgId = az group show --name $TemplateSpecRG --query id -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tsRgId)) {
      throw "Failed to resolve resource ID for Template Spec Resource Group: $TemplateSpecRG"
    }
    az tag update --resource-id $tsRgId --operation Delete --tags SecurityControl | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to remove tags from Template Spec Resource Group: $TemplateSpecRG"
    }
    Write-Host "[+] Removed tags from Template Spec Resource Group: $TemplateSpecRG" -ForegroundColor Green
  } catch {
    Write-Host "[!] Failed to remove tags from Template Spec Resource Group: $TemplateSpecRG" -ForegroundColor Yellow
    Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Write-Host ""

#===============================================================================
# STEP 3: CLEAN UP AI FOUNDRY WAIT DEPLOYMENT SCRIPTS
#===============================================================================

Write-Host "[3] Step 3: Removing AI Foundry capability-host wait deployment scripts..." -ForegroundColor Cyan

try {
  # Best-effort cleanup: these scripts are a transient workaround and should not be left behind.
  # If the resource type is not registered, the CLI isn't available, or the scripts don't exist,
  # we log and continue.
  $waitScripts = az resource list -g $ResourceGroup --resource-type Microsoft.Resources/deploymentScripts --query "[?ends_with(name, '-wait-capabilityhost')].name" -o tsv 2>$null

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to list deploymentScripts in Resource Group: $ResourceGroup"
  }

  if ($waitScripts -and $waitScripts.Trim() -ne '') {
    $waitScriptsArray = $waitScripts -split "`n" | Where-Object { $_.Trim() -ne '' }
    Write-Host "  [i] Found $($waitScriptsArray.Count) deployment script(s) to remove" -ForegroundColor Yellow

    foreach ($scriptName in $waitScriptsArray) {
      $scriptName = $scriptName.Trim()
      if ($scriptName) {
        Write-Host "    [X] Removing: $scriptName" -ForegroundColor Gray
        try {
          az resource delete -g $ResourceGroup --resource-type Microsoft.Resources/deploymentScripts -n $scriptName --only-show-errors 2>$null
          if ($LASTEXITCODE -ne 0) {
            throw "az resource delete failed"
          }
          Write-Host "    [+] Removed: $scriptName" -ForegroundColor Green
        } catch {
          Write-Host "    [!] Failed to remove: $scriptName" -ForegroundColor Yellow
        }
      }
    }
  } else {
    Write-Host "  [i] No AI Foundry wait deployment scripts found" -ForegroundColor Gray
  }
} catch {
  Write-Host "  [!] Error during deployment script cleanup: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

#===============================================================================
# STEP 4: DIRECTORY CLEANUP
#===============================================================================

# Step 4: Clean up deploy directory
Write-Host "[4] Step 4: Cleaning up deploy directory..." -ForegroundColor Cyan
if (Test-Path $deployDir) {
  Remove-Item -Path $deployDir -Recurse -Force
  Write-Host "  [+] Removed deploy directory: ./deploy/" -ForegroundColor Green
} else {
  Write-Host "  [i] No deploy directory found to remove" -ForegroundColor Gray
}

#===============================================================================
# COMPLETION SUMMARY
#===============================================================================

Write-Host ""
Write-Host "[OK] Cleanup complete!" -ForegroundColor Green
Write-Host ""