# AI Foundry

This repo can deploy an Azure AI Foundry (Azure AI Services account + Foundry Project + model deployments) as part of the landing zone.

## Defaults

By default, when AI Foundry is enabled, [infra/main.bicep](../infra/main.bicep) deploys:

- An AI Services account (AI Foundry)
- A Foundry Project
- Model deployments (as configured by `aiFoundryDefinition.aiModelDeployments`, or the repo defaults)

And it **does** deploy the Foundry Agent Service (Capability Hosts) and its dependent resources by default.
If you want **project + models only** (no agent, no dependencies), you must explicitly disable those via parameters.

## Deployment modes supported by this template

This template supports the following Foundry modes via `aiFoundryDefinition`:

### 1) Full agent-ready Foundry (dependencies + capability hosts) (default)

Use this when you want the Foundry Agent Service (Capability Hosts) created and wired to its typical dependencies.

Key parameters:

- `aiFoundryDefinition.includeAssociatedResources`: `true` (default)
- `aiFoundryDefinition.aiFoundryConfiguration.createCapabilityHosts`: `true` (default)

### 2) Project + models only (no dependencies, no agent)

Use this when you want:

- AI Foundry account
- a Foundry Project
- model deployments

But you do **not** want:

- AI Search / Storage / Cosmos created by the Foundry component
- Capability Hosts (Foundry Agent Service)

Key parameters:

- `aiFoundryDefinition.includeAssociatedResources`: `false`
- `aiFoundryDefinition.aiFoundryConfiguration.createCapabilityHosts`: `false`

### 3) Disable AI Foundry entirely

Use this when you want to skip all Foundry resources.

Key parameters:

- `deployToggles.aiFoundry`: `false`

## Private endpoints and DNS

When `deployPrivateEndpointsAndDns = true` (driven by the landing zone’s Private Endpoint/DNS toggle), the Foundry component will:

- Always create a private endpoint + private DNS configuration for the **AI Foundry account**
- Only create private endpoints + DNS for **AI Search / Storage / Cosmos** when `aiFoundryDefinition.includeAssociatedResources = true`

## How to configure (examples)

### Full Foundry (dependencies + capability hosts) (default)

```bicep
param aiFoundryDefinition = {
  includeAssociatedResources: true
  aiFoundryConfiguration: {
    createCapabilityHosts: true
    project: {
      name: 'aifoundry-default-project'
      displayName: 'Default AI Foundry Project'
      description: 'This is the default project for AI Foundry.'
    }
  }

  // Optional model deployments
  aiModelDeployments: [
    {
      name: 'gpt-4o'
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '1'
      }
      sku: {
        name: 'Standard'
        capacity: 1
      }
    }
  ]
}
```

### Project + models only

```bicep
param aiFoundryDefinition = {
  // Disable associated resources + capability hosts
  includeAssociatedResources: false
  aiFoundryConfiguration: {
    createCapabilityHosts: false
    project: {
      name: 'aifoundry-minimal-project'
      displayName: 'Minimal Project'
      description: 'Project with model deployments only (no agent dependencies).'
    }
  }
}
```

## Notes

- `includeAssociatedResources` controls what the **Foundry component** creates (Search/Storage/Cosmos + their PE/DNS + project connections). It does not prevent the landing zone from deploying Search/Storage/Cosmos if you enabled those separately.
- If `includeAssociatedResources = false`, the Foundry Project is still created, but **without** the dependency connections.
