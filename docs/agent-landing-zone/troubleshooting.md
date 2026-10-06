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

### Stale component checkout

**Message** contains `Remove or relocate the stale sibling checkout`.

**Cause.** `predeploy` clones each component next to this repository at the tag and commit pinned in `manifest.json`. A folder with that name already exists at a different commit or with local changes.

**Fix.** Move or delete the folder named in the message and run `azd deploy` again. If you are developing a component locally, keep your work in a separate folder.

### A component deployment fails

**Cause.** The build or the container app update for one component failed.

**Fix.** Open the newest file in the `.logs` folder of that component checkout. Common causes are a registry that the build host cannot reach (see the agent pool entry above) or a missing role assignment for your identity on the registry.

## Provision and post-provision stages

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
