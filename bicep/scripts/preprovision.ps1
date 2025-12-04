<#
.SYNOPSIS
    Preprovision script for AI/ML Landing Zone with optional Template Specs

.DESCRIPTION
    This script:
    1. Creates a copy of the infra directory as 'deploy'
    2. Optionally builds Template Specs from all wrappers (controlled by AZURE_DEPLOY_TS)
    3. Optionally replaces wrapper references with Template Spec references in deploy/main.bicep
    4. Creates deploy/main.bicep ready for deployment

    Environment Variables:
    - AZURE_SUBSCRIPTION_ID: Required. Azure subscription ID (GUID format)
    - AZURE_LOCATION: Required. Azure region (e.g., eastus2, westus3)
    - AZURE_RESOURCE_GROUP: Required. Resource group name
    - AZURE_TS_RG: If set, uses existing Template Specs from this resource group instead of creating new ones

.EXAMPLE
    # Deploy with new Template Specs (default)
    ./scripts/preprovision.ps1
    
.EXAMPLE
    # Use existing Template Specs from another resource group
    $env:AZURE_TS_RG = "rg-shared-templates"
    ./scripts/preprovision.ps1
#>

# Suppress PSScriptAnalyzer warnings
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[CmdletBinding()]
param(
  [string]$BicepRoot = (Resolve-Path "$PSScriptRoot/..").Path,
  [string]$Location = $env:AZURE_LOCATION,
  [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
  [string]$ResourceGroup = $env:AZURE_RESOURCE_GROUP,
  [string]$TemplateSpecRG = $env:AZURE_TS_RG
)

$ErrorActionPreference = 'Stop'

#===============================================================================
# INITIALIZATION & VALIDATION
#===============================================================================

Write-Host ""
Write-Host "[*] AI/ML Landing Zone - Template Spec Preprovision" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor DarkGray
Write-Host ""

# Force interactive mode for console input
if (-not [Console]::IsInputRedirected) {
  # Enable console input for interactive prompts
  [Console]::TreatControlCAsInput = $false
}

# Check and prompt for required environment variables
$missingVars = @()
if (-not $Location) {
  $missingVars += "AZURE_LOCATION"
}
if (-not $ResourceGroup) {
  $missingVars += "AZURE_RESOURCE_GROUP"
}
if (-not $SubscriptionId) {
  $missingVars += "AZURE_SUBSCRIPTION_ID"
}

if ($missingVars.Count -gt 0) {
  Write-Host "[!] Some required environment variables are missing:" -ForegroundColor Yellow
  foreach ($var in $missingVars) {
    Write-Host "  - $var" -ForegroundColor Yellow
  }
  Write-Host ""
  Write-Host "[?] Let's set them interactively..." -ForegroundColor Cyan
  Write-Host ""
  
  # Prompt for AZURE_LOCATION if missing
  if (-not $Location) {
    $attempts = 0
    $maxAttempts = 50
    do {
      $attempts++
      if ($attempts -gt $maxAttempts) {
        Write-Host "  [X] Too many attempts. Exiting..." -ForegroundColor Red
        exit 1
      }
      Write-Host "Enter location (Azure region, e.g., eastus2, westus3, centralus): " -NoNewline -ForegroundColor White
      $Location = [Console]::ReadLine()
      if ($Location) { $Location = $Location.Trim() }
      if ([string]::IsNullOrWhiteSpace($Location)) {
        Write-Host "  [!] Location cannot be empty. Please enter a valid Azure region." -ForegroundColor Red
      }
    } while ([string]::IsNullOrWhiteSpace($Location))
    
    Write-Host "  [+] Setting AZURE_LOCATION = '$Location'" -ForegroundColor Green
    try {
      & azd env set AZURE_LOCATION $Location
      $env:AZURE_LOCATION = $Location
      Write-Host "  [+] Successfully set AZURE_LOCATION" -ForegroundColor Green
    } catch {
      Write-Host "  [X] Failed to set AZURE_LOCATION using azd: $($_.Exception.Message)" -ForegroundColor Red
      Write-Host "  [i] Setting as environment variable for this session only" -ForegroundColor Yellow
      $env:AZURE_LOCATION = $Location
    }
  }
  
  # Prompt for AZURE_RESOURCE_GROUP if missing
  if (-not $ResourceGroup) {
    $attempts = 0
    $maxAttempts = 50
    do {
      $attempts++
      if ($attempts -gt $maxAttempts) {
        Write-Host "  [X] Too many attempts. Exiting..." -ForegroundColor Red
        exit 1
      }
      Write-Host "Enter resourceGroup name (e.g., rg-myproject, rg-aiml-dev): " -NoNewline -ForegroundColor White
      $ResourceGroup = [Console]::ReadLine()
      if ($ResourceGroup) { $ResourceGroup = $ResourceGroup.Trim() }
      if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
        Write-Host "  [!] ResourceGroup name cannot be empty. Please enter a valid name." -ForegroundColor Red
      }
    } while ([string]::IsNullOrWhiteSpace($ResourceGroup))
    
    Write-Host "  [+] Setting AZURE_RESOURCE_GROUP = '$ResourceGroup'" -ForegroundColor Green
    try {
      & azd env set AZURE_RESOURCE_GROUP $ResourceGroup
      $env:AZURE_RESOURCE_GROUP = $ResourceGroup
      Write-Host "  [+] Successfully set AZURE_RESOURCE_GROUP" -ForegroundColor Green
    } catch {
      Write-Host "  [X] Failed to set AZURE_RESOURCE_GROUP using azd: $($_.Exception.Message)" -ForegroundColor Red
      Write-Host "  [i] Setting as environment variable for this session only" -ForegroundColor Yellow
      $env:AZURE_RESOURCE_GROUP = $ResourceGroup
    }
  }
  
  # Prompt for AZURE_SUBSCRIPTION_ID if missing
  if (-not $SubscriptionId) {
    $attempts = 0
    $maxAttempts = 50
    do {
      $attempts++
      if ($attempts -gt $maxAttempts) {
        Write-Host "  [X] Too many attempts. Exiting..." -ForegroundColor Red
        exit 1
      }
      Write-Host "Enter subscription ID (Azure subscription GUID): " -NoNewline -ForegroundColor White
      $SubscriptionId = [Console]::ReadLine()
      if ($SubscriptionId) { $SubscriptionId = $SubscriptionId.Trim() }
      if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        Write-Host "  [!] Subscription ID cannot be empty. Please enter a valid Azure subscription GUID." -ForegroundColor Red
      } elseif ($SubscriptionId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        Write-Host "  [!] Invalid subscription ID format. Please enter a valid GUID format (e.g., 12345678-1234-1234-1234-123456789012)." -ForegroundColor Red
        $SubscriptionId = $null
      }
    } while ([string]::IsNullOrWhiteSpace($SubscriptionId))
    
    Write-Host "  [+] Setting AZURE_SUBSCRIPTION_ID = '$SubscriptionId'" -ForegroundColor Green
    try {
      & azd env set AZURE_SUBSCRIPTION_ID $SubscriptionId
      $env:AZURE_SUBSCRIPTION_ID = $SubscriptionId
      Write-Host "  [+] Successfully set AZURE_SUBSCRIPTION_ID" -ForegroundColor Green
    } catch {
      Write-Host "  [X] Failed to set AZURE_SUBSCRIPTION_ID using azd: $($_.Exception.Message)" -ForegroundColor Red
      Write-Host "  [i] Setting as environment variable for this session only" -ForegroundColor Yellow
      $env:AZURE_SUBSCRIPTION_ID = $SubscriptionId
    }
  }
  
  Write-Host ""
}

# Determine behavior based on AZURE_TS_RG
$useExistingTemplateSpecs = -not [string]::IsNullOrWhiteSpace($TemplateSpecRG)

if (-not $TemplateSpecRG) {
  $TemplateSpecRG = $ResourceGroup
}

Write-Host "[i] Configuration:" -ForegroundColor Yellow
Write-Host "  Subscription ID: $SubscriptionId" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White  
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Template Spec RG: $TemplateSpecRG" -ForegroundColor White
Write-Host "  Use Existing Template Specs: $useExistingTemplateSpecs" -ForegroundColor White
Write-Host ""

#===============================================================================
# STEP 1: SETUP & DIRECTORY PREPARATION
#===============================================================================

# Define paths
$infraDir = Join-Path $BicepRoot 'infra'
$deployDir = Join-Path $BicepRoot 'deploy'
$deployWrappersDir = Join-Path $deployDir 'wrappers'

# Step 1: Copy infra directory to deploy
Write-Host "[1] Step 1: Creating deploy directory..." -ForegroundColor Cyan
if (Test-Path $deployDir) {
  Remove-Item -Path $deployDir -Recurse -Force
  Write-Host "  Removed existing deploy directory" -ForegroundColor Gray
}

Copy-Item -Path $infraDir -Destination $deployDir -Recurse
Write-Host "  [+] Copied infra → deploy" -ForegroundColor Green

#===============================================================================
# STEP 2: AZURE AUTHENTICATION & RESOURCE GROUP SETUP
#===============================================================================

# Step 2: Set Azure subscription
Write-Host ""
Write-Host "[2] Step 2: Azure setup..." -ForegroundColor Cyan
if ($SubscriptionId -and ($SubscriptionId.Trim() -ne '')) {
  az account set --subscription $SubscriptionId | Out-Null
  Write-Host "  [+] Set subscription: $SubscriptionId" -ForegroundColor Green
}

# Ensure resource groups exist
Write-Host "  Checking resource groups..." -ForegroundColor Gray

# Check if main resource group exists
$rgExists = $null
$ErrorActionPreference = 'SilentlyContinue'
$rgExists = az group show --name $ResourceGroup --only-show-errors --query name --output tsv
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($rgExists)) {
  Write-Host "  Creating resource group: $ResourceGroup" -ForegroundColor Yellow
  try {
    az group create --name $ResourceGroup --location $Location --only-show-errors | Out-Null
    Write-Host "  [+] Created resource group: $ResourceGroup" -ForegroundColor Green
  } catch {
    Write-Host "  [X] Failed to create resource group: $ResourceGroup" -ForegroundColor Red
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [!] Possible solutions:" -ForegroundColor Yellow
    Write-Host "      1. Ensure you have 'Contributor' or 'Owner' role on the subscription" -ForegroundColor White
    Write-Host "      2. Ask your Azure administrator to create the resource group" -ForegroundColor White
    Write-Host "      3. Use an existing resource group you have access to" -ForegroundColor White
    Write-Host "      4. Check if you're signed into the correct Azure account: az account show" -ForegroundColor White
    Write-Host ""
    exit 1
  }
} else {
  Write-Host "  [+] Resource group already exists: $ResourceGroup" -ForegroundColor Green
}

# Check Template Spec resource group if different (only create if not using existing)
if ($TemplateSpecRG -ne $ResourceGroup -and -not $useExistingTemplateSpecs) {
  $tsRgExists = $null
  $ErrorActionPreference = 'SilentlyContinue'
  $tsRgExists = az group show --name $TemplateSpecRG --only-show-errors --query name --output tsv
  $ErrorActionPreference = 'Stop'
  
  if ([string]::IsNullOrWhiteSpace($tsRgExists)) {
    Write-Host "  Creating Template Spec resource group: $TemplateSpecRG" -ForegroundColor Yellow
    try {
      az group create --name $TemplateSpecRG --location $Location --only-show-errors | Out-Null
      Write-Host "  [+] Created Template Spec resource group: $TemplateSpecRG" -ForegroundColor Green
    } catch {
      Write-Host "  [X] Failed to create Template Spec resource group: $TemplateSpecRG" -ForegroundColor Red
      Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
      Write-Host ""
      Write-Host "  [!] Possible solutions:" -ForegroundColor Yellow
      Write-Host "      1. Ensure you have 'Contributor' or 'Owner' role on the subscription" -ForegroundColor White
      Write-Host "      2. Ask your Azure administrator to create the resource group" -ForegroundColor White
      Write-Host "      3. Set AZURE_TS_RG to an existing resource group you have access to" -ForegroundColor White
      Write-Host "      4. Remove AZURE_TS_RG to use the same RG as the main deployment" -ForegroundColor White
      Write-Host ""
      exit 1
    }
  } else {
    Write-Host "  [+] Template Spec resource group already exists: $TemplateSpecRG" -ForegroundColor Green
  }
}

#===============================================================================
# STEP 3: TEMPLATE SPEC CREATION & PUBLISHING
#===============================================================================

# Initialize templateSpecs dictionary
$templateSpecs = @{}

# Step 3: Template Specs processing
Write-Host ""
if ($useExistingTemplateSpecs) {
  Write-Host "[3] Step 3: Getting existing Template Spec IDs..." -ForegroundColor Cyan
} else {
  Write-Host "[3] Step 3: Building Template Specs..." -ForegroundColor Cyan
}

$wrapperFiles = Get-ChildItem -Path $deployWrappersDir -Filter "*.bicep"

foreach ($wrapperFile in $wrapperFiles) {
  $wrapperName = $wrapperFile.BaseName
  # Extract environment name from TemplateSpecRG (assumes rg-<envname> pattern, fallback to 'main')
  $envPrefix = if ($TemplateSpecRG -match '^rg-(.+)$') { $matches[1] } else { 'main' }
  
  # Truncate long wrapper names to avoid Template Spec name limits (64 chars max)
  $shortWrapperName = if ($wrapperName.Length -gt 40) {
    # For long names, create meaningful abbreviations
    $parts = $wrapperName -split '\.'
    if ($parts.Count -ge 3) {
      # Take first letter of each part except the last, plus full last part
      $abbreviated = ($parts[0..($parts.Count-2)] | ForEach-Object { $_.Substring(0, 1) }) -join '.'
      "$abbreviated.$($parts[-1])"
    } else {
      $wrapperName.Substring(0, 40)
    }
  } else {
    $wrapperName
  }
  
  $tsName = "ts-$envPrefix-wrp-$shortWrapperName"
  $version = "current"
  
  Write-Host "  Processing: $wrapperName" -ForegroundColor Yellow
  
  # Build bicep to JSON only if we're creating new Template Specs
  $jsonPath = $null
  if (-not $useExistingTemplateSpecs) {
    $jsonPath = Join-Path $wrapperFile.Directory "$($wrapperName).json"
    try {
      if (Get-Command bicep -ErrorAction SilentlyContinue) {
        bicep build $wrapperFile.FullName --outfile $jsonPath
      } else {
        az bicep build --file $wrapperFile.FullName --outfile $jsonPath
      }
      Write-Host "    [+] Built JSON: $wrapperName.json" -ForegroundColor Green
    } catch {
      Write-Host "    [X] Failed to build: $wrapperName" -ForegroundColor Red
      continue
    }
  }
  
  # Check for existing Template Spec or create new one
  try {
    if ($useExistingTemplateSpecs) {
      # Use existing Template Specs from specified resource group
      Write-Host "    [?] Looking for existing Template Spec..." -ForegroundColor Gray
      $tsId = az ts show -g $TemplateSpecRG -n $tsName -v $version --query id -o tsv 2>$null
      if (-not $tsId) {
        # If version doesn't exist, get the latest version ID
        $tsId = az ts show -g $TemplateSpecRG -n $tsName --query id -o tsv 2>$null
      }
      
      if ($tsId) {
        $templateSpecs[$wrapperFile.Name] = $tsId
        Write-Host "    [+] Found existing Template Spec: $tsName" -ForegroundColor Green
      } else {
        Write-Host "    [!] Template Spec not found: $tsName" -ForegroundColor Yellow
      }
    } else {
      Write-Host "    [?] Checking if Template Spec exists..." -ForegroundColor Gray

      # Check if Template Spec exists by listing all in resource group and filtering
      $existingTemplateSpecs = az ts list -g $TemplateSpecRG --query "[?name=='$tsName'].name" -o tsv 2>$null
      $templateSpecExists = $existingTemplateSpecs -and $existingTemplateSpecs.Trim() -ne ''

      if ($templateSpecExists) {
        Write-Host "    [i] Template Spec already exists, skipping..." -ForegroundColor Cyan

        # Get existing Template Spec ID (specific version when available)
        $tsId = az ts show -g $TemplateSpecRG -n $tsName -v $version --query id -o tsv 2>$null
        if (-not $tsId) {
          $tsId = az ts show -g $TemplateSpecRG -n $tsName --query id -o tsv 2>$null
        }

        $templateSpecs[$wrapperFile.Name] = $tsId
        Write-Host "    [+] Using existing Template Spec: $tsName" -ForegroundColor Green
      } else {
        Write-Host "    [+] Creating new Template Spec..." -ForegroundColor Gray -NoNewline
        # Create new template spec with version
        $job = Start-Job -ScriptBlock {
          param($TemplateSpecRG, $tsName, $version, $Location, $jsonPath, $wrapperName)
          az ts create -g $TemplateSpecRG -n $tsName -v $version -l $Location --template-file $jsonPath --display-name "Wrapper: $wrapperName" --description "Auto-generated Template Spec for $wrapperName wrapper" --only-show-errors 2>$null
        } -ArgumentList $TemplateSpecRG, $tsName, $version, $Location, $jsonPath, $wrapperName

        # Wait with progress indicator (max 5 minutes)
        $timeout = 300 # 5 minutes
        $elapsed = 0
        while ($job.State -eq 'Running' -and $elapsed -lt $timeout) {
          Start-Sleep 2
          Write-Host "." -ForegroundColor Gray -NoNewline
          $elapsed += 2

          # Show elapsed time every 20 seconds
          if ($elapsed % 20 -eq 0) {
            Write-Host " ($($elapsed)s)" -ForegroundColor DarkGray -NoNewline
          }
        }

        if ($job.State -eq 'Running') {
          Stop-Job $job
          Remove-Job $job -Force
          Write-Host ""
          throw "Template Spec operation timed out after $timeout seconds"
        }

        $result = Receive-Job $job -Wait
        Remove-Job $job
        Write-Host "" # New line after progress dots

        Write-Host "    [i] Getting Template Spec ID..." -ForegroundColor Gray
        # Get Template Spec ID
        $tsId = az ts show -g $TemplateSpecRG -n $tsName -v $version --query id -o tsv 2>$null

        if ([string]::IsNullOrWhiteSpace($tsId)) {
          Write-Host "    [X] Failed to get Template Spec ID for: $tsName" -ForegroundColor Red
          # Don't add to templateSpecs dictionary if creation failed
        } else {
          $templateSpecs[$wrapperFile.Name] = $tsId
          Write-Host "    [+] Published Template Spec:" -ForegroundColor Green
          Write-Host "      $tsName" -ForegroundColor White
        }
      }
    }
  }
  catch {
    Write-Host "    [X] Failed to process Template Spec:" -ForegroundColor Red
    Write-Host "      $wrapperName" -ForegroundColor White
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
  }

  # Clean up JSON file only if it was created
  if (-not $useExistingTemplateSpecs -and $jsonPath -and (Test-Path $jsonPath)) {
    Remove-Item $jsonPath -Force
  }
}

#===============================================================================
# STEP 4: BICEP TEMPLATE TRANSFORMATION
#===============================================================================

# Step 4: Update all bicep files with Template Spec references
Write-Host ""
if ($templateSpecs.Count -gt 0) {
  Write-Host "[4] Step 4: Updating bicep references..." -ForegroundColor Cyan
  
  # Find all bicep files in deploy directory
  $bicepFiles = Get-ChildItem -Path $deployDir -Filter "*.bicep" -Recurse
  
  foreach ($file in $bicepFiles) {
    Write-Host "  Processing: $($file.Name)" -ForegroundColor Gray
    
    $content = Get-Content $file.FullName -Raw
    $fileModified = $false
    $replacementCount = 0
    
    # Replace wrapper references with Template Spec references
    foreach ($wrapperFile in $templateSpecs.Keys) {
      $tsId = $templateSpecs[$wrapperFile]
      
      # Skip if template spec ID is empty or invalid
      if ([string]::IsNullOrWhiteSpace($tsId)) {
        continue
      }
      
      if ($tsId -match '/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.Resources/templateSpecs/([^/]+)/versions/([^/]+)') {
        $subscription = $matches[1]
        $resourceGroup = $matches[2] 
        $templateSpecName = $matches[3]
        $version = $matches[4]
        $tsReference = "ts:$subscription/$resourceGroup/$templateSpecName`:$version"
        
        # Pattern 1: 'wrappers/file.bicep' (used in main.bicep)
        $wrapperPath = "wrappers/$wrapperFile"
        if ($content.Contains("'$wrapperPath'")) {
          $content = $content.Replace("'$wrapperPath'", "'$tsReference'")
          $replacementCount++
          $fileModified = $true
        }
        
        # Pattern 2: '../wrappers/file.bicep' (used in modules/*.bicep)
        $wrapperPathRel = "../wrappers/$wrapperFile"
        if ($content.Contains("'$wrapperPathRel'")) {
          $content = $content.Replace("'$wrapperPathRel'", "'$tsReference'")
          $replacementCount++
          $fileModified = $true
        }
      }
    }
    
    if ($fileModified) {
      Set-Content -Path $file.FullName -Value $content -Encoding UTF8
      Write-Host "    [+] Updated references in $($file.Name)" -ForegroundColor Green
    }
  }
  
  Write-Host ""
  Write-Host "  [+] Updated bicep files with Template Spec references" -ForegroundColor Green
} else {
  Write-Host "[4] Step 4: Skipping bicep transformation (no Template Specs found)..." -ForegroundColor Yellow
}

#===============================================================================
# STEP 5: APPLY TAGS
#===============================================================================

# Step 5: Apply tags to resource groups
Write-Host ""
Write-Host "[5] Step 5: Applying tags..." -ForegroundColor Cyan

# Apply tag to main resource group
try {
  Write-Host "  Applying tags to resource group: $ResourceGroup" -ForegroundColor Gray
  az group update --name $ResourceGroup --tags "SecurityControl=Ignore" --only-show-errors | Out-Null
  Write-Host "  [+] Applied tags to: $ResourceGroup" -ForegroundColor Green
} catch {
  Write-Host "  [!] Warning: Failed to apply tags to resource group: $ResourceGroup" -ForegroundColor Yellow
  Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Apply tag to Template Spec resource group if different
if ($TemplateSpecRG -ne $ResourceGroup) {
  try {
    Write-Host "  Applying tags to Template Spec resource group: $TemplateSpecRG" -ForegroundColor Gray
    az group update --name $TemplateSpecRG --tags "SecurityControl=Ignore" --only-show-errors | Out-Null
    Write-Host "  [+] Applied tags to: $TemplateSpecRG" -ForegroundColor Green
  } catch {
    Write-Host "  [!] Warning: Failed to apply tags to Template Spec resource group: $TemplateSpecRG" -ForegroundColor Yellow
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

#===============================================================================
# COMPLETION SUMMARY
#===============================================================================

Write-Host ""
Write-Host "[OK] Preprovision complete!" -ForegroundColor Green
if ($useExistingTemplateSpecs) {
  Write-Host "  Using existing Template Specs: $($templateSpecs.Count)" -ForegroundColor White
  Write-Host "  Template Spec references updated in main.bicep" -ForegroundColor White
} else {
  Write-Host "  Template Specs created: $($templateSpecs.Count)" -ForegroundColor White
  Write-Host "  Template Spec references updated in main.bicep" -ForegroundColor White
}
Write-Host "  Deploy directory ready: ./bicep/deploy/" -ForegroundColor White
Write-Host ""