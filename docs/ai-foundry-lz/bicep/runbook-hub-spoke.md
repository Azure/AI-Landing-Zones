# Runbook — Hub-and-Spoke deployment

This runbook walks you through deploying the AI Landing Zone as a **spoke** in an Application Landing Zone (ALZ) topology, where a separate **hub** subscription owns shared platform resources (Azure Firewall, Bastion, Private DNS zones, central Log Analytics workspace).

It mirrors exactly what the v2.0.0 team did to validate `v2.0.0-dev` end-to-end against a real Azure subscription, and you can follow it as a working tutorial.

> **Audience**: developers and platform engineers who are comfortable with `azd` and `az` but may not be deep networking specialists. Every command has an explanation of what it does and why.

---

## 1. What you'll end up with

After this runbook you have:

```
+--------------------------------------------------+
|  Hub VNet (10.100.0.0/16)                        |
|  rg-ailz-hub                                     |
|    Azure Firewall (10.100.0.4)                   |
|    Azure Bastion (Standard SKU, with tunneling)  |
|    Log Analytics Workspace                       |
|                                                  |
|              ▲ VNet peering ▼                    |
+--------------------------------------------------+
                                                    
+--------------------------------------------------+
|  Spoke VNet (192.168.0.0/22)                     |
|  rg-ailz-spoke-MMDDYYHHMM                        |
|    AI Foundry account + project                  |
|    Container Apps Environment (internal)         |
|    Cosmos DB, Key Vault, ACR, Storage, AppConfig |
|    AI Search                                     |
|    Jumpbox VM (no public IP, reached via         |
|      hub Bastion through the peering)            |
|    Application Insights                          |
|    13 Private Endpoints + 14 Private DNS zones   |
+--------------------------------------------------+
```

You verify success by opening the deployed Container App hello-world from inside the jumpbox via its private FQDN.

---

## 2. Prerequisites

| What | Why |
| --- | --- |
| Azure subscription with **Contributor** and **User Access Administrator** | Provision resources + assign RBAC |
| Same Azure region for hub and spoke (this guide uses `eastus2`) | Bastion peering is regional |
| `az` ≥ 2.60, `azd` ≥ 1.25, PowerShell 7 | Tooling expected by the templates |
| Repo cloned locally | This document refers to relative paths in the repo |

```pwsh
az login
azd auth login
$sub = '<your-subscription-id>'
az account set --subscription $sub
```

---

## 3. Deploy the hub

The hub is a **simulation** for testing. In a real ALZ deployment, the hub already exists and you skip this step.

This repo ships `tests/hub/` with a minimal hub fixture: VNet, Firewall + Policy, Bastion (Standard SKU, native-client tunneling enabled), and a Log Analytics workspace.

```pwsh
$hubRg = 'rg-ailz-hub'
az group create -n $hubRg -l eastus2 --query "properties.provisioningState" -o tsv

pwsh ./tests/scripts/Deploy-Hub.ps1 -ResourceGroupName $hubRg -Location eastus2
```

The script writes the resource IDs of the deployed hub resources to `tests/hub/.outputs.json` for downstream consumption.

**Expected duration**: ~10 minutes.

**Verify**:

```pwsh
az network firewall list -g $hubRg --query "[].{name:name,state:provisioningState}" -o table
az network bastion list  -g $hubRg --query "[].{name:name,sku:sku.name,tunneling:enableTunneling}" -o table
```

You should see one firewall in `Succeeded` and one Bastion with `Standard` SKU and `tunneling=True`.

---

## 4. Capture hub outputs

The spoke deployment needs three resource IDs from the hub:

```pwsh
$hubOut         = Get-Content ./tests/hub/.outputs.json -Raw | ConvertFrom-Json
$hubVnetId      = $hubOut.hubVnetResourceId
$hubLawId       = $hubOut.logAnalyticsWorkspaceResourceId
$hubBastionId   = $hubOut.bastionResourceId
$hubFwPrivateIp = $hubOut.firewallPrivateIp

"VNet:     $hubVnetId"
"LAW:      $hubLawId"
"Bastion:  $hubBastionId"
"FW IP:    $hubFwPrivateIp"
```

---

## 5. Create the spoke environment

Use a deterministic naming pattern so multiple test deployments don't clash:

```pwsh
$stamp     = Get-Date -Format 'MMddyyHHmm'
$spokeRg   = "rg-ailz-spoke-$stamp"
$envName   = "ailz-v2-spoke-$stamp"

az group create -n $spokeRg -l eastus2 --query "properties.provisioningState" -o tsv

azd env new $envName --subscription $sub --location eastus2
```

> All subsequent `azd env set` and `azd provision` commands operate against this new environment.

---

## 6. Configure topology

This is where the v2.0.0 flags come in. Each `azd env set` here corresponds to a feature in [v2-migration.md §3](./v2-migration.md).

### 6.1. Deployment mode (advisory)

```pwsh
azd env set DEPLOYMENT_MODE ailz-integrated
```

This sets a deployment tag (`deploymentMode=ailz-integrated`) so the topology intent is visible in the deployment record. It does not by itself change any other defaults — you still set the flags below explicitly.

### 6.2. Network isolation (Zero Trust)

```pwsh
azd env set NETWORK_ISOLATION true
```

This is unchanged from v1.x. PEs everywhere, public access disabled on PaaS planes.

### 6.3. Decoupled jumpbox / Bastion / NAT GW

The spoke wants its own jumpbox VM (so it can run data-plane scripts inside the spoke VNet), but reuses the **hub's** Bastion for SSH/RDP access:

```pwsh
azd env set DEPLOY_JUMPBOX true
azd env set DEPLOY_BASTION false
azd env set EXISTING_BASTION_RESOURCE_ID $hubBastionId
azd env set DEPLOY_NAT_GATEWAY true
azd env set DEPLOY_SOFTWARE false      # skip jumpbox post-config in this test
```

If your hub also exposes a NAT Gateway you want to reuse, swap the last two for:

```pwsh
azd env set DEPLOY_NAT_GATEWAY false
azd env set EXISTING_NAT_GATEWAY_RESOURCE_ID <hub-nat-gw-id>
```

### 6.4. Observability reuse

```pwsh
azd env set EXISTING_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID $hubLawId
```

The spoke skips LAW creation and binds App Insights, Container Apps Environment diagnostics, and AMPLS (if any) to the hub LAW. Cross-RG references are handled transparently.

### 6.5. Hub peering

```pwsh
azd env set HUB_INTEGRATION_HUB_VNET_RESOURCE_ID $hubVnetId
# create-hub-peering defaults to true and works fine as-is
```

`main.bicep` creates the spoke→hub peering automatically. The reverse direction is done after `azd provision` (see §8).

### 6.6. Hub firewall vs. spoke firewall

This guide deploys the spoke **without** its own Azure Firewall, since the hub already has one. To avoid forwarding spoke egress to the hub FW (which requires a hub FW policy that allows it), keep the route-table empty for this test:

```pwsh
azd env set DEPLOY_AZURE_FIREWALL false
# Leave HUB_INTEGRATION_EGRESS_NEXT_HOP_IP unset → spoke uses default Internet routing
```

In production, set `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP=$hubFwPrivateIp` to forward `0.0.0.0/0` through the hub FW (you'll need a corresponding hub FW policy that allows the spoke source CIDRs).

### 6.7. Optional: Disable Search to skip the slowest resource

If you're iterating fast and don't need AI Search for your test:

```pwsh
azd env set DEPLOY_SEARCH_SERVICE false
```

The hello-world test app does not depend on AI Search at runtime.

### 6.8. Optional: cross-region Search if your home region is full

`InsufficientResourcesAvailable` on AI Search can hit any region during peak hours. To work around it, deploy AI Search in a sibling region:

```pwsh
azd env set AZURE_SEARCH_LOCATION eastus    # spoke is in eastus2
```

The Private Endpoint stays in the spoke VNet (eastus2); only the Search service itself lives in eastus. This validates the v2.0 "cross-region PE" scenario without any code changes.

### 6.9. Optional: Foundry inference-only

```pwsh
azd env set DEPLOY_AAF_AGENT_SVC false
```

Use this when the spoke only needs AI Foundry hosted model inference. The AI Foundry account, project, and model deployments remain enabled, while the Agent Service Standard Setup and its associated AI Search, Storage, Cosmos DB, and Key Vault resources are skipped. `DEPLOY_SEARCH_SERVICE` remains independent and controls only the workload/RAG Search service.

### 6.10. Optional: GPT-RAG Foundry IQ Pattern B

Use this only for a GPT-RAG environment that has been validated for Foundry IQ.
Pattern B registers the existing GPT-RAG Azure AI Search index as a Foundry IQ
`searchIndex` knowledge source.

```pwsh
azd env set RETRIEVAL_BACKEND foundry_iq
azd env set FOUNDRY_IQ_PATTERN searchIndex
azd env set FOUNDRY_IQ_API_VERSION 2026-05-01-preview
azd env set FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN free
azd env set FOUNDRY_IQ_FILTER_ADD_ON_ENABLED true
```

After `azd provision`, run `scripts/Configure-FoundryIQKnowledgeBase.ps1` from
the jumpbox or another VNet-connected host to create or update the Search
data-plane knowledge source and knowledge base. The caller needs **Search Service
Contributor** on the Search service. Set
`FOUNDRY_IQ_KNOWLEDGE_RETRIEVAL_BILLING_PLAN=standard` only after billing
approval.

### 6.11. Sanity check

```pwsh
azd env get-values | Sort-Object
```

Confirm `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_LOCATION=eastus2`, `AZURE_PRINCIPAL_ID`, and the flags above are present.

---

## 7. Provision the spoke

```pwsh
azd provision
```

> A **pre-flight script** (`scripts/Invoke-PreflightChecks.ps1`) runs automatically as an `azd preprovision` hook before the deployment touches Azure. It validates the parameter set (CIDR ranges, BYO resources, conflicting flags, and insufficient AI Foundry OpenAI model quota) and fails fast on deterministic mistakes. To bypass it temporarily, set `$env:PREFLIGHT_SKIP = 'true'` before running `azd provision`. See [docs/v2-migration.md §6](./v2-migration.md#6-pre-flight-validation-script) for the full list of checks.

**Expected duration**: 25–35 minutes for a network-isolated spoke with all PEs and the AI Foundry account.

If `azd` reports "Login expired" mid-deploy (refresh token is 90 days), don't panic — the ARM deployment continues server-side. After token refresh (`azd auth login`), re-run `azd provision` and it will pick up where it left off.

**Verify**:

```pwsh
az resource list -g $spokeRg --query "length(@)" -o tsv     # ~80 resources for a full deploy
az containerapp list -g $spokeRg --query "[].{name:name,fqdn:properties.configuration.ingress.fqdn}" -o table
az vm list -g $spokeRg --query "[].{name:name,powerState:powerState}" -d -o table
```

---

## 8. Create the reverse hub→spoke peering

The spoke→hub peering is created automatically by `main.bicep`. The reverse direction (hub→spoke) needs to be created **after** the spoke VNet exists and **from a context that has write access to the hub RG**.

```pwsh
pwsh ./tests/scripts/Add-HubSpokePeering.ps1 `
    -HubVnetResourceId  $hubVnetId `
    -SpokeVnetResourceId (az network vnet show -g $spokeRg -n (az network vnet list -g $spokeRg --query "[0].name" -o tsv) --query id -o tsv)
```

**Verify both directions show `Connected`**:

```pwsh
$hubVnetName   = ($hubVnetId.Split('/'))[-1]
$spokeVnetName = (az network vnet list -g $spokeRg --query "[0].name" -o tsv)

az network vnet peering list -g $hubRg   --vnet-name $hubVnetName   --query "[].{name:name,state:peeringState,fwd:allowForwardedTraffic}" -o table
az network vnet peering list -g $spokeRg --vnet-name $spokeVnetName --query "[].{name:name,state:peeringState,fwd:allowForwardedTraffic}" -o table
```

`peeringState=Connected` on both sides is the success criterion.

---

## 9. End-to-end test

The deployed Container App is the canonical `mcr.microsoft.com/dotnet/samples:aspnetapp` image, which serves a hello-world ASP.NET page on **port 8080**. Under `networkIsolation=true`, the Container Apps environment is **internal** — the app is only reachable from inside the spoke VNet.

We test it from the jumpbox.

### 9.1. Without opening RDP (CI / automation path)

Use `az vm run-command` to execute a small PowerShell snippet on the jumpbox and capture the output:

```pwsh
$fqdn = az containerapp show -g $spokeRg -n (az containerapp list -g $spokeRg --query "[0].name" -o tsv) --query "properties.configuration.ingress.fqdn" -o tsv

$script = @"
Resolve-DnsName -Type A '$fqdn' | Format-Table -AutoSize | Out-String
try {
    `$r = Invoke-WebRequest -Uri 'http://$fqdn' -UseBasicParsing -TimeoutSec 30
    Write-Host ('Status=' + `$r.StatusCode + ' Len=' + `$r.Content.Length)
    Write-Host `$r.Content.Substring(0, [Math]::Min(400, `$r.Content.Length))
} catch { Write-Host ('ERROR: ' + `$_.Exception.Message) }
"@

az vm run-command invoke -g $spokeRg -n $vmName --command-id RunPowerShellScript --scripts $script --query "value[0].message" -o tsv
```

**Expected output**:

```
ca-...-orchestrator.<region-suffix>.eastus2.azurecontainerapps.io  CNAME  ...  →  privatelink.eastus2.azurecontainerapps.io
privatelink.eastus2.azurecontainerapps.io                          A     ...  →  192.168.2.x         ← spoke private IP, not public
Status=200 Len=3753
<!DOCTYPE html><html lang="en"><head>...<title>Welcome to .NET - aspnetapp</title>...
```

The fact that DNS resolves to a **private** address (`192.168.x.x` from the ACA environment subnet) is the proof that the Private DNS zone for `privatelink.<region>.azurecontainerapps.io` is correctly linked to the spoke VNet and that the spoke→hub peering is not interfering with private-DNS resolution.

### 9.2. Interactive (developer path)

To explore the spoke interactively via RDP/SSH through the hub Bastion:

```pwsh
# RDP to the Windows jumpbox via the hub Bastion (cross-VNet works because of the peering)
az network bastion rdp `
  --name (az network bastion list -g $hubRg --query "[0].name" -o tsv) `
  --resource-group $hubRg `
  --target-resource-id (az vm show -g $spokeRg -n $vmName --query id -o tsv)
```

This requires the **Standard** (or Premium) Bastion SKU with `enableTunneling=true` — both are configured by the hub fixture in §3. First time access requires resetting the VM password via the portal (**Support + troubleshooting → Reset password**, username `testvmuser`).

Once logged in, open a browser inside the jumpbox and navigate to `http://<container-app-fqdn>` to see the hello-world page.

---

## 10. Tear down

```pwsh
azd down --force --purge    # spoke resources

# Optional: also delete the hub fixture
az group delete -n $hubRg --yes --no-wait
```

`--purge` purges soft-deleted Key Vault / App Configuration / Cognitive Services accounts so the names are immediately reusable.

---

## 11. Troubleshooting

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| `LinkedInvalidPropertyId: 'null' at properties.routeTable.id` | `${VAR=null}` default produced the string `"null"` for a string-typed param. Fixed in v2.0.0 — only happens if you reverted that fix. | Make sure your `main.parameters.json` uses `${VAR=}` (empty default) for nullable string params. |
| `InsufficientResourcesAvailable` on AI Search | Regional SKU capacity exhausted | `azd env set AZURE_SEARCH_LOCATION eastus` (or another sibling region) and re-run `azd provision` |
| `InvalidResourceLocation: uai-srch-... already exists in eastus2` after moving Search to a different region | The previous attempt created a UAI in the old region | `az identity delete -g <spoke-rg> -n uai-srch-<token>` then re-run |
| `Login expired` mid-deploy | `azd` token refresh window (90 days) elapsed | `azd auth login` and re-run; the in-flight ARM deployment continues server-side |
| Container App FQDN resolves to a public IP from the jumpbox | Private DNS zone not linked to the spoke VNet (or BYO override pointed at a zone that's not linked) | Check `az network private-dns link vnet list -g <rg> -z privatelink.<region>.azurecontainerapps.io` |
| Container App returns 502 from the jumpbox | Image pull failure or app crashed | `az containerapp logs show -g <rg> -n <ca>` and inspect; common cause is firewall blocking image pull (set `extendFirewallForJumpboxBootstrap=true` or whitelist the registry) |

---

## 12. What this validates

A successful run of this runbook validates the entire v2.0.0 hub-and-spoke story:

- ✅ Decoupled `deployJumpbox` / `deployBastion` / `deployNatGateway`
- ✅ Cross-RG reuse of hub Bastion via `existingBastionResourceId`
- ✅ Cross-RG reuse of hub Log Analytics workspace
- ✅ Cross-RG App Insights connection (AI Foundry submodule)
- ✅ Spoke→hub VNet peering created by `main.bicep`
- ✅ Reverse hub→spoke peering helper script
- ✅ Cross-region AI Search with PE in the spoke region (if §6.8 was used)
- ✅ Deployment-mode tag on the deployment
- ✅ Hello-world container app reachable only via the private FQDN
- ✅ Pre-flight validation script running as a `preprovision` hook

It does **not** validate (these are covered by the [Standalone runbook](./runbook-standalone.md)):

- BYO Private DNS zones (§3.6 in the migration guide)
- BYO route table for external egress
- `allowedIpRanges` for the public-with-restricted-IPs scenario