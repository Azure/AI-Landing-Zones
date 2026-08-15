# 🏗️ Full Deployment Guide - All Environments

This guide covers deploying the AI Citadel Governance Hub across **development, staging, and production** environments with enterprise-grade configuration, networking, and governance.

For quick non-production deployments, see the [Quick Deployment Guide](./quick-deployment-guide.md).

### How to use this guide

Deploying the hub is a three-phase journey. This guide covers **Phase 1 (Plan)** and **Phase 2 (Deploy)**; day-2 configuration lives in the [Post-Deployment Guide](./post-deployment-guide.md).

| Phase | You do | Primary references |
|-------|--------|--------------------|
| **1. Plan** | Pick region(s), network model, SKUs, resiliency/BC-DR posture | This guide · [Networking Guide](./network-approach.md) · [Sizing Guide](./citadel-sizing-guide.md) · [Resiliency Guide](./resiliency-guide.md) · [BC/DR Guide](./business-continuity-dr-guide.md) |
| **2. Deploy** | Provision the landing zone (`azd up`) | This guide |
| **3. Operate** | Onboard backends & use cases, enable auth, activate reporting, upgrade | [Post-Deployment Guide](./post-deployment-guide.md) |

> 💡 **Complete the [Deployment Decisions Checklist](#-deployment-decisions-checklist) first.** Every decision maps to a parameter in [`main.bicepparam`](../bicep/infra/main.bicepparam), so a completed checklist becomes your deployment configuration.

---

## 📋 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Deployment Decisions Checklist](#-deployment-decisions-checklist)
3. [Deployment Preparation](#-deployment-preparation)
   - [Sizing & SKU Selection](#1-sizing--sku-selection)
   - [Parameter Files Strategy](#2-parameter-files-strategy)
   - [Resource Naming & Tagging](#3-resource-naming--tagging)
   - [Network Architecture](#4-network-architecture)
   - [Resiliency & Business Continuity](#5-resiliency--business-continuity)
   - [AI Model Deployment](#6-ai-model-deployment-optional)
   - [Log Analytics Strategy](#7-log-analytics-strategy)
   - [Inference API Diagnostic Logging](#8-inference-api-diagnostic-logging)
   - [Security & Compliance](#9-security--compliance)
4. [Deployment Execution](#-deployment-execution)
5. [Post-Deployment Validation](#-post-deployment-validation)
6. [Next Steps: Operate the Hub](#-next-steps-operate-the-hub)
7. [Troubleshooting](#-troubleshooting)

---

## ✅ Prerequisites

### Azure Requirements

| Requirement | Details |
|-------------|---------|
| **Azure Subscription** | Active subscription with sufficient quota |
| **Permissions** | Owner or Contributor + User Access Administrator |
| **Resource Providers** | All required providers registered (see below) |
| **Service Quotas** | Verified quotas for LLMs, CosmosDB and other elements |

## 📝 Deployment Decisions Checklist

Work through this checklist first — each decision maps directly to a parameter in [`main.bicepparam`](../bicep/infra/main.bicepparam). The linked guides help you choose.

- [ ] **Sizing (T-shirt size → SKUs)** — pick Small / Medium / Large per environment → [Sizing Guide](./citadel-sizing-guide.md)
  - [ ] Development (cost-optimized SKUs)
  - [ ] Staging (production SKUs, reduced capacity)
  - [ ] Production (production SKUs, full capacity)
- [ ] **Resiliency posture** — circuit breaker, session affinity, failover, error handling → [Resiliency Guide](./resiliency-guide.md)
- [ ] **Business continuity / DR** — single-region, multi-region, or Premium multi-region; RTO/RPO targets → [BC/DR Guide](./business-continuity-dr-guide.md)
- [ ] Subscription allocation
  - [ ] New subscription
  - [ ] Existing subscription
- [ ] Target Azure Region(s)
  - [ ] Primary Region (for core governance components)
  - [ ] Regions for Foundry instances and model deployments
- [ ] Network Approach
  - [ ] Hub-Based (using new subnets in existing hub network)
  - [ ] AIGovSpoke-Hub-Spoke (create dedicated spoke VNet linked to hub)
- [ ] Bring-Your-Own Network
  - [ ] Create new VNet with customized address space
  - [ ] Use existing VNet integration (vnet/subnets already created & configured)
  - [ ] Use exiting Private DNS Zones (better with using existing VNet)
  - [ ] Create new Private DNS Zones (better with new VNet)
- [ ] APIM Network Configuration
  - [ ] External (public endpoint, suitable for dev/test)
  - [ ] Internal (private endpoint, recommended for production)
  - [ ] APIM Custom Domains (list them for gateway, developer portal and management names)
- [ ] Log Analytics Strategy
  - [ ] New Workspace will be created
  - [ ] Use existing centralized Workspace (cross-environment)
- [ ] Resource Naming Convention & tags
  - [ ] Auto-generated names
  - [ ] Custom names/tags per organizational standards
- [ ] Microsoft Foundry Model Deployment
  - [ ] Deploy models as part of AI Citadel deployment (specify models/regions)
  - [ ] None (use existing deployments that will be onboarded later)
- [ ] Inference API Diagnostic Logging
  - [ ] Azure Monitor LLM log verbosity (enabled/disabled, message capture, max payload size)
  - [ ] Application Insights log headers and body capture size
  - [ ] Use defaults (recommended) or customize per environment
- [ ] Source Control Strategy
  - [ ] Single repository with branches per environment
      - [ ] Branch for original unchanged Citadel Governance Hub repo (synchronized with upstream)
      - [ ] Branches for dev, staging, production with environment-specific parameter files (apply changes through new parameter files only)
  - [ ] Separate repositories per environment (with similar branching strategy to point 1)
  - [ ] Automation Strategy
      - [ ] Manual deployments using `azd up` or `az deployment sub create`
      - [ ] CI/CD pipelines (i.e. Azure DevOps or GitHub Actions) for automated deployments

Leverage deployment parameter files ([main.bicepparam](../bicep/infra/main.bicepparam)) to capture these decisions for each environment.

### Required Resource Providers

You can use Azure Cloud Shell or your local Azure CLI installation to register the required resource providers.

First we make sure that the target subscription is selected:

```bash 
az login
az account list --output table
az account set --subscription "<subscription-name or id>"
az account show --output table
```

Then register all required resource providers:

```bash
# Register all required providers
az provider register --namespace Microsoft.AlertsManagement
az provider register --namespace Microsoft.ApiCenter
az provider register --namespace Microsoft.ApiManagement
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.Automation
az provider register --namespace Microsoft.Cache
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Diagnostics
az provider register --namespace Microsoft.DocumentDB
az provider register --namespace Microsoft.EventHub
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.MachineLearningServices
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Resources
az provider register --namespace Microsoft.Search
az provider register --namespace Microsoft.Sql
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Web

# Verify registration status
az provider list --query "[?registrationState=='Registered'].namespace" -o table
```

### Deployment Tools

**Option 1: Local Machine**
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (v2.50.0+)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (v0.20.0+)
- [Git](https://git-scm.com/downloads)
- [VS Code](https://code.visualstudio.com/) with extensions:
  - Bicep

**Option 2: Azure Cloud Shell**
- All tools pre-installed
- Storage account for persistence must be attached
- Built-in editor (in the classic mode)

**Option 3:  DevOps (i.e. Azure DevOps / GitHub Actions)**
- Self-hosted or Microsoft-hosted agents
- Service Principal with appropriate permissions
- Secure variable groups for secrets

---

## 🎯 Deployment Preparation

Based on your choices in the [Deployment Decisions Checklist](#-deployment-decisions-checklist), you can now prepare your deployment configuration.

For source control, make sure you have a working directory linked to your source control repository.

First you need to get the deployment template files:

```bash
# Create a working directory:
mkdir ai-hub-citadel-deployment
# Make the repository your current directory:
cd ai-hub-citadel-deployment # it may differ if you used git clone

# Copy repo files
azd init --template Azure-Samples/ai-hub-gateway-solution-accelerator -e ai-hub-citadel-dev --branch citadel-v1

# or use git clone:
# git clone https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator.git
# git checkout citadel-v1

```

Once you have the Infrastructure-as-Code files, proceed to configure your deployment based on the following strategies.

You can perform the deployment using either `azd up` (recommended) or `az deployment sub create` commands.

### 1. Sizing & SKU Selection

Before touching parameter files, decide the **size** of each environment. The [Citadel Sizing Guide](./citadel-sizing-guide.md) uses a T-shirt model (Small / Medium / Large) tied to expected PTU throughput and SLA needs, and tells you exactly which SKUs to set.

| T-shirt size | Fit | APIM SKU |
|--------------|-----|----------|
| **Small** | Dev / experimental, no SLA | Developer |
| **Medium Classic** | Non-prod or minimum-prod with SLA, full network isolation | Premium |
| **Medium v2** | Non-prod or minimum-prod with SLA | StandardV2 |
| **Large** | Multi-zone production with SLA | Premium (multi-unit) |

Once you have chosen a size, set the SKUs in your parameter file under the **`COMPUTE SKU & SIZE`** block:

```bicep
// ============================================================================
// COMPUTE SKU & SIZE - SKUs and capacity settings for services
// ============================================================================
param apimSku = readEnvironmentVariable('APIM_SKU', 'StandardV2')
param apimSkuUnits = int(readEnvironmentVariable('APIM_SKU_UNITS', '1'))
param eventHubCapacityUnits = int(readEnvironmentVariable('EVENTHUB_CAPACITY', '1'))
param cosmosDbRUs = int(readEnvironmentVariable('COSMOS_DB_RUS', '400'))
param logicAppsSkuCapacityUnits = int(readEnvironmentVariable('LOGIC_APPS_SKU_CAPACITY_UNITS', '1'))
param apicSku = readEnvironmentVariable('APIC_SKU', 'Free')
param keyVaultSkuName = readEnvironmentVariable('KEY_VAULT_SKU_NAME', 'standard')
```

> 📐 **See the [Sizing Guide](./citadel-sizing-guide.md)** for the reference Azure pricing estimates behind each size and for scale-out guidance (adding APIM units).

---

### 2. Parameter Files Strategy

AI Citadel Governance Hub uses **Bicep parameter files (.bicepparam)** for environment-specific configurations.

>NOTE: Always keep a separate copy of your customized parameter files with different names of the main repository `main.bicepparam` to avoid overwriting during updates.

#### Available Parameter Files

| File | Purpose | Use Case |
|------|---------|----------|
| [`main.bicepparam`](../bicep/infra/main.bicepparam) | Environment variables | Used in azd deployments, CI/CD (Default values come from here) |
| [`main.parameters.dev.bicepparam`](../bicep/infra/main.parameters.dev.bicepparam) | Development | Dev/test environments |
| [`main.parameters.prod.bicepparam`](../bicep/infra/main.parameters.prod.bicepparam) | Production | Production workloads |
| [`main.parameters.complete.bicepparam`](../bicep/infra/main.parameters.complete.bicepparam) | Reference | All parameters documented |

#### Parameter File Structure

```bicep
using './main.bicep'

// Basic Configuration
param environmentName = 'citadel-dev'
param location = 'eastus'
param tags = {
  'azd-env-name': 'citadel-dev'
  Environment: 'Development'
  CostCenter: 'Engineering'
}

// Compute SKUs
param apimSku = 'Developer'
param apimSkuUnits = 1

// Networking
param useExistingVnet = false
param useExistingLogAnalytics = false

// Features
param enableAPICenter = true
```

---

### 3. Resource Naming & Tagging

#### Naming Strategy

AI Citadel supports two naming approaches:

**Option A: Auto-Generated Names (for default non-production deployment)**
```bicep
param resourceGroupName = ''  // Auto-generated: rg-citadel-dev
param apimServiceName = ''    // Auto-generated: apim-abc123def
param logAnalyticsName = ''   // Auto-generated: log-abc123def
```

Benefits:
- ✅ Quick naming across environments
- ✅ Unique names prevent conflicts
- ✅ Includes environment hash for traceability

**Option B: Custom Names**
```bicep
param resourceGroupName = 'rg-ai-gov-citadel-prod-eastus'
param apimServiceName = 'apim-ai-gov-citadel-prod'
param logAnalyticsName = 'law-ai-gov-citadel-shared'
```

Benefits:
- ✅ Human-readable names
- ✅ Matches organizational naming standards
- ✅ Easier to locate in portal

#### Tagging Strategy

**Minimum Required Tags:**
```bicep
param tags = {
  'azd-env-name': 'ai-gov-citadel-prod'
  Environment: 'Production'
  CostCenter: 'Platform'
  Owner: 'platform-team@company.com'
  Criticality: 'High'
}
```

**Recommended Tags by Environment:**

| Tag | Dev | Staging | Production |
|-----|-----|---------|------------|
| Environment | Development | Staging | Production |
| Criticality | Low | Medium | High |
| CostCenter | Engineering | Engineering | Platform |

---

### 4. Network Architecture

#### Network Deployment Approaches

AI Citadel Governance Hub supports **two architectural patterns** for network integration.

Based on your decisions in the earlier checklist, choose one of the following approaches:

##### **Approach 1: Hub-Based (Citadel as Part of Hub)**

Citadel Governance Hub deployed **within** your existing hub VNet.

```
┌─────────────────────────────────────┐
│         Hub Network (VNet)          │
│  ┌──────────────────────────────┐   │
│  │   Citadel Governance Hub     │   │
│  │   - APIM (External/Internal) │   │
│  │   - Private Endpoints        │   │
│  │   - Log Analytics            │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │   Shared Services            │   │
│  │   - Azure Firewall & WAF     │   │
│  │   - DNS                      │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
           │           │
           ▼           ▼
    ┌──────────┐  ┌──────────┐
    │ Spoke 1  │  │ Spoke 2  │
    │ Agents   │  │ Agents   │
    └──────────┘  └──────────┘
```

**Configuration:**
```bicep
param useExistingVnet = true
param vnetName = 'vnet-hub-eastus'
param existingVnetRG = 'rg-network-hub'
param apimSubnetName = 'snet-citadel-apim'
param privateEndpointSubnetName = 'snet-citadel-private-endpoints'
param functionAppSubnetName = 'snet-citadel-functions'
```

**When to Use:**
- ✅ Citadel manages all enterprise AI traffic
- ✅ Direct spoke-to-hub connectivity
- ✅ Simplified network topology

---

##### **Approach 2: Hub-Spoke-Hub (Citadel as Dedicated Spoke)**

Citadel deployed in a **dedicated spoke** with firewall in between.

```
                 ┌─────────────┐
                 │ Hub Network │
                 │  - Firewall │
                 │  - DNS      │
                 └──────┬──────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
  ┌────────────┐ ┌────────────┐ ┌────────────┐
  │  Spoke 1   │ │  Citadel   │ │  Spoke 2   │
  │  Agents    │ │  Governance│ │  Agents    │
  └────────────┘ │   Hub      │ └────────────┘
                 │  - APIM    │
                 │  - PE      │
                 └────────────┘
```

**Configuration:**
```bicep
param useExistingVnet = false  // Creates new spoke VNet
param vnetName = 'vnet-citadel-eastus'
param vnetAddressPrefix = '10.170.0.0/24'
param dnsZoneRG = 'rg-network-hub'
param dnsSubscriptionId = '<hub-subscription-id>'

// Post-deployment: Configure VNet peering to hub
```

**When to Use:**
- ✅ Defense-in-depth security (dual inspection)
- ✅ Isolated AI workloads from general traffic
- ✅ Separate cost centers/subscriptions
- ✅ Compliance requirements for network isolation

---

#### Network Setup Options

##### **Option 1: Create New Network (Greenfield)**

Citadel creates all networking components:

```bicep
param useExistingVnet = false
param vnetAddressPrefix = '10.170.0.0/24'
param apimSubnetPrefix = '10.170.0.0/26'
param privateEndpointSubnetPrefix = '10.170.0.64/26'
param functionAppSubnetPrefix = '10.170.0.128/26'

// Network access
param apimNetworkType = 'External'  // or 'Internal' for production
param apimV2UsePrivateEndpoint = true
param cosmosDbPublicAccess = 'Disabled'
param eventHubNetworkAccess = 'Enabled'  // Required during deployment of APIM v2 SKUs
```

**Includes:**
- ✅ Virtual Network with subnets
- ✅ Network Security Groups
- ✅ Private DNS Zones
- ✅ Private Endpoints for all services
- ✅ Route tables (needed for APIM Developer and Premium SKUs)

---

##### **Option 2: Bring Your Own Network (Brownfield)**

Integrate with existing enterprise network:

```bicep
param useExistingVnet = true
param vnetName = 'vnet-hub-prod-eastus'
param existingVnetRG = 'rg-network-prod'

// Subnet names (must exist)
param apimSubnetName = 'snet-citadel-apim'
param privateEndpointSubnetName = 'snet-citadel-pe'
param functionAppSubnetName = 'snet-citadel-functions'

// DNS configuration
param dnsZoneRG = 'rg-network-dns'
param dnsSubscriptionId = '00000000-0000-0000-0000-000000000000'
```

**Prerequisites:**
1. VNet with sufficient address space
2. Three subnets created:
   - APIM subnet: `/26` or larger (64 IPs)
   - Private endpoint subnet: `/26` or larger
   - Function App subnet: `/26` or larger
3. Private DNS zones created (or delegated)
4. NSG required rules configured for APIM subnet

**Required DNS Zones:**
- `privatelink.vaultcore.azure.com`
- `privatelink.monitor.azure.com`
- `privatelink.servicebus.windows.net`
- `privatelink.documents.azure.com`
- `privatelink.blob.core.windows.net`
- `privatelink.file.core.windows.net`
- `privatelink.table.core.windows.net`
- `privatelink.queue.core.windows.net`
- `privatelink.azure-api.net` (for APIM v2 SKUs)
- `privatelink.services.ai.azure.com` (for AI Foundry)
- `privatelink.openai.azure.com` (for AI Foundry)
- `privatelink.cognitiveservices.azure.com` (for AI Foundry)

**APIM Subnet Requirements:**

For **Developer/Premium SKU** (VNet injection):
```bash
# No special delegation required
# NSG must allow all required APIM management traffic
# must have required service endpoints enabled
# associated with APIM route table
```

For **StandardV2/PremiumV2 SKU** (Private Endpoint):
```bash
# Standard subnet configuration
# Private endpoint will be created
```

Detailed guide: [Bring Your Own Network](./network-approach.md)

---

### 5. Resiliency & Business Continuity

Resiliency is a **planning decision**, not a post-deploy afterthought — the topology and SKU you pick here determine what recovery objectives you can meet. Two complementary guides cover the two layers:

| Layer | What it protects | Guide |
|-------|------------------|-------|
| **Backend resiliency** | Keeping LLM traffic flowing when a *backend* throttles or fails — circuit breaking, session affinity, automated failover, structured error handling. | [Resiliency Guide](./resiliency-guide.md) |
| **Hub business continuity** | Keeping the *gateway itself* available when a service, zone, or whole region fails — multi-region topologies, global routing, Cosmos DB multi-write. | [BC/DR Guide](./business-continuity-dr-guide.md) |

> **Golden rule:** a resilient gateway in front of a fragile backend still fails, and a resilient backend behind a single-region gateway is unreachable when that region goes down. **Plan both.**

**Decisions to lock in now (they influence SKU, region, and network choices above):**

- [ ] **BC/DR topology** — single-region + zone redundancy, multiple full deployments (recommended, works on StandardV2+), or APIM Premium multi-region. See [Deployment topologies](./business-continuity-dr-guide.md#3-deployment-topologies).
- [ ] **RTO / RPO / RLO targets** per use case (drives topology). See [Planning your BC/DR strategy](./business-continuity-dr-guide.md#2-planning-your-bcdr-strategy).
- [ ] **Global usage consolidation** — if going multi-region, plan Cosmos DB multi-write via [`citadel-cosmos-global-multi-master-sync`](../bicep/infra/citadel-cosmos-global-multi-master-sync/README.md) (configured post-deployment).

> Circuit breaker, session affinity, and failover defaults are applied automatically during **backend onboarding** (a post-deployment step) — you tune them there. See the [Post-Deployment Guide](./post-deployment-guide.md).

---

### 6. AI Model Deployment (Optional)

#### Microsoft Foundry Configuration

AI Citadel always deploys at least **one Microsoft Foundry resource** — the **primary** Foundry (the first entry in `aiFoundryInstances`). This primary Foundry is mandatory because the AI Citadel Gateway re-uses its **AI Services unified endpoint** (`https://<foundry>.cognitiveservices.azure.com/`) to power:

- **Content Safety** policies (`llm-content-safety` / `content-safety-backend` in APIM)
- **PII detection / anonymization** policies (`piiServiceUrl` named value in APIM)

Additional entries can be added to deploy **extra Foundry resources in different regions** for added LLM capacity, geo-redundancy, or access to region-restricted models. The primary Foundry can also host LLM deployments alongside the additional ones — there is no separation between "core capability" and "LLM" Foundry roles.

> **Note:** The previous standalone Azure Language Service and Azure AI Content Safety resources are no longer provisioned. Their capabilities are consumed directly from the primary Foundry account (AI Services kind), removing two private endpoints and simplifying RBAC and DNS configuration.

Input parameters are separated into two parts:

##### Foundry instances deployment

```bicep
// AI Foundry instances configuration array
param aiFoundryInstances = [
  {
    name: readEnvironmentVariable('AI_FOUNDRY_RESOURCE_NAME', '')
    location: readEnvironmentVariable('AZURE_LOCATION', 'swedencentral')
    customSubDomainName: ''
    defaultProjectName: 'citadel-governance-project'
  }
  {
    name: readEnvironmentVariable('AI_FOUNDRY_RESOURCE_NAME', '')
    location: 'eastus2'
    customSubDomainName: ''
    defaultProjectName: 'citadel-governance-project'
  }
]
```

The above, creates two Foundry instances in `swedencentral` and `eastus2` regions as examples.

This allows you to deploy models in multiple regions for geo-redundancy, added capacity or accessing restricted regional models.

###### Foundry model deployments

```bicep
// AI Foundry model deployments configuration
param aiFoundryModelsConfig = [
  {
    name: 'gpt-4o-mini'
    publisher: 'OpenAI'
    version: '2024-07-18'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 0 // First instance in aiFoundryInstances array
  }
  {
    name: 'gpt-4o'
    publisher: 'OpenAI'
    version: '2024-11-20'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 0
  }
  {
    name: 'DeepSeek-R1'
    publisher: 'DeepSeek'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 1
    aiserviceIndex: 0
  }
  {
    name: 'Phi-4'
    publisher: 'Microsoft'
    version: '3'
    sku: 'GlobalStandard'
    capacity: 1
    aiserviceIndex: 0
  }
  {
    name: 'text-embedding-3-large'
    publisher: 'OpenAI'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 0
  }
  {
    name: 'gpt-5'
    publisher: 'OpenAI'
    version: '2025-08-07'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 1 // Second instance in aiFoundryInstances array
  }
  {
    name: 'DeepSeek-R1'
    publisher: 'DeepSeek'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 1
    aiserviceIndex: 1
  }
  {
    name: 'text-embedding-3-large'
    publisher: 'OpenAI'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 1
  }
]
```

>NOTE: Ensure that your target subscription has sufficient quota for the selected models.

##### Disable Microsoft Foundry Model deployment

If you are planning to leverage existing model deployments or you are planning to provision the LLMs separately, you can skip model deployment during Citadel provisioning. 

```bicep
param aiFoundryModelsConfig = [] // No models will be deployed as part of AI Citadel primary deployment
```

---

### 7. Log Analytics Strategy

#### Option 1: Create New Log Analytics Workspace

**Recommended for:** Isolated environments, proof-of-concept, dedicated subscriptions

```bicep
param useExistingLogAnalytics = false
param logAnalyticsName = ''  // Auto-generated if empty or supply a compliant name.
```

**Benefits:**
- ✅ Isolated logs per environment
- ✅ Independent retention policies
- ✅ Simplified RBAC
- ✅ Environment-specific dashboards

**Typical Setup:**
```
┌────────────────┐  ┌────────────────┐  ┌─────────────────┐
│ LAW Dev        │  │ LAW Staging    │  │ LAW Prod        │
│ - 30d retention│  │ - 90d retention│  │ - 180d retention│
│ - Dev RBAC     │  │ - Ops RBAC     │  │ - Audit RBAC    │
└────────────────┘  └────────────────┘  └─────────────────┘
```

---

#### Option 2: Bring Your Own Log Analytics (Recommended for Enterprise)

**Recommended for:** Enterprise, multi-environment, centralized monitoring

```bicep
param useExistingLogAnalytics = true
param existingLogAnalyticsName = 'law-centralized-prod'
param existingLogAnalyticsRG = 'rg-monitoring-prod'
param existingLogAnalyticsSubscriptionId = '00000000-0000-0000-0000-000000000000'
```

>NOTE: Log Analytics can exists in a different subscription than the Citadel governance hub deployment subscription.

**Benefits:**
- ✅ Centralized logging across all environments
- ✅ Integration with central SIEM
- ✅ Cross-environment correlation
- ✅ Compliance and audit requirements

**Typical Setup:**
```
              ┌──────────────────────────┐
              │ Centralized LAW (Prod)   │
              │ - All environments       │
              │ - 180d retention         │
              │ - Advanced analytics     │
              └──────────────────────────┘
                            ▲
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────────┐         ┌────────┐        ┌────────┐
    │  Dev   │         │Staging │        │  Prod  │
    │ Citadel│         │Citadel │        │ Citadel│
    └────────┘         └────────┘        └────────┘
```

---

### 8. Inference API Diagnostic Logging

AI Citadel configures **per-API diagnostic logging** on every inference API (Universal LLM API and Azure OpenAI API). Two diagnostic channels are provisioned:

| Channel | Purpose | Default Destination |
|---------|---------|--------------------|
| **Azure Monitor** (`azuremonitor`) | LLM-aware diagnostics sent to Log Analytics | Azure Monitor / Log Analytics |
| **Application Insights** (`applicationinsights`) | Request/response tracing with custom headers | Application Insights |

Both channels are fully configurable through the deployment parameter files.

#### Azure Monitor Log Settings (`azureMonitorLogSettings`)

Controls frontend/backend request and response header capture, body byte limits, and **LLM-specific** log settings (prompt/completion logging).

**Default values:**

```bicep
param azureMonitorLogSettings = {
  frontend: {
    request:  { headers: [], body: { bytes: 0 } }   // No frontend headers/body captured by default
    response: { headers: [], body: { bytes: 0 } }
  }
  backend: {
    request:  { headers: [], body: { bytes: 0 } }   // No backend headers/body captured by default
    response: { headers: [], body: { bytes: 0 } }
  }
  largeLanguageModel: {
    logs: 'enabled'                                  // LLM logging enabled
    requests:  { messages: 'all', maxSizeInBytes: 262144 }  // Capture all prompt messages (up to 256 KB)
    responses: { messages: 'all', maxSizeInBytes: 262144 }  // Capture all completion messages (up to 256 KB)
  }
}
```

| Property | Default | Description |
|----------|---------|-------------|
| `frontend.request.headers` | `[]` | HTTP headers to capture from the client request |
| `frontend.request.body.bytes` | `0` | Max bytes of client request body to log (`0` = none) |
| `frontend.response.headers` | `[]` | HTTP headers to capture from the response to client |
| `frontend.response.body.bytes` | `0` | Max bytes of response body to log (`0` = none) |
| `backend.request.headers` | `[]` | HTTP headers to capture from the backend request |
| `backend.request.body.bytes` | `0` | Max bytes of backend request body to log (`0` = none) |
| `backend.response.headers` | `[]` | HTTP headers to capture from backend response |
| `backend.response.body.bytes` | `0` | Max bytes of backend response body to log (`0` = none) |
| `largeLanguageModel.logs` | `'enabled'` | Enable or disable LLM-specific logging (`'enabled'` / `'disabled'`) |
| `largeLanguageModel.requests.messages` | `'all'` | Which prompt messages to capture (`'all'` / `'none'`) |
| `largeLanguageModel.requests.maxSizeInBytes` | `262144` | Maximum prompt payload size in bytes (256 KB) |
| `largeLanguageModel.responses.messages` | `'all'` | Which completion messages to capture (`'all'` / `'none'`) |
| `largeLanguageModel.responses.maxSizeInBytes` | `262144` | Maximum completion payload size in bytes (256 KB) |

**Example — Production with header capture and reduced LLM payload:**
```bicep
param azureMonitorLogSettings = {
  frontend: {
    request:  { headers: [ 'Content-type', 'User-agent' ], body: { bytes: 0 } }
    response: { headers: [ 'x-ms-region' ], body: { bytes: 0 } }
  }
  backend: {
    request:  { headers: [ 'Content-type' ], body: { bytes: 8192 } }
    response: { headers: [ 'x-ratelimit-remaining-tokens', 'x-ratelimit-remaining-requests' ], body: { bytes: 8192 } }
  }
  largeLanguageModel: {
    logs: 'enabled'
    requests:  { messages: 'all', maxSizeInBytes: 131072 }  // 128 KB limit
    responses: { messages: 'all', maxSizeInBytes: 131072 }
  }
}
```

**Example — Disable LLM prompt/completion logging (privacy-sensitive environments):**
```bicep
param azureMonitorLogSettings = {
  frontend: {
    request:  { headers: [], body: { bytes: 0 } }
    response: { headers: [], body: { bytes: 0 } }
  }
  backend: {
    request:  { headers: [], body: { bytes: 0 } }
    response: { headers: [], body: { bytes: 0 } }
  }
  largeLanguageModel: {
    logs: 'disabled'
    requests:  { messages: 'none', maxSizeInBytes: 0 }
    responses: { messages: 'none', maxSizeInBytes: 0 }
  }
}
```

---

#### Application Insights Log Settings (`appInsightsLogSettings`)

Controls which HTTP headers are captured and how many bytes of request/response body are logged to Application Insights for all inference APIs.

**Default values:**

```bicep
param appInsightsLogSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens', 'x-ratelimit-remaining-requests' ]
  body: { bytes: 0 }  // No body captured by default
}
```

| Property | Default | Description |
|----------|---------|-------------|
| `headers` | `[ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens', 'x-ratelimit-remaining-requests' ]` | HTTP headers captured in both frontend and backend request/response traces |
| `body.bytes` | `0` | Max bytes of request/response body to log (`0` = none) |

**Example — Capture up to 8 KB of body content:**
```bicep
param appInsightsLogSettings = {
  headers: [ 'Content-type', 'User-agent', 'x-ms-region', 'x-ratelimit-remaining-tokens', 'x-ratelimit-remaining-requests' ]
  body: { bytes: 8192 }
}
```

**Example — Minimal header capture for cost-sensitive environments:**
```bicep
param appInsightsLogSettings = {
  headers: [ 'Content-type' ]
  body: { bytes: 0 }
}
```

---

#### Recommended Settings by Environment

| Setting | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Azure Monitor LLM logs** | `'enabled'` | `'enabled'` | `'enabled'` (or `'disabled'` for PII-sensitive workloads) |
| **LLM messages capture** | `'all'` | `'all'` | `'all'` or `'none'` |
| **LLM max payload (bytes)** | `262144` (256 KB) | `262144` (256 KB) | `131072`–`262144` (128–256 KB) |
| **App Insights body bytes** | `8192` (8 KB) | `0` | `0` |
| **App Insights headers** | All 5 defaults | All 5 defaults | All 5 defaults |

> **Note:** Increasing body byte capture or LLM payload sizes will increase Log Analytics and Application Insights ingestion costs. For production environments, balance observability needs against cost and data-sensitivity requirements.

---

### 9. Security & Compliance

#### Entra ID Authentication

JWT-based authentication adds a security layer on top of subscription API keys. When enabled, the gateway validates JWT tokens from Microsoft Entra ID before forwarding requests to backends.

**Automatic Provisioning (Recommended):**

Set `entraAuth` to `true` and leave `entraClientId` empty. After deploying the landing zone, run the standalone Entra ID setup script which creates the app registration **and configures APIM directly** — no redeployment needed:

```bash
# 1. Deploy the gateway infrastructure (creates Key Vault, APIM, etc.)
azd up

# 2. Run Entra ID setup (creates app registration + configures APIM named values)
cd bicep/infra/entra-id-setup
pwsh ./setup.ps1

# Done! APIM is now JWT-ready. No redeployment needed.
```

The setup script automatically:
1. Creates an Entra ID App Registration with OAuth2 scopes and app roles
2. Creates a service principal
3. Generates a client secret and stores it in Key Vault as `ENTRA-APP-CLIENT-SECRET`
4. Configures APIM JWT named values directly: `JWT-TenantId`, `JWT-AppRegistrationId`, `JWT-Issuer`, `JWT-OpenIdConfigUrl`
5. Stores `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_AUDIENCE` as azd environment variables for future deployments

> **Prerequisite:** The deploying user must have `Application.ReadWrite.All` or the `Application Developer` role in Entra ID.

See [Entra ID Setup README](../bicep/infra/entra-id-setup/README.md) for full details.

```bicep
param entraAuth = true
// Leave these empty for auto-provisioning:
param entraTenantId = ''
param entraClientId = ''
param entraAudience = ''
```

**Manual Configuration (Bring Your Own App Registration):**

```bicep
param entraAuth = true
param entraTenantId = '00000000-0000-0000-0000-000000000000'
param entraClientId = '11111111-2222-3333-4444-555555555555'
param entraAudience = 'api://citadel-gateway'
```

**How JWT Authentication Works Across APIs:**

- JWT named values are deployed when `entraAuth=true`, supporting all APIs (Azure OpenAI, Universal LLM, Unified AI)
- API Key authentication is always required (subscription-based)
- JWT validation is optional per access contract — enable it per product by setting `jwtAuth.enabled: true` in the access contract JSON
- The `security-handler` policy fragment handles both API Key and JWT validation
- When a product requires JWT, clients must send both `api-key` and `Authorization: Bearer {token}` headers

**Access Contract JWT Integration:**

To require JWT authentication for a specific access contract, include the `jwtAuth` policy in the contract JSON:

```json
{
  "policies": {
    "jwtAuth": { "enabled": true },
    "modelAccess": { "enabled": true, "allowedModels": ["gpt-4o"] }
  }
}
```

**Acquiring a JWT Token (Client Credentials Flow):**

```http
POST https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={entra-app-client-id}
&client_secret={entra-app-client-secret}
&scope={audience}/.default
```

**Validation:** See the [JWT Access Contract Validation Notebook](../test/citadel-jwt-access-contract-tests.ipynb) for end-to-end testing.

Guide: [Entra ID Authentication](./entraid-auth-validation.md)

#### Network Security

All applicable network security settings are configurable through the parameters of the accelerator:

**Suggested Production Configuration:**
```bicep
// APIM Security
param apimNetworkType = 'Internal'  // No public access (applies to APIM Developer and Premium SKUs)
param apimV2UsePrivateEndpoint = true
param apimV2PublicNetworkAccess = false

// Service Network Access
param cosmosDbPublicAccess = 'Disabled'
param eventHubNetworkAccess = 'Disabled'  // Enable during deployment, disable after for APIM Standardv2 and PremiumV2 SKUs

...

```

---

## 🚀 Deployment Execution

It is recommended to leverage Azure Developer CLI (`azd`) for simplified deployments of both the infrastructure and application (Logic Apps workflows).

Based on the configured parameter files, you can deploy using either `az deployment sub create` or `azd up`.

### Using `az deployment sub create`:

**For Development:**
```bash
az deployment sub create \
  --location eastus \
  --template-file ./bicep/infra/main.bicep \
  --parameters ./bicep/infra/main.parameters.dev.bicepparam
```

**For Production:**
```bash
az deployment sub create \
  --location eastus \
  --template-file ./bicep/infra/main.bicep \
  --parameters ./bicep/infra/main.parameters.prod.bicepparam
```

**For Custom Environments:**
1. Copy `main.parameters.complete.bicepparam`
2. Rename to `main.parameters.<env>.bicepparam`
3. Customize values
4. Version control the file

>Note: Using `az deployment sub create` will only provision the infrastructure. You still will need to deploy the `Logic App` workflows separately after the infrastructure is ready.

### Using `azd up`:

This automatically picks up the `main.bicepparam` file. You can override specific parameters using environment variables or by modifying the `main.bicepparam` file directly.

```bash
# Authenticate to Azure
# append --tenant-id <your-tenant-id> if needed
azd auth login

# Initialize environment
azd env new ai-hub-citadel-dev-01

# Provision and deploy everything based on defaults
azd up
```

>NOTE: Using `azd up` will use the `main.bicepparam` file for parameter values. You can modify it or set environment variables to override specific parameters. This command provisions the infrastructure and deploys the Logic App workflows in one step.

### Existing Resource Group Deployment Execution

Use this path only when subscription-scoped deployment is not possible and the hub resource group already exists. Create your own resource-scope parameter file, such as `resources.parameters.dev.bicepparam` or `resources.parameters.prod.bicepparam`, with the values for that environment. This exception uses `resources.bicep` directly at resource group scope. It is not an `azd up` flow.

Replace `dev` in the example below with your environment name when needed.

```bash
# Preview the resource-group deployment
az deployment group what-if \
  --resource-group <existing-hub-resource-group> \
  --template-file ./bicep/infra/resources.bicep \
  --parameters ./bicep/infra/resources.parameters.dev.bicepparam

# Deploy infrastructure into the existing resource group
az deployment group create \
  --resource-group <existing-hub-resource-group> \
  --template-file ./bicep/infra/resources.bicep \
  --parameters ./bicep/infra/resources.parameters.dev.bicepparam
```

---

## ✅ Post-Deployment Validation

Confirm the landing zone provisioned correctly before moving on to configuration.

### Verify Resource Deployment

```bash
# List all resources in resource group
RG_NAME=$(az deployment sub show \
  --name <deployment-name> \
  --query properties.outputs.resourceGroupName.value -o tsv)

az resource list \
  --resource-group $RG_NAME \
  --output table

```

### Validate Governance Hub functionality

This repo includes a set of validation notebooks under the `/validation` folder:

- [llm-backend-onboarding-runner.ipynb](../validation/llm-backend-onboarding-runner.ipynb): Onboard existing LLM backends, configure routing, and validate connectivity.
- [citadel-access-contracts-tests.ipynb](../validation/citadel-access-contracts-tests.ipynb): Onbaord AI Agents and AI use cases into the gateway
- [citadel-agent-frameworks-tests.ipynb](../validation/citadel-agent-frameworks-tests.ipynb): Build/deploy 3 types of agents that uses the gateway's access contracts (Microsoft Agent Framework, Foundry Agent and LangChain agent)

---

## ➡️ Next Steps: Operate the Hub

The `main.bicep` deployment is the **initial implementation only**. All day-2 configuration — onboarding backends and use cases, enabling authentication, activating usage reporting, going multi-region, and upgrading the gateway to newer releases — is covered end-to-end in the:

### 👉 [Post-Deployment Guide](./post-deployment-guide.md)

At a glance, your next activities are:

| Activity | Guide / Module |
|----------|----------------|
| Onboard LLM backends & routing (**Backend Contract**) | [llm-backend-onboarding](../bicep/infra/llm-backend-onboarding/README.md) · [LLM Access Guide](./llm-access-guide.md) |
| Onboard use cases (**Access Contract**) | [citadel-access-contracts](../bicep/infra/citadel-access-contracts/README.md) |
| Enable Entra ID (JWT) authentication | [entra-id-setup](../bicep/infra/entra-id-setup/README.md) · [Entra ID Auth](./entraid-auth-validation.md) |
| Activate Power BI usage reporting | [Power BI Dashboard](./power-bi-dashboard.md) |
| Go multi-region (Cosmos DB multi-write) | [citadel-cosmos-global-multi-master-sync](../bicep/infra/citadel-cosmos-global-multi-master-sync/README.md) · [BC/DR Guide](./business-continuity-dr-guide.md) |
| Upgrade an existing gateway to a newer release | [APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md) · [Release Version Management](./release-version-management.md) |
| Enable PII detection / masking | [PII Masking](./pii-masking-apim.md) |
| Configure alerts & throttling events | [Throttling Events Handling](./throttling-events-handling.md) |

> **Keeping the repo current:** synchronize your local repository's `original` branch with the upstream accelerator, then open a Pull Request into your environment-specific branch to merge changes. To apply those changes to a *running* gateway, use the [APIM Gateway Upgrade](../bicep/infra/apim-gateway-upgrade/README.md) submodule rather than re-running `main.bicep` — see the [Post-Deployment Guide](./post-deployment-guide.md#6-upgrade-the-gateway-to-a-newer-release).

---

## 🚨 Troubleshooting

Visit the [Deployment Troubleshooting Guide](./#) for common issues and resolutions.

### Getting Help

- **GitHub Issues:** [Report a bug](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/issues)

---

**Congratulations! Your AI Citadel Governance Hub landing zone is deployed. Continue with the [Post-Deployment Guide](./post-deployment-guide.md) to onboard workloads and go live.** 🎉
