# Publish to Teams

Publish an existing Foundry hosted agent as a Teams app. This is a **manual
post-deployment task**: the landing zone template does not create the bot or
publish the app.

```text
Teams -> Azure Bot Service -> Foundry agent Activity endpoint
                             Restricted public HTTPS
```

Foundry and Bot Service keep **public network access disabled**. Foundry exposes
only the Activity route to service-managed Bot Service and Microsoft 365 source
ranges; authentication still applies. This channel does not use your private
endpoint, Application Gateway or web UI.

!!! note "Scope"
    This runbook uses the [documented Foundry REST publishing flow](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network).
    It publishes the agent, not the Agent App UI or a `classic` Container Apps
    orchestrator. The same publishing API also supports Microsoft 365 Copilot;
    this runbook verifies Teams, not Copilot Studio or Agent 365 autopilot.

## Prerequisites

- A working `hosted-no-panel` or `hosted-panel` deployment from
  [Full stack deploy](deploy-full-stack.md), with a tested agent version.
- A [VNet-connected host](network-isolation.md#reach-the-private-network) that
  resolves and reaches the Foundry project's private endpoint.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli),
  [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli)
  and **PowerShell 7.4 or later**. Use the same PowerShell session throughout.
- **Foundry User** on the project, plus **Azure Bot Service Contributor Role**
  and permission to create resource-group deployments in the target resource
  group. Resource-group **Contributor** also covers the bot and deployment.
  A subscription administrator must register `Microsoft.BotService` if needed.
- Teams access in the **same tenant** as Foundry, and tenant app policies that
  permit the app. Organization-wide publication also needs Microsoft 365 admin
  approval.

!!! warning "Approve the data flow first"
    Teams and Microsoft 365 process publishing metadata and agent conversations
    under their own compliance and data-residency commitments. Approve this
    channel before sending organizational data. Do not assume the web UI's
    delegated authentication, document permissions or upload features transfer
    unchanged to Teams.

## Step 1: Select the agent and save its configuration

In the Azure portal, note the subscription, resource group, Foundry resource and
project names. In [Foundry](https://ai.azure.com/), open the project and agent;
note the **tested agent version**. The bundled agent name is
`agent-app-orchestrator`; use the actual name for a custom agent.

Replace the placeholders, then run:

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
$agent.agent_endpoint | ConvertTo-Json -Depth 100
```

**Expected:** the intended tenant and subscription, an agent identity
`client_id`, and the current endpoint configuration. Keep `agent-before.json`
in this local working folder, outside source control.

Choose the audience **before Step 3**:

| `$publishScope` | Who can call the agent | Store visibility |
| --- | --- | --- |
| `Shared` (start here) | Authorized identities through `BotServiceRbac` | Initially only the publisher, under **Your agents**; no publishing approval required |
| `Tenant` | Everyone in the Foundry tenant through `BotServiceTenant` | **Built by your org**, after Microsoft 365 admin approval |

For organization-wide publication, set `$publishScope = "Tenant"` only after
that access has been approved. With `Shared`, an administrator can give selected
testers **Foundry Agent Consumer** at the
[agent scope](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot-authorization#grant-access-to-one-agent).
Sharing an app link does not grant invocation permission.

!!! note "Older agents"
    If the identity check fails, follow the
    [Foundry migration guidance](https://learn.microsoft.com/azure/foundry/agents/how-to/migrate-agent-applications).
    Do not substitute the project's managed identity or the web UI client ID.

## Step 2: Create the bot and Teams channel

Check provider registration:

```powershell
az provider show --namespace Microsoft.BotService --query registrationState --output tsv
```

**Expected:** `Registered`. If not, have a subscription administrator run
`az provider register --namespace Microsoft.BotService --wait`.

Save this as **`bot-service.bicep`** in `$work`:

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

Deploy this **separate** template into the Foundry resource group:

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

**Expected:** the agent's `activityProtocol` URL and `"pna": "Disabled"`.
No bot application code, client secret, public VNet ingress or custom connector
is required.

## Step 3: Enable the restricted Activity route

This keeps existing protocols and non-Bot authorization schemes, adds the
matching Bot Service scheme, and pins traffic to the tested agent version.

!!! warning "Preserve the web application path"
    The API replaces the protocol configuration and authorization array.
    Keep existing entries, especially `responses`, `invocations` and `Entra`.
    Pinning the active version affects **all consumers** of this agent, not
    only Teams. Do not run concurrent agent configuration changes.

```powershell
if ($publishScope -notin @("Shared", "Tenant")) { throw "Choose Shared or Tenant." }
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

## Step 4: Publish the app

Replace the metadata placeholders with approved values. Use your organization's
real HTTPS website, privacy statement and terms of use.

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

**Expected:** a successful response containing `titleId`. For `Tenant`, a
Microsoft 365 administrator must approve the request in
[Microsoft 365 admin center > Agents > Requests](https://admin.cloud.microsoft/?#/agents/all/requested).
Tenant app policies can still restrict availability.

!!! note "App version versus agent version"
    `appVersion` versions the Teams listing. Increment it when republishing
    metadata or changing publication scope. `$agentVersion` selects the runtime.
    A runtime update does not require republishing the Teams listing.

<details markdown="1">
<summary>Optional: download the generated Teams package</summary>

For an approved manual package review or upload process, use the same request
body with the ZIP endpoint:

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

1. Open Teams **Apps** and find the agent. For `Shared`, use the publishing
   account; for `Tenant`, wait for approval and look under **Built by your org**.
   Add the app and open its chat. Complete any sign-in card.
2. Send a greeting, then a real workload question and a follow-up. Check that
   tools and knowledge sources work, not only that the bot replies.
3. Test with an intended user and an unauthorized user. For `Shared`, the latter
   must not invoke the agent. For protected data, verify document access with
   both allowed and denied identities before broader rollout.
4. From the connected host, review the final endpoint and network settings:

    ```powershell
    $after = Invoke-RestMethod -Uri "${agentUri}?api-version=v1" -Headers $headers
    $after.agent_endpoint | ConvertTo-Json -Depth 30
    az cognitiveservices account show --name $foundryName --resource-group $resourceGroup `
        --query properties.publicNetworkAccess --output tsv
    az resource show --ids $botServiceId --api-version 2022-09-15 `
        --query properties.publicNetworkAccess --output tsv
    ```

**Expected:** the tested version at 100%, preserved original protocols and
`Entra`, `activity.enable_m365_public_endpoint=true`, the matching Bot Service
scheme, and **both PNA values `Disabled`**.

!!! note "Channel limitations"
    Foundry currently documents no streaming responses or citations for
    published agents. Teams file capabilities do not prove that the bundled
    application's web-upload pipeline is supported in this channel.
    See [Foundry publishing limitations](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network#limitations).

## Update or stop publication

| Task | Action |
| --- | --- |
| Release a new runtime version | Test it, then change the [active version](https://learn.microsoft.com/azure/foundry/agents/how-to/configure-agent#select-the-active-agent-version). Keep the bot and listing. |
| Roll back agent behavior | Select the previous tested version. This changes the version for every consumer of the stable endpoint. |
| Change Teams name, descriptions or URLs | Repeat Step 4 with reviewed metadata and a higher `appVersion`. |
| Redeploy the landing zone or hosted agent | Recheck the active version, Activity exception, Bot Service authorization and end-to-end Teams behavior. Manual channel configuration is not owned by the landing zone template. |

To stop channel access while keeping the web application's private path, read
the **current** configuration and disable only the Activity exception:

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

Keep Foundry PNA disabled. Confirm new Teams requests no longer reach the agent,
then have the administrator block/remove the app from the catalog. Uninstalling
the app alone is not endpoint access revocation. Do not delete shared Foundry
resources or blindly restore an old configuration over subsequent changes.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Project GET/PATCH fails or times out | Private DNS/VNet connectivity, selected tenant, Foundry User role and token audience `https://ai.azure.com`. If the token expired, repeat the token/header commands in Step 1. Do not enable PNA. |
| Bot deployment denied | `Microsoft.BotService` registration, bot/deployment permissions and Azure Policy. |
| Agent is missing from Teams | Correct account/scope, admin approval and app policies. Refresh the store or sign out/in; catalog caching can delay discovery. |
| `403 NetworkAccessDenied` on Activity | Verify the flag and test through Teams, not a public `curl` request. Arbitrary public source IPs remain blocked. |
| User can open the app but gets an authorization error | Same-tenant sign-in and, for `Shared`, Foundry Agent Consumer access. Do not switch to `Tenant` just to clear a denial. |
| Bot replies, but tools or retrieval fail | Runtime identity grants, user/data authorization and outbound access. A successful web UI test does not validate Teams identity propagation. |
| `version already exists` | Increase `appVersion`; do not change the runtime version to fix listing metadata. |

For other errors, use [Foundry publishing troubleshooting](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot)
and [published-agent authorization](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot-authorization).
