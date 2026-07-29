# Hosted-Agent Deployment Prerequisites

The `deployHostedAgent` flag readies an AI Landing Zone for a downstream Microsoft Foundry hosted-agent deployment. It is a **prerequisites-only** opt-in, not a workload topology switch: it does not create an agent version, Container App, or any application UI, and it does not modify or suppress any existing workload resource.

**Source repository:** [Azure/bicep-ptn-aiml-landing-zone](https://github.com/Azure/bicep-ptn-aiml-landing-zone/)

## What the flag does and does not do

When `deployHostedAgent` is `false` (the default), the compiled resource graph is identical to a deployment without the flag. No RBAC changes; no additional outputs; complete backward compatibility.

When `deployHostedAgent` is `true`, the landing zone adds exactly two infrastructure changes:

1. **Azure AI Project Manager** on the AI Foundry project — assigned to the deploying principal so it can register the deployment contract against the project.
2. **Container Registry Repository Reader** on the selected ACR — assigned to the AI Foundry project's managed identity so Foundry can pull the agent image during `azd deploy`.

These additions come on top of the existing resource graph. Nothing is removed, suppressed, or reordered.

!!! note "What the flag explicitly does not do"
    - Does **not** create an agent version or a dedicated per-agent identity.
    - Does **not** create any Container App — neither a workload replacement nor an admin panel.
    - Does **not** modify `containerAppsList`, Container Apps Environment, Cosmos DB, Storage, AI Search, App Configuration, or any other existing resource.
    - Does **not** emit App Configuration keys for the agent.
    - Workload topology remains entirely under the existing parameters.

The data-plane operations — creating the immutable agent version, the dedicated per-agent identity, the invocation endpoint, and that identity's ACR pull assignment — are performed by the downstream `azure.ai.agent` service during `azd deploy`. See the official [hosted-agent `azure.yaml` reference](https://learn.microsoft.com/azure/foundry/agents/concepts/azure-yaml-reference#azureaiagent-service) and the [pre-built image workflow](https://learn.microsoft.com/azure/foundry/agents/how-to/deploy-hosted-agent-private-azure-container-registry#deploy-a-pre-built-image).

---

## Parameters

### `deployHostedAgent`

| | |
|---|---|
| **Type** | `bool` |
| **Default** | `false` |

Enable accelerator-neutral prerequisites and deployment contracts for a Microsoft Foundry hosted agent. Requires `deployAiFoundry=true`.

### `hostedAgent`

| | |
|---|---|
| **Type** | `hostedAgentConfigurationType` (exported Bicep type) |
| **Default** | All fields empty; `runtime` = `1` CPU / `1Gi`; `protocols` = `responses 2.0.0` |

Typed handoff consumed by the downstream `azure.ai.agent` service. Values are validated by preflight only when `deployHostedAgent=true`.

| Field | Required when enabled | Description |
|---|---|---|
| `name` | Yes | Stable hosted-agent name. Reusing the same name in a later deployment creates a new immutable version under that name. |
| `image` | Yes | Repository path inside the selected ACR, **without** a tag or digest (e.g. `agents/my-agent`). |
| `version` | Yes | Immutable OCI digest in `sha256:<64 hex characters>` form. Mutable tags are rejected by preflight because Foundry versions are immutable by design. |
| `startupCommand` | Yes | Command that starts the agent server. Maps to `startupCommand` in the [`azure.ai.agent` service contract](https://learn.microsoft.com/azure/foundry/agents/concepts/azure-yaml-reference#azureaiagent-service). |
| `runtime.cpu` | Yes | CPU allocation (`1`, `500m`, etc.). Maps to `container.resources` in `azure.ai.agent`. |
| `runtime.memory` | Yes | Memory allocation (`1Gi`, `512Mi`, etc.). Maps to `container.resources` in `azure.ai.agent`. |
| `protocols` | Yes | One or more invocation-protocol entries. Each entry has a `protocol` (`responses` \| `invocations` \| `invocations_ws` \| `a2a`) and an optional `version` string. |

```json
"hostedAgent": {
  "value": {
    "name": "sample-agent",
    "image": "agents/sample-agent",
    "version": "sha256:<64-hex-digest>",
    "startupCommand": "python main.py",
    "runtime": {
      "cpu": "1",
      "memory": "1Gi"
    },
    "protocols": [
      { "protocol": "responses", "version": "2.0.0" }
    ]
  }
}
```

### `hostedAgentContainerRegistryResourceId`

| | |
|---|---|
| **Type** | `string` |
| **Default** | `''` (empty — landing-zone ACR is used when `deployContainerRegistry=true`) |

Resource ID of an **existing** Azure Container Registry when `deployContainerRegistry=false`. The deploying principal must have permission to create role assignments at this scope.

### `hostedAgentContainerRegistryEndpoint`

| | |
|---|---|
| **Type** | `string` |
| **Default** | `''` (empty — resolved from landing-zone ACR when `deployContainerRegistry=true`) |

Login endpoint of an existing ACR (e.g. `contoso.azurecr.io`). Required when `hostedAgentContainerRegistryResourceId` is set. Private endpoint, DNS, and VNet-internal build connectivity for an existing registry remain the consumer's responsibility.

---

## Quickstart

```bash
# Enable hosted-agent prerequisites
azd env set DEPLOY_HOSTED_AGENT true

# Provide the typed handoff in main.parameters.json (or via environment)
# Edit hostedAgent.name / image / version / startupCommand / runtime / protocols

azd provision
```

After provisioning, map the outputs into the accelerator's `azure.ai.agent` service and run `azd deploy` from the accelerator.

---

## Outputs

All hosted-agent outputs are empty strings / `false` / `null` when `deployHostedAgent=false`.

| Output | Type | Description |
|---|---|---|
| `DEPLOY_HOSTED_AGENT` | `bool` | Effective enablement value. |
| `AZURE_AI_PROJECT_RESOURCE_ID` | `string` | Foundry project resource ID for the downstream `azure.ai.agent` block. |
| `AZURE_AI_PROJECT_ENDPOINT` | `string` | Foundry project endpoint URL. |
| `AZURE_CONTAINER_REGISTRY_RESOURCE_ID` | `string` | Resource ID of the selected registry (landing-zone ACR or BYO). |
| `AZURE_CONTAINER_REGISTRY_ENDPOINT` | `string` | Login endpoint of the selected registry. |
| `HOSTED_AGENT_DEPLOYMENT` | `object` | Consolidated typed handoff for the downstream service (see below). |

### `HOSTED_AGENT_DEPLOYMENT` shape

```jsonc
{
  "enabled": true,
  "agent": {
    "name": "<name>",
    "image": "<endpoint>/<repo>@sha256:<digest>",
    "imageVersion": "sha256:<digest>",
    "startupCommand": "<command>",
    "runtime": { "cpu": "1", "memory": "1Gi" },
    "protocols": [{ "protocol": "responses", "version": "2.0.0" }]
  },
  "foundry": {
    "projectResourceId": "<resource-id>",
    "projectEndpoint": "<endpoint>",
    "projectPrincipalId": "<managed-identity-object-id>",
    "agentSubnetResourceId": "<subnet-resource-id>"
  },
  "containerRegistry": {
    "resourceId": "<resource-id>",
    "endpoint": "<login-server>"
  },
  "privateBuild": {
    "required": false,           // true when networkIsolation=true
    "subnetResourceId": "...",   // build-agent subnet when networkIsolation=true
    "jumpboxResourceId": "...",  // jumpbox when networkIsolation=true
    "acrTaskAgentPoolName": "..."
  }
}
```

---

## Container registry selection

The landing zone resolves the registry automatically:

| `deployContainerRegistry` | Registry used | Consumer responsibilities |
|---|---|---|
| `true` (default) | Landing-zone ACR | None — RBAC, endpoints, and connectivity managed by the landing zone. |
| `false` | ACR provided via `hostedAgentContainerRegistryResourceId` / `hostedAgentContainerRegistryEndpoint` | Private endpoint, DNS integration, authentication-as-ARM policy, and network reachability remain **the consumer's responsibility**. |

---

## Network isolation and image build/push

When `networkIsolation=true`, the landing-zone ACR disables public network access and places the registry behind a private endpoint. In this mode, building and pushing the agent image **must** happen from a VNet-connected runner — options include:

- The landing-zone **jumpbox VM** (pre-provisioned when `deployJumpbox=true`).
- The landing-zone **ACR Task agent pool** (when `deployAcrTaskAgentPool=true`).
- Any other machine with line-of-sight to the private endpoint (CI agent, self-hosted runner, Azure DevOps agent on the agent subnet).

The `HOSTED_AGENT_DEPLOYMENT.privateBuild` output exposes the subnet and jumpbox resource IDs, and the ACR Task pool name, so the downstream deployment can configure its build step without hard-coding resource names.

---

## Downstream `azd deploy` responsibility

`azd provision` (the landing zone) prepares the infrastructure prerequisites. The downstream accelerator's `azd deploy` step, driven by the `azure.ai.agent` service in `azure.yaml`, is responsible for:

- Creating the immutable agent version.
- Provisioning the dedicated per-agent managed identity.
- Assigning the agent identity's ACR pull role.
- Exposing the invocation endpoint.

These are data-plane resources. The landing zone neither creates nor manages them.

Reference: [hosted-agent `azure.yaml` reference](https://learn.microsoft.com/azure/foundry/agents/concepts/azure-yaml-reference#azureaiagent-service).

---

## Private-registry compatibility gate

Microsoft Learn documents a Foundry-project creation-date condition that determines whether a fully private ACR (public access disabled + private endpoint only) is supported:

| Foundry project created | Private-endpoint-only ACR support |
|---|---|
| **After June 25, 2026** | ✅ Supported — public access may be disabled; Foundry pulls exclusively through the private endpoint. |
| **Before June 25, 2026** | ⚠️ Not supported — the registry must remain reachable over its public endpoint. Disabling public access will cause the hosted-agent pull to fail at `azd deploy` time. |

!!! warning "Check your project's creation date before going live"
    If your AI Foundry project predates June 25, 2026 and you are using a private-endpoint-only registry, either keep the registry's public endpoint enabled or migrate to a new Foundry project created after June 25, 2026.

References:
- [Deploy a hosted agent from a private Azure Container Registry](https://learn.microsoft.com/azure/foundry/agents/how-to/deploy-hosted-agent-private-azure-container-registry) — full private-ACR deployment guide including the creation-date limitation
- [Hosted-agent permissions — Azure resource setup](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agent-permissions#azure-resource-setup) — role assignments and network requirements

---

## Role assignments added

See [Permissions](permissions.md#hosted-agent-role-assignments) for the complete table. In summary:

| Resource | Role | Assignee |
|---|---|---|
| AI Foundry project | Azure AI Project Manager | Deploying principal (executor) |
| Selected ACR | Container Registry Repository Reader | AI Foundry project managed identity |

---

## See also

- [Parameterization](parameterization.md#hosted-agent-deployment-contract) — full parameter reference
- [Permissions](permissions.md#hosted-agent-role-assignments) — RBAC detail
- [Deployed Resources](deployed-resources.md) — resource inventory
- [Building Accelerators (Submodule Pattern)](accelerator-pattern.md) — how downstream accelerators consume the landing zone
- [Hosted-agent `azure.yaml` reference](https://learn.microsoft.com/azure/foundry/agents/concepts/azure-yaml-reference#azureaiagent-service) — Microsoft Foundry service contract
- [Deploy a pre-built image (private ACR)](https://learn.microsoft.com/azure/foundry/agents/how-to/deploy-hosted-agent-private-azure-container-registry#deploy-a-pre-built-image) — downstream image workflow
- [Hosted-agent permissions](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agent-permissions#azure-resource-setup) — Foundry-side permission model
