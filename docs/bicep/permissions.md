# Permissions

The following role assignments are provisioned by the template based on the **default configuration** in `main.parameters.json`. This includes the default set of container apps, their associated roles, and the services they interact with.

!!! note
    If you customize the parameters before provisioning — such as adding or removing container apps or changing role mappings — the actual assignments will vary accordingly.

## Microsoft Foundry and AI Search Assignments

| Resource | Role | Assignee | Description |
|---|---|---|---|
| Microsoft Foundry Account | Cognitive Services User | Search Service | Allow Search Service to access vectorizers |
| GenAI App Search Service | Search Index Data Reader | Microsoft Foundry Project | Read index data |
| GenAI App Search Service | Search Service Contributor | Microsoft Foundry Project | Create AI Search connection |
| GenAI App Storage Account | Storage Blob Data Reader | Microsoft Foundry Project | Read blob data |
| GenAI App Storage Account | Storage Blob Data Reader | Search Service | Read blob data for indexing |

## Container App Role Assignments

Current default configuration provisions a single Hello World container app (`orchestrator`), so only the assignments below are expected by default.

| Resource | Role | Assignee | Description |
|---|---|---|---|
| GenAI App Configuration Store | App Configuration Data Reader | ContainerApp: orchestrator | Read configuration data |
| GenAI App Container Registry | AcrPull | ContainerApp: orchestrator | Pull container images |
| GenAI App Key Vault | Key Vault Secrets User | ContainerApp: orchestrator | Read secrets |
| GenAI App Search Service | Search Index Data Reader | ContainerApp: orchestrator | Read index data |
| GenAI App Storage Account | Storage Blob Data Reader | ContainerApp: orchestrator | Read blob data |
| GenAI App Cosmos DB | Cosmos DB Built-in Data Contributor | ContainerApp: orchestrator | Read/write Cosmos DB data |
| Microsoft Foundry Account | Cognitive Services User | ContainerApp: orchestrator | Access Cognitive Services |
| Microsoft Foundry Account | Cognitive Services OpenAI User | ContainerApp: orchestrator | Use OpenAI APIs |

## Executor Role Assignments

| Resource | Role | Assignee | Description |
|---|---|---|---|
| GenAI App Configuration Store | App Configuration Data Owner | Executor | Full control over configuration settings |
| GenAI App Container Registry | AcrPush | Executor | Push container images |
| GenAI App Container Registry | AcrPull | Executor | Pull container images |
| GenAI App Key Vault | Key Vault Contributor | Executor | Manage Key Vault settings |
| GenAI App Key Vault | Key Vault Secrets Officer | Executor | Create Key Vault secrets |
| GenAI App Search Service | Search Service Contributor | Executor | Create/update search service elements |
| GenAI App Search Service | Search Index Data Contributor | Executor | Read/write search index data |
| GenAI App Search Service | Search Index Data Reader | Executor | Read index data |
| GenAI App Storage Account | Storage Blob Data Contributor | Executor | Read/write blob data |
| GenAI App Cosmos DB | Cosmos DB Built-in Data Contributor | Executor | Read/write Cosmos DB data |
| Microsoft Foundry Account | Cognitive Services OpenAI User | Executor | Use OpenAI APIs |
| Microsoft Foundry Account | Cognitive Services User | Executor | Access Cognitive Services |

## Jumpbox VM Role Assignments

| Resource | Role | Assignee | Description |
|---|---|---|---|
| GenAI App Container Apps | Container Apps Contributor | Jumpbox VM | Full control over Container Apps |
| Azure Managed Identity | Managed Identity Operator | Jumpbox VM | Assign and manage user-assigned identities |
| GenAI App Container Registry | Container Registry Repository Writer | Jumpbox VM | Write to ACR repositories |
| GenAI App Container Registry | Container Registry Tasks Contributor | Jumpbox VM | Manage ACR tasks |
| GenAI App Container Registry | Container Registry Data Access Configuration Administrator | Jumpbox VM | Manage ACR data access configuration |
| GenAI App Container Registry | AcrPush | Jumpbox VM | Push container images |
| GenAI App Configuration Store | App Configuration Data Owner | Jumpbox VM | Full control over configuration settings |
| GenAI App Key Vault | Key Vault Contributor | Jumpbox VM | Manage Key Vault settings |
| GenAI App Key Vault | Key Vault Secrets Officer | Jumpbox VM | Create Key Vault secrets |
| GenAI App Search Service | Search Service Contributor | Jumpbox VM | Create/update search service elements |
| GenAI App Search Service | Search Index Data Contributor | Jumpbox VM | Read/write search index data |
| GenAI App Storage Account | Storage Blob Data Contributor | Jumpbox VM | Read/write blob data |
| GenAI App Cosmos DB | Cosmos DB Built-in Data Contributor | Jumpbox VM | Read/write Cosmos DB data |
| Microsoft Foundry Account | Cognitive Services Contributor | Jumpbox VM | Manage Cognitive Services resources |
| Microsoft Foundry Account | Cognitive Services OpenAI User | Jumpbox VM | Use OpenAI APIs |
