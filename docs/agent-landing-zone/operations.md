# Operations

This page covers day-two tasks: upgrading, redeploying components, permissions, monitoring and teardown.

## Upgrading

### From GPT-RAG

Agent Landing Zone is the new name for GPT-RAG, starting with release v4.0.0. The repositories were renamed:

| Before | Now |
| --- | --- |
| `Azure/GPT-RAG` | [`Azure/agent-landing-zone`](https://github.com/Azure/agent-landing-zone) |
| `Azure/gpt-rag-ui` | [`Azure/agent-app-ui`](https://github.com/Azure/agent-app-ui) |
| `Azure/gpt-rag-orchestrator` | [`Azure/agent-app-orchestrator`](https://github.com/Azure/agent-app-orchestrator) |
| `Azure/gpt-rag-ingestion` | [`Azure/agent-app-ingestion`](https://github.com/Azure/agent-app-ingestion) |

GitHub redirects the old repository URLs, but update your remotes:

```bash
git remote set-url origin https://github.com/Azure/agent-landing-zone.git
```

!!! warning "No in-place upgrade from GPT-RAG v3"
    Environments created with GPT-RAG v3 cannot be upgraded in place. Resource names, App Configuration labels and environment variables changed. Deploy a new environment with Agent Landing Zone and migrate your data (documents, search indexes and conversation history) to it.

Components still read runtime settings with the legacy `gpt-rag` label as a fallback, so custom settings you copy over keep working. Prefer the `agent-lz` label for new settings. See [Runtime settings](configuration.md#runtime-settings).

### Between Agent Landing Zone releases

1. Check out the new release tag.
2. Read the release notes and the changelog for parameter changes.
3. Run `azd up`. The platform is updated in place, and each component is redeployed at the version pinned in `manifest.json`.

## Redeploying components

To redeploy the application components without reprovisioning the platform, run from the repository root:

```bash
azd deploy
```

This redeploys every selected component at the version pinned in `manifest.json`. For each component, the deploy step clones the component repository into a sibling folder of the landing zone checkout (for example `../gpt-rag-orchestrator`), or reuses that folder after checking that it is at the pinned commit. It then runs the component's own `scripts/deploy.ps1` (Windows) or `scripts/deploy.sh` (Linux and macOS). Logs are written to `.logs/` inside each component folder.

### Redeploying one component

To redeploy a single component, run its deploy script from its sibling folder:

```bash
cd ../gpt-rag-orchestrator
./scripts/deploy.sh   # or .\scripts\deploy.ps1 on Windows
```

!!! note "Stale component folders"
    If a sibling folder is at a different commit than the one pinned in `manifest.json`, the deploy stops with the message "Remove or relocate the stale sibling checkout". Delete or rename that folder and run `azd deploy` again.

## Role assignments (classic topology)

With `DEPLOYMENT_TOPOLOGY=classic`, each Container App uses its own managed identity. The landing zone assigns the roles each component needs:

| Component | Roles |
| --- | --- |
| UI | App Configuration Data Reader, AcrPull, Key Vault Secrets User, Storage Blob Data Reader, Storage Blob Delegator |
| Orchestrator | App Configuration Data Reader, AcrPull, Key Vault Secrets User, Cognitive Services User, Cognitive Services OpenAI User, Search Index Data Reader, Storage Blob Data Reader, Cosmos DB Built-in Data Contributor |
| Ingestion | App Configuration Data Reader, AcrPull, Key Vault Secrets User, Cognitive Services User, Cognitive Services OpenAI User, Search Index Data Contributor, Storage Blob Data Contributor, Cosmos DB Built-in Data Contributor |

For hosted topologies, the hosted agent identity is configured by the access bootstrap. See [Hosted agents](hosted-agents.md#access-bootstrap).

For custom applications, roles come from capability profiles. See [Capability profiles](build-your-own-app.md#capability-profiles).

## Monitoring

- **Application Insights** collects traces, requests and dependencies from every component.
- **Log Analytics** stores Container Apps console and system logs. Query them with the `ContainerAppConsoleLogs_CL` and `ContainerAppSystemLogs_CL` tables.
- Hosted agents send OpenTelemetry traces to the same Application Insights resource. See [Telemetry content capture](hosted-agents.md#telemetry-content-capture).

## Teardown

To delete the environment and purge soft-deleted resources (Key Vault, Azure AI services, App Configuration):

```bash
azd down --purge
```

!!! warning
    This deletes all data in the environment, including documents, indexes and conversation history.
