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

#===============================================================================
# AUTHENTICATION CHECK
#===============================================================================

Write-Host "[0] Step 0: Checking Azure authentication..." -ForegroundColor Cyan

# Check Azure CLI authentication
Write-Host "  Checking Azure CLI authentication..." -ForegroundColor Gray
try {
  $null = az account show 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Not authenticated"
  }
  $currentAccount = az account show --query "{name:name, id:id}" -o json | ConvertFrom-Json
  Write-Host "  [+] Azure CLI authenticated" -ForegroundColor Green
  Write-Host "  [i] Current account: $($currentAccount.name) ($($currentAccount.id))" -ForegroundColor DarkGray
} catch {
  Write-Host ""
  Write-Host "  [X] Not authenticated with Azure CLI" -ForegroundColor Red
  Write-Host "  [!] Please authenticate before running this script:" -ForegroundColor Yellow
  Write-Host "      1. Run: az login" -ForegroundColor Yellow
  Write-Host "      2. Set subscription: az account set --subscription <subscription-id>" -ForegroundColor Yellow
  Write-Host ""
  exit 1
}

# Check Azure Developer CLI authentication (optional but recommended)
Write-Host "  Checking Azure Developer CLI authentication..." -ForegroundColor Gray
try {
  $azdAuthStatus = azd auth login --check-status 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] Azure Developer CLI authenticated" -ForegroundColor Green
  } else {
    Write-Host "  [!] Azure Developer CLI not authenticated (optional)" -ForegroundColor Yellow
    Write-Host "  [i] You can authenticate with: azd auth login" -ForegroundColor DarkGray
  }
} catch {
  Write-Host "  [!] Azure Developer CLI not found or not authenticated (optional)" -ForegroundColor Yellow
  Write-Host "  [i] You can authenticate with: azd auth login" -ForegroundColor DarkGray
}

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
  #===============================================================================
  # TEMPLATE SPEC TOGGLE
  #===============================================================================

  # By default, this script uses Template Specs for wrapper modules. You can disable
  # this behavior for local/dev provisioning (avoids ts: restore/auth issues) by setting:
  #   AZURE_DEPLOY_TS=false

  $deployTemplateSpecs = $true
  if (-not [string]::IsNullOrWhiteSpace($env:AZURE_DEPLOY_TS)) {
    $raw = $env:AZURE_DEPLOY_TS.Trim().ToLowerInvariant()
    $deployTemplateSpecs = -not ($raw -in @('0', 'false', 'no', 'off'))
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
Write-Host "  Deploy Template Specs (AZURE_DEPLOY_TS): $deployTemplateSpecs" -ForegroundColor White
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

if (-not $deployTemplateSpecs) {
  Write-Host "[3] Step 3: Skipping Template Specs (AZURE_DEPLOY_TS=false)" -ForegroundColor Yellow
  Write-Host "  [i] Deploy will use local wrapper modules from ./bicep/deploy/wrappers" -ForegroundColor Gray
  $templateSpecs = @{}

  Write-Host ""
  Write-Host "[OK] Preprovision complete!" -ForegroundColor Green
  Write-Host "  Template Specs: disabled" -ForegroundColor White
  Write-Host "  Deploy directory ready: ./bicep/deploy/" -ForegroundColor White
  Write-Host ""
  exit 0
}

#===============================================================================
# STEP 3: TEMPLATE SPEC CREATION & PUBLISHING (PARALLEL)
#===============================================================================

# Initialize templateSpecs dictionary
$templateSpecs = @{}

# Step 3: Template Specs processing
Write-Host ""
if ($useExistingTemplateSpecs) {
  Write-Host "[3] Step 3: Getting existing Template Spec IDs (parallel)..." -ForegroundColor Cyan
} else {
  Write-Host "[3] Step 3: Building Template Specs (parallel)..." -ForegroundColor Cyan
}

$wrapperFiles = Get-ChildItem -Path $deployWrappersDir -Filter "*.bicep"

# Determine max parallel jobs (default: min of processor count or 10)
$maxParallelJobs = [Math]::Min([Environment]::ProcessorCount, 10)
if ($env:AZURE_PARALLEL_JOBS) {
  $maxParallelJobs = [int]$env:AZURE_PARALLEL_JOBS
}

Write-Host "  [i] Processing $($wrapperFiles.Count) wrappers with up to $maxParallelJobs parallel jobs" -ForegroundColor Gray
Write-Host ""

# Extract environment name once (used by all jobs)
$envPrefix = if ($TemplateSpecRG -match '^rg-(.+)$') { $matches[1] } else { 'main' }

# ScriptBlock for parallel job execution
$jobScriptBlock = {
  param($wrapperFilePath, $wrapperFileName, $wrapperName, $envPrefix, $TemplateSpecRG, $Location, $useExistingTemplateSpecs)
  
  # Truncate long wrapper names to avoid Template Spec name limits (64 chars max)
  $shortWrapperName = if ($wrapperName.Length -gt 40) {
    $parts = $wrapperName -split '\.'
    if ($parts.Count -ge 3) {
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
  
  # Build bicep to JSON only if we're creating new Template Specs
  $jsonPath = $null
  if (-not $useExistingTemplateSpecs) {
    $jsonPath = [System.IO.Path]::ChangeExtension($wrapperFilePath, '.json')
    try {
      if (Get-Command bicep -ErrorAction SilentlyContinue) {
        bicep build $wrapperFilePath --outfile $jsonPath 2>$null | Out-Null
      } else {
        az bicep build --file $wrapperFilePath --outfile $jsonPath 2>$null | Out-Null
      }
    } catch {
      return @{
        Success = $false
        WrapperName = $wrapperName
        WrapperFileName = $wrapperFileName
        Error = "Failed to build Bicep: $($_.Exception.Message)"
      }
    }
  }
  
  # Check for existing Template Spec or create new one
  try {
    $tsId = $null
    
    if ($useExistingTemplateSpecs) {
      # Use existing Template Specs from specified resource group
      $tsId = az ts show -g $TemplateSpecRG -n $tsName -v $version --query id -o tsv 2>$null
      if (-not $tsId) {
        $tsId = az ts show -g $TemplateSpecRG -n $tsName --query id -o tsv 2>$null
      }
      
      if ($tsId) {
        return @{
          Success = $true
          WrapperName = $wrapperName
          WrapperFileName = $wrapperFileName
          TemplateSpecId = $tsId
          TemplateSpecName = $tsName
          Action = 'Found'
        }
      } else {
        return @{
          Success = $false
          WrapperName = $wrapperName
          WrapperFileName = $wrapperFileName
          Error = "Template Spec not found: $tsName"
        }
      }
    } else {
      # Check if Template Spec exists
      $existingTemplateSpecs = az ts list -g $TemplateSpecRG --query "[?name=='$tsName'].name" -o tsv 2>$null
      $templateSpecExists = $existingTemplateSpecs -and $existingTemplateSpecs.Trim() -ne ''
      
      if ($templateSpecExists) {
        # Get existing Template Spec ID
        $tsId = az ts show -g $TemplateSpecRG -n $tsName -v $version --query id -o tsv 2>$null
        if (-not $tsId) {
          $tsId = az ts show -g $TemplateSpecRG -n $tsName --query id -o tsv 2>$null
        }
        
        return @{
          Success = $true
          WrapperName = $wrapperName
          WrapperFileName = $wrapperFileName
          TemplateSpecId = $tsId
          TemplateSpecName = $tsName
          Action = 'Reused'
        }
      } else {
        # Create new template spec
        az ts create -g $TemplateSpecRG -n $tsName -v $version -l $Location `
          --template-file $jsonPath `
          --display-name "Wrapper: $wrapperName" `
          --description "Auto-generated Template Spec for $wrapperName wrapper" `
          --only-show-errors 2>$null | Out-Null
        
        # Get Template Spec ID
        $tsId = az ts show -g $TemplateSpecRG -n $tsName -v $version --query id -o tsv 2>$null
        
        if ([string]::IsNullOrWhiteSpace($tsId)) {
          return @{
            Success = $false
            WrapperName = $wrapperName
            WrapperFileName = $wrapperFileName
            Error = "Failed to get Template Spec ID after creation"
          }
        }
        
        return @{
          Success = $true
          WrapperName = $wrapperName
          WrapperFileName = $wrapperFileName
          TemplateSpecId = $tsId
          TemplateSpecName = $tsName
          Action = 'Created'
        }
      }
    }
  }
  catch {
    return @{
      Success = $false
      WrapperName = $wrapperName
      WrapperFileName = $wrapperFileName
      Error = $_.Exception.Message
    }
  }
  finally {
    # Clean up JSON file
    if ($jsonPath -and (Test-Path $jsonPath)) {
      Remove-Item $jsonPath -Force -ErrorAction SilentlyContinue
    }
  }
}

# SPAWN PHASE: Create parallel jobs
$jobs = @()
$startTime = Get-Date

foreach ($wrapperFile in $wrapperFiles) {
  # Start background job
  $job = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList @(
    $wrapperFile.FullName,
    $wrapperFile.Name,
    $wrapperFile.BaseName,
    $envPrefix,
    $TemplateSpecRG,
    $Location,
    $useExistingTemplateSpecs
  )
  
  $jobs += @{
    Job = $job
    WrapperName = $wrapperFile.BaseName
  }
  
  # THROTTLE: Wait if too many jobs running
  while ((Get-Job -State Running).Count -ge $maxParallelJobs) {
    Start-Sleep -Milliseconds 100
  }
}

Write-Host "  [⚡] All $($jobs.Count) jobs spawned, monitoring completion..." -ForegroundColor Cyan
Write-Host ""

# MONITOR PHASE: Collect results as jobs complete
$completed = 0
$failed = 0
$actions = @{ Created = 0; Reused = 0; Found = 0 }

while ($jobs.Count -gt 0) {
  $remainingJobs = @()
  
  foreach ($jobInfo in $jobs) {
    $job = $jobInfo.Job
    
    if ($job.State -eq 'Completed') {
      $result = Receive-Job -Job $job
      Remove-Job -Job $job
      
      $completed++
      $progressPercent = [Math]::Round(($completed / $wrapperFiles.Count) * 100)
      
      if ($result.Success) {
        $templateSpecs[$result.WrapperFileName] = $result.TemplateSpecId
        $actions[$result.Action]++
        
        $actionSymbol = switch ($result.Action) {
          'Created' { '✓' }
          'Reused' { '↻' }
          'Found' { '→' }
        }
        
        Write-Host "  [$actionSymbol] ($completed/$($wrapperFiles.Count) | $progressPercent%) $($result.WrapperName)" -ForegroundColor Green
      } else {
        $failed++
        Write-Host "  [✗] ($completed/$($wrapperFiles.Count) | $progressPercent%) $($jobInfo.WrapperName) - $($result.Error)" -ForegroundColor Red
      }
    }
    elseif ($job.State -eq 'Failed') {
      $completed++
      $failed++
      $progressPercent = [Math]::Round(($completed / $wrapperFiles.Count) * 100)
      Write-Host "  [✗] ($completed/$($wrapperFiles.Count) | $progressPercent%) $($jobInfo.WrapperName) - job failed" -ForegroundColor Red
      Remove-Job -Job $job
    }
    else {
      # Job still running
      $remainingJobs += $jobInfo
    }
  }
  
  $jobs = $remainingJobs
  
  # Show progress indicator
  if ($jobs.Count -gt 0) {
    $runningCount = ($jobs.Job | Where-Object { $_.State -eq 'Running' }).Count
    Write-Progress -Activity "Building Template Specs" `
      -Status "$completed/$($wrapperFiles.Count) completed, $runningCount running" `
      -PercentComplete (($completed / $wrapperFiles.Count) * 100)
    
    Start-Sleep -Milliseconds 200
  }
}

Write-Progress -Activity "Building Template Specs" -Completed

# Calculate duration and speedup
$duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
$estimatedSequentialTime = $wrapperFiles.Count * 8  # Assume ~8s per wrapper sequentially
$speedup = if ($duration -gt 0) { [Math]::Round($estimatedSequentialTime / $duration, 1) } else { 1 }

# Summary
Write-Host ""
Write-Host "  [✓] Template Specs processing completed in $duration seconds!" -ForegroundColor Green
Write-Host "      Success: $($completed - $failed) | Failed: $failed" -ForegroundColor Cyan
if ($actions.Created -gt 0) { Write-Host "      Created: $($actions.Created)" -ForegroundColor White }
if ($actions.Reused -gt 0) { Write-Host "      Reused: $($actions.Reused)" -ForegroundColor White }
if ($actions.Found -gt 0) { Write-Host "      Found: $($actions.Found)" -ForegroundColor White }
if ($speedup -gt 1) {
  Write-Host "  [⚡] Speedup: ${speedup}x faster than sequential processing!" -ForegroundColor Yellow
}

#===============================================================================
# STEP 4: BICEP TEMPLATE TRANSFORMATION
#===============================================================================

# Step 4: Update main.bicep with Template Spec references (in-place)
Write-Host ""
if ($templateSpecs.Count -gt 0) {
  Write-Host "[4] Step 4: Updating main.bicep references..." -ForegroundColor Cyan
} else {
  Write-Host "[4] Step 4: Skipping main.bicep transformation (no Template Specs found)..." -ForegroundColor Yellow
}

$mainBicepPath = Join-Path $deployDir 'main.bicep'

if ((Test-Path $mainBicepPath) -and ($templateSpecs.Count -gt 0)) {
  $content = Get-Content $mainBicepPath -Raw
  $replacementCount = 0
  
  # Replace wrapper references with Template Spec references
  foreach ($wrapperFile in $templateSpecs.Keys) {
    $wrapperPath = "wrappers/$wrapperFile"
    
    # Convert ARM Resource ID to Bicep Template Spec format
    # From: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Resources/templateSpecs/{name}/versions/{version}
    # To: ts:{sub}/{rg}/{name}:{version}
    $tsId = $templateSpecs[$wrapperFile]
    
    # Skip if template spec ID is empty or invalid
    if ([string]::IsNullOrWhiteSpace($tsId)) {
      Write-Host "  [!] Skipping $wrapperFile - no valid Template Spec ID" -ForegroundColor Yellow
      continue
    }
    
    if ($tsId -match '/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.Resources/templateSpecs/([^/]+)/versions/([^/]+)') {
      $subscription = $matches[1]
      $resourceGroup = $matches[2] 
      $templateSpecName = $matches[3]
      $version = $matches[4]
      $tsReference = "ts:$subscription/$resourceGroup/$templateSpecName`:$version"
    } else {
      # Skip invalid template spec IDs to avoid empty references
      Write-Host "  [!] Skipping $wrapperFile - invalid Template Spec ID format: $tsId" -ForegroundColor Yellow
      continue
    }
    
    if ($content.Contains($wrapperPath)) {
      $content = $content.Replace("'$wrapperPath'", "'$tsReference'")
      $replacementCount++
      
      # Show clean, properly formatted replacement message
      Write-Host "  [+] Replaced:" -ForegroundColor Green
      Write-Host "    $wrapperPath" -ForegroundColor White
      Write-Host "    -> $tsReference" -ForegroundColor Gray
    }
  }
  
  # Save back to main.bicep (in-place replacement)
  Set-Content -Path $mainBicepPath -Value $content -Encoding UTF8
  Write-Host ""
  Write-Host "  [+] Updated deploy/main.bicep ($replacementCount references replaced)" -ForegroundColor Green

  #===============================================================================
  # STEP 5: APPLY TAGS
  #===============================================================================

  Write-Host ""
  Write-Host "[5] Step 5: Applying Resource Group tags..." -ForegroundColor Cyan
  Write-Host "[i] Temporarily applying Resource Group tags to ignore controls..." -ForegroundColor Yellow

  az group update --name $ResourceGroup --tags "SecurityControl=Ignore" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply tags to Resource Group: $ResourceGroup"
  }
  Write-Host "[+] Added tags to Resource Group: $ResourceGroup" -ForegroundColor Green

  if ($TemplateSpecRG -and ($TemplateSpecRG -ne $ResourceGroup)) {
    az group update --name $TemplateSpecRG --tags "SecurityControl=Ignore" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to apply tags to Template Spec Resource Group: $TemplateSpecRG"
    }
    Write-Host "[+] Added tags to Template Spec Resource Group: $TemplateSpecRG" -ForegroundColor Green
  }

  # Proactively restore Template Spec artifacts so subsequent `bicep build` / `azd provision`
  # does not fail due to auth/restore timing issues.
  Write-Host "" 
  Write-Host "[6] Step 6: Restoring Template Spec artifacts..." -ForegroundColor Cyan

  # Warm up token (helps avoid intermittent Azure CLI auth timeouts during restore)
  try {
    $null = az account get-access-token --resource https://management.azure.com/ --query expiresOn -o tsv 2>$null
  } catch {
    # non-fatal
  }

  $maxRestoreAttempts = 5
  for ($attempt = 1; $attempt -le $maxRestoreAttempts; $attempt++) {
    Write-Host "  [i] bicep restore attempt $attempt/$maxRestoreAttempts" -ForegroundColor Gray
    try {
      if (Get-Command bicep -ErrorAction SilentlyContinue) {
        bicep restore $mainBicepPath 2>$null | Out-Null
      } else {
        az bicep restore --file $mainBicepPath 2>$null | Out-Null
      }
      Write-Host "  [+] Artifact restore completed" -ForegroundColor Green
      break
    } catch {
      if ($attempt -eq $maxRestoreAttempts) {
        Write-Host "  [X] Artifact restore failed after $maxRestoreAttempts attempts" -ForegroundColor Red
        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "" 
        Write-Host "  [!] Fix suggestions:" -ForegroundColor Yellow
        Write-Host "      1) Run: az login" -ForegroundColor White
        Write-Host "      2) Run: az account set --subscription $SubscriptionId" -ForegroundColor White
        Write-Host "      3) Re-run: azd provision" -ForegroundColor White
        Write-Host "" 
        throw
      }
      $sleepSeconds = [Math]::Min(30, 2 * $attempt)
      Write-Host "  [!] Restore attempt failed; retrying in ${sleepSeconds}s..." -ForegroundColor Yellow
      Start-Sleep -Seconds $sleepSeconds
    }
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