# Deploy your first agent application

Deploy a private reference application with a web chat and a Foundry-hosted agent.
The web chat is the user interface (UI).
Complete these five stages on one page:

1. Prepare the deployment and application login.
2. Provision the private infrastructure.
3. Connect to the Windows jumpbox and complete configuration.
4. Finish application login and publish the agent.
5. Test a task, denied access and a request trace.

This path uses Bicep, the reference application, Hosted execution and `conversational` mode.
It creates a standalone Azure virtual network (VNet), Azure Firewall, NAT Gateway, Windows jumpbox and Azure Bastion.

Bastion provides browser-based access to the jumpbox without a public VM endpoint.
The jumpbox is an administrator's virtual machine (VM) inside the private VNet.

Azure Container Registry (ACR) Tasks builds images in a VNet-connected agent pool.
Local Docker is unnecessary.

The result is a configured pilot, not production-readiness certification.
The first task uses supplied, non-sensitive text.
Shared-document ingestion, retrieval-augmented generation (RAG), workflows, Model Context Protocol (MCP), SQL, history and feedback are later tasks.
The reference agent is not a custom business application.

!!! warning "Cost and private access"
    Charges start when Azure resources are created, before application acceptance.
    This profile includes Firewall, Bastion, a VM and an ACR Tasks pool.
    Model use, runtime, storage and monitoring also incur charges.

    Approve the [resource inventory](../bicep/deployed-resources.md) and [cost estimate](../architecture/cost-guide.md) before provisioning.
    Keep the environment private throughout this procedure.
    Do not enable public service access or anonymous login to repair a failure.

<span id="prepare"></span>

## 1. Prepare the deployment and login

**Computer: your initial Windows computer. Shell: PowerShell 7.**

### Confirm people, access and capacity

1. Select one Azure subscription, tenant, supported region and unique azd environment name.
2. Ask the Azure administrator to approve these permissions for the deployment operator.

    | Operation | Required access |
    | --- | --- |
    | Deploy resources | Contributor-equivalent actions on all three destination groups; permission to create missing groups |
    | Assign resource roles | Scoped `Microsoft.Authorization/roleAssignments/write`, such as Role Based Access Control Administrator |
    | Configure services and build images | Selected service data roles, App Configuration Data Owner, secret-management permissions and registry/build permissions |
    | Publish Hosted agents | Foundry User-equivalent authoring on the exact project, plus Foundry account read access |
    | Recover jumpbox access | Authorized VM password reset if the provisioning credential is unavailable |
    | Find the acceptance trace | Foundry project access and Log Analytics Reader; protected tables can require Privileged Monitoring Data Reader |

    Contributor alone cannot assign resource roles.
    Subscription Owner is not required when the approved scoped roles cover these operations.
    The [permissions reference](../bicep/permissions.md) lists the selected service roles.

3. Ask the Entra application administrator to perform the registration and consent actions below.
4. Select one approved pilot user and one separate user outside the admission lists.
5. Record both users' tenant IDs and user object IDs in the approved environment record.
6. Confirm resource-provider registration, Responsible AI terms, regional service availability and model quota with the Azure administrator.
7. Check the [regional capacity caveats](../bicep/regional-considerations.md) for the selected region.
8. Stop if permissions, tenant consent, budget or capacity remain unapproved.

Separate identities serve separate purposes: the deployment operator, frontend, Hosted runtime and signed-in user are not interchangeable.
CLI login authenticates the operator; it does not grant application admission or tenant consent.

### Install tools and initialize the project

1. Install [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd), Git, PowerShell 7 and Python 3.12.
2. Open PowerShell 7 on the initial computer.
3. Initialize the project in an empty directory outside existing checkouts:

    ```powershell
    $ErrorActionPreference = "Stop"
    $PSNativeCommandUseErrorActionPreference = $true
    New-Item -ItemType Directory agent-landing-zone
    Set-Location agent-landing-zone
    azd init --template Azure/agent-landing-zone --branch v7.1.0 --environment <environment-name> .
    ```

Initialization creates and selects the local environment.
It does not deploy Azure resources.

4. Keep the trailing `.` in the initialization command.
5. Do not add `--up` or create the same local environment again.
6. Confirm `azure.yaml`, `manifest.json` and `main.parameters.json` exist in the project root.
7. Run all subsequent lifecycle commands from this project root.
8. Prepare the Python environment:

    ```powershell
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    python -m pip install -r config/requirements.txt
    azd extension install azure.ai.agents
    ```

9. Keep this Python environment active for lifecycle commands.
10. Stop if organization policy blocks required tools or Python activation.
11. Replace every command placeholder with an approved value before execution.
12. Sign in to both CLIs:

    ```powershell
    az login --tenant <tenant-id>
    azd auth login --tenant-id <tenant-id>
    az account set --subscription <subscription-id>
    azd env set AZURE_SUBSCRIPTION_ID <subscription-id>
    azd env set AZURE_RESOURCE_GROUP <foundry-resource-group>
    azd env set AZURE_APP_RESOURCE_GROUP <application-resource-group>
    azd env set AZURE_NETWORK_RESOURCE_GROUP <network-resource-group>
    azd env set AZURE_LOCATION <region>
    ```

The three new, dedicated groups contain Foundry, application and network resources respectively.
Deployment scripts, called hooks, create missing application and network groups.
The Azure Developer CLI creates the root Foundry group.
One provision operation targets all three groups.

13. Record the environment name, subscription, tenant, region and three group names in the approved nonsecret deployment record.
14. Keep development, test and production resources, identities, configuration, secrets and data separate.

<span id="register-login"></span>

### Register and authorize application login before provision

--8<-- "agent-login-registration.md"

--8<-- "agent-login-consent.md"

This pilot uses `user_delegated` authentication.
It uses OBO to invoke Foundry as the signed-in user.
The standard Foundry-resource audience is used below.

Stop if the endpoint owner has not approved `https://ai.azure.com/.default`.

<span id="private-profile"></span>

### Select the private profile

**Deployment operator — initial computer, selected azd environment**

1. Apply this profile before the first provision:

    ```powershell
    azd env set ORCHESTRATION_HOST hosted
    azd env set APPLICATION_MODE conversational
    azd env set HOSTED_AGENT_AUTH_MODE user_delegated
    azd env set HOSTED_AGENT_RESOURCE_SCOPE https://ai.azure.com/.default
    azd env set DEPLOY_INGESTION_CONTAINER_APP false
    azd env set DEPLOY_AGENT_APP_MCP false
    azd env set ENABLE_CHAT_HISTORY false
    azd env set ENABLE_USER_FEEDBACK false
    azd env set ENABLE_PRIVATE_ATTACHMENTS false
    azd env set NETWORK_ISOLATION true
    azd env set DEPLOYMENT_MODE standalone
    azd env set USE_EXISTING_VNET false
    azd env set DEPLOY_AZURE_FIREWALL true
    azd env set DEPLOY_NAT_GATEWAY true
    azd env set DEPLOY_JUMPBOX true
    azd env set DEPLOY_BASTION true
    azd env set BASTION_SKU_NAME Standard
    azd env set BASTION_ENABLE_TUNNELING false
    azd env set DEPLOY_ACR_TASK_AGENT_POOL true
    azd env set HOSTED_AGENT_CAPTURE_MESSAGE_CONTENT false
    ```

  !!! note
      Some values already match the template defaults.
      You do not need to set them in a new environment.
      They are shown here to make the selected profile explicit.

2. Ask the network operator to approve the new VNet's address plan in root `main.parameters.json`.
3. Keep the selected subnets nonoverlapping with networks this environment must reach.
4. Keep `publicIngress.enabled` set to `false` in root `main.parameters.json`.
5. Save the reviewed root parameter file and all approved nonsecret environment inputs for the computer handoff.
6. Do not edit the generated `infra/bicep/main.parameters.json`.

The baseline can provision backing services for later native retrieval.
This procedure does not load documents or claim document authorization.
The separate Agent App Ingestion service remains disabled.

**Check:** Registration and consent are complete; the selected environment has the approved private profile.

<span id="provision"></span>

## 2. Provision the private infrastructure

**Computer: initial computer. Identity: deployment operator.**

1. Review the selected components' declared outbound destinations:

    ```powershell
    python -m config.deployment.egress --plan --environment <environment-name>
    ```

2. Approve the selected destinations and purposes with the network operator.
3. Set explicit post-provision deferral before creating resources:

    ```powershell
    azd env set RUN_FROM_JUMPBOX false
    ```

4. Validate the application binding before provisioning:

    ```powershell
    azd hooks run preup
    ```

5. Provision the infrastructure:

    ```powershell
    azd provision
    ```

6. Confirm the hook's **Continue with Zero Trust provisioning?** prompt after approving the private profile.

The secure `vmAdminPassword` input uses azd's `$(secretOrRandomPassword)` expression.
There is no documented default password or guaranteed Key Vault copy.
An unavailable credential requires an authorized VM password reset, described below.

Do not put passwords in source, shell commands, history or logs.

7. Wait for successful infrastructure provisioning and the explicit deferral message:

    ```text
    Post-provision configuration explicitly deferred; application setup is incomplete.
    ```

8. Stop if provisioning fails or the expected deferral is absent.
9. Record the deployed jumpbox VM and Bastion names from the network resource group in Azure portal.
10. Preserve the original `.azure/<environment-name>/resource-groups.json` through the approved secure file-transfer process.

11. Record the original parameter-file and binding hashes:

    ```powershell
    Get-FileHash main.parameters.json -Algorithm SHA256
    Get-FileHash ".azure/<environment-name>/resource-groups.json" -Algorithm SHA256
    ```

12. Record the bound application ID:

    ```powershell
    azd env get-value AGENTLZ_APP_ID
    ```

The reference application's ID is `agent-lz-default`.

**Expected result:** The private network and access hosts exist.
Application configuration, images and user acceptance remain incomplete.
Placeholder responses do not prove application readiness.

<span id="jumpbox"></span>

## 3. Connect to the jumpbox and complete configuration

### Open the Windows desktop through Bastion

**Computer: initial computer. Browser: Azure portal.**

1. Open the deployed jumpbox VM in the network resource group.
2. Use the VM's approved provisioning credential if it is available.
3. Ask the authorized VM administrator to reset the password if that credential is unavailable.

For a reset, the VM administrator performs these actions in Azure portal:

1. Open the jumpbox VM's **Help > Reset password** page.
2. Select **Reset password**.
3. Enter the deployed administrator username, normally `testvmuser`.
4. Enter a new strong password from the organization's approved credential manager.
5. Select **Update**.
6. Transfer access to that credential through the approved secure process.

Do not put the password in a command, source file, screenshot or deployment record.
Stop if the reset fails or the administrator cannot authorize it.

The connecting operator then performs these actions:

1. Open the VM's **Connect > Bastion** page.
2. Select the deployed Bastion instance.
3. Enter the deployed VM administrator username and approved password.
4. Select **Connect** to open the Windows desktop.

**Computer handoff:** All remaining deployment commands and private-service browsing run **inside the jumpbox**.
The ACR Tasks pool does not connect the initial computer to private services.
Portal Bastion access does not require native RDP tunneling.

<span id="computer-handoff"></span>

### Restore the same source, inputs and destination binding

**Computer: jumpbox. Shell: PowerShell 7. Identity: the same approved deployment operator.**

1. Install or verify the tools listed in stage 1 on the jumpbox.
2. Open PowerShell 7 inside the jumpbox.
3. Fetch the exact source revision:

    ```powershell
    $ErrorActionPreference = "Stop"
    $PSNativeCommandUseErrorActionPreference = $true
    git clone https://github.com/Azure/agent-landing-zone.git
    Set-Location agent-landing-zone
    git checkout --detach ef03a1248a9ee1de0a6023225a25fff7bae9577f
    git rev-parse HEAD
    ```

4. Compare the reported commit with `ef03a1248a9ee1de0a6023225a25fff7bae9577f`.
5. Stop if the revisions differ.
6. Prepare Python and the Foundry extension in this checkout:

    ```powershell
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    python -m pip install -r config/requirements.txt
    azd extension install azure.ai.agents
    ```

7. Authenticate both CLIs as the approved deployment operator:

    ```powershell
    az login --tenant <tenant-id>
    azd auth login --tenant-id <tenant-id>
    az account set --subscription <subscription-id>
    ```

8. Create the absent local environment once in this new checkout:

    ```powershell
    azd env new <same-environment-name>
    ```

If that local environment already exists, use `azd env select <same-environment-name>` instead.
Neither command provisions resources.

9. Restore these artifacts through the organization's approved secure file-transfer process:

    | Artifact from initial computer | Destination on jumpbox |
    | --- | --- |
    | Reviewed root `main.parameters.json` | This exact checkout's root `main.parameters.json` |
    | Approved nonsecret deployment record | Operator's protected working record |
    | Original `.azure/<environment-name>/resource-groups.json` | Same relative path in this checkout |

10. Verify the transferred parameter file and binding match the originals with SHA-256 file hashes.

    ```powershell
    Get-FileHash main.parameters.json -Algorithm SHA256
    Get-FileHash ".azure/<same-environment-name>/resource-groups.json" -Algorithm SHA256
    ```

11. Do not transfer tokens, credentials, the virtual environment or the entire `.azure` directory.
12. Do not generate or edit a replacement resource-group binding.
13. Reapply the original target values:

    ```powershell
    azd env set AZURE_SUBSCRIPTION_ID <same-subscription-id>
    azd env set AZURE_RESOURCE_GROUP <same-foundry-resource-group>
    azd env set AZURE_APP_RESOURCE_GROUP <same-application-resource-group>
    azd env set AZURE_NETWORK_RESOURCE_GROUP <same-network-resource-group>
    azd env set AZURE_LOCATION <same-region>
    ```

14. Reapply the entire private-profile command block from stage 1 with the original approved values.
15. Reapply any additional approved nonsecret inputs from the deployment record.
16. Refresh the existing deployment outputs:

    ```powershell
    azd env refresh
    ```

Refresh restores outputs, not the complete deployment configuration or immutable multi-group destination binding.
The root group alone is insufficient.

17. Compare the subscription and all three group names with the original deployment record.
18. Stop if any target, input or binding differs from the original environment.
19. Do not run another provision operation merely to reconstruct local state.
20. Confirm the original application ID and this checkout's `app-definition.json` both identify `agent-lz-default`.
21. Restore the same local application binding with the supported helper:

    ```powershell
    python -m config.appdefinition --bind --env-name <same-environment-name>
    ```

<span id="complete-configuration"></span>

### Check private access and finish post-provision

1. Read the selected environment's App Configuration endpoint:

    ```powershell
    azd env get-value APP_CONFIG_ENDPOINT
    ```

2. Resolve that endpoint's hostname from the jumpbox:

    ```powershell
    Resolve-DnsName <app-configuration-hostname>
    Test-NetConnection <app-configuration-hostname> -Port 443
    ```

3. Confirm the service address is private and the TCP check succeeds.
4. Ask the network operator to repair DNS, routing or firewall failures before continuing.
5. Clear deferral on the jumpbox:

    ```powershell
    azd env set RUN_FROM_JUMPBOX true
    azd env set AZURE_SKIP_NETWORK_ISOLATION_WARNING false
    azd hooks run postprovision
    ```

The hook checks connectivity, configures services, reconciles selected roles and publishes platform outputs.
`RUN_FROM_JUMPBOX` does not bypass connectivity checks.

6. Stop if the hook reports a configuration, permission or private-link readiness failure.

For a reported Search shared private-link request, the resource owner must approve only that exact request.
The request identifies its target and connection.

1. Open the reported target resource's **Networking > Private endpoint connections** in Azure portal.
2. Match the connection to the exact Search request reported by the hook.
3. Approve that connection only after confirming its ownership and purpose.
4. Rerun `azd hooks run postprovision` after the approved connection becomes ready.

Do not approve every pending connection or bypass the readiness gate.

7. Verify published platform outputs without resolving credentials:

    ```powershell
    az appconfig kv show --endpoint <app-configuration-endpoint> --key AGENTLZ_PLATFORM_OUTPUTS --label agent-lz --auth-mode login
    azd env get-value ACR_TASK_AGENT_POOL
    ```

8. Confirm the ACR Tasks pool output is nonempty.
9. Record the frontend Container App HTTPS URL from the application resource group's Container App **Overview**.

**Expected result:** Private configuration completes successfully.
The selected services and VNet-connected build pool are ready for application publication.
The UI still needs its final login settings.

<span id="publish"></span>

## 4. Finish login and publish the application

**Computer: jumpbox, including the browser used for private Azure services.**

<span id="configure-login"></span>

### Configure the callback, secrets and admission before deploy

--8<-- "agent-login-callback.md"

--8<-- "agent-login-settings.md"

--8<-- "agent-login-admission.md"

1. Include only the approved pilot user in the admission settings.
2. Confirm the second test user is absent from both admission lists.
3. Verify the Foundry project's Application Insights connection identifies this environment's monitoring resource.
4. Keep prompt and response-content capture disabled.
5. Stop if callback registration, secret references or admission settings remain incomplete.

Basic request traces do not require message-content capture.

### Publish from the configured foundation

**Deployment operator — jumpbox PowerShell 7, project root, selected environment**

1. Deploy the application:

    ```powershell
    azd deploy
    ```

Deployment prepares the pinned Hosted image, publishes the agent and deploys the frontend.
The private ACR Tasks pool builds the images; no local Docker installation is required.
The lifecycle reconciles the actual Hosted runtime identity and frontend secret grants.

2. Wait for successful agent publication and frontend deployment.
3. Stop if a build, publication, role reconciliation or frontend deployment fails.
4. Verify the frontend identity has App Configuration Data Reader on this environment's configuration store.
5. Verify the frontend identity has Key Vault Secrets User on its two referenced authentication secrets.
6. Allow new role assignments to propagate before testing.

The UI caches authentication settings at startup.
A later login-setting change requires frontend restart or redeployment, then a new user sign-in.
It does not require a Hosted-agent restart for a UI-only authentication change.

<span id="grant-agent-access"></span>

### Grant the pilot user access to the published agent

**Azure RBAC administrator — jumpbox PowerShell 7, approved subscription**

1. Obtain the published agent name, Foundry account name and project name from this deployment.
2. Sign in to Azure CLI as the authorized RBAC administrator:

    ```powershell
    az login --tenant <tenant-id>
    ```

3. Substitute the approved pilot user's **user object ID**, not the UI client ID:

    ```powershell
    $subscriptionId = "<subscription-id>"
    $agentScope = "/subscriptions/$subscriptionId/resourceGroups/<foundry-resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-account>/projects/<project>/agents/<published-agent-name>"
    $pilotUserObjectId = "<approved-user-object-id>"
    az account set --subscription $subscriptionId
    az role assignment create --assignee-object-id $pilotUserObjectId --assignee-principal-type User --role "eed3b665-ab3a-47b6-8f48-c9382fb1dad6" --scope $agentScope
    ```

The role is **Foundry Agent Consumer**, scoped to this individual published agent.
It allows invocation, not authoring.
The portal's consumer-role picker currently uses account scope; this CLI command uses agent scope.

4. Allow the caller grant to propagate before acceptance.
5. Do not grant the denied test user UI admission.
6. Do not replace a failed user grant with broader Owner or service credentials.

**Expected result:** The approved user has both UI admission and agent-scoped Foundry caller access.
Tenant consent, UI admission, Foundry access and source permissions remain separate controls.

<span id="verify"></span>

## 5. Test a task and verify the boundaries

**Computer: jumpbox. Browser: separate signed-out and test-user sessions.**

<span id="test-task"></span>

### Run a self-contained, non-sensitive task

1. Open the frontend HTTPS URL in a signed-out browser session.
2. Confirm chat is unavailable before login.
3. Sign in as the approved pilot user.
4. Confirm the browser returns through the registered HTTPS callback.
5. Send this synthetic task:

    ```text
    Use only the following non-sensitive planning note. Do not search or call tools.
    Prepare a short research draft for human review.
    Give three bullets: the objective, the next action, and one unresolved question.
    Do not invent dates, owners, prices or facts.

    Note: A community library wants to compare two workshop formats.
    Volunteers proposed an online session and an in-person session.
    The team has not chosen a budget, date or accessibility requirements.
    Its next action is to collect attendee preferences.
    ```

6. Check that the answer compares the proposed workshop formats.
7. Check that the next action collects attendee preferences.
8. Check that the unresolved question concerns an unspecified budget, date or accessibility requirement.
9. Reject invented facts, claims of tool execution or unsupported source citations.
10. Record the request time, deployed agent version and available response or trace identifier.

Wording can vary; a literal response match is unnecessary.
This tests the supplied-text reference-agent task, not ingestion, protected retrieval or document ACLs.

### Confirm denied access

1. Open a separate browser session as the user outside both admission lists.
2. Confirm the application denies that user's access.
3. Stop acceptance if signed-out chat or unapproved-user chat succeeds.
4. Use only sanitized status and correlation fields to investigate failures.
5. Do not capture tokens, secrets or private message content.

<span id="find-trace"></span>

### Find the request trace

**Investigating operator — jumpbox browser, deployed Foundry project**

1. Open **Agents > Traces** in the deployed Foundry project.
2. Select the published Hosted agent.
3. Select a time range containing the recorded request.
4. Find the request by trace ID, response ID or recorded time.
5. Open its hosting operation and nested Agent Framework/model spans.
6. Confirm the operation succeeded for the deployed agent version.

Service invocation telemetry alone does not establish that application spans were exported.
Missing traces can indicate ingestion delay, wrong project, wrong Application Insights connection, insufficient access or exporter failure.

7. Keep acceptance incomplete until the request trace is located.
8. Do not enable message-content capture merely to find a trace.

**Done:** The approved user completed the task, signed-out chat was blocked, the unapproved user was denied, and the request trace exists.
Documentation checks do not replace these live acceptance steps.

## Next steps

- [Customize the application](build-your-own-app.md).
- [Add shared data with Foundry IQ](foundry-iq.md).
- [Operate and recover the deployment](deployment-operations.md).
- [Remove resources safely](deploy-full-stack.md#remove-an-environment).

Confirm ownership, retention and backups before resource deletion.
Treat purge as a separate irreversible decision, not a deployment retry.
