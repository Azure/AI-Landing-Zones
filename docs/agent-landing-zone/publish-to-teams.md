# Publish to Teams and Microsoft 365 Copilot

<a id="publish-to-teams"></a>

Use this runbook to publish an existing Foundry hosted agent to **Teams and
Microsoft 365 Copilot**. You will create a Bot Service resource, configure the
agent's channel access and publish its app listing. These are manual
post-deployment tasks; the landing zone template does not perform them.

The procedure publishes the hosted agent, not the Agent App UI. It applies to
`hosted-no-panel` and `hosted-panel` deployments, not to an orchestrator running
in Container Apps with the `classic` topology.

Messages from either client follow the same path:

**Teams / Microsoft 365 Copilot** &rarr; **Azure Bot Service** &rarr;
**Foundry Activity endpoint**

Foundry and Bot Service keep **public network access (PNA) disabled**. Following
the [Foundry REST publishing flow](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network),
you enable a restricted public HTTPS exception for the Activity route. Foundry
allows only service-managed Microsoft channel source ranges and still requires
authentication and authorization. Channel messages do not pass through your
private endpoint, Application Gateway or web UI.

| Publishing option | How it relates to this runbook |
| --- | --- |
| Teams and Microsoft 365 Copilot | This procedure publishes to both clients. Verify each one in Step 5. |
| Microsoft Agent 365 autopilot | Follow the [separate autopilot procedure](https://learn.microsoft.com/azure/foundry/agents/how-to/agent-365). It creates instances with their own agent user accounts and requires tenant enrollment, licensing and admin approval. |
| Copilot Studio | Connecting a Copilot Studio agent to Foundry is a different integration and is not covered here. |

## Prerequisites

- **Deployment:** Complete [Full stack deploy](deploy-full-stack.md) with
  `hosted-no-panel` or `hosted-panel`, and test the agent version you will publish.
- **Network access:** Run the commands from a
  [VNet-connected host](network-isolation.md#reach-the-private-network) that
  resolves and reaches the Foundry project's private endpoint. Agent management
  requests remain private.
- **Tools:** Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli),
  [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli)
  and **PowerShell 7.4 or later**. Run Steps 1-4 in the same PowerShell session;
  later blocks use variables set by earlier ones.
- **Azure permissions:** You need **Foundry User** on the project, plus
  **Azure Bot Service Contributor Role** and permission to create deployments
  in the target resource group. Resource-group **Contributor** covers both bot
  creation and deployment. A subscription administrator must register
  `Microsoft.BotService` if it is not already registered.
- **Microsoft 365 access:** Use member accounts in the **same tenant as Foundry**,
  with access to Teams and Microsoft 365 Copilot and app policies that allow the
  agent. Guest accounts cannot call these agents. Identify a Microsoft 365
  administrator to approve publication if you plan to distribute it tenant-wide.

!!! warning "Approve the data flow first"
    Obtain your organization's approval before sending data through this
    channel. Microsoft 365 processes publishing metadata and conversations under
    its own compliance and data-residency commitments. Do not assume the web
    UI's delegated authentication, document permissions or upload features work
    unchanged in Teams or Copilot.

## Step 1: Select the agent and save its configuration

In the Azure portal, collect the subscription ID, resource group name, Foundry
resource name and project name. Then open the agent in
[Foundry](https://ai.azure.com/) and record its name and **tested version**.
The bundled agent is named `agent-app-orchestrator`; use your agent's actual
name if you customized the deployment.

Expand the block below, replace every placeholder and run it on the connected
host. The commands check the agent's identity and save its configuration before
you change it.

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

**Expected result:** The commands complete without errors and display the
intended tenant and subscription, the endpoint configuration and a
working-folder path. Record that path. Keep `target.json` and
`agent-before.json` in that folder, outside source control; neither file
contains the bearer token.

Before continuing, choose who can use the agent. The block starts with
`$publishScope = "Shared"`, which is the recommended pilot scope. Your choice
controls both catalog visibility and permission to call the agent:

| `$publishScope` | Who can call the agent | Store visibility |
| --- | --- | --- |
| `Shared` | Only identities with the required Foundry permissions can invoke it, through `BotServiceRbac`. | Initially, only the publisher sees it under **Your agents**. Publishing approval is not required. |
| `Tenant` | Everyone in the Foundry tenant can invoke it, through `BotServiceTenant`. | It appears under **Built by your org** after Microsoft 365 admin approval. |

For tenant-wide distribution, set `$publishScope = "Tenant"` in the same
session **before Step 3**, and only after your organization approves that access.
For a `Shared` pilot, ask an administrator to grant selected testers
**Foundry Agent Consumer** at the
[agent scope](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot-authorization#grant-access-to-one-agent).
Sharing an app link does not grant invocation permission.

!!! note "If the agent identity check fails"
    Stop and follow the
    [Foundry migration guidance](https://learn.microsoft.com/azure/foundry/agents/how-to/migrate-agent-applications).
    Bot Service needs the agent identity's client ID, not the project's managed
    identity or the web UI client ID.

## Step 2: Create the bot and Teams channel

Complete the three sections below in order. This creates a separate Bot Service
resource and its Teams channel; the same channel also serves Microsoft 365
Copilot. You do not need to add a bot runtime or modify the landing zone template.

<details class="runbook-command" markdown="1">
<summary>1. Check Bot Service provider registration</summary>

Run this command in the PowerShell session from Step 1:

```powershell
az provider show --namespace Microsoft.BotService --query registrationState --output tsv
```

**Expected result:** The provider state is `Registered`. If it is not, ask a
subscription administrator to run
`az provider register --namespace Microsoft.BotService --wait`, then check again.
Do not deploy the bot until registration is complete.

</details>

<details class="runbook-command" markdown="1">
<summary>2. Save bot-service.bicep in the working folder</summary>

Create a file named **`bot-service.bicep`** in the `$work` folder created in
Step 1, and paste the following template into it:

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

<details class="runbook-command" markdown="1">
<summary>3. Deploy the bot and verify its network setting</summary>

Replace `<agent-display-name>` with the name users should see. Run the commands
from `$work` to deploy the saved template into the Foundry resource group.

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

**Expected result:** The bot's endpoint matches the agent's `activityProtocol`
URL, and its network setting is `"pna": "Disabled"`. The bot uses the agent's
identity; you do not need a client secret, public VNet ingress or a custom
connector.

## Step 3: Enable the restricted Activity route

Run the block below to enable the restricted Activity route, apply the Bot
Service authorization scheme for your chosen audience and send traffic to the
tested agent version. The block reads the current configuration so it can
preserve the existing protocols and non-Bot authorization schemes.

!!! warning "Preserve the web application path"
    The API replaces the submitted protocol configuration and authorization
    array. Do not remove existing entries, especially `responses`, `invocations`
    and `Entra`: removing them can break the web application's existing
    invocation path. Selecting the active version affects **all consumers** of
    the agent, not just Teams and Copilot. Do not let another operator change
    the agent configuration while you run this step.

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

**Expected result:** The update completes without errors and prints no output.
You will check the final configuration in Step 5.

## Step 4: Publish the app

Replace the placeholders below with approved listing details, including your
organization's HTTPS website, privacy statement and terms of use. These details
are visible to users; do not include secrets or sensitive information.

Keep `publishAsAutopilot` set to `false`. This procedure publishes an agent to
the Teams and Copilot stores; creating an Agent 365 autopilot requires the
[separate autopilot procedure](https://learn.microsoft.com/azure/foundry/agents/how-to/agent-365).

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

**Expected result:** The response contains `titleId`. If you selected `Tenant`,
ask a Microsoft 365 administrator to approve the request in
[Microsoft 365 admin center > Agents > Requests](https://admin.cloud.microsoft/?#/agents/all/requested).
Approval is required before tenant-wide discovery, and app policies can still
restrict availability.

!!! note "App version versus agent version"
    `appVersion` is the version of the store listing. Increase it when you
    republish metadata or change publication scope. `$agentVersion` selects the
    running agent version; changing that version does not require republishing
    the listing.

<details class="runbook-command" markdown="1">
<summary>Optional: download the generated Teams package</summary>

If your administrator requires a package for review or manual upload, run this
block in the same session after creating the publication request:

```powershell
Invoke-WebRequest -Method Post -Uri "${agentUri}/microsoft365/zip?api-version=v1" `
    -Headers $headers -ContentType "application/json" -Body $body -OutFile appPackage.zip
```

Extract the ZIP and review its manifest and icons with the
[package inspection checklist](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot#inspect-the-downloaded-package).
Keep the generated IDs and agent sections unchanged. To upload the package in
Teams, select **Apps > Manage your apps > Upload an app**, then choose
**Upload a custom app** or **Submit an app to your org**, as permitted by your
administrator.

The download call does **not** submit the app to the catalogs, but it can update
the agent's publishing configuration and requires agent write permission. If you
already published directly, do not upload a second copy unless your
administrator requires it.

</details>

## Step 5: Install and verify

<a id="resume-in-a-new-session"></a>

<details class="runbook-command" markdown="1">
<summary>Returning later or using a new PowerShell session?</summary>

Use this block only to resume verification or maintenance after the bot has
been created. Run it on the connected host, replacing `<saved-working-folder>`
with the path recorded in Step 1. It restores the connection variables and gets
a fresh token without recreating the bot or republishing the app.

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

After publication, open the agent in both clients. For `Shared`, sign in with
the publishing account. For `Tenant`, wait for admin approval and find the agent
under **Built by your org**.

| Client | Open the agent |
| --- | --- |
| Teams | Open **Apps**, find the agent, add it and open its chat. |
| Microsoft 365 Copilot | Open the **Agents** area, find the agent in the agent store and add it. For `Shared`, look under **Your agents**. |

Complete these checks in **each client** before making the agent available to
users:

1. Complete any sign-in prompt. Send a greeting, a representative workload
   question and a follow-up. Confirm that the expected tools and knowledge
   sources work; receiving a reply alone is not enough.
2. For a `Shared` pilot, test with an authorized user and a tenant member who
   lacks agent permission. The second user must be denied. Use member accounts,
   not guests. With `Tenant`, all tenant members are authorized to call the
   agent, so this is not a valid negative test.
3. If the agent handles protected data, test with identities that should and
   should not access that data. Confirm the intended restrictions in both
   clients, regardless of publication scope.

Then return to the connected host and run the final configuration check:

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

**Expected result:** The tested version receives 100% of traffic. The original
protocols and `Entra` authorization are preserved,
`activity.enable_m365_public_endpoint` is `true`, and the Bot Service scheme
matches your publication scope. **Both PNA values must remain `Disabled`.**

!!! note "Channel limitations"
    Foundry's documentation currently states that published agents do not
    support streaming responses or citations. File support in a client does not
    mean the Agent App UI's upload pipeline is available through that client. Review the
    [Foundry publishing limitations](https://learn.microsoft.com/azure/foundry/agents/how-to/publish-copilot-virtual-network#limitations)
    before rollout.

## Update or stop publication

Use the following actions to maintain the published agent. If your PowerShell
session ended or its token expired, [resume the session](#resume-in-a-new-session)
before running the maintenance commands.

| Task | Action |
| --- | --- |
| Release a new runtime version | Test the version, then select it as the [active version](https://learn.microsoft.com/azure/foundry/agents/how-to/configure-agent#select-the-active-agent-version). You can keep the existing bot and listing. |
| Roll back agent behavior | Select the previous tested version as active. This changes the version for every consumer of the stable endpoint. |
| Change the listing name, descriptions or URLs | Edit `publish-request.json`, increase `appVersion` and run **Update listing metadata** below. Keep `botServiceArmId` and `publishScope` unchanged for a metadata-only update. |
| Check publication after redeployment | Recheck the active version, Activity exception and authorization, then repeat the client tests in Step 5. The landing zone template does not manage this manual configuration. |

<details class="runbook-command" markdown="1">
<summary>Update listing metadata</summary>

Open `publish-request.json` in the saved working folder. Update the listing
details, increase `appVersion` and review the entire request before running the
block below. A `Tenant` update can require renewed admin approval.

```powershell
$body = Get-Content publish-request.json -Raw
$result = Invoke-RestMethod -Method Post `
    -Uri "${agentUri}/microsoft365/publish?api-version=v1" `
    -Headers $headers -ContentType "application/json" -Body $body
$result | ConvertTo-Json -Depth 20 | Set-Content publish-result.json
$result
```

</details>

To stop channel access from **both clients**, run the block below. It disables
only the Activity exception, leaving the web application's private path
unchanged. Keep Foundry PNA disabled.

<details class="runbook-command" markdown="1">
<summary>Stop Teams and Copilot access</summary>

The commands read the **current** protocol configuration and change only the
Activity exception:

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

After the update, confirm that new requests from Teams and Copilot no longer
reach the agent. Ask the administrator to block or remove the app from the
catalogs. Uninstalling the app alone does not revoke endpoint access. Do not
delete shared Foundry resources or restore an old backup over later
configuration changes.

## Troubleshooting

| Symptom | What to check or do |
| --- | --- |
| A project GET or PATCH fails or times out. | Check private DNS and connectivity, the selected tenant, the Foundry User role and the token audience (`https://ai.azure.com`). If the token expired, [resume the session](#resume-in-a-new-session). Do not enable PNA to bypass the error. |
| The bot deployment is denied. | Check `Microsoft.BotService` registration, bot and deployment permissions, and any Azure Policy denial. |
| The agent is missing from either client. | Check the signed-in account, publication scope, admin approval and app policies. Refresh the store or sign out and back in; catalog caching can delay discovery. |
| Activity returns `403 NetworkAccessDenied`. | Check that the Activity exception is enabled and test through Teams or Copilot. A public `curl` request from an arbitrary IP remains blocked by design. |
| A user can open the app but receives an authorization error. | Check that the user is signed in to the Foundry tenant and, for `Shared`, has Foundry Agent Consumer access. Do not switch to `Tenant` just to remove the error. |
| The agent replies, but tools or retrieval fail. | Check runtime identity permissions, data authorization and outbound access. A successful web UI test does not validate identity propagation through the channel. |
| A Teams conversation is stuck or returns `no tool output found`. | Send `/foundry_new_preview` in that chat to reset it. This discards the previous conversation context, which cannot be restored. |
| Publication returns `version already exists`. | Increase `appVersion` and submit the listing again. Do not change the runtime version to fix a listing-version error. |

For other errors, use [Foundry publishing troubleshooting](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot)
and [published-agent authorization](https://learn.microsoft.com/azure/foundry/agents/how-to/troubleshoot-publish-copilot-authorization).
