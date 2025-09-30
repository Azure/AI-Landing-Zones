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
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path,
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
$deployDir = Join-Path $RepoRoot 'deploy'

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
# STEP 2: DIRECTORY CLEANUP
#===============================================================================

# Step 2: Clean up deploy directory
Write-Host "[2] Step 2: Cleaning up deploy directory..." -ForegroundColor Cyan
if (Test-Path $deployDir) {
  Remove-Item -Path $deployDir -Recurse -Force
  Write-Host "  [+] Removed deploy directory: ./deploy/" -ForegroundColor Green
} else {
  Write-Host "  [i] No deploy directory found to remove" -ForegroundColor Gray
}

#===============================================================================
# STEP 3: REMOVE TAGS
#===============================================================================

# Step 3: Remove temporary tags from resource groups
Write-Host ""
Write-Host "[3] Step 3: Removing temporary tags..." -ForegroundColor Cyan

# Remove tag from main resource group
if ($ResourceGroup) {
  try {
    Write-Host "  Removing temporary tags from resource group: $ResourceGroup" -ForegroundColor Gray
    az group update --name $ResourceGroup --remove tags.SecurityControl --only-show-errors | Out-Null
    Write-Host "  [+] Removed temporary tags from: $ResourceGroup" -ForegroundColor Green
  } catch {
    Write-Host "  [!] Warning: Failed to remove temporary tags from resource group: $ResourceGroup" -ForegroundColor Yellow
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

# Remove tag from Template Spec resource group if different
if ($TemplateSpecRG -and $TemplateSpecRG -ne $ResourceGroup) {
  try {
    Write-Host "  Removing temporary tags from Template Spec resource group: $TemplateSpecRG" -ForegroundColor Gray
    az group update --name $TemplateSpecRG --remove tags.SecurityControl --only-show-errors | Out-Null
    Write-Host "  [+] Removed temporary tags from: $TemplateSpecRG" -ForegroundColor Green
  } catch {
    Write-Host "  [!] Warning: Failed to remove temporary tags from Template Spec resource group: $TemplateSpecRG" -ForegroundColor Yellow
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

#===============================================================================
# COMPLETION SUMMARY
#===============================================================================

Write-Host ""
Write-Host "[OK] Cleanup complete!" -ForegroundColor Green
Write-Host ""