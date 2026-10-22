# Connect Copilot Studio to a private Foundry agent

Connect a **Copilot Studio agent** to an existing **Microsoft Foundry hosted
agent** without enabling Foundry public network access.

Messages follow this path:

**Copilot Studio** &rarr; **Power Automate agent flow** &rarr;
**HTTP with Microsoft Entra ID (preauthorized)** &rarr;
**Power Platform delegated subnet** &rarr; **Foundry private endpoint**

This is an authenticated HTTP integration, not the native **Microsoft Foundry
agent** connected-agent tool and not [Teams publication](publish-to-teams.md).
It does not require Bot Service or an exception for the Foundry Activity route.

## Prerequisites

- **Foundry:** A running, tested hosted agent with a stable **Responses** endpoint
  and a recorded active version. This runbook uses the agent endpoint shown in
  Step 3, not a Container Apps `/invocations` URL or an Activity endpoint.
- **Azure network:** The platform team has already delivered the Power Platform
  delegated subnet, regional connectivity, an enterprise policy, an approved
  Foundry private endpoint and private DNS. Every subnet referenced by the
  policy must resolve and reach Foundry over HTTPS. Foundry **public network
  access must be Disabled**.
- **Power Platform:** A **Managed Environment** with Dataverse, a maker account
  allowed to create agents, flows and connections, and a Power Platform
  administrator to associate the enterprise policy. The administrator needs
  read access to that Azure policy.
- **Governance:** Your data policies permit the trigger and HTTP connector
  together. Confirm Copilot Studio capacity and premium-connector entitlements;
  this connector is Premium. Azure hosting and model charges are separate.
  See [agent-flow licensing](https://learn.microsoft.com/microsoft-copilot-studio/flows-faqs).

Creating Azure network resources is outside this procedure. A subnet alone is
not sufficient: the enterprise policy must reference the required regional
networks and be associated with the environment. Use the
[Power Platform setup requirements](https://learn.microsoft.com/power-platform/admin/vnet-support-setup-configure)
if the platform handoff is incomplete.

!!! warning "Choose the effective identity before sharing"
    This procedure uses a **specific, shared connection** signed in as an
    approved Microsoft Entra user in the Foundry tenant. Foundry sees that
    connection user, **not automatically the person chatting in Studio**.
    Do not use it for user-specific document permissions unless your application
    independently enforces them. Require authentication, restrict the Studio
    agent to approved users and approve the data they can all access.

    Per-user connections require a separate identity and channel design; they
    are not enabled by forwarding a user name in the prompt. See
    [flow connection credentials](https://learn.microsoft.com/microsoft-copilot-studio/advanced-flow-create#manage-which-connections-are-used-by-the-flow).

## Step 1: Associate the environment with the private network

1. Record the **Power Platform environment ID**, the Azure **enterprise policy
   resource ID**, and the Foundry **resource, project, agent and active version**.
   Select this same environment in Copilot Studio and Power Automate.
2. In the [Power Platform admin center](https://admin.powerplatform.microsoft.com/),
   open **Security > Data and privacy > Azure Virtual Network policies**.
   Select the environment, select the prepared policy and **Save**. If the
   correct association already exists, leave it unchanged.
3. Open **Manage > Environments**, select the environment, then **History**.
   Wait for the policy operation to show **Succeeded** before testing.
4. Have the platform team confirm private DNS, routing and HTTPS access from
   **each** delegated regional subnet, not just from the jumpbox.
5. In the Azure portal, open the Foundry resource's **Networking** settings.
   Confirm public network access is **Disabled** and the intended private
   endpoint connection is **Approved**. Do not change either setting to get a
   successful test.

**Expected result:** The Managed Environment is linked to the intended policy,
and all its regional paths can reach the Foundry private endpoint. Schedule the
change: enabling subnet delegation can cause up to 30 minutes of connection
instability, and the environment's other supported workloads are affected too.

## Step 2: Authorize the connection user

Have an authorized Azure RBAC administrator grant the connection user
**Foundry Agent Consumer** on the **specific agent**, if equivalent access is
not already present. This allows invocation without authoring access.
The agent's own identity and downstream permissions are separate; do not replace
them with the connection user's identity.

<details class="runbook-command" markdown="1">
<summary>PowerShell: grant access to this agent only</summary>

Run with PowerShell 7 and Azure CLI. Replace every placeholder; use the
**object ID of the user who will sign in to the connection**, not an app client ID.

```powershell
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$subscriptionId = "<subscription-id>"
$agentScope = "/subscriptions/$subscriptionId/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-resource>/projects/<project>/agents/<agent>"
$connectionUserObjectId = "<connection-user-object-id>"

az login
az account set --subscription $subscriptionId
az role assignment create `
    --assignee-object-id $connectionUserObjectId `
    --assignee-principal-type User `
    --role "eed3b665-ab3a-47b6-8f48-c9382fb1dad6" `
    --scope $agentScope `
    --query "{id:id,scope:scope}" --output json
```

</details>

**Expected result:** The assignment targets the intended user and agent.
Record its ID if this is a new pilot-only grant, and allow RBAC propagation.
Do not grant subscription Owner, broad Contributor or extra project-authoring
roles to resolve an invocation failure. See
[Foundry RBAC and agent scopes](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry#agent-scope-role-assignments).

## Step 3: Create the authenticated agent flow

In Copilot Studio, select **Flows > New flow > Agent flow**. Use the environment
from Step 1 and name the flow **Call private Foundry agent**. Keep it in a solution
so it can be moved with its connection reference.

### Input and connection

1. In **When an agent calls the flow**, add one **Text** input named `message`.
   Its display name and JSON property are different: the first text input in the
   tested designer uses the property **`text`**. Check **Code view / Peek code**
   and use the actual property in the expression below.
2. Between the trigger and **Respond to the agent**, add **Invoke an HTTP
   request** from **HTTP with Microsoft Entra ID (preauthorized)**.
   Do **not** use **Get web resource**; it is not supported with VNet delegation.
3. Create a connection with **Log in with Microsoft Entra ID**, using:

| Connection field | Value |
| --- | --- |
| Microsoft Entra ID Resource URI (Application ID URI) | `https://ai.azure.com` |
| Base Resource URL | `https://<foundry-resource>.services.ai.azure.com` |
| Sign-in account | The connection user authorized in Step 2 |

Do not append the project path to the base URL or use the resource hostname as
the token audience. Do not supply a bearer token, API key or client secret.
If tenant policy blocks the connector or requires consent, stop and have the
administrator review the [connector's permission requirements](https://learn.microsoft.com/connectors/webcontents/);
do not bypass the policy with another connector.

### HTTP request

Keep the action name **Invoke an HTTP request**. The expressions below reference
its internal name, `Invoke_an_HTTP_request`; check that name in Code view if the
designer adds a suffix.

| Request field | Value |
| --- | --- |
| Method | `POST` |
| URL | The fixed agent Responses URL below |
| Header | `Content-Type`: `application/json` |
| Retry policy | **None** for the pilot; a repeated POST can duplicate work |

```text
https://<foundry-resource>.services.ai.azure.com/api/projects/<project>/agents/<agent>/endpoint/protocols/openai/responses?api-version=v1
```

Replace the placeholders with the selected agent's actual endpoint values.
The stable endpoint uses its **active version**; record and verify that version
before acceptance. Do not let the chat user or generative orchestration choose
the URL, method, headers or connection.

For **Body**, select **Expression** and paste this expression, without `@{...}`:

```text
string(setProperty(json('{"store":true,"stream":false}'), 'input', triggerBody()?['text']))
```

Replace `text` only if the trigger uses another property. Constructing the object
before serializing it preserves quotes, line breaks, backslashes and Unicode.
Do not concatenate the user's message into a JSON string.

This request is nonstreaming. `store:true` requests response storage; approve
Foundry's retention settings before using real data. It does **not** implement
multi-turn history: each call sends only the current message.

### Response and publication

In **Respond to the agent**, add a **Text** output named `foundry_response`.
Set its value using **Expression**:

```text
if(contains(body('Invoke_an_HTTP_request'), '$content'), base64ToString(body('Invoke_an_HTTP_request')?['$content']), string(body('Invoke_an_HTTP_request')))
```

The connector can wrap the JSON response in a base64 `$content` envelope.
This expression returns the actual JSON text in either form.

Keep **Respond to the agent** configured to run **only after HTTP success**.
In its **Settings > Networking**, set **Asynchronous response = Off**.
Select the specific authorized connection in the flow's connection/run-only
settings, not **Provided by run-only user**. Save and **Publish** the flow.

**Expected result:** The published flow has one text input, one authenticated
POST and one text output. Its complete synchronous execution must stay within
the [100-second agent-action limit](https://learn.microsoft.com/microsoft-copilot-studio/advanced-flow-create).
Streaming and background completion are not handled by this relay.

## Step 4: Relay the actual response in Copilot Studio

Use a **dedicated pilot Studio agent**. The topic below handles every nonempty
message; do not add it unchanged to an agent with other routing responsibilities.
Require [user authentication](https://learn.microsoft.com/microsoft-copilot-studio/advanced-end-user-authentication)
and restrict sharing before adding real users.

1. Create a topic named **Private Foundry relay**. Change its trigger to
   **A message is received** and set the condition to
   `!IsBlank(System.Activity.Text)`.
2. Add **Add a tool**, select the published **Call private Foundry agent** flow,
   and bind its `message` input to **`System.Activity.Text`**. Save the
   `foundry_response` output in the text variable **`Topic.FoundryResponse`**.
3. Add **Variable management > Set a variable value**. Create the text variable
   **`Topic.FoundryReply`** and set its value using the **Formula** tab below.
   It reads all message `output_text` parts, rather than assuming the first output
   item is a message; tool calls can precede it.

    <details class="runbook-command" markdown="1">
    <summary>Power Fx: extract text only from a completed, error-free response</summary>

    ```powerfx
    IfError(
        With(
            { r: ParseJSON(Topic.FoundryResponse) },
            If(
                Text(r.status) = "completed" && IsBlank(r.error),
                Concat(
                    Filter(Table(r.output), Text(Value.type) = "message") As m,
                    Concat(
                        Filter(Table(m.Value.content), Text(Value.type) = "output_text") As c,
                        Text(c.Value.text),
                        Char(10)
                    ),
                    Char(10)
                ),
                Blank()
            )
        ),
        Blank()
    )
    ```

    </details>

4. Add a **Condition** using
   `IsBlank(Topic.FoundryReply) || IsMatch(Topic.FoundryReply, "\s*", MatchOptions.Complete)`.
   In the true branch (missing or whitespace-only text), send:
   **"The Foundry agent did not return a completed text response. Please contact
   the support team."** Do not display raw JSON or retry the POST automatically.
   In the other branch, add **Send a message** containing the variable
   **`Topic.FoundryReply`**, without a generative rewrite.
5. End **both branches** with **Topic management > End all topics**.
   Do not enable a second Foundry tool as an automatic fallback. Run the topic
   checker and resolve every error before saving.

**Expected result:** One message invokes the flow once and displays Foundry's
actual text. Invalid JSON, an incomplete/failed response or missing text produces
an explicit failure message. If the HTTP action itself fails, Studio's error
handling must report the failed action, not substitute a generated answer.

## Step 5: Verify the private path, then publish

Use harmless test data in a **new** Studio test conversation. Record the UTC
window and flow run ID. A chatbot reply alone is not proof of backend execution.

| Check | Acceptance evidence |
| --- | --- |
| Request integrity | A message containing `"quotes"`, a newline, `C:\test\file` and `café` reaches the flow unchanged. Use an echo-capable test agent if exact round-trip comparison is needed. |
| Real Foundry execution | The matching flow run shows HTTP **200**, decoded `status: completed`, no non-null `error`, and real `output_text`. Check the selected agent/version in available response or runtime diagnostics. |
| Private ingress | Foundry PNA is still **Disabled**. Correlate the bounded run window and target resource with Foundry gateway diagnostics or equivalent approved network evidence; the source is the delegated private path, not a public connector address. |
| No hidden fallback | The topic trace invokes the intended flow once and sends its returned text. A failed action or invalid response gives an error, not a plausible generated reply. |
| Authorization | An approved pilot user can invoke the Studio agent; an unshared user cannot. Separately confirm that the connection identity and agent cannot expose data outside the approved shared-data boundary. |
| Runtime limit | Representative calls complete below **100 seconds**, including connector and agent processing. |

Use existing approved diagnostic settings; do not turn on prompt or document
capture just to obtain network evidence. A jumpbox success establishes only the
jumpbox path. If gateway logs are unavailable, do not claim that private ingress
has been independently verified.

After these checks pass, **publish the Studio agent** and repeat the test from
the intended authenticated channel with an approved pilot user. Designer success
does not verify channel authentication, sharing or connection behavior.

## Troubleshooting

| Symptom | Check and action |
| --- | --- |
| `Public access is disabled` / HTTP 403 | Confirm the flow ran in the associated environment, uses **Invoke an HTTP request** from the exact connector, and the policy operation succeeded. Inspect the ingress source before changing RBAC. Do not enable Foundry PNA. |
| DNS failure or timeout | Have the platform team check DNS, peering/routes, NSGs and HTTPS from **both regional paths**, where required. A private endpoint in only one reachable network is insufficient. |
| HTTP 401 / authorization 403 | Verify the connection user's tenant, `https://ai.azure.com` audience, connection health and agent-scoped invocation access. Distinguish connector-consent errors from Foundry RBAC errors; allow role propagation. |
| HTTP 404 / unsupported endpoint | Compare the fixed URL, project and agent with the tested stable Responses endpoint. Do not substitute Activity, Container Apps or another API version. |
| Response contains `$content`, or Studio shows base64 | Apply the Step 3 decoder and check the HTTP action's internal name. |
| Failed/empty response despite HTTP 200 | Inspect the decoded response status, error and output types in restricted run history. The agent must return a completed text response; the relay does not render files or handle tool approvals. |
| Flow is missing from the tool picker | Check the selected environment, solution membership, published state and required trigger/response actions. |
| Topic checker rejects the formula | Confirm `Topic.FoundryResponse` is Text, paste into the **Formula** tab, and preserve the `As m` / `As c` aliases. Use commas as Power Fx argument separators. |
| Studio action times out | Check full execution time and synchronous response settings. Optimize the agent or design an explicit asynchronous integration; do not increase retries or send a fake success. |

Restrict run-history access. Once validation is complete, apply your organization's
**Secure inputs / Secure outputs** policy to the HTTP and response actions:
these can contain prompts, retrieved data and replies. Share only sanitized UTC
timestamps, run/request IDs and status codes during diagnosis.

## Operate or stop the integration

- **Change:** Export/version the solution and record the endpoint, active agent
  version and connection reference before editing. Rebind the connection in each
  target environment and repeat Step 5 after an agent, policy or identity change.
- **Maintain:** Assign an owner for connection reauthentication, monitor failures,
  latency and capacity, and review access and response-retention policies.
  This single-message relay does not supply history or end-user OBO.
- **Stop:** Disable the relay topic/flow and republish the Studio agent. Remove a
  pilot-only role assignment only if it was created for this integration and is
  not shared. Do not delete the delegated subnet or detach the environment's VNet
  policy as routine rollback: other workloads may depend on it. Keep Foundry PNA
  disabled throughout.
