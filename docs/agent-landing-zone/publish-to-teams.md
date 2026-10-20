# Publish to Teams and Microsoft 365 Copilot

<a id="publish-to-teams"></a>

Publish a Foundry hosted agent to **Teams and Microsoft 365 Copilot**. This manual
task is separate from the landing zone deployment. Expand the commands as you
follow the five steps.

**Teams / Microsoft 365 Copilot** &rarr; **Azure Bot Service** &rarr;
**Foundry Activity endpoint**

Foundry and Bot Service keep **public network access disabled**. Only the
Activity route accepts restricted public HTTPS from service-managed Microsoft
channel ranges, with authentication. It does not use your private endpoint,
Application Gateway or web UI. This follows the
[Foundry REST publishing flow](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network).

| Destination | Covered here? |
| --- | --- |
| Teams and Microsoft 365 Copilot | Yes. One publication, then verify each client in Step 5. |
| Microsoft Agent 365 autopilot | No. A [separate flow](https://learn.microsoft.com/azure/foundry/agents/how-to/agent-365) creates instances with their own agent user accounts and requires tenant enrollment, licensing and admin approval. |
| Copilot Studio | No. This is not a connected-agent configuration. |

Not the web UI or a `classic` Container Apps orchestrator.

## Prerequisites

- A working `hosted-no-panel` or `hosted-panel` deployment from
  [Full stack deploy](deploy-full-stack.md), with a tested agent version.
- A [VNet-connected host](network-isolation.md#reach-the-private-network) that
  resolves and reaches the Foundry project's private endpoint.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli),
  [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli)
  and **PowerShell 7.4 or later**. Run Steps 1-4 in one session.
- **Foundry User** on the project, plus **Azure Bot Service Contributor Role**
  and permission to create resource-group deployments in the target resource
  group. Resource-group **Contributor** also covers the bot and deployment.
  A subscription administrator must register `Microsoft.BotService` if needed.
- Teams and Microsoft 365 Copilot access for **members of the Foundry tenant**,
  with applicable licenses and app policies. Guests cannot call these agents.
  Organization-wide publication needs Microsoft 365 admin approval.

!!! warning "Approve the data flow first"
    Microsoft 365 processes metadata and conversations under its own compliance
    and data-residency commitments. Approve this channel first. The web UI's
    delegated authentication, document permissions and uploads do not
    automatically transfer to either client.

## Step 1: Select the agent and save its configuration

In the Azure portal, note the subscription, resource group, Foundry resource and
project names. In [Foundry](https://ai.azure.com/), open the project and agent;
note the **tested agent version**. The bundled agent name is
`agent-app-orchestrator`; use the actual name for a custom agent.

Replace the placeholders and run on the connected host.

<details class="runbook-command" markdown="1">
<summary>PowerShell: select the target and save a backup</summary>

```powershell
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$subscriptionId = "<subscription-id>"
$resourceGroup = "<foundry-resource-group>"
$foundryName = "<foundry-resource-name>"
$projectName = "<foundry-project-name>"
$agentName = "agent-app-orchestrator"
$agentVersion = "<tested-agent-version>"
$botName = "<globally-unique-bot-name>"
$publishScope = "Shared"

az login
az account set --subscription $subscriptionId
$tenantId = az account show --query tenantId --output tsv
az account show --query "{subscription:id,tenant:tenantId}" --output table

$pna = az cognitiveservices account show --name $foundryName `
    --resource-group $resourceGroup --query properties.publicNetworkAccess --output tsv
if ($pna -ne "Disabled") { throw "This runbook requires Foundry PNA Disabled." }

$work = Join-Path $HOME ("teams-publication-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Path $work | Out-Null
Set-Location $work

$projectEndpoint = "https://$foundryName.services.ai.azure.com/api/projects/$projectName"
$agentUri = "$projectEndpoint/agents/$([uri]::EscapeDataString($agentName))"
$token = az account get-access-token --resource https://ai.azure.com `
    --query accessToken --output tsv
$headers = @{ Authorization = "Bearer $token" }
Remove-Variable token

$agent = (Invoke-WebRequest -Uri "${agentUri}?api-version=v1" `
    -Headers $headers).Content | ConvertFrom-Json -AsHashtable
if (-not $agent.instance_identity.client_id -or -not $agent.agent_endpoint) {
    throw "The agent needs a unique identity and stable endpoint. Stop before publishing."
}
$agent | ConvertTo-Json -Depth 100 | Set-Content agent-before.json
@{
    subscriptionId = $subscriptionId
    tenantId = $tenantId
    resourceGroup = $resourceGroup
    foundryName = $foundryName
    agentUri = $agentUri
    botName = $botName
} | ConvertTo-Json | Set-Content target.json
$agent.agent_endpoint | ConvertTo-Json -Depth 100
"Working folder: $work"
```

</details>

**Expected:** the intended tenant/subscription, identity `client_id`, endpoint
configuration and working-folder path. Keep that path, `target.json` and
`agent-before.json` outside source control; they contain no bearer token.

Choose the audience **before Step 3**, in the same session:

| `$publishScope` | Who can call the agent | Store visibility |
| --- | --- | --- |
| `Shared` (start here) | Authorized identities through `BotServiceRbac` | Publisher only initially, under **Your agents**; no publishing approval |
| `Tenant` | Everyone in the Foundry tenant through `BotServiceTenant` | **Built by your org**, after Microsoft 365 admin approval |

Set `$publishScope = "Tenant"` only after organization-wide access is approved.
For `Shared`, grant selected testers **Foundry Agent Consumer** at the
[agent scope](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot-authorization#grant-access-to-one-agent).
Sharing an app link does not grant invocation permission.

If the identity check fails, follow the
[migration guidance](https://learn.microsoft.com/azure/foundry/agents/how-to/migrate-agent-applications).
Do not substitute the project identity or web UI client ID.

## Step 2: Create the bot and Teams channel

Check registration, save the template, then deploy it. The Teams channel below
also serves the Microsoft 365 Copilot publishing flow.

<details class="runbook-command" markdown="1">
<summary>1. Check Bot Service provider registration</summary>

```powershell
az provider show --namespace Microsoft.BotService --query registrationState --output tsv
```

**Expected:** `Registered`. If not, have a subscription administrator run
`az provider register --namespace Microsoft.BotService --wait`.

</details>

<details class="runbook-command" markdown="1">
<summary>2. Save bot-service.bicep in the working folder</summary>

```bicep
param botName string
param displayName string
param msaAppId string
param tenantId string
param endpoint string

resource bot 'Microsoft.BotService/botServices@2022-09-15' = {
  name: botName
  kind: 'azurebot'
  location: 'global'
  sku: {
    name: 'F0'
  }
  properties: {
    displayName: displayName
    endpoint: endpoint
    msaAppId: msaAppId
    msaAppTenantId: tenantId
    msaAppType: 'SingleTenant'
    publicNetworkAccess: 'Disabled'
  }
}

resource teams 'Microsoft.BotService/botServices/channels@2021-03-01' = {
  parent: bot
  name: 'MsTeamsChannel'
  location: 'global'
  properties: {
    channelName: 'MsTeamsChannel'
  }
}
```

</details>

Deploy this **separate** template into the Foundry resource group.
Replace the display name in the commands.

<details class="runbook-command" markdown="1">
<summary>3. Deploy the bot and verify its network setting</summary>

```powershell
$displayName = "<agent-display-name>"
$activityEndpoint = "$agentUri/endpoint/protocols/activityProtocol"

az deployment group create --resource-group $resourceGroup `
    --name "teams-bot" --template-file bot-service.bicep `
    --parameters botName=$botName displayName="$displayName" `
        msaAppId=$($agent.instance_identity.client_id) tenantId=$tenantId `
        endpoint=$activityEndpoint --output none

$botServiceId = az bot show --name $botName --resource-group $resourceGroup `
    --query id --output tsv
az resource show --ids $botServiceId --api-version 2022-09-15 `
    --query "properties.{endpoint:endpoint,pna:publicNetworkAccess}" --output json
```

</details>

**Expected:** the agent's `activityProtocol` URL and `"pna": "Disabled"`.
No bot application code, client secret, public VNet ingress or custom connector
is required.

## Step 3: Enable the restricted Activity route

Enable the route, preserve existing protocols and pin the tested version.

!!! warning "Preserve the web application path"
    The API replaces the protocol configuration and authorization array.
    Keep existing entries, especially `responses`, `invocations` and `Entra`.
    Pinning the active version affects **all consumers** of this agent, not
    only Microsoft 365 clients. Do not run concurrent configuration changes.

<details class="runbook-command" markdown="1">
<summary>PowerShell: enable Activity and pin the tested version</summary>

```powershell
if ($publishScope -notin @("Shared", "Tenant")) { throw "Choose Shared or Tenant." }
$agent = (Invoke-WebRequest -Uri "${agentUri}?api-version=v1" `
    -Headers $headers).Content | ConvertFrom-Json -AsHashtable
$protocols = $agent.agent_endpoint.protocol_configuration
if (-not $protocols) { throw "Review the agent's existing protocols before continuing." }
$activity = $protocols.activity
if (-not $activity) { $activity = @{} }
$activity.enable_m365_public_endpoint = $true
$protocols.activity = $activity

$botScheme = if ($publishScope -eq "Tenant") { "BotServiceTenant" } else { "BotServiceRbac" }
$schemes = @($agent.agent_endpoint.authorization_schemes |
    Where-Object { $_.type -notin @("BotServiceRbac", "BotServiceTenant") })
$schemes += @{ type = $botScheme }
if ("Entra" -notin $schemes.type) { throw "Review missing Entra authorization before continuing." }

$patch = @{
    agent_endpoint = @{
        protocol_configuration = $protocols
        authorization_schemes = $schemes
        version_selector = @{
            version_selection_rules = @(
                @{ type = "FixedRatio"; agent_version = $agentVersion; traffic_percentage = 100 }
            )
        }
    }
} | ConvertTo-Json -Depth 100

Invoke-RestMethod -Method Patch -Uri "${agentUri}?api-version=v1" `
    -Headers $headers -ContentType "application/merge-patch+json" -Body $patch |
    Out-Null
```

</details>

**Expected:** the PATCH succeeds. Step 5 checks the resulting configuration.

## Step 4: Publish the app

Replace the metadata placeholders with approved values. Use your organization's
HTTPS website, privacy statement and terms of use. Keep
`publishAsAutopilot=false`; Agent 365 autopilot needs the separate flow linked above.

<details class="runbook-command" markdown="1">
<summary>PowerShell: publish to Teams and Microsoft 365 Copilot</summary>

```powershell
$publishRequest = @{
    agentDisplayName = $displayName
    botServiceArmId = $botServiceId
    publishScope = $publishScope
    publishAsAutopilot = $false
    appVersion = "1.0.0"
    shortDescription = "<short-description>"
    fullDescription = "<full-description>"
    developerName = "<organization-name>"
    developerWebsiteUrl = "https://<organization-domain>"
    privacyUrl = "https://<organization-domain>/privacy"
    termsOfUseUrl = "https://<organization-domain>/terms"
}
$body = $publishRequest | ConvertTo-Json -Depth 10
$body | Set-Content publish-request.json
$result = Invoke-RestMethod -Method Post `
    -Uri "${agentUri}/microsoft365/publish?api-version=v1" `
    -Headers $headers -ContentType "application/json" -Body $body
$result | ConvertTo-Json -Depth 20 | Set-Content publish-result.json
$result
```

</details>

**Expected:** a successful response containing `titleId`. For `Tenant`, a
Microsoft 365 administrator must approve the request in
[Microsoft 365 admin center > Agents > Requests](https://admin.cloud.microsoft/?#/agents/all/requested).
Tenant app policies can still restrict availability.

!!! note "App version versus agent version"
    `appVersion` versions the store listing; increase it for metadata or scope
    changes. `$agentVersion` selects the runtime; updating it does not require
    republishing the listing.

<details class="runbook-command" markdown="1">
<summary>Optional: download the generated Teams package</summary>

For manual review or upload, reuse the request body:

```powershell
Invoke-WebRequest -Method Post -Uri "${agentUri}/microsoft365/zip?api-version=v1" `
    -Headers $headers -ContentType "application/json" -Body $body -OutFile appPackage.zip
```

Inspect the manifest and icons using the
[package inspection checklist](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot#inspect-the-downloaded-package).
Keep generated IDs and agent sections unchanged. In Teams, use
**Apps > Manage your apps > Upload an app**, then **Upload a custom app** or
**Submit an app to your org**, as allowed by your administrator.

Downloading does **not** submit the app for publication, but it can update the
agent's publishing configuration. It requires agent write permission.

</details>

## Step 5: Install and verify

<a id="resume-in-a-new-session"></a>

<details class="runbook-command" markdown="1">
<summary>Returning later or using a new PowerShell session?</summary>

After Step 2, resume verification or maintenance without recreating or
republishing. Use the Step 1 folder and connected host.

```powershell
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-Location "<saved-working-folder>"
$target = Get-Content target.json -Raw | ConvertFrom-Json -AsHashtable
$resourceGroup = $target.resourceGroup
$foundryName = $target.foundryName
$agentUri = $target.agentUri

az login --tenant $target.tenantId
az account set --subscription $target.subscriptionId
$token = az account get-access-token --resource https://ai.azure.com `
    --query accessToken --output tsv
$headers = @{ Authorization = "Bearer $token" }
Remove-Variable token
$botServiceId = az bot show --name $target.botName --resource-group $resourceGroup `
    --query id --output tsv
```

</details>

Find the agent in each client. Use the publishing account for `Shared`; for
`Tenant`, wait for admin approval and look under **Built by your org**.

| Client | Open the agent |
| --- | --- |
| Teams | **Apps** > find the agent > add it > open its chat. |
| Microsoft 365 Copilot | Open the **Agents** area > find the agent in the agent store > add/open it. For `Shared`, check **Your agents**. |

In **each client**:

1. Complete any sign-in card. Send a greeting, a workload question and a
   follow-up. Verify tools and knowledge sources, not just a reply.
2. Test an intended user and a tenant member without permission, not a guest.
   With `Shared`, the latter must be denied. For protected data, verify both
   allowed and denied identities before rollout.

From the connected host, check the final configuration:

<details class="runbook-command" markdown="1">
<summary>PowerShell: verify the endpoint and both PNA settings</summary>

```powershell
$after = Invoke-RestMethod -Uri "${agentUri}?api-version=v1" -Headers $headers
$after.agent_endpoint | ConvertTo-Json -Depth 30
az cognitiveservices account show --name $foundryName --resource-group $resourceGroup `
    --query properties.publicNetworkAccess --output tsv
az resource show --ids $botServiceId --api-version 2022-09-15 `
    --query properties.publicNetworkAccess --output tsv
```

</details>

**Expected:** the tested version at 100%, preserved original protocols and
`Entra`, `activity.enable_m365_public_endpoint=true`, the matching Bot Service
scheme, and **both PNA values `Disabled`**.

!!! note "Channel limitations"
    Published agents currently have no streaming responses or citations.
    Client file capabilities do not imply support for the web-upload pipeline.
    See [Foundry publishing limitations](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network#limitations).

## Update or stop publication

If the original session ended or its token expired, [resume the session](#resume-in-a-new-session)
before using the commands below.

| Task | Action |
| --- | --- |
| Release a new runtime version | Test it, then change the [active version](https://learn.microsoft.com/azure/foundry/agents/how-to/configure-agent#select-the-active-agent-version). Keep the bot and listing. |
| Roll back agent behavior | Select the previous tested version. This changes the version for every consumer of the stable endpoint. |
| Change listing name, descriptions or URLs | Edit `publish-request.json`, increase `appVersion`, then submit below. Keep `botServiceArmId` and `publishScope` unchanged for metadata-only updates. |
| Redeploy the landing zone or agent | Recheck the active version, Activity exception, authorization and both clients. The template does not own this manual configuration. |

<details class="runbook-command" markdown="1">
<summary>Update listing metadata</summary>

Edit and review `publish-request.json` first, then run:

```powershell
$body = Get-Content publish-request.json -Raw
$result = Invoke-RestMethod -Method Post `
    -Uri "${agentUri}/microsoft365/publish?api-version=v1" `
    -Headers $headers -ContentType "application/json" -Body $body
$result | ConvertTo-Json -Depth 20 | Set-Content publish-result.json
$result
```

</details>

To stop access from **both clients**, disable only the Activity exception.
Keep Foundry PNA disabled; the web application's private path stays available.

<details class="runbook-command" markdown="1">
<summary>Stop Teams and Copilot access</summary>

Read the **current** configuration before changing it:

```powershell
$current = (Invoke-WebRequest -Uri "${agentUri}?api-version=v1" `
    -Headers $headers).Content | ConvertFrom-Json -AsHashtable
$protocols = $current.agent_endpoint.protocol_configuration
if (-not $protocols.activity) { throw "No Activity configuration found; review the endpoint." }
$protocols.activity.enable_m365_public_endpoint = $false
$disable = @{ agent_endpoint = @{ protocol_configuration = $protocols } } |
    ConvertTo-Json -Depth 100
Invoke-RestMethod -Method Patch -Uri "${agentUri}?api-version=v1" `
    -Headers $headers -ContentType "application/merge-patch+json" -Body $disable |
    Out-Null
```

</details>

Confirm new requests from both clients are blocked, then have the administrator
block/remove the app. Uninstalling alone does not revoke endpoint access.
Do not delete shared resources or overwrite later changes with an old backup.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Project GET/PATCH fails or times out | Check private connectivity, tenant, Foundry User and token audience `https://ai.azure.com`. For an expired token, [resume](#resume-in-a-new-session). Do not enable PNA. |
| Bot deployment denied | `Microsoft.BotService` registration, bot/deployment permissions and Azure Policy. |
| Agent is missing from either client | Check account/scope, approval and app policies. Refresh or sign out/in; catalog caching can delay discovery. |
| `403 NetworkAccessDenied` on Activity | Verify the flag and test through Teams, not a public `curl` request. Arbitrary public source IPs remain blocked. |
| User can open the app but gets an authorization error | Same-tenant sign-in and, for `Shared`, Foundry Agent Consumer access. Do not switch to `Tenant` just to clear a denial. |
| Bot replies, but tools or retrieval fail | Check runtime grants, data authorization and outbound access. Web UI success does not validate channel identity propagation. |
| Conversation is stuck or returns `no tool output found` | Send `/foundry_new_preview` in the Teams chat to reset it. Previous conversation context cannot be restored. |
| `version already exists` | Increase `appVersion`; do not change the runtime version to fix listing metadata. |

For other errors, use [Foundry publishing troubleshooting](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot)
and [published-agent authorization](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot-authorization).
