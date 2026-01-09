#!/usr/bin/env pwsh
#requires -Version 7
<#
Script: rm-rg.ps1
Overview:
  Safely and forcefully deletes an Azure Resource Group or its contents by removing common blockers first.
  Handles: NSG disassociations (NICs/subnets), Private Endpoints on subnets, Service Association Links (Azure Container Apps),
  subnet delegations/service endpoints/route tables/NAT gateways, VNet peerings, Private DNS zone VNet links, RG locks,
  plus heavy blockers: Container Apps, Managed Environments, Application Gateways, Azure Firewalls, Bastion, VMs/NICs,
  and Azure AI Search services (including shared private link resources and private endpoint connections cleanup).
  
  Behavior controlled by -DeleteResourceGroup parameter:
    Y (default): Deletes the entire resource group and all its contents
    N: Deletes only the resources inside the resource group, keeping the RG itself
  
  Triggers deletion and optionally polls for completion.

Exit codes:
  1 (input/validation), 2 (delete cmd failed), 3 (timeout), 4 (rollback to Succeeded after Deleting).

MANUAL DELETION GUIDE - If you want to delete manually:
  This script automates complex Azure resource group deletion by handling dependency blockers.
  If you prefer manual deletion, follow these high-level steps in the exact order shown below
  to avoid the common blockers that prevent resource group deletion:

  1. PREPARATION:
     • Remove any resource locks at the resource group level
     • Identify all NSGs (Network Security Groups) in the resource group

  2. NSG CLEANUP (for each NSG):
     • Remove NSG associations from all NICs (Network Interfaces) 
     • Remove NSG associations from all subnets
     • Delete the NSG itself

  3. HEAVY RESOURCE CLEANUP (delete in this order):
     • Delete all Container Apps
     • Delete all Container Apps Managed Environments  
     • Delete all Application Gateways
     • Delete all Azure Firewalls
     • Delete all Bastion hosts
     • Delete all Virtual Machines
     • Delete orphaned Network Interface Cards (NICs not attached to VMs or Private Endpoints)

  4. SEARCH SERVICES CLEANUP (for each Azure AI Search service):
     • Delete all shared private link resources
     • Delete all private endpoint connections
     • Enable public network access (if deletion fails due to private access restrictions)
     • Delete the search service

  5. VNET/SUBNET CLEANUP (for each VNet):
     • For each subnet:
       - Delete DevCenter environments, projects, network connections, and devcenters referencing the subnet
       - Delete Connected Environments, DevOps Infrastructure, App Service Environments, Batch pools referencing the subnet
       - Delete Private Endpoints on the subnet
       - Delete cross-RG Container Apps Managed Environments using the subnet
       - Delete Service Association Links (SALs) - may require ACA delegation
       - Remove subnet properties: NSG, route table, NAT gateway, delegations, service endpoints
       - Delete the subnet
     • Delete all VNet peerings
     • Remove Private DNS zone VNet links
     • Detach DDoS protection plans
     • Delete the VNet

  6. FINAL CLEANUP:
     • Remove any remaining resource locks
     • Delete the resource group (or remaining resources if keeping the RG)

  Note: Some resources may have cross-resource group dependencies that need to be resolved first.
        Wait between deletion steps as some operations are asynchronous.
#>

param(
  [switch]$Force,
  [switch]$NoWait,
  [switch]$Confirm,
  [int]$TimeoutMinutes = 20,
  [int]$PollSeconds = 10,
  # Max time to wait for a single Azure CLI call before failing (prevents indefinite hangs on auth/DNS/network issues)
  [int]$AzCliTimeoutSeconds = 90,
  # Reduce noisy Azure CLI stderr (still prints concise warnings). Use -ShowAzCliErrors to print raw az output.
  [switch]$ShowAzCliErrors,
  # Foundry/CognitiveServices: try to delete capability hosts first to avoid leftovers
  [switch]$SkipCapabilityHostCleanup,
  [string]$CapabilityHostApiVersion = '2025-04-01-preview',
  # Optional wait time after capability host deletion (service may take time to unlink resources)
  [int]$CapabilityHostSettleMinutes = 20,
  # After capability hosts are gone, optionally try deleting Cognitive Services accounts and retry on linkage/409
  [switch]$SkipCognitiveServicesAccountDelete,
  [int]$AccountDeleteRetryTimeoutMinutes = 25,
  [int]$AccountDeleteRetryPollSeconds = 15,
  # After deleting Cognitive Services accounts, optionally purge deleted accounts to force back-end cleanup/unlink.
  [switch]$SkipCognitiveServicesAccountPurge,
  [int]$AccountPurgeWaitMinutes = 20,
  [int]$AccountPurgeSettleMinutes = 20,
  [string]$AccountPurgeApiVersion = '2025-04-01-preview',
  [string[]]$AccountPurgeApiVersionFallbacks = @('2025-06-01','2024-10-01-preview','2023-05-01','2022-12-01'),
  [string]$TenantId,
  # Optional service principal (workaround for Conditional Access blocking public client ID 04b07795-8ddb-461a-bbee-02f9e1bf7b46)
  [string]$SpClientId,
  [string]$SpClientSecret,
  [string]$SpTenantId,
  # Alternative secret sourcing
  [string]$SpClientSecretFile,
  [switch]$PromptSpSecret,
  # Keep switch for parity (no-op now that Az fallback is gone)
  [switch]$ForceSAL,
  # Y: Delete RG and its content; N: Delete only RG content, keep the RG itself
  [ValidateSet('Y','N')]
  [string]$DeleteResourceGroup = 'Y'
)

# Relaunch in pwsh if running under Windows PowerShell (non-Core)
if ($PSVersionTable.PSEdition -ne 'Core') {
  $url = 'https://raw.githubusercontent.com/placerda/azure-utils/main/ps/rm-rg.ps1'
  $tmp = Join-Path $env:TEMP "rm-rg-$([guid]::NewGuid()).ps1"
  Invoke-WebRequest $url -OutFile $tmp
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $tmp @PSBoundParameters
  exit $LASTEXITCODE
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reduce Python warnings from some Azure CLI extensions (best-effort)
# Note: Azure CLI MSI uses an embedded Python; some extensions can emit deprecation warnings.
$env:PYTHONWARNINGS = 'ignore'

# Globals
$script:SUB = $null
$script:RG  = $null
$script:TENANT = $null
$script:DELETE_RG = 'Y'

# Prefer the Azure CLI PowerShell shim (azps.ps1) on Windows to avoid cmd.exe parsing edge-cases.
# This also tends to reduce noisy cmd-specific errors like "... was unexpected at this time.".
function Resolve-AzCliEntrypoint {
  try {
    $azCmd = (Get-Command az -ErrorAction Stop).Source
    if ($azCmd) {
      $wbin = Split-Path -Parent $azCmd
      $azps = Join-Path $wbin 'azps.ps1'
      if (Test-Path -Path $azps) { return $azps }
    }
  } catch { }
  return 'az'
}

$script:AZ_CLI_ENTRY = Resolve-AzCliEntrypoint

# Override `az` within this script scope so *all* subsequent calls use the chosen entrypoint.
function az {
  & $script:AZ_CLI_ENTRY @args
}

function Invoke-AzCli-WithTimeout {
  param(
    [Parameter(Mandatory = $true)] [string[]]$Arguments,
    [int]$TimeoutSeconds = 90,
    [switch]$ThrowOnNonZero
  )

  # NOTE: On Windows, Azure CLI is typically exposed as az.cmd (cmd.exe shim), which can be finicky
  # with some characters in arguments. When available, we prefer azps.ps1 (PowerShell shim) by
  # launching a pwsh process that runs azps.ps1 with the desired arguments.

  $psi = [System.Diagnostics.ProcessStartInfo]::new()

  $azEntry = $script:AZ_CLI_ENTRY
  $usePwshShim = $false
  if ($azEntry -and ($azEntry.ToString().ToLowerInvariant().EndsWith('.ps1')) -and (Test-Path -Path $azEntry)) {
    $usePwshShim = $true
  }

  if ($usePwshShim) {
    $pwshExe = Join-Path $PSHOME 'pwsh.exe'
    if (-not (Test-Path -Path $pwshExe)) {
      # Non-Windows fallback
      $pwshExe = Join-Path $PSHOME 'pwsh'
    }

    $psi.FileName = $pwshExe
    [void]$psi.ArgumentList.Add('-NoProfile')
    [void]$psi.ArgumentList.Add('-NonInteractive')
    [void]$psi.ArgumentList.Add('-ExecutionPolicy')
    [void]$psi.ArgumentList.Add('Bypass')
    [void]$psi.ArgumentList.Add('-File')
    [void]$psi.ArgumentList.Add($azEntry)
    foreach ($a in $Arguments) { [void]$psi.ArgumentList.Add($a) }
  } else {
    # Generic fallback: try to run az directly (works on non-Windows or when az is an actual executable).
    $psi.FileName = 'az'
    foreach ($a in $Arguments) { [void]$psi.ArgumentList.Add($a) }
  }

  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  try {
    [void]$p.Start()
  } catch {
    $cmd = ($usePwshShim ? "pwsh -File $azEntry" : 'az')
    throw "Failed to start Azure CLI process (${cmd} ...): $($_.Exception.Message)"
  }

  if (-not $p.WaitForExit([Math]::Max(1, $TimeoutSeconds) * 1000)) {
    try { $p.Kill($true) } catch { }
    throw "Azure CLI timed out after ${TimeoutSeconds}s: az $($Arguments -join ' ')"
  }

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $rc = $p.ExitCode

  if ($ThrowOnNonZero -and $rc -ne 0) {
    $msg = ($stderr ?? $stdout ?? '').ToString().Trim()
    throw "Azure CLI failed (rc=$rc): az $($Arguments -join ' ')${([Environment]::NewLine)}$msg"
  }

  return @{
    ExitCode = $rc
    StdOut   = $stdout
    StdErr   = $stderr
  }
}

# State file (remember last subscription/RG/tenant/deleteRG preference)
$StateFile = Join-Path $env:TEMP 'cleanup-nsgs-last.ps1'

# -------------------- Foundry / CapabilityHost helpers --------------------
function Get-AzAccessToken {
  try {
    $tok = az account get-access-token --query accessToken --output tsv 2>$null
    if (-not $tok) { return '' }
    return ($tok.ToString().Trim())
  } catch {
    return ''
  }
}

function Invoke-AzureMgmt-WebRequest {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('GET','DELETE')] [string]$Method,
    [Parameter(Mandatory=$true)] [string]$Url
  )

  $token = Get-AzAccessToken
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Failed to get Azure access token. Run 'az login' and ensure the subscription is set."
  }

  $headers = @{ Authorization = "Bearer $token" }

  try {
    # -SkipHttpErrorCheck allows us to inspect response even on non-2xx
    return Invoke-WebRequest -Method $Method -Uri $Url -Headers $headers -ContentType 'application/json' -SkipHttpErrorCheck
  } catch {
    # Some failures still carry a response object
    if ($_.Exception.Response) { return $_.Exception.Response }
    throw
  }
}

function Wait-AzureAsyncOperation {
  param(
    [Parameter(Mandatory=$true)] [string]$OperationUrl,
    [int]$TimeoutMinutes = 20,
    [int]$PollSeconds = 10
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $lastRaw = $null
  while ($sw.Elapsed.TotalMinutes -lt $TimeoutMinutes) {
    Start-Sleep -Seconds $PollSeconds

    $token = Get-AzAccessToken
    if ([string]::IsNullOrWhiteSpace($token)) {
      throw "Failed to refresh Azure access token while polling async operation."
    }
    $headers = @{ Authorization = "Bearer $token" }

    try {
      $resp = Invoke-RestMethod -Method GET -Uri $OperationUrl -Headers $headers -ContentType 'application/json'
      $lastRaw = $resp
    } catch {
      # Best-effort: transient network / throttling / eventual consistency
      Start-Sleep -Seconds ([Math]::Min(15, $PollSeconds))
      continue
    }

    $errCode = $null
    try { $errCode = $resp.error.code } catch { }
    if ($errCode -eq 'TransientError') {
      Write-Host "     (info) TransientError while polling; continuing…" -ForegroundColor DarkYellow
      continue
    }

    $status = $null
    try { $status = $resp.status } catch { }
    if ([string]::IsNullOrWhiteSpace($status)) {
      # Some operations return provisioningState
      try { $status = $resp.provisioningState } catch { }
    }

    if ([string]::IsNullOrWhiteSpace($status)) {
      Write-Host "     (warn) Could not determine async operation status; continuing…" -ForegroundColor DarkYellow
      continue
    }

    Write-Host "     · Async status: $status (elapsed $([int]$sw.Elapsed.TotalSeconds)s)"

    if ($status -in @('Succeeded','Success')) { return $true }
    if ($status -in @('Failed','Canceled','Cancelled')) { return $false }
    # otherwise keep polling: Deleting/InProgress/Running/etc
  }

  throw "Timed out waiting for async operation after ${TimeoutMinutes} minutes."
}

function Wait-CognitiveServices-CapabilityHosts-Gone {
  param(
    [Parameter(Mandatory=$true)] [string]$rg,
    [int]$TimeoutMinutes = 20,
    [int]$PollSeconds = 10
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $emptyStreak = 0
  while ($sw.Elapsed.TotalMinutes -lt $TimeoutMinutes) {
    Start-Sleep -Seconds $PollSeconds

    $capsLeft = @()
    try {
      $raw = az resource list -g $rg --query "[?starts_with(type,'Microsoft.CognitiveServices/') && contains(type,'capabilityHosts')].id" --output tsv 2>$null
      if ($raw) { $capsLeft = $raw -split "`n" }
    } catch {
      $capsLeft = @()
    }

    $capsLeft = @($capsLeft | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($capsLeft.Count -eq 0) {
      $emptyStreak++
      Write-Host "     · Remaining capability hosts: 0 (elapsed $([int]$sw.Elapsed.TotalSeconds)s)"
      # Two consecutive empty polls to avoid eventual-consistency blips
      if ($emptyStreak -ge 2) { return $true }
      continue
    }

    $emptyStreak = 0
    Write-Host "     · Remaining capability hosts: $($capsLeft.Count) (elapsed $([int]$sw.Elapsed.TotalSeconds)s)"
  }

  return $false
}

function Test-AzureResource-Exists {
  param([Parameter(Mandatory=$true)][string]$ResourceId)
  try {
    az resource show --ids $ResourceId --query id --output tsv 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Remove-CognitiveServices-Accounts-WithRetryInRg {
  param(
    [Parameter(Mandatory=$true)] [string]$rg,
    [int]$TimeoutMinutes = 25,
    [int]$PollSeconds = 15
  )

  Write-Host "   - Scanning RG for Microsoft.CognitiveServices/accounts…" -ForegroundColor Cyan
  $acctIds = @()
  try {
    $raw = az resource list -g $rg --resource-type Microsoft.CognitiveServices/accounts --query "[].id" --output tsv 2>$null
    if ($raw) { $acctIds = $raw -split "`n" }
  } catch { $acctIds = @() }
  $acctIds = @($acctIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

  if ($acctIds.Count -eq 0) {
    Write-Host "   - No Cognitive Services accounts found." -ForegroundColor DarkGreen
    return
  }

  foreach ($id in $acctIds) {
    $rid = $id.Trim()
    $name = $rid.Split('/')[-1]
    Write-Host "   - Attempting to delete account: $name" -ForegroundColor Cyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $accepted = $false
    while ($sw.Elapsed.TotalMinutes -lt $TimeoutMinutes) {
      # If it already vanished, we're done.
      if (-not (Test-AzureResource-Exists -ResourceId $rid)) {
        Write-Host "     · Account no longer exists." -ForegroundColor DarkGreen
        $accepted = $true
        break
      }

      # Try delete. Capture output because native failures don't throw by default.
      $out = ''
      try {
        $out = (az resource delete --ids $rid --no-wait 2>&1 | Out-String)
      } catch {
        $out = $_.ToString()
      }
      $rc = $LASTEXITCODE

      if ($rc -eq 0) {
        Write-Host "     · Delete request accepted (elapsed $([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor DarkGreen
        $accepted = $true
        break
      }

      $msg = ($out ?? '').ToString().Trim()
      $linkage = ($msg -match '(?i)conflict|409|capability\s*host|linked|linkage|unlink|still\s*in\s*use|InUse|being\s*deleted|DeletionInProgress')
      if ($linkage) {
        Write-Host "     · Still linked/unlinking; retrying in ${PollSeconds}s… (elapsed $([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor DarkYellow
        Start-Sleep -Seconds $PollSeconds
        continue
      }

      Write-Host "     (warn) Account delete failed (rc=$rc). Output: $msg" -ForegroundColor DarkYellow
      Start-Sleep -Seconds $PollSeconds
    }

    if (-not $accepted) {
      Write-Host "   (warn) Timed out waiting for account '$name' to accept deletion. Continuing RG cleanup…" -ForegroundColor DarkYellow
      continue
    }

    # Best-effort: wait for the account to disappear from ARM to avoid RG delete blockers.
    Write-Host "     · Waiting for account to disappear…" -ForegroundColor Cyan
    $gone = $false
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw2.Elapsed.TotalMinutes -lt $TimeoutMinutes) {
      Start-Sleep -Seconds $PollSeconds
      if (-not (Test-AzureResource-Exists -ResourceId $rid)) { $gone = $true; break }
      Write-Host "       - still present (elapsed $([int]$sw2.Elapsed.TotalSeconds)s)"
    }
    if ($gone) {
      Write-Host "     · Account deleted." -ForegroundColor DarkGreen
    } else {
      Write-Host "     (warn) Account still present after timeout; service may still be deleting in background." -ForegroundColor DarkYellow
    }
  }
}

function Get-CognitiveServices-Accounts-InRg {
  param([Parameter(Mandatory=$true)][string]$rg)

  $accts = @()
  try {
    $raw = az resource list -g $rg --resource-type Microsoft.CognitiveServices/accounts --query "[].{id:id,name:name,location:location}" --output json 2>$null
    if ($raw) { $accts = $raw | ConvertFrom-Json }
  } catch { $accts = @() }

  if (-not $accts) { return @() }
  return @($accts | Where-Object { $_.id -and $_.name })
}

function Test-CognitiveServices-DeletedAccount-Exists {
  param(
    [Parameter(Mandatory=$true)][string]$SubscriptionId,
    [Parameter(Mandatory=$true)][string]$Location,
    [Parameter(Mandatory=$true)][string]$AccountName,
    [Parameter(Mandatory=$true)][string]$ApiVersion
  )

  $url = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Location/deletedAccounts/$AccountName?api-version=$ApiVersion"
  try {
    $resp = Invoke-AzureMgmt-WebRequest -Method GET -Url $url
    $code = $null
    try { $code = [int]$resp.StatusCode } catch { }
    return ($code -ge 200 -and $code -lt 300)
  } catch {
    return $false
  }
}

function Invoke-CognitiveServices-DeletedAccount-Purge {
  param(
    [Parameter(Mandatory=$true)][string]$SubscriptionId,
    [Parameter(Mandatory=$true)][string]$Location,
    [Parameter(Mandatory=$true)][string]$AccountName,
    [Parameter(Mandatory=$true)][string]$ApiVersion,
    [int]$TimeoutMinutes = 20,
    [int]$PollSeconds = 10
  )

  $url = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Location/deletedAccounts/$AccountName?api-version=$ApiVersion"
  $resp = Invoke-AzureMgmt-WebRequest -Method DELETE -Url $url

  $code = $null
  try { $code = [int]$resp.StatusCode } catch { }
  if ($code -eq 404) { return @{ ok = $true; code = 404; message = 'NotFound' } }
  if ($code -eq 200 -or $code -eq 204) { return @{ ok = $true; code = $code; message = 'Deleted' } }

  $opUrl = $null
  try { $opUrl = $resp.Headers['Azure-AsyncOperation'] } catch { $opUrl = $null }
  if ([string]::IsNullOrWhiteSpace($opUrl)) {
    try { $opUrl = $resp.Headers['Location'] } catch { $opUrl = $null }
  }

  if (-not [string]::IsNullOrWhiteSpace($opUrl)) {
    $ok = Wait-AzureAsyncOperation -OperationUrl $opUrl -TimeoutMinutes $TimeoutMinutes -PollSeconds $PollSeconds
    return @{ ok = $ok; code = $code; message = 'Async' }
  }

  return @{ ok = ($code -ge 200 -and $code -lt 300); code = $code; message = 'NoAsyncHeader' }
}

function Purge-CognitiveServices-DeletedAccounts {
  param(
    [Parameter(Mandatory=$true)][string]$SubscriptionId,
    [Parameter(Mandatory=$true)][object[]]$Accounts,
    [int]$WaitMinutes = 20,
    [int]$SettleMinutes = 20,
    [string]$ApiVersion = '2025-04-01-preview',
    [string[]]$ApiVersionFallbacks = @('2025-06-01','2024-10-01-preview','2023-05-01','2022-12-01'),
    [int]$TimeoutMinutes = 20,
    [int]$PollSeconds = 10
  )

  if (-not $Accounts -or $Accounts.Count -eq 0) {
    Write-Host "   - No Cognitive Services accounts captured for purge." -ForegroundColor DarkYellow
    return
  }

  $allApis = @($ApiVersion) + @($ApiVersionFallbacks | Where-Object { $_ -and $_ -ne $ApiVersion })

  foreach ($a in $Accounts) {
    $name = if ($null -ne $a.name) { [string]$a.name } else { '' }
    $loc = if ($null -ne $a.location) { [string]$a.location } else { '' }
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($loc)) {
      Write-Host "   (warn) Skipping purge for account with missing name/location." -ForegroundColor DarkYellow
      continue
    }

    Write-Host "   - [Foundry] Purge deleted account record: $name (location: $loc)" -ForegroundColor Cyan

    # Wait until the deleted account record becomes visible (eventual consistency)
    $visible = $false
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalMinutes -lt $WaitMinutes) {
      foreach ($api in $allApis) {
        if (Test-CognitiveServices-DeletedAccount-Exists -SubscriptionId $SubscriptionId -Location $loc -AccountName $name -ApiVersion $api) {
          $visible = $true
          break
        }
      }
      if ($visible) { break }
      Start-Sleep -Seconds $PollSeconds
      Write-Host "     · waiting for deleted record to appear… (elapsed $([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor DarkYellow
    }

    if (-not $visible) {
      Write-Host "     (warn) Deleted account record not visible yet; purge may fail. Continuing…" -ForegroundColor DarkYellow
    }

    $purged = $false
    foreach ($api in $allApis) {
      try {
        $r = Invoke-CognitiveServices-DeletedAccount-Purge -SubscriptionId $SubscriptionId -Location $loc -AccountName $name -ApiVersion $api -TimeoutMinutes $TimeoutMinutes -PollSeconds $PollSeconds
        if ($r.ok) {
          Write-Host "     · Purge request succeeded (api=$api, http=$($r.code))." -ForegroundColor DarkGreen
          $purged = $true
          break
        }

        Write-Host "     · Purge attempt failed (api=$api, http=$($r.code)); trying fallback…" -ForegroundColor DarkYellow
      } catch {
        Write-Host "     · Purge attempt threw (api=$api): $($_.Exception.Message)" -ForegroundColor DarkYellow
      }
    }

    if (-not $purged) {
      Write-Host "     (warn) Could not purge deleted account '$name'. It may already be purged or the API version may differ." -ForegroundColor DarkYellow
    }
  }

  if ($SettleMinutes -gt 0) {
    Write-Host "   - Waiting ${SettleMinutes} minute(s) for back-end unlink after purge…" -ForegroundColor Cyan
    Start-Sleep -Seconds ($SettleMinutes * 60)
  }
}

function Remove-CognitiveServices-CapabilityHosts-InRg {
  param(
    [Parameter(Mandatory=$true)] [string]$rg,
    [string]$apiVersion = '2025-04-01-preview',
    [int]$timeoutMinutes = 20,
    [int]$pollSeconds = 10,
    [int]$settleMinutes = 0
  )

  Write-Host "   - Scanning RG for capability hosts…" -ForegroundColor Cyan
  $caps = @()
  try {
    $raw = az resource list -g $rg --query "[?starts_with(type,'Microsoft.CognitiveServices/') && contains(type,'capabilityHosts')].{id:id,name:name,type:type}" --output json 2>$null
    if ($raw) { $caps = $raw | ConvertFrom-Json }
  } catch {
    $caps = @()
  }

  if (-not $caps -or $caps.Count -eq 0) {
    Write-Host "   - No capability hosts found." -ForegroundColor DarkGreen
    return
  }

  # Delete project capability hosts first (as recommended)
  $ordered = $caps | Sort-Object @{ Expression = { if ($_.id -match '/projects/') { 0 } else { 1 } } }, @{ Expression = { $_.id.Length }; Descending = $true }

  foreach ($c in $ordered) {
    if (-not $c.id) { continue }

    $rid = $c.id.ToString().Trim()
    $name = if ($c.name) { $c.name } else { $rid.Split('/')[-1] }
    $rtype = if ($c.type) { $c.type } else { '' }
    Write-Host "   - Deleting capability host: $name ($rtype)" -ForegroundColor Cyan

    $url = "https://management.azure.com$rid?api-version=$apiVersion"
    $resp = Invoke-AzureMgmt-WebRequest -Method DELETE -Url $url

    # 404 -> already gone
    $code = $null
    try { $code = [int]$resp.StatusCode } catch { }
    if ($code -eq 404) {
      Write-Host "     (info) Already deleted: $name" -ForegroundColor DarkYellow
      continue
    }
    if ($code -ge 400 -and $code -ne 202 -and $code -ne 204 -and $code -ne 200) {
      Write-Host "     (warn) Delete request returned HTTP $code for $name. Continuing…" -ForegroundColor DarkYellow
    }

    $opUrl = $null
    try { $opUrl = $resp.Headers['Azure-AsyncOperation'] } catch { $opUrl = $null }
    if ([string]::IsNullOrWhiteSpace($opUrl)) {
      try { $opUrl = $resp.Headers['Location'] } catch { $opUrl = $null }
    }

    if (-not [string]::IsNullOrWhiteSpace($opUrl)) {
      $ok = Wait-AzureAsyncOperation -OperationUrl $opUrl -TimeoutMinutes $timeoutMinutes -PollSeconds $pollSeconds
      if (-not $ok) {
        Write-Host "     (warn) Async delete did not succeed for $name (see operation output)." -ForegroundColor DarkYellow
      }
    } else {
      Write-Host "     (info) No Azure-AsyncOperation header returned; assuming delete accepted." -ForegroundColor DarkYellow
    }
  }

  Write-Host "   - Waiting for capability host resources to disappear from RG…" -ForegroundColor Cyan
  $gone = Wait-CognitiveServices-CapabilityHosts-Gone -rg $rg -TimeoutMinutes $timeoutMinutes -PollSeconds $pollSeconds
  if (-not $gone) {
    Write-Host "   (warn) Capability hosts still listed after timeout; service may still be unlinking resources." -ForegroundColor DarkYellow
  }

  if ($settleMinutes -gt 0) {
    Write-Host "   - Waiting ${settleMinutes} minute(s) for service to unlink resources…" -ForegroundColor Cyan
    Start-Sleep -Seconds ($settleMinutes * 60)
  } else {
    Write-Host "   - (info) Service may take up to ~20 minutes to fully unlink resources after capability host deletion." -ForegroundColor DarkYellow
  }
}

# -------------------- SAL (ACA) helpers --------------------
function Get-Subnet-SAL-Ids {
  param($rg, $vnet, $subnet)
  try {
    az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query "serviceAssociationLinks[].id" --output tsv
  } catch { '' }
}

# Retrieve detailed info for a SAL (serviceAssociationLink) returning a hashtable
function Get-SAL-Detail {
  param([string]$salId)
  if (-not $salId) { return $null }
  $apis = @('2024-03-01','2023-09-01')
  foreach ($api in $apis) {
    try {
      $json = az rest --method get --url "https://management.azure.com$salId?api-version=$api" --output json 2>$null
      if ($LASTEXITCODE -eq 0 -and $json) {
        return ($json | ConvertFrom-Json)
      }
    } catch { }
  }
  return $null
}

# Ensure required CLI extensions are present (best-effort, idempotent)
function Ensure-Cli-Extensions {
  param([string[]]$names)
  foreach ($n in $names) {
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    try {
      $present = az extension list --query "[?name=='$n'] | length(@)" --output tsv 2>$null
    } catch { $present = '0' }
    if ($present -ne '0') { continue }
    Write-Host "   - Installing CLI extension: $n" -ForegroundColor DarkCyan
    try { az extension add --name $n --only-show-errors | Out-Null } catch { Write-Host "     (warn) could not add extension $n" -ForegroundColor DarkYellow }
  }
}

# DevCenter targeted cleanup for subnet references (order: environments -> projects -> network connections -> devcenters)
function Remove-DevCenter-Resources-For-Subnet {
  param([string]$subnetId)
  if (-not $subnetId) { return }
  Ensure-Cli-Extensions -names @('devcenter')

  Write-Host "   - Locating resources referencing subnet..."

  function _DelIds { param([string[]]$ids,[string]$label)
    foreach ($id in ($ids | Where-Object { $_ })) {
      Write-Host "     · Deleting ${label}: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "       (warn) failed ${label}: $id" -ForegroundColor DarkYellow }
    }
  }

  try { $envs = az resource list --query "[?type=='Microsoft.DevCenter/devcenters/projects/environments' && contains(to_string(properties),'$subnetId')].id" --output tsv } catch { $envs = '' }
  _DelIds -ids ($envs -split "`n") -label 'Dev Environment'

  try { $projects = az resource list --query "[?type=='Microsoft.DevCenter/devcenters/projects' && contains(to_string(properties),'$subnetId')].id" --output tsv } catch { $projects = '' }
  _DelIds -ids ($projects -split "`n") -label 'DevCenter Project'

  try { $netConns = az resource list --query "[?type=='Microsoft.DevCenter/networkConnections' && contains(to_string(properties),'$subnetId')].id" --output tsv } catch { $netConns = '' }
  _DelIds -ids ($netConns -split "`n") -label 'Network Connection'

  try { $devcenters = az resource list --query "[?type=='Microsoft.DevCenter/devcenters' && contains(to_string(properties),'Microsoft.DevCenter/networkConnections') && contains(to_string(properties),'$subnetId')].id" --output tsv } catch { $devcenters = '' }
  _DelIds -ids ($devcenters -split "`n") -label 'DevCenter'
}

function Ensure-ACA-Delegation {
  param($rg, $vnet, $subnet)
  try {
    $has = az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query "length(delegations[?serviceName=='Microsoft.App/environments'])" --output tsv
  } catch { $has = '0' }
  if ($has -eq '0') {
    Write-Host "   - Adding delegation Microsoft.App/environments on ${rg}/${vnet}/${subnet}"
    az network vnet subnet update -g $rg --vnet-name $vnet -n $subnet --delegations Microsoft.App/environments | Out-Null
  }
}

function Delete-SALs-CLI {
  param($salIds)
  $ok = $true
  foreach ($sid in ($salIds -split "`n")) {
    if ([string]::IsNullOrWhiteSpace($sid)) { continue }
    Write-Host "   - Deleting Service Association Link: $sid"

    $apis = @('2024-03-01','2023-09-01')
    $deleted = $false
    foreach ($api in $apis) {
      $tries = 0
      $lastErr = ''
      do {
        $out = ''
        try {
          # Capture az output to avoid repeating noisy CLI errors; we print concise status lines instead.
          $out = (& az resource delete --ids $sid --api-version $api --only-show-errors 2>&1 | Out-String)
        } catch {
          $out = $_.ToString()
        }
        $rc = $LASTEXITCODE

        if ($rc -ne 0) {
          $lastErr = ($out ?? '').ToString().Trim()
          if ($ShowAzCliErrors -and $lastErr) {
            Write-Host "     (az) $lastErr" -ForegroundColor DarkYellow
          }

          # Treat common SAL/linkage failures as transient during retries
          $transient = ($lastErr -match '(?i)Some resources failed to be deleted|InUseSubnetCannotBeDeleted|Conflict|409|in use|being deleted|DeletionInProgress|TransientError')
          if ($transient -and $tries -lt 3) {
            Write-Host "     · SAL still blocking deletion (api=$api try=$($tries+1)/4); retrying…" -ForegroundColor DarkYellow
          } elseif ($tries -lt 3) {
            Write-Host "     · SAL delete failed (api=$api try=$($tries+1)/4); retrying…" -ForegroundColor DarkYellow
          }
          if ($tries -lt 3) { Start-Sleep -Seconds 3 }
        }
        $tries++
      } while ($rc -ne 0 -and $tries -lt 4)
      if ($rc -eq 0) { $deleted = $true; break }
    }

    if (-not $deleted) {
      $ok = $false
      Write-Host "     (warn) Failed to delete SAL after retries; it may be removed asynchronously or require deleting its owning service first." -ForegroundColor DarkYellow
    }
  }
  return $ok
}

function Wait-SAL-Gone {
  param(
    [string]$rg, [string]$vnet, [string]$subnet,
    [int]$maxSeconds = 180, [int]$pollSeconds = 6
  )
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $maxSeconds) {
    try {
      $left = az network vnet subnet show -g $rg --vnet-name $vnet -n $subnet --query "length(serviceAssociationLinks)" --output tsv 2>$null
      if (-not $left -or [int]$left -eq 0) { return $true }
    } catch { return $true }
    Start-Sleep -Seconds $pollSeconds
  }
  return $false
}

function Delete-ACAEnvs-Referencing-Subnet {
  param($subnetId)
  try {
    $ids = az resource list --resource-type Microsoft.App/managedEnvironments --query "[?properties.vnetConfiguration.infrastructureSubnetId=='$subnetId'].id" --output tsv
  } catch { $ids = '' }
  foreach ($id in ($ids -split "`n")) {
    if ($id) {
      Write-Host "   - Deleting ACA Managed Environment (cross-RG): $id"
      try { az resource delete --ids $id | Out-Null } catch {
        Write-Host "     (warn) failed to delete ME: $id" -ForegroundColor DarkYellow
      }
    }
  }
}

function Delete-Subnet-Consumers-Broad {
  param([string]$subnetId)

  $subnetLabel = $subnetId
  try {
    $parts = $subnetId -split '/'
    if ($parts.Length -ge 11) {
      $rgName = $parts[4]
      $vnetName = $parts[8]
      $subnetName = $parts[10]
      $subnetLabel = "$rgName/$vnetName/$subnetName"
    }
  } catch { }

  Write-Host "   - Checking for resources that reference this subnet ($subnetLabel)…"

  # NOTE: Avoid JMESPath operators like &&/|| here because on Windows az.cmd can be parsed by cmd.exe
  # in a way that treats them as command operators (causing "--output was unexpected at this time.").
  $queries = @(
    "[?type=='Microsoft.App/connectedEnvironments'][?contains(to_string(properties),'$subnetId')].id",
    "[?starts_with(type,'Microsoft.DevCenter/')][?contains(to_string(properties),'$subnetId')].id",
    "[?starts_with(type,'Microsoft.DevOpsInfrastructure/')][?contains(to_string(properties),'$subnetId')].id",
    "[?type=='Microsoft.Web/hostingEnvironments'][?contains(to_string(properties),'$subnetId')].id",
    "[?type=='Microsoft.Batch/batchAccounts/pools'][?contains(to_string(properties),'$subnetId')].id"
  )

  $refIds = @()
  foreach ($q in $queries) {
    try {
      # Use the timeout wrapper + exit code checks so we don't treat CLI errors as IDs.
      $res = Invoke-AzCli-WithTimeout -Arguments @('resource','list','--query',"$q",'--output','tsv','--only-show-errors') -TimeoutSeconds $AzCliTimeoutSeconds
      if ($res.ExitCode -eq 0 -and $res.StdOut) {
        $refIds += (($res.StdOut ?? '') -split "`n")
      } elseif ($ShowAzCliErrors -and $res.ExitCode -ne 0) {
        $msg = ($res.StdOut ?? '').ToString().Trim()
        if ($msg) { Write-Host "     (az) resource list failed: $msg" -ForegroundColor DarkYellow }
      }
    } catch {
      if ($ShowAzCliErrors) { Write-Host "     (az) resource list failed: $($_.Exception.Message)" -ForegroundColor DarkYellow }
    }
  }

  # Only keep real ARM resource IDs (avoid cmd.exe parsing noise being misinterpreted as IDs on Windows).
  $refIds = $refIds |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.ToString().Trim() } |
    Where-Object { $_ -match '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/[^/]+/.+$' } |
    Sort-Object -Unique
  foreach ($rid in $refIds) {
    Write-Host "     · Deleting referencing resource: $rid"
    try { az resource delete --ids $rid | Out-Null } catch {
      Write-Host "       (warn) couldn't delete: $rid" -ForegroundColor DarkYellow
    }
  }

  $deadline = [DateTime]::UtcNow.AddMinutes(5)
  while ([DateTime]::UtcNow -lt $deadline) {
    $stillIds = @()
    foreach ($q2 in $queries) {
      try {
        $res2 = Invoke-AzCli-WithTimeout -Arguments @('resource','list','--query',"$q2",'--output','tsv','--only-show-errors') -TimeoutSeconds $AzCliTimeoutSeconds
        if ($res2.ExitCode -eq 0 -and $res2.StdOut) {
          $stillIds += (($res2.StdOut ?? '') -split "`n")
        }
      } catch { }
    }
    $stillIds = @($stillIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($stillIds.Count -eq 0) { break }
    Start-Sleep -Seconds 10
  }
}

function Delete-ServiceAssociationLinks {
  param($rg, $vnet, $subnet)

  $salIds = Get-Subnet-SAL-Ids -rg $rg -vnet $vnet -subnet $subnet
  if (-not $salIds) { return $true }

  # Detect DevCenter owners to clean up first
  $acctId = (az account show --query id --output tsv 2>$null).Trim()
  $subnetIdFull = "/subscriptions/$acctId/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets/$subnet"

  $needsDevCenterCleanup = $false
  foreach ($sid in ($salIds -split "`n")) {
    if (-not $sid) { continue }
    $detail = Get-SAL-Detail -salId $sid
    if ($detail -and $detail.properties.serviceName -match 'Microsoft\.DevCenter/networkConnections') {
      $needsDevCenterCleanup = $true; break
    }
  }
  if ($needsDevCenterCleanup) {
    Write-Host "   - Subnet link indicates dependencies; attempting dependency cleanup first..." -ForegroundColor Cyan
    Remove-DevCenter-Resources-For-Subnet -subnetId $subnetIdFull
    $salIds = Get-Subnet-SAL-Ids -rg $rg -vnet $vnet -subnet $subnet
    if (-not $salIds) { return $true }
  }

  # SAL delete needs ACA delegation present during the operation
  Ensure-ACA-Delegation -rg $rg -vnet $vnet -subnet $subnet

  # CLI path
  $ok = Delete-SALs-CLI -salIds $salIds
  if ($ok) {
    if (Wait-SAL-Gone -rg $rg -vnet $vnet -subnet $subnet -maxSeconds 180) { return $true }
  }

  # Optional last resort via raw REST delete (still CLI-based)
  if ($ForceSAL) {
    Write-Host "     (info) ForceSAL enabled: attempting raw DELETE via az rest..." -ForegroundColor Cyan
    foreach ($sid in ($salIds -split "`n")) {
      if (-not $sid) { continue }
      foreach ($api in @('2024-03-01','2023-09-01')) {
        Write-Host "       · REST DELETE $api $sid" -ForegroundColor DarkCyan
        try { az rest --method delete --url "https://management.azure.com$sid?api-version=$api" --only-show-errors | Out-Null } catch { }
        Start-Sleep 1
      }
    }
    if (Wait-SAL-Gone -rg $rg -vnet $vnet -subnet $subnet -maxSeconds 60) { return $true }
  }

  return $false
}

# -------------------- Prompt --------------------
function Prompt-Context {
  if (Test-Path -Path $StateFile) {
    . $StateFile
    $script:SUB    = $SUB
    $script:RG     = $RG
    $script:TENANT = $TENANT
    $script:DELETE_RG = if ($DELETE_RG) { $DELETE_RG } else { 'Y' }

    Write-Host "`nLast used:" -ForegroundColor Cyan
    Write-Host "  Subscription: $script:SUB"
    Write-Host "  ResourceGroup: $script:RG"
    Write-Host "  Tenant: $script:TENANT"
    Write-Host "  DeleteResourceGroup: $script:DELETE_RG"
  }

  # --- Subscription ---
  $reuseSub = if ($script:SUB) { Read-Host "Reuse last subscription ($script:SUB)? [Y/n]" } else { 'n' }
  if ([string]::IsNullOrWhiteSpace($reuseSub)) { $reuseSub = 'Y' }
  if ($reuseSub -match '^(n|no)$' -or -not $script:SUB) {
    $subs = az account list --query "[].{id:id,name:name}" --output tsv 2>$null
    if (-not $subs) { Write-Host "   (error) No subscriptions found." -ForegroundColor Red; exit 1 }
    $subsArr = @()
    foreach ($s in ($subs -split "`n")) {
      $parts = $s -split "`t"
      if ($parts.Count -ge 2) { $subsArr += [PSCustomObject]@{ Id=$parts[0]; Name=$parts[1] } }
    }
    Write-Host "`nAvailable subscriptions:" -ForegroundColor Cyan
    for ($i=0; $i -lt $subsArr.Count; $i++) { Write-Host " [$i] $($subsArr[$i].Name) ($($subsArr[$i].Id))" }
    $subChoice = Read-Host "Select subscription index"
    if (-not $subChoice -or $subChoice -ge $subsArr.Count) { Write-Host "Invalid subscription choice." -ForegroundColor Red; exit 1 }
    $script:SUB = $subsArr[$subChoice].Id
  }
  az account set --subscription $script:SUB | Out-Null

  # --- Resource group ---
  $reuseRG = if ($script:RG) { Read-Host "Reuse last resource group ($script:RG)? [Y/n]" } else { 'n' }
  if ([string]::IsNullOrWhiteSpace($reuseRG)) { $reuseRG = 'Y' }
  if ($reuseRG -match '^(n|no)$' -or -not $script:RG) {
    $rgs = az group list --query "[].{name:name,location:location}" --output tsv 2>$null
    if (-not $rgs) { Write-Host "   (error) No resource groups found." -ForegroundColor Red; exit 1 }
    $rgArr = @()
    foreach ($r in ($rgs -split "`n")) {
      $parts = $r -split "`t"
      if ($parts.Count -ge 2) { $rgArr += [PSCustomObject]@{ Name=$parts[0]; Location=$parts[1] } }
    }
    Write-Host "`nAvailable resource groups:" -ForegroundColor Cyan
    for ($i=0; $i -lt $rgArr.Count; $i++) { Write-Host " [$i] $($rgArr[$i].Name) (location=$($rgArr[$i].Location))" }
    $rgChoice = Read-Host "Select resource group index"
    # FIX: Convert to integer and validate
    try {
      $rgChoiceInt = [int]$rgChoice
      if ($rgChoiceInt -lt 0 -or $rgChoiceInt -ge $rgArr.Count) {
        Write-Host "Invalid RG choice. Please select a number between 0 and $($rgArr.Count - 1)." -ForegroundColor Red
        exit 1
      }
      $script:RG = $rgArr[$rgChoiceInt].Name
    } catch {
      Write-Host "Invalid RG choice. Please enter a valid number." -ForegroundColor Red
      exit 1
    }
  }
  # --- Tenant (info only; no prompt) ---
  # Override: -TenantId <tenant-guid>
  if ($TenantId) {
    $script:TENANT = $TenantId.Trim()
  } else {
    # Prefer current az context tenant; fall back to state-file tenant if az isn't available
    try {
      $detectedTenant = (az account show --query tenantId --output tsv 2>$null)
      if ($detectedTenant) { $script:TENANT = $detectedTenant.Trim() }
    } catch { }
  }

  # --- Delete Resource Group Preference ---
  # Only prompt if not passed as parameter
  if (-not $PSBoundParameters.ContainsKey('DeleteResourceGroup')) {
    $reuseDelRG = if ($script:DELETE_RG) { Read-Host "Delete entire resource group or just its content? Last: $script:DELETE_RG [Y=delete RG, N=delete content only, default=$script:DELETE_RG]" } else { '' }
    if ([string]::IsNullOrWhiteSpace($reuseDelRG)) { 
      # Keep the last value
    } else {
      $reuseDelRG = $reuseDelRG.ToUpper()
      if ($reuseDelRG -in @('Y','N')) {
        $script:DELETE_RG = $reuseDelRG
      }
    }
  } else {
    # Use the parameter value
    $script:DELETE_RG = $DeleteResourceGroup
  }

  # --- Save state ---
  $safeSub    = $script:SUB -replace "'","''"
  $safeRg     = $script:RG  -replace "'","''"
  $safeTenant = $script:TENANT -replace "'","''"
  $safeDelRG  = $script:DELETE_RG -replace "'","''"
  Set-Content -Path $StateFile -Value @(
    "`$SUB = '$safeSub'",
    "`$RG  = '$safeRg'",
    "`$TENANT = '$safeTenant'",
    "`$DELETE_RG = '$safeDelRG'"
  ) -Encoding UTF8

  Write-Host "`nSelected Subscription: $script:SUB" -ForegroundColor Green
  Write-Host "Selected Resource Group: $script:RG" -ForegroundColor Green
  if ($TenantId) {
    Write-Host "Tenant (override): $script:TENANT" -ForegroundColor Green
  } else {
    Write-Host "Tenant (info): $script:TENANT (override with -TenantId)" -ForegroundColor Green
  }
  Write-Host "Delete Resource Group: $script:DELETE_RG (Y=delete RG, N=content only)" -ForegroundColor Green
}

# -------------------- Network helpers --------------------
function Unset-Subnet-Props {
  param($rg, $vnet, $subnet)
  Write-Host "   - Clearing associations on subnet ${rg}/${vnet}/${subnet}"
  foreach ($prop in 'networkSecurityGroup','routeTable','natGateway','delegations','serviceEndpoints') {
    try {
      az network vnet subnet update -g $rg --vnet-name $vnet -n $subnet --remove $prop | Out-Null
    } catch {
      Write-Host "     · (warn) could not remove $prop" -ForegroundColor DarkYellow
    }
  }
}

function Unset-Subnet-Props-WhileSALPresent {
  param($rg, $vnet, $subnet)
  Write-Host "   - Clearing non-delegation associations on subnet ${rg}/${vnet}/${subnet} (SAL still present)" -ForegroundColor DarkYellow
  # Keep delegations intact while SAL exists (some SAL deletions require specific delegation).
  foreach ($prop in 'networkSecurityGroup','routeTable','natGateway','serviceEndpoints') {
    try {
      az network vnet subnet update -g $rg --vnet-name $vnet -n $subnet --remove $prop | Out-Null
    } catch {
      Write-Host "     · (warn) could not remove $prop" -ForegroundColor DarkYellow
    }
  }
}

function Delete-RouteTables-In-RG {
  param([string]$rg)
  Write-Host ">> Deleting Route Tables in '$rg' (best-effort)…"
  $rts = @()
  $listedOk = $true
  try {
    $raw = az network route-table list -g $rg --query "[].{id:id,name:name}" --output json 2>$null
    if ($raw) { $rts = $raw | ConvertFrom-Json }
  } catch {
    $listedOk = $false
    $rts = @()
  }

  if (-not $listedOk) {
    Write-Host "   (warn) Failed to list route tables (network/DNS/auth). Skipping route table cleanup." -ForegroundColor DarkYellow
    return
  }

  if (-not $rts -or $rts.Count -eq 0) {
    Write-Host "   - No route tables found." -ForegroundColor DarkGreen
    return
  }

  foreach ($rt in $rts) {
    $rtId = ($rt.id ?? '').ToString().Trim()
    $rtName = ($rt.name ?? '').ToString().Trim()
    if (-not $rtId -or -not $rtName) { continue }

    # Detach from any subnets that still reference it
    try {
      $subsRaw = az network route-table show -g $rg -n $rtName --query "subnets[].id" --output tsv 2>$null
    } catch { $subsRaw = '' }

    if ($subsRaw) {
      foreach ($sid in ($subsRaw -split "`n")) {
        if ([string]::IsNullOrWhiteSpace($sid)) { continue }
        $parts = $sid -split '/'
        $rgIndex = [Array]::IndexOf($parts, 'resourceGroups')
        $vnetIndex = [Array]::IndexOf($parts, 'virtualNetworks')
        $subnetIndex = [Array]::IndexOf($parts, 'subnets')
        if ($rgIndex -lt 0 -or $vnetIndex -lt 0 -or $subnetIndex -lt 0) { continue }
        $sRg = $parts[$rgIndex + 1]
        $sVnet = $parts[$vnetIndex + 1]
        $sSubnet = $parts[$subnetIndex + 1]
        if ($sRg -and $sVnet -and $sSubnet) {
          Write-Host "   - Detaching route table from subnet ${sRg}/${sVnet}/${sSubnet}"
          try { az network vnet subnet update -g $sRg --vnet-name $sVnet -n $sSubnet --remove routeTable | Out-Null } catch { }
        }
      }
    }

    # Attempt to delete the route table
    $out = ''
    try { $out = (& az network route-table delete -g $rg -n $rtName --only-show-errors 2>&1 | Out-String) } catch { $out = $_.ToString() }
    if ($LASTEXITCODE -eq 0) {
      Write-Host "   - Deleted route table: $rtName" -ForegroundColor DarkGreen
    } else {
      $msg = ($out ?? '').ToString().Trim()
      if ($ShowAzCliErrors -and $msg) { Write-Host "     (az) $msg" -ForegroundColor DarkYellow }
      Write-Host "   (info) Route table delete deferred: $rtName" -ForegroundColor DarkYellow
    }
  }
}

function Delete-PrivateEndpoints-For-Subnet {
  param($subnetId)
  Write-Host "   - Looking for Private Endpoints on this subnet…"
  try { $PEs = az network private-endpoint list --query "[?subnet.id=='$subnetId'].{id:id}" --output tsv } catch { $PEs = '' }
  if ($PEs) {
    foreach ($pe in ($PEs -split "`n")) {
      if ([string]::IsNullOrWhiteSpace($pe)) { continue }
      Write-Host "     · Deleting Private Endpoint: $pe"
      try { az resource delete --ids $pe | Out-Null } catch { Write-Host "       (warn) failed: $pe" -ForegroundColor DarkYellow }
    }
  }
}

function Remove-VNet-Peerings {
  param($rg)
  Write-Host ">> Removing VNet peerings in '$rg' (if any)…"
  try { $vnets = (az network vnet list -g $rg --query "[].name" --output tsv) -split "`n" } catch { $vnets = @() }
  foreach ($v in $vnets) {
    if ([string]::IsNullOrWhiteSpace($v)) { continue }
    try { $peerings = (az network vnet peering list -g $rg --vnet-name $v --query "[].name" --output tsv) -split "`n" } catch { $peerings = @() }
    foreach ($p in $peerings) {
      if ([string]::IsNullOrWhiteSpace($p)) { continue }
      Write-Host "   - Deleting peering ${rg}/${v}/${p}"
      try { az network vnet peering delete -g $rg --vnet-name $v -n $p | Out-Null } catch { Write-Host "     (warn) peering delete failed: $p" -ForegroundColor DarkYellow }
    }
  }
}

function Remove-PrivateDns-VNetLinks {
  param($targetVNetId)
  Write-Host ">> Removing Private DNS zone links referencing VNet (best-effort)…"
  try { $zonesRaw = az network private-dns zone list --query "[].{n:name,rg:resourceGroup}" --output tsv } catch { $zonesRaw = '' }
  if (-not $zonesRaw) { return }

  foreach ($line in ($zonesRaw -split "`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "\t"
    if ($parts.Count -lt 2) { continue }
    $zName = $parts[0]
    $zRg   = $parts[1]

    try {
      $linksRaw = az network private-dns link vnet list -g $zRg -z $zName --query "[?virtualNetwork.id=='$targetVNetId'].{id:id,name:name}" --output tsv
    } catch { $linksRaw = '' }

    if (-not $linksRaw) { continue }
    foreach ($l in ($linksRaw -split "`n")) {
      if ([string]::IsNullOrWhiteSpace($l)) { continue }
      $lp = $l -split "\t"
      $lname = if ($lp.Count -ge 2) { $lp[1] } else { $null }
      if (-not $lname) { continue }

      Write-Host "   - Deleting Private DNS VNet link: $zRg/$zName/$lname"
      try {
        az network private-dns link vnet delete -g $zRg -z $zName -n $lname --yes | Out-Null
      } catch {
        Write-Host "     (warn) could not delete DNS link $lname" -ForegroundColor DarkYellow
      }
    }
  }
}

function Broad-Disassociate-NSG {
  param($NSG_ID)
  Write-Host ">> Broad disassociation across subscription for NSG: $NSG_ID"

  try {
    $nicsRaw = az network nic list --query "[?networkSecurityGroup && networkSecurityGroup.id=='$NSG_ID'].{rg:resourceGroup,name:name}" --output tsv
  } catch { $nicsRaw = '' }
  if ($nicsRaw) {
    foreach ($entry in ($nicsRaw -split "`n")) {
      if ([string]::IsNullOrWhiteSpace($entry)) { continue }
      $parts = $entry -split "`t"; $RG_NIC = $parts[0]; $NIC_NAME = $parts[1]
      Write-Host "   - Removing NSG from NIC ${RG_NIC}/${NIC_NAME}"
      try { az network nic update -g $RG_NIC -n $NIC_NAME --remove networkSecurityGroup | Out-Null } catch {
        Write-Host "     (warn) NIC update failed ${RG_NIC}/${NIC_NAME}" -ForegroundColor DarkYellow
      }
    }
  }

  try { $vnetList = az network vnet list --query "[].{rg:resourceGroup,name:name}" --output tsv } catch { $vnetList = '' }
  if ($vnetList) {
    foreach ($v in ($vnetList -split "`n")) {
      if ([string]::IsNullOrWhiteSpace($v)) { continue }
      $parts = $v -split "`t"; $VNET_RG = $parts[0]; $VNET_NAME = $parts[1]

      try { $subsRaw = az network vnet subnet list -g $VNET_RG --vnet-name $VNET_NAME --query "[?networkSecurityGroup && networkSecurityGroup.id=='$NSG_ID'].name" --output tsv } catch { $subsRaw = '' }
      if ($subsRaw) {
        foreach ($S in ($subsRaw -split "`n")) {
          if ([string]::IsNullOrWhiteSpace($S)) { continue }
          Write-Host "   - Disassociating NSG from subnet ${VNET_RG}/${VNET_NAME}/${S}"
          try {
            az network vnet subnet update -g $VNET_RG --vnet-name $VNET_NAME -n $S --remove networkSecurityGroup | Out-Null
          } catch {
            Write-Host "     (warn) subnet update failed: ${VNET_RG}/${VNET_NAME}/${S}" -ForegroundColor DarkYellow
          }
        }
      }
    }
  }
}

# -------------------- Heavy resource cleanup --------------------
function Delete-ContainerApps-In-RG {
  param($rg)
  Write-Host ">> Deleting Container Apps in '$rg'…"
  try { $ids = az resource list -g $rg --resource-type Microsoft.App/containerApps --query "[].id" --output tsv } catch { $ids = '' }
  foreach ($id in ($ids -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting CA: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
}

function Delete-ManagedEnvironments-In-RG {
  param($rg)
  Write-Host ">> Deleting Container Apps managed environments in '$rg'…"
  try { $ids = az resource list -g $rg --resource-type Microsoft.App/managedEnvironments --query "[].id" --output tsv } catch { $ids = '' }
  foreach ($id in ($ids -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting ME: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
}

function Delete-ApplicationGateways-In-RG {
  param($rg)
  Write-Host ">> Deleting Application Gateways in '$rg'…"
  try { $ids = az network application-gateway list -g $rg --query "[].id" --output tsv } catch { $ids = '' }
  foreach ($id in ($ids -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting AGW: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
}

function Delete-AzureFirewalls-In-RG {
  param($rg)
  Write-Host ">> Deleting Azure Firewalls in '$rg'…"
  try {
    if ($ShowAzCliErrors) {
      $ids = az network firewall list -g $rg --query "[].id" --output tsv
    } else {
      # azure-firewall CLI extension currently emits a noisy Python UserWarning (pkg_resources deprecated).
      # It does not affect deletion, so we suppress stderr unless explicitly requested.
      $ids = az network firewall list -g $rg --query "[].id" --output tsv 2>$null
    }
  } catch { $ids = '' }
  foreach ($id in ($ids -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting AFW: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
}

function Delete-Bastions-In-RG {
  param($rg)
  Write-Host ">> Deleting Bastion hosts in '$rg'…"
  try { $ids = az network bastion list -g $rg --query "[].id" --output tsv } catch { $ids = '' }
  foreach ($id in ($ids -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting Bastion: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
}

function Delete-VMs-And-NICs-In-RG {
  param($rg)
  Write-Host ">> Deleting VMs and leftover NICs in '$rg'…"
  try { $vmIds = az vm list -g $rg --query "[].id" --output tsv } catch { $vmIds = '' }
  foreach ($id in ($vmIds -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting VM: $id"
      try { az vm delete --ids $id --yes | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
  Start-Sleep -Seconds 10
  try { $nicIds = az network nic list -g $rg --query "[?virtualMachine==null && privateEndpoint==null].id" --output tsv } catch { $nicIds = '' }
  foreach ($id in ($nicIds -split "`n")) {
    if (-not [string]::IsNullOrWhiteSpace($id)) {
      Write-Host "   - Deleting NIC: $id"
      try { az resource delete --ids $id | Out-Null } catch { Write-Host "     (warn) failed: $id" -ForegroundColor DarkYellow }
    }
  }
}

function Force-Delete-Remaining-SearchServices {
  param($rg)
  Write-Host ">> Checking for remaining Search services and forcing deletion..." -ForegroundColor Cyan
  
  try { 
    $searchServices = az search service list -g $rg --query "[].{name:name,id:id}" --output json | ConvertFrom-Json
  } catch { 
    $searchServices = @()
  }
  
  foreach ($service in $searchServices) {
    if (-not $service.name) { continue }
    Write-Host "   - Force deleting remaining Search service: $($service.name)"
    
    # Try multiple approaches to force delete
    try { az search service delete --name $service.name -g $rg --yes --no-wait | Out-Null } catch { }
    try { az resource delete --ids $service.id --no-wait | Out-Null } catch { }
  }
}

function Delete-SearchServices-In-RG {
  param($rg)
  Write-Host ">> Force-deleting Azure AI Search services in '$rg'…"
  
  try { 
    $searchServices = az search service list -g $rg --query "[].{name:name,id:id}" --output json | ConvertFrom-Json
  } catch { 
    $searchServices = @()
  }
  
  foreach ($service in $searchServices) {
    if (-not $service.name) { continue }
    
    Write-Host "   - Processing Search service: $($service.name)"
    
    # Step 1: Remove shared private link resources
    Write-Host "     · Removing shared private link resources..."
    try {
      $sharedLinks = az search shared-private-link-resource list --service-name $service.name -g $rg --query "[].name" --output tsv 2>$null
      if ($sharedLinks) {
        foreach ($linkName in ($sharedLinks -split "`n")) {
          if ($linkName) {
            Write-Host "       - Deleting shared private link: $linkName (with timeout)"
            try { 
              # Add timeout for shared private link deletion
              $job = Start-Job -ScriptBlock { 
                param($linkName, $serviceName, $rg)
                az search shared-private-link-resource delete --name $linkName --service-name $serviceName -g $rg --yes --no-wait 2>$null
              } -ArgumentList $linkName, $service.name, $rg
              
              # Wait max 20 seconds for the job
              if (Wait-Job -Job $job -Timeout 20) {
                Receive-Job -Job $job | Out-Null
              } else {
                Write-Host "         (warn) timeout deleting shared private link: $linkName" -ForegroundColor DarkYellow
                Stop-Job -Job $job -ErrorAction SilentlyContinue
              }
              Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch { 
              Write-Host "         (warn) failed to delete shared private link: $linkName" -ForegroundColor DarkYellow 
            }
          }
        }
      }
    } catch { 
      Write-Host "       (info) No shared private links found or failed to list" -ForegroundColor DarkCyan 
    }
    
    # Step 2: Remove private endpoint connections
    Write-Host "     · Removing private endpoint connections..."
    try {
      $peConnections = az search private-endpoint-connection list --service-name $service.name -g $rg --query "[].name" --output tsv 2>$null
      if ($peConnections) {
        foreach ($peName in ($peConnections -split "`n")) {
          if ($peName) {
            Write-Host "       - Deleting private endpoint connection: $peName (with timeout)"
            try { 
              # Add timeout and async deletion for private endpoint connections
              $job = Start-Job -ScriptBlock { 
                param($serviceName, $rg, $peName)
                az search private-endpoint-connection delete --name $peName --service-name $serviceName -g $rg --no-wait 2>$null
              } -ArgumentList $service.name, $rg, $peName
              
              # Wait max 30 seconds for the job
              if (Wait-Job -Job $job -Timeout 30) {
                Receive-Job -Job $job | Out-Null
              } else {
                Write-Host "         (warn) timeout deleting private endpoint connection: $peName" -ForegroundColor DarkYellow
                Stop-Job -Job $job -ErrorAction SilentlyContinue
              }
              Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch { 
              Write-Host "         (warn) failed to delete private endpoint connection: $peName" -ForegroundColor DarkYellow 
            }
          }
        }
      }
    } catch { 
      Write-Host "       (info) No private endpoint connections found or failed to list" -ForegroundColor DarkCyan 
    }

    # Wait a bit for cleanup to complete
    Write-Host "     · Waiting for private access cleanup to complete..."
    Start-Sleep -Seconds 15
    
    # Step 3: Enable public network access if needed (to allow deletion)
    Write-Host "     · Enabling public network access for deletion..."
    try {
      az search service update --name $service.name -g $rg --public-access Enabled | Out-Null
      Start-Sleep -Seconds 5
    } catch {
      Write-Host "       (warn) failed to enable public access" -ForegroundColor DarkYellow
    }
    
    # Step 4: Delete the search service
    Write-Host "     · Deleting Search service: $($service.name) (with timeout)"
    try { 
      # Add timeout for search service deletion
      $job = Start-Job -ScriptBlock { 
        param($serviceName, $rg)
        az search service delete --name $serviceName -g $rg --yes --no-wait 2>$null
      } -ArgumentList $service.name, $rg
      
      # Wait max 60 seconds for the job
      if (Wait-Job -Job $job -Timeout 60) {
        Receive-Job -Job $job | Out-Null
        Write-Host "       · Search service deletion initiated successfully"
      } else {
        Write-Host "       (warn) timeout deleting search service: $($service.name)" -ForegroundColor DarkYellow
        Stop-Job -Job $job -ErrorAction SilentlyContinue
      }
      Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    } catch { 
      Write-Host "       (warn) failed to delete search service: $($service.name)" -ForegroundColor DarkYellow 
    }
  }
}

function Detach-VNet-DdosPlan {
  param($rg, $vnet)
  try {
    az network vnet show -g $rg -n $vnet --query "ddosProtectionPlan.id" --output tsv | Out-Null
    if ($LASTEXITCODE -eq 0) {
      az network vnet update -g $rg -n $vnet --remove ddosProtectionPlan | Out-Null
      Write-Host "   - Detached DDoS plan from ${rg}/${vnet}"
    }
  } catch { }
}

function Try-Delete-VNet {
  param($rg, $vnet, [int]$attempts = 6)
  for ($i = 0; $i -lt $attempts; $i++) {
    az network vnet delete -g $rg -n $vnet | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host ">> Deleted VNet ${rg}/${vnet}"; return $true }
    if ($i -eq 0) { Detach-VNet-DdosPlan -rg $rg -vnet $vnet }
    Start-Sleep -Seconds ([int][math]::Pow(2, $i) * 5)
  }
  return $false
}

# -------------------- Main VNet breaker --------------------
function Break-VNet-Blockers-In-RG {
  param($rg)
  Write-Host ">> Breaking VNet/Subnet blockers in '$rg'…"

  Delete-ContainerApps-In-RG       -rg $rg
  Delete-ManagedEnvironments-In-RG -rg $rg
  Delete-ApplicationGateways-In-RG -rg $rg
  Delete-AzureFirewalls-In-RG      -rg $rg
  Delete-Bastions-In-RG            -rg $rg
  Delete-VMs-And-NICs-In-RG        -rg $rg
  Delete-SearchServices-In-RG      -rg $rg

  try { $vnetNamesRaw = az network vnet list -g $rg --query "[].name" --output tsv } catch { $vnetNamesRaw = '' }
  if ($vnetNamesRaw) {
    $vnetNames = $vnetNamesRaw -split "`n"

    foreach ($VNET in $vnetNames) {
      if ([string]::IsNullOrWhiteSpace($VNET)) { continue }

      $passes = 0
      do {
        $passes++
        $deferred = @()

        try { $subsRaw = az network vnet subnet list -g $rg --vnet-name $VNET --query "[].name" --output tsv } catch { $subsRaw = '' }
        if ($subsRaw) {
          foreach ($S in ($subsRaw -split "`n")) {
            if ([string]::IsNullOrWhiteSpace($S)) { continue }

            $accountId = (az account show --query id --output tsv).Trim()
            $SUBNET_ID = "/subscriptions/$accountId/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$VNET/subnets/$S"

            Delete-Subnet-Consumers-Broad -subnetId $SUBNET_ID
            Delete-PrivateEndpoints-For-Subnet -subnetId $SUBNET_ID
            Delete-ACAEnvs-Referencing-Subnet -subnetId $SUBNET_ID

            $salCleared = Delete-ServiceAssociationLinks -rg $rg -vnet $VNET -subnet $S
            if (-not $salCleared) {
              Write-Host "     (info) Deferring ${rg}/${VNET}/${S} until SALs are gone." -ForegroundColor DarkYellow
              # Even if SAL blocks subnet deletion, try to detach route tables / NSGs / NAT so those resources can be deleted.
              Unset-Subnet-Props-WhileSALPresent -rg $rg -vnet $VNET -subnet $S
              $deferred += $S
              continue
            }

            Unset-Subnet-Props -rg $rg -vnet $VNET -subnet $S

            az network vnet subnet delete -g $rg --vnet-name $VNET -n $S | Out-Null
            if ($LASTEXITCODE -eq 0) {
              Write-Host "   - Deleted subnet ${rg}/${VNET}/$S"
            } else {
              Write-Host "     (info) Subnet delete deferred: ${rg}/${VNET}/$S" -ForegroundColor DarkYellow
              $deferred += $S
            }
          }
        }

        if ($deferred.Count -gt 0 -and $passes -lt 4) {
          Write-Host "   - Waiting before next subnet pass (remaining: $($deferred -join ', '))..."
          Start-Sleep -Seconds (10 * $passes)
        }
      } while ($deferred.Count -gt 0 -and $passes -lt 4)

      Remove-VNet-Peerings -rg $rg
      $acct  = (az account show --query id --output tsv).Trim()
      $vnetId = "/subscriptions/$acct/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$VNET"
      Remove-PrivateDns-VNetLinks -targetVNetId $vnetId

      if (-not (Try-Delete-VNet -rg $rg -vnet $VNET)) {
        Write-Host "   (info) VNet delete deferred: ${rg}/${VNET}" -ForegroundColor DarkYellow
      }
    }
  }

  # Best-effort cleanup: route tables often remain if a single subnet is still blocked.
  Delete-RouteTables-In-RG -rg $rg
}

# -------------------- Main --------------------
function Main {
  Prompt-Context

  Write-Host ">> Using subscription: $script:SUB"
  # Optional SP login (pure CLI)
  if (-not $SpClientId -and $env:AZ_SUBDEL_SP_CLIENT_ID) { $SpClientId = $env:AZ_SUBDEL_SP_CLIENT_ID }
  if (-not $SpClientSecret -and $env:AZ_SUBDEL_SP_CLIENT_SECRET) { $SpClientSecret = $env:AZ_SUBDEL_SP_CLIENT_SECRET }
  if (-not $SpTenantId -and $env:AZ_SUBDEL_SP_TENANT_ID) { $SpTenantId = $env:AZ_SUBDEL_SP_TENANT_ID }

  if (-not $SpClientSecret -and $SpClientSecretFile) {
    try {
      if (Test-Path -Path $SpClientSecretFile) {
        $SpClientSecret = (Get-Content -Raw -Path $SpClientSecretFile).Trim()
      } else {
        Write-Host "   (warn) Secret file not found: $SpClientSecretFile" -ForegroundColor DarkYellow
      }
    } catch {
      Write-Host "   (warn) Could not read secret file: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
  }
  if ($SpClientId -and -not $SpClientSecret -and $PromptSpSecret) {
    try {
      $sec = Read-Host "Service principal client secret (input hidden)" -AsSecureString
      if ($sec) { $SpClientSecret = [System.Net.NetworkCredential]::new('', $sec).Password }
    } catch {
      Write-Host "   (warn) Secure prompt failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
  }
  if ($SpClientId -and $SpClientSecret) {
    $loginTenant = if ($SpTenantId) { $SpTenantId } elseif ($script:TENANT) { $script:TENANT } elseif ($TenantId) { $TenantId } else { '' }
    if ($loginTenant) {
      Write-Host "   - Logging in with service principal (clientId=$SpClientId tenant=$loginTenant)" -ForegroundColor Cyan
      try { az login --service-principal -u $SpClientId -p $SpClientSecret --tenant $loginTenant --only-show-errors | Out-Null } catch { Write-Host "   (error) SP login failed: $($_.Exception.Message)" -ForegroundColor Red }
    } else {
      Write-Host "   (warn) Service principal tenant not resolved; skipping SP login." -ForegroundColor DarkYellow
    }
  } elseif ($SpClientId -and -not $SpClientSecret) {
    Write-Host "   (info) SP client id provided but no secret (and none loaded). Use -SpClientSecretFile <path>, set env AZ_SUBDEL_SP_CLIENT_SECRET, or add -PromptSpSecret to input it securely." -ForegroundColor DarkYellow
  }

  az account set --subscription $script:SUB | Out-Null

  # Persist detected tenant if blank
  if ([string]::IsNullOrWhiteSpace($script:TENANT)) {
    try { $script:TENANT = (az account show --query tenantId --output tsv 2>$null).Trim() } catch { $script:TENANT = '' }
    $safeSub    = $script:SUB -replace "'","''"
    $safeRg     = $script:RG  -replace "'","''"
    $safeTenant = $script:TENANT -replace "'","''"
    $safeDelRG  = $script:DELETE_RG -replace "'","''"
    Set-Content -Path $StateFile -Value @(
      "`$SUB = '$safeSub'",
      "`$RG  = '$safeRg'",
      "`$TENANT = '$safeTenant'",
      "`$DELETE_RG = '$safeDelRG'"
    ) -Encoding UTF8
  }

  Write-Host ">> Verifying resource group '$script:RG' exists…"

  $rgExists = ''
  try {
    # Use az group exists first. It's fast and avoids extra output noise.
    $existsResult = Invoke-AzCli-WithTimeout -Arguments @('group','exists','-n',$script:RG,'--only-show-errors','-o','tsv') -TimeoutSeconds $AzCliTimeoutSeconds -ThrowOnNonZero
    $rgExists = ($existsResult.StdOut ?? '').ToString().Trim().ToLowerInvariant()
  } catch {
    Write-Host "Azure CLI failed while checking if resource group exists (it may be blocked/hanging)." -ForegroundColor Red
    Write-Host "Troubleshooting:" -ForegroundColor DarkYellow
    Write-Host "  - Run: az account show -o table" -ForegroundColor DarkYellow
    Write-Host "  - Run: az group exists -n $script:RG -o tsv" -ForegroundColor DarkYellow
    Write-Host "  - If needed: az login ; az account set --subscription $script:SUB" -ForegroundColor DarkYellow
    Write-Host "  - If network/proxy issues: verify management.azure.com connectivity" -ForegroundColor DarkYellow
    if ($ShowAzCliErrors) { Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkYellow }
    exit 1
  }

  if ($rgExists -eq 'false') {
    # Disambiguate: non-existent vs no access vs timeout.
    try {
      Invoke-AzCli-WithTimeout -Arguments @('group','show','-n',$script:RG,'--only-show-errors','-o','none') -TimeoutSeconds $AzCliTimeoutSeconds -ThrowOnNonZero | Out-Null
      # If group show succeeds, treat it as existing.
      $rgExists = 'true'
    } catch {
      $msg = ($_.Exception.Message ?? '').ToString()
      if ($msg -match '(?i)AuthorizationFailed|Forbidden|does not have authorization') {
        Write-Host "Resource group '$script:RG' may exist but you do not have access to read it." -ForegroundColor Red
        Write-Host "Troubleshooting:" -ForegroundColor DarkYellow
        Write-Host "  - Ensure your identity has at least Reader on the subscription/resource group" -ForegroundColor DarkYellow
        Write-Host "  - Run: az role assignment list --assignee <yourUPN> --scope /subscriptions/$script:SUB -o table" -ForegroundColor DarkYellow
        if ($ShowAzCliErrors) { Write-Host "Details: $msg" -ForegroundColor DarkYellow }
        exit 1
      }
      if ($msg -match '(?i)timed out|timeout') {
        Write-Host "Azure CLI timed out while checking resource group '$script:RG'." -ForegroundColor Red
        Write-Host "Troubleshooting:" -ForegroundColor DarkYellow
        Write-Host "  - Re-run with a higher -AzCliTimeoutSeconds (e.g., 180)" -ForegroundColor DarkYellow
        Write-Host "  - If needed: az login ; az account set --subscription $script:SUB" -ForegroundColor DarkYellow
        Write-Host "  - If network/proxy issues: verify management.azure.com connectivity" -ForegroundColor DarkYellow
        if ($ShowAzCliErrors) { Write-Host "Details: $msg" -ForegroundColor DarkYellow }
        exit 1
      }

      Write-Host "Resource group '$script:RG' does not exist (or is not visible). Nothing to delete." -ForegroundColor DarkYellow
      exit 0
    }
  }

  if ($rgExists -ne 'true') {
    Write-Host "Could not determine resource group existence for '$script:RG' (unexpected az output: '$rgExists')." -ForegroundColor Red
    Write-Host "Try: az group exists -n $script:RG -o tsv" -ForegroundColor DarkYellow
    exit 1
  }

  Write-Host ">> Removing locks in RG (if any)…"
  try { $locks = az lock list --resource-group $script:RG --query "[].id" --output tsv } catch { $locks = '' }
  if ($locks) {
    foreach ($L in ($locks -split "`n")) {
      if ($L) { try { az lock delete --ids $L | Out-Null } catch { Write-Host "(warn) could not delete RG lock $L" -ForegroundColor DarkYellow } }
    }
  }

  if (-not $SkipCapabilityHostCleanup) {
    Write-Host ">> [Foundry] Deleting capability hosts first (if any)…" -ForegroundColor Cyan
    try {
      Remove-CognitiveServices-CapabilityHosts-InRg -rg $script:RG -apiVersion $CapabilityHostApiVersion -timeoutMinutes $TimeoutMinutes -pollSeconds $PollSeconds -settleMinutes $CapabilityHostSettleMinutes
    } catch {
      Write-Host "   (warn) Capability host cleanup failed or was incomplete: $($_.Exception.Message)" -ForegroundColor DarkYellow
      Write-Host "   (warn) Continuing with RG cleanup; you may need to retry capability host deletion manually." -ForegroundColor DarkYellow
    }
  } else {
    Write-Host ">> [Foundry] Skipping capability host cleanup (per -SkipCapabilityHostCleanup)." -ForegroundColor DarkYellow
  }

  if (-not $SkipCognitiveServicesAccountDelete) {
    Write-Host ">> [Foundry] Trying to delete Cognitive Services accounts (retry on linkage)…" -ForegroundColor Cyan
    try {
      $capturedAccounts = Get-CognitiveServices-Accounts-InRg -rg $script:RG
      Remove-CognitiveServices-Accounts-WithRetryInRg -rg $script:RG -TimeoutMinutes $AccountDeleteRetryTimeoutMinutes -PollSeconds $AccountDeleteRetryPollSeconds

      if (-not $SkipCognitiveServicesAccountPurge) {
        Write-Host ">> [Foundry] Purging deleted Cognitive Services accounts (best-effort)…" -ForegroundColor Cyan
        Purge-CognitiveServices-DeletedAccounts -SubscriptionId $script:SUB -Accounts $capturedAccounts -WaitMinutes $AccountPurgeWaitMinutes -SettleMinutes $AccountPurgeSettleMinutes -ApiVersion $AccountPurgeApiVersion -ApiVersionFallbacks $AccountPurgeApiVersionFallbacks
      } else {
        Write-Host ">> [Foundry] Skipping Cognitive Services account purge (per -SkipCognitiveServicesAccountPurge)." -ForegroundColor DarkYellow
      }
    } catch {
      Write-Host "   (warn) Cognitive Services account delete step failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
      Write-Host "   (warn) Continuing with RG cleanup; RG deletion may still work and finish later." -ForegroundColor DarkYellow
    }
  } else {
    Write-Host ">> [Foundry] Skipping Cognitive Services account delete (per -SkipCognitiveServicesAccountDelete)." -ForegroundColor DarkYellow
  }

  Write-Host ">> Enumerating NSGs in '$script:RG'…"
  try { $nsgsRaw = az network nsg list -g $script:RG --query "[].id" --output tsv } catch { $nsgsRaw = '' }
  $NSG_IDS = if ($nsgsRaw) { $nsgsRaw -split "`n" } else { @() }
  foreach ($NSG_ID in $NSG_IDS) {
    if ([string]::IsNullOrWhiteSpace($NSG_ID)) { continue }
    $NSG_NAME = $NSG_ID.Split('/')[-1]
    Write-Host ">> Processing NSG: $NSG_NAME"

    try { $rgNicsRaw = az network nic list -g $script:RG --query "[?networkSecurityGroup && networkSecurityGroup.id=='$NSG_ID'].name" --output tsv } catch { $rgNicsRaw = '' }
    if ($rgNicsRaw) {
      foreach ($nic in ($rgNicsRaw -split "`n")) {
        if ($nic) {
          Write-Host "   - Removing NSG from NIC $script:RG/$nic"
          try { az network nic update -g $script:RG -n $nic --remove networkSecurityGroup | Out-Null } catch { Write-Host "     (warn) failed NIC update $nic" -ForegroundColor DarkYellow }
        }
      }
    }

    try { $vnetsRaw = az network vnet list -g $script:RG --query "[].name" --output tsv } catch { $vnetsRaw = '' }
    if ($vnetsRaw) {
      foreach ($VNET in ($vnetsRaw -split "`n")) {
        if (-not $VNET) { continue }
        try { $subsRaw = az network vnet subnet list -g $script:RG --vnet-name $VNET --query "[?networkSecurityGroup && networkSecurityGroup.id=='$NSG_ID'].name" --output tsv } catch { $subsRaw = '' }
        if ($subsRaw) {
          foreach ($S in ($subsRaw -split "`n")) {
            if ($S) {
              Write-Host "   - Disassociating NSG from subnet ${script:RG}/${VNET}/$S"
              try { az network vnet subnet update -g $script:RG --vnet-name $VNET -n $S --remove networkSecurityGroup | Out-Null } catch { Write-Host "     (warn) subnet update failed $S" -ForegroundColor DarkYellow }
            }
          }
        }
      }
    }

    try {
      az network nsg delete --ids $NSG_ID | Out-Null
    } catch {
      Write-Host "!! NSG delete failed; performing broad disassociation & retrying…"
      Broad-Disassociate-NSG -NSG_ID $NSG_ID
      try { az network nsg delete --ids $NSG_ID | Out-Null } catch { Write-Host "!! Final NSG delete failed: $NSG_ID" -ForegroundColor Red }
    }
  }

  Break-VNet-Blockers-In-RG -rg $script:RG

  Write-Host ">> Final lock cleanup at RG level…"
  try { $locks2 = az lock list --resource-group $script:RG --query "[].id" --output tsv } catch { $locks2 = '' }
  if ($locks2) {
    foreach ($L2 in ($locks2 -split "`n")) {
      if ($L2) { try { az lock delete --ids $L2 | Out-Null } catch { Write-Host "(warn) could not delete RG lock $L2" -ForegroundColor DarkYellow } }
    }
  }

  if ($Confirm -and -not $Force) {
    Write-Host
    if ($script:DELETE_RG -eq 'Y') {
      $sure = Read-Host "About to DELETE resource group '$script:RG' and all its content. Are you sure? [y/N]"
    } else {
      $sure = Read-Host "About to DELETE all resources inside '$script:RG' (keeping the resource group). Are you sure? [y/N]"
    }
    if (-not ($sure.ToLower() -in @('y','yes'))) {
      Write-Host 'Aborted.'
      return
    }
  }

  if ($script:DELETE_RG -eq 'Y') {
    Write-Host ">> Deleting resource group '$script:RG'…"
    $deleteArgs = @('group','delete','-n',$script:RG,'--yes','--no-wait')
    try { az @deleteArgs | Out-Null } catch { Write-Host "(error) RG delete command failed: $($_.Exception.Message)" -ForegroundColor Red; exit 2 }

    if ($NoWait) { Write-Host "Delete initiated (no-wait)." -ForegroundColor Green; return }

    Write-Host ">> Polling for deletion (timeout ${TimeoutMinutes}m, interval ${PollSeconds}s)…"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $sawDeleting = $false
    while ($true) {
      Start-Sleep -Seconds $PollSeconds
      # Never assume 'Deleted' on errors (DNS/auth). Use az group exists when possible.
      $exists = ''
      try { $exists = (az group exists -n $script:RG --output tsv 2>$null).ToString().Trim() } catch { $exists = '' }

      if ($exists -eq 'false') {
        $state = 'Deleted'
      } elseif ($exists -eq 'true') {
        try {
          $state = (az group show -n $script:RG --query properties.provisioningState --output tsv 2>$null).ToString().Trim()
        } catch {
          $state = 'Unknown'
        }
      } else {
        $state = 'Unknown'
      }

      if (-not $state) { $state = 'Unknown' }
      Write-Host "   - State: $state (elapsed $([int]$sw.Elapsed.TotalSeconds)s)"
      if ($state -eq 'Deleted') { break }
      if ($state -eq 'Deleting') { $sawDeleting = $true }
      if ($state -eq 'Succeeded' -and $sawDeleting) {
        Write-Host "Deletion appears to have rolled back to 'Succeeded'. The resource group still exists; deletion likely failed due to blockers (see errors above)." -ForegroundColor Yellow
        exit 4
      }
      if ($state -eq 'Unknown') {
        if ($sw.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
          Write-Host "Timeout waiting for deletion (state unknown due to network/DNS/auth errors)." -ForegroundColor Yellow
          exit 3
        }
        continue
      }
      if ($sw.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
        Write-Host "Timeout waiting for deletion. Investigating remaining resources:" -ForegroundColor Yellow
        try { 
          $remainingList = az resource list -g $script:RG --output table
          Write-Host $remainingList
          
          # Try to force delete remaining resources
          Write-Host ">> Attempting to force delete remaining resources..." -ForegroundColor Cyan
          
          # Special handling for Search services that might still be processing
          Force-Delete-Remaining-SearchServices -rg $script:RG
          
          $remainingIds = az resource list -g $script:RG --query "[].id" --output tsv
          if ($remainingIds) {
            foreach ($rid in ($remainingIds -split "`n")) {
              if ($rid) {
                $resourceName = $rid.Split('/')[-1]
                Write-Host "   - Force deleting: $resourceName"
                try { 
                  az resource delete --ids $rid --no-wait | Out-Null 
                } catch { 
                  Write-Host "     (warn) Force delete failed: $resourceName" -ForegroundColor DarkYellow
                }
              }
            }
            
            # Wait a bit and retry RG deletion
            Write-Host "   - Waiting for force deletions to process..."
            Start-Sleep -Seconds 30
            
            Write-Host ">> Retrying resource group deletion..." -ForegroundColor Cyan
            try { 
              az group delete -n $script:RG --yes --no-wait | Out-Null
              Write-Host "   - RG deletion re-initiated. Check Azure portal for final status." -ForegroundColor Green
            } catch {
              Write-Host "   - RG deletion retry failed. Manual cleanup may be required." -ForegroundColor Red
            }
          }
        } catch { }
        exit 3
      }
    }
    Write-Host "✅ Resource group deleted (or no longer returned)." -ForegroundColor Green
  } else {
    Write-Host ">> Deleting all resources inside resource group '$script:RG' (keeping the RG)…"
    
    # List all resources in the resource group
    try { 
      $resourceIds = az resource list -g $script:RG --query "[].id" --output tsv 
    } catch { 
      Write-Host "(error) Failed to list resources in RG: $($_.Exception.Message)" -ForegroundColor Red
      exit 2
    }
    
    if (-not $resourceIds) {
      Write-Host "✅ No resources found in resource group. Resource group is already empty." -ForegroundColor Green
      return
    }
    
    $resourcesToDelete = $resourceIds -split "`n" | Where-Object { $_ }
    $totalResources = $resourcesToDelete.Count
    Write-Host "   - Found $totalResources resource(s) to delete"
    
    $deletedCount = 0
    $failedCount = 0
    
    foreach ($rid in $resourcesToDelete) {
      if ([string]::IsNullOrWhiteSpace($rid)) { continue }
      $resourceName = $rid.Split('/')[-1]
      Write-Host "   - Deleting resource: $resourceName"
      try { 
        az resource delete --ids $rid --no-wait | Out-Null
        $deletedCount++
      } catch { 
        Write-Host "     (warn) Failed to delete resource: $rid" -ForegroundColor DarkYellow
        $failedCount++
      }
    }
    
    if ($NoWait) { 
      Write-Host "✅ Delete initiated for $deletedCount resource(s) (no-wait). Resource group '$script:RG' remains." -ForegroundColor Green
      if ($failedCount -gt 0) {
        Write-Host "   - $failedCount resource(s) failed to delete" -ForegroundColor Yellow
      }
      return 
    }
    
    # Poll to ensure resources are deleted
    Write-Host ">> Polling for resource deletion (timeout ${TimeoutMinutes}m, interval ${PollSeconds}s)…"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
      Start-Sleep -Seconds $PollSeconds
      try { 
        $remainingResources = az resource list -g $script:RG --query "[].id" --output tsv 
        $remaining = if ($remainingResources) { ($remainingResources -split "`n" | Where-Object { $_ }).Count } else { 0 }
      } catch { 
        $remaining = 0 
      }
      
      Write-Host "   - Remaining resources: $remaining (elapsed $([int]$sw.Elapsed.TotalSeconds)s)"
      
      if ($remaining -eq 0) { break }
      
      if ($sw.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
        Write-Host "Timeout waiting for all resources to be deleted. Some resources may still remain:" -ForegroundColor Yellow
        try { az resource list -g $script:RG --output table } catch { }
        exit 3
      }
    }
    
    Write-Host "✅ All resources deleted from resource group '$script:RG'. Resource group remains." -ForegroundColor Green
  }
}

Main