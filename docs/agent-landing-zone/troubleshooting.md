# Troubleshooting

This page lists the errors you are most likely to see, grouped by the deployment stage that raises them. Each entry shows the message, the cause, and the fix.

Every stage writes its output to the terminal. Component deployments also write logs to the `.logs` folder of each component checkout.

!!! tip "Sharing diagnostics"
    When you ask for help, share the failing command, the error message, and the specific non-secret settings involved (for example `NETWORK_ISOLATION`, `BUILD_MODE`, `AZURE_LOCATION`). Do not paste the full output of `azd env get-values`; it can contain endpoints and identifiers you may not want to publish.

## Deploy stage

These checks run in the `predeploy` hook, in this order, before any application is built.

### Hosted deployment is not prepared

**Symptom.** Deploying a hosted topology stops and asks you to run the preparation script.

**Cause.** Hosted topologies need `HOSTED_AGENT_PREPARED=true` and `DEPLOY_HOSTED_AGENT=true`. `azd up` does not set them; the preparation script does.

**Fix.**

```bash
pwsh scripts/prepareHostedDeployment.ps1
azd deploy
```

See [Hosted agents](hosted-agents.md#topologies).

### Hosted agent deployment returns an agent permission denial

**Symptom.** Agent creation or lookup returns HTTP 403 and names
`Microsoft.CognitiveServices/accounts/AIServices/agents/read` as a missing action.

**Cause.** The actual deployment principal lacks Foundry agent data-plane
permissions. Successful private DNS/TLS checks and ARM provisioning do not
prove agent authorization.

**Fix.** Verify the object ID in the denial against the identity used by
`azd auth login`. An authorized administrator can grant **Foundry User**
(formerly **Azure AI User**) at the target Foundry project scope for a runner
that creates and updates agents. Verify the assignment, allow propagation,
then retry. Do not substitute Azure AI Developer, which targets workspace/hub
scenarios, or grant resource-group Owner. See
[Connected-host deployment](network-isolation.md#complete-the-deployment-from-a-connected-host).
This authoring role is not delegated-user/OBO acceptance evidence.

### Application definition does not match the environment

**Symptom.** `predeploy` exits with code `2` after validating the application definition.

**Cause.** The application definition and the topology bound to the environment disagree, for example a hosted definition in a classic environment.

**Fix.** Select the definition that matches the environment, or change the topology and provision again. See [Custom applications](build-your-own-app.md).

### Private deployment prerequisites failed

**Message.**

```text
Private deployment prerequisites failed. Use a VPN/VNet-connected host; RUN_FROM_JUMPBOX is not a connectivity bypass.
```

**Cause.** `NETWORK_ISOLATION=true` and the host cannot resolve or open a TLS connection to App Configuration, or to the Foundry project endpoint for hosted topologies. The check waits up to 20 seconds per endpoint.

**Fix.** Run the deployment from the jumpbox or from a host connected through VPN or a peered VNet. Setting `RUN_FROM_JUMPBOX` does not skip this check. See [Verify private connectivity](network-isolation.md#verify-private-connectivity).

### ACR Task agent pool is missing

**Message.**

```text
Run 'azd env set DEPLOY_ACR_TASK_AGENT_POOL true' and 'azd provision', or set BUILD_MODE=local on a VNet-connected host with Docker.
```

**Cause.** `NETWORK_ISOLATION=true`, no ACR Task agent pool was provisioned, and `BUILD_MODE` is not `local`. Without a pool inside the VNet, the private registry cannot build images.

**Fix (recommended).** Provision the agent pool:

```bash
azd env set DEPLOY_ACR_TASK_AGENT_POOL true
azd provision
azd deploy
```

**Fix (alternative).** Build on a VNet-connected host that has Docker installed:

```bash
azd env set BUILD_MODE local
azd deploy
```

The jumpbox does not include Docker by default. See [Image builds in isolated deployments](network-isolation.md#image-builds-in-isolated-deployments).

### Package installation fails inside the build pool

**Symptom.** An ACR run starts in the private agent pool, but package
installation fails. For example, npm reports `Exit handler never called!`,
followed by `tsc: not found` during the frontend build.

**Diagnosis.** Retrieve the actual failed ACR run log from a VNet-connected
host. Correlate its timestamps and the build-agent source address with Azure
Firewall deny logs. An existing pool and a successfully pulled base image do
not prove that package feeds are reachable. Check the exact pinned lockfile's
`resolved` URLs; setting npm's registry alone does not replace those URLs.

**Fix.** If firewall logs confirm blocked package hosts, add only the required
feeds and their verified download CDN to
`parameters.additionalAcrTaskBuildFqdns.value` in `main.parameters.json`,
provision, and retry the same pinned source. See
[Application-specific package feeds](network-isolation.md#application-specific-package-feeds).
Keep the exception confined to build-subnet HTTPS traffic. Do not upgrade npm
speculatively or treat a later missing compiler as proof of a dependency
version defect.

### Stale component checkout

**Message** contains `Remove or relocate the stale sibling checkout`.

**Cause.** `predeploy` clones each component next to this repository at the tag and commit pinned in `manifest.json`. A folder with that name already exists at a different commit or with local changes.

**Fix.** Move or delete the folder named in the message and run `azd deploy` again. If you are developing a component locally, keep your work in a separate folder.

### A component deployment fails

**Cause.** The build or the container app update for one component failed.

**Fix.** Open the newest file in the `.logs` folder of that component checkout. Common causes are a registry that the build host cannot reach (see the agent pool entry above) or a missing role assignment for your identity on the registry.

### Deploy succeeds but the UI or administrative panel does not start

**Symptom.** Child deployment commands return success, but the latest
application revision is unhealthy. The UI reports missing
`OAUTH_AZURE_AD_CLIENT_ID`, `OAUTH_AZURE_AD_CLIENT_SECRET`, or
`OAUTH_AZURE_AD_TENANT_ID`; ingestion reports missing OAuth panel settings.

**Cause.** Hosted UI startup validates the default user-delegated OAuth
contract. The panel also requires Entra configuration. A previous healthy
placeholder revision can still serve HTTP 200 while the new image fails.

**Fix.** Check the latest revision's image, health, and startup logs. Configure
the [delegated authentication settings](hosted-agents.md#configure-the-uis-delegated-authentication),
store the client credential in Key Vault, and publish only its reference
with label `agent-lz`. Restart the intended revision and verify its health,
the Entra login redirect, and rejection of unauthenticated panel data requests.
Then verify real user login, OBO, and document authorization. Do not switch
to service identity or disable the panel to turn a missing-authentication
failure into a passing acceptance result.

## Provision and post-provision stages

### Quota check rejects an unchanged existing deployment

**Symptom.** Re-provisioning an existing environment reports less remaining
model quota than the configured capacity, although that same account already
has the requested deployment at that capacity.

**Cause.** In v4.2.2, both preflight gates compare the full requested capacity
with unused regional quota. They do not credit capacity already allocated to
the target deployment, so the second provision step of a hosted deployment
can stop before Azure receives the incremental update.

**Fix.** Verify the selected environment, account location, deployment name,
model/version and SKU. Do not disable preflight, reduce capacity just to pass
the check, or delete the existing deployment. The correction tracked in
[agent-landing-zone#773](https://github.com/Azure/agent-landing-zone/pull/773)
uses one shared quota calculation for both gates. It credits only a verified,
successful matching deployment in the selected subscription and resource group,
checks increases against the remaining quota, and aggregates deployments using
the same quota pool. Fresh allocations and unverified or changed targets still
need their full capacity; model availability checks remain in place.
Until that correction is released, record this as a preflight limitation, not
successful hosted deployment acceptance.

### Foundry rejects evaluation API-key creation

**Message.** `Failed to list key. disableLocalAuth is set to be true`.

**Cause.** The Foundry account requires Microsoft Entra ID. In v4.2.2,
post-provision still attempts to copy an evaluation API key to Key Vault;
its final success message does not prove that this secret was created.
This does not require enabling key authentication for the application.

**Fix.** Keep local authentication disabled and use Microsoft Entra ID for
evaluation clients. The correction tracked in
[agent-landing-zone#773](https://github.com/Azure/agent-landing-zone/pull/773)
checks the account's authentication setting, explicitly reports key injection
as not applicable for Entra-only accounts, and fails on unexpected key or
Key Vault errors. Until that correction is released, record this post-provision
limitation separately from application runtime results.

### Administrative panel cannot resolve its Cosmos database

**Message.** `DEPLOY_ADMINISTRATIVE_PANEL is true but DATABASE_ACCOUNT_NAME is not set`.

**Cause.** In v4.2.2, post-provision publishes the resolved account and database
under `DATABASE_ACCOUNT_NAME` and `DATABASE_NAME` in App Configuration, but
panel role assignment expects them in the process environment.

**Fix.** Confirm these two non-secret settings under label `agent-lz` in the
selected environment's App Configuration. For a split recovery, supply those
same values to `config.panel.setup`; do not infer the database name from a
resource-name pattern or widen the grants to the account scope. The correction
in [agent-landing-zone#773](https://github.com/Azure/agent-landing-zone/pull/773)
reads the published settings when process inputs are absent and preserves the
existing container-scoped roles.

### Missing endpoint output

**Message.**

```text
Missing <KEY>. Run provisioning and load the selected azd environment outputs before this stage.
```

**Cause.** The stage needs an output that the selected `azd` environment does not have: `APP_CONFIG_ENDPOINT`, `AZURE_AI_PROJECT_ENDPOINT`, or `AZURE_CONTAINER_REGISTRY_ENDPOINT`.

**Fix.** Confirm the environment with `azd env select <name>`, then run `azd provision`. If you moved to another machine, run `azd env refresh` to load the outputs.

### Private post-provision prerequisites failed

**Message.**

```text
Private post-provision prerequisites failed. Connect through VPN/VNet and rerun postProvision; configuration has not started.
```

**Cause.** Provisioning completed, but the host cannot reach App Configuration on the private network. No configuration was applied.

**Fix.** Connect through the jumpbox, VPN, or a peered VNet, then run:

```bash
azd hooks run postprovision
```

### Post-provision was deferred

**Message.**

```text
Post-provision configuration explicitly deferred; application setup is incomplete.
```

**Cause.** This is a warning, not a failure. `RUN_FROM_JUMPBOX` is `false`, or `AZURE_SKIP_NETWORK_ISOLATION_WARNING` is `true`, so post-provision skipped configuration on purpose.

**Fix.** Finish the configuration from a connected host. See [Post-provision can be deferred](network-isolation.md#post-provision-can-be-deferred) and [Complete a deferred post-provision](operations.md#complete-a-deferred-post-provision).

### `NETWORK_ISOLATION` is not a boolean

**Cause.** The value is something other than `true` or `false`.

**Fix.**

```bash
azd env set NETWORK_ISOLATION true   # or false
```

### Provisioning fails in Azure

**Cause.** Common causes are model quota in the selected region, a resource name that is already taken, or a policy that denies a resource configuration.

**Fix.** Read the failed operation in the Azure portal under **Resource group > Deployments**. For quota, choose another region or request more capacity. Then run `azd provision` again; provisioning is incremental.

## Runtime

### The orchestrator returns HTTP 422

**Cause.** The hosted agent uses the stateless **Responses 2.0.0** protocol, and the request sends `conversation` or `previous_response_id`.

**Fix.** Remove those fields and send the context the agent needs in each request. See [Calling the agent](hosted-agents.md#calling-the-agent).

### The application starts but does not answer

Check, in this order:

1. The container app revision is healthy. See [Check application health](operations.md#check-application-health).
2. The logs show the startup sequence and no configuration errors. See [Stream logs from a container app](operations.md#stream-logs-from-a-container-app).
3. Runtime settings use the label `agent-lz` in App Configuration. After changing a setting, restart the revision. See [Change a runtime setting](operations.md#change-a-runtime-setting).
4. Application Insights shows the failing dependency. Use the queries in [Monitoring](operations.md#monitoring).

### Access denied between services

**Cause.** A managed identity is missing a role, or a role assignment has not propagated yet. New assignments can take several minutes.

**Fix.** Compare the assignments with [Identity and roles](operations.md#identity-and-roles). Wait a few minutes and retry before adding roles manually.

## Related pages

- [Network isolation](network-isolation.md)
- [Operations](operations.md)
- [Configuration](configuration.md)
