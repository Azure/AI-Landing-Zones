"use strict";

const quoteFields = ["additionalAgents", "buildVMs", "vpnGateways", "expressRouteGateways", "botServices",
  "workIQ", "fabricIQ", "webGrounding", "speech", "agent365", "defender", "entraLicenses", "purview", "networkWatcherGB"];

const deploymentOptions = [
  ["foundry-project", "foundryAccounts", "Foundry accounts", "deployAiFoundry"],
  ["foundry-project", "agentServices", "Agent Service setups", "deployAAfAgentSvc"],
  ["model", "chatDeployments", "Chat model deployments", "modelDeploymentList"],
  ["embeddings", "embeddingDeployments", "Embedding deployments", "modelDeploymentList"],
  ["search", "searchServices", "Application Search services", "deploySearchService"],
  ["backing-search", "backingSearchServices", "New backing Search services", "aiSearchResourceId"],
  ["storage", "storageAccounts", "Application Storage accounts", "deployStorageAccount"],
  ["backing-storage", "backingStorageAccounts", "New backing Storage accounts", "aiFoundryStorageAccountResourceId"],
  ["backing-cosmos", "backingCosmosAccounts", "New backing Cosmos accounts", "aiFoundryCosmosDBAccountResourceId"],
  ["foundry-vault", "backingVaults", "New backing Key Vaults", "keyVaultResourceId"],
  ["application-vault", "vaults", "Application Key Vaults", "deployKeyVault"],
  ["appconfig", "configurationStores", "App Configuration stores", "deployAppConfig"],
  ["registry", "containerRegistries", "Container Registries", "deployContainerRegistry"],
  ["aca-environment", "containerEnvironments", "Container Apps environments", "deployContainerEnv"],
  ["frontend-app", "frontendDeployments", "Container Apps deployment sets", "deployContainerApps / containerAppsList"],
  ["acr-build-pool", "buildPools", "Private build pools", "deployAcrTaskAgentPool"],
  ["firewall", "firewalls", "Local firewalls", "deployAzureFirewall"],
  ["jumpbox", "jumpboxes", "Jumpbox VMs", "deployJumpbox"],
  ["bastion", "bastions", "Bastion hosts", "deployBastion"],
  ["nat", "natGateways", "NAT Gateways", "deployNatGateway"],
  ["logs", "logWorkspaces", "New Log Analytics workspaces", "deployLogAnalytics"],
  ["insights", "insightsInstances", "New Application Insights resources", "deployAppInsights"],
  ["ampls", "privateMonitorScopes", "Private Monitor scopes", "enablePrivateLogAnalytics"],
  ["dns", "privateDnsDeployments", "New private DNS zone sets", "policyManagedPrivateDns / existingPrivateDnsZone*ResourceId"],
  ["nsg", "nsgDeployments", "NSG configuration sets", "deployNsgs"]
].map(([id, field, label, parameter]) => ({ id, field, label, parameter }));

window.architecture = {
  quoteFields, deploymentOptions,
  buildAllocatedHours: s => s.buildMode === "daily" ?
    s.buildDays * s.buildDeploymentsPerDay * s.buildMinutes / 60 : s.buildHours,
  included(s) {
    const foundry = s.foundryAccounts > 0;
    const agent = foundry && s.agentServices > 0;
    const environment = s.containerEnvironments > 0;
    const apps = environment && s.frontendDeployments > 0;
    const registry = s.containerRegistries > 0;
    const monitor = s.logWorkspaces > 0 && s.insightsInstances > 0 && s.privateMonitorScopes > 0;
    const included = {
      "foundry-project": foundry, "foundry-tools": foundry,
      model: foundry && s.chatDeployments > 0, embeddings: foundry && s.embeddingDeployments > 0,
      hosted: agent, "additional-agents": agent,
      search: s.searchServices > 0, "backing-search": agent && s.backingSearchServices > 0,
      storage: s.storageAccounts > 0, "backing-storage": agent && s.backingStorageAccounts > 0,
      "backing-cosmos": agent && s.backingCosmosAccounts > 0, "foundry-vault": agent && s.backingVaults > 0,
      "application-vault": s.vaults > 0, appconfig: s.configurationStores > 0,
      registry, "aca-environment": environment, compute: environment, "frontend-app": apps,
      appgateway: apps, "gateway-ip": apps,
      "extra-frontends": apps, "orchestrator-app": apps, "ingestion-app": apps,
      "acr-build-pool": registry && s.buildPools > 0,
      firewall: s.firewalls > 0, "firewall-policy": s.firewalls > 0,
      "firewall-ip": s.firewalls > 0, "firewall-management-ip": s.firewalls > 0,
      routes: s.firewalls > 0, jumpbox: s.jumpboxes > 0, "jumpbox-disk": s.jumpboxes > 0,
      bastion: s.jumpboxes > 0 && s.bastions > 0, "bastion-ip": s.jumpboxes > 0 && s.bastions > 0,
      nat: s.jumpboxes > 0 && s.natGateways > 0, "nat-ip": s.jumpboxes > 0 && s.natGateways > 0,
      logs: s.logWorkspaces > 0, insights: s.logWorkspaces > 0 && s.insightsInstances > 0,
      monitor: s.logWorkspaces > 0, ampls: monitor, dns: s.privateDnsDeployments > 0,
      nsg: s.nsgDeployments > 0 || (apps && s.appGateway > 0)
    };
    for (const [suffix, parent] of [
      ["foundry", "foundry-project"], ["foundry-storage", "backing-storage"],
      ["foundry-search", "backing-search"], ["foundry-cosmos", "backing-cosmos"],
      ["foundry-vault", "foundry-vault"], ["app-storage", "storage"], ["app-search", "search"],
      ["app-vault", "application-vault"], ["appconfig", "appconfig"], ["acr", "registry"],
      ["aca", "aca-environment"], ["monitor", "ampls"]
    ]) included[`pe-${suffix}`] = included[parent];
    included["private-data"] = Object.entries(included).some(([id, value]) => id.startsWith("pe-") && value) ||
      s.applicationCosmos > 0 || s.speech > 0 || (s.apimUnits > 0 && s.apimSku === "Standard v2");
    return included;
  },
  defaults: {
    ...Object.fromEntries(deploymentOptions.map(option => [option.field, 1])),
    ...Object.fromEntries(quoteFields.flatMap(field => [[`${field}MonthlyRate`, 0], [`${field}PriceSource`, ""]])),
    applicationCosmos: 0, cosmosMRU: 5, cosmosGB: 1, cosmosBackupGB: 1,
    backingCosmosMode: "manual", backingCosmosRU: 5000, backingCosmosGB: 10,
    backingBackupMode: "continuous30", backingBackupGB: 10,
    backingStorageGB: 10, vaultOperations: 1, embeddingMillions: 5,
    orchestratorApps: 0, ingestionApps: 0, extraFrontendApps: 0, additionalAgents: 0,
    dnsQueries: 1, endpointIngressGB: 50, endpointEgressGB: 50, natGB: 10, buildHours: 730,
    buildMode: "daily", buildDeploymentsPerDay: 1, buildDays: 30, buildMinutes: 40,
    vpnGateways: 0, expressRouteGateways: 0, buildVMs: 0,
    botServices: 0, workIQ: 0, fabricIQ: 0, webGrounding: 0, speech: 0,
    agent365: 0, defender: 0, entraLicenses: 0, purview: 0,
    networkWatcherGB: 0, workloadPolicies: 0
  },

  resources(s, { priced, bill, find, publishedPrice, input, select, number, escape, MissingPrice }) {
    const rows = [];
    const included = window.architecture.included(s);
    const buildHours = window.architecture.buildAllocatedHours(s);
    const dnsZones = 8 + Number(included["aca-environment"]) + Number(included.registry) + (included.ampls ? 5 : 0);
    function add(resource, count, calculate) {
      const { field, unit = "resources", settings = "", detail = "", ...metadata } = resource;
      const quoteField = quoteFields.includes(field) ? field : metadata.id === "network-watcher" ? "networkWatcherGB" : null;
      const source = quoteField ? s[`${quoteField}PriceSource`].trim() : "";
      const monthlyRate = quoteField ? s[`${quoteField}MonthlyRate`] : 0;
      const quoteControls = quoteField ? input(`${quoteField}MonthlyRate`, "Monthly USD / unit (0 only if already covered)", 0, 10000000, .01) +
        `<label>Price source, date and billing scope<input type="text" maxlength="300" data-field="${quoteField}PriceSource" value="${escape(s[`${quoteField}PriceSource`])}"></label>` +
        '<span class="setting-hint">Use the monthly price for your selected plan and billing unit. Add a source before including this option. Enter 0 only when that source confirms no incremental charge.</span>' : "";
      const optional = field ? window.architecture.defaults[field] === 0 : count === 0;
      const entry = {
        ...metadata,
        tag: metadata.tag || (optional ? "Optional / default: 0" : "Isolated reference"),
        optional, included: count > 0,
        setting: `<span class="setting-static">${metadata.sku || "Architecture inventory"}</span>` + settings + quoteControls,
        quantity: field ? input(field, `${unit} (0 = not included)`, 0, 100, 1, !!quoteField && !source) : `${number(count)} ${unit}`,
        detail: `${detail} Quantities describe a fresh isolated standalone estimate without resource reuse. They do not discover, deploy or delete Azure resources.`,
        lines: []
      };
      if (quoteField) {
        const quantity = field ? count : s[quoteField];
        if (quantity > 0 && !source) {
          rows.push({ ...entry, amount: null, issue: `Enter the price source and billing scope for ${entry.name}.`, quoteRequired: true });
        } else if (source) {
          const meter = { retailPrice: monthlyRate, meterName: "Your plan's monthly unit price", unitOfMeasure: "unit-month",
            productName: entry.name, skuName: metadata.sku, armRegionName: s.region, currencyCode: "USD",
            type: "OperatorEstimate", tierMinimumUnits: 0 };
          rows.push({ ...entry, operatorEstimate: true, estimateSource: source,
            lines: [{ meter, quantity, description: field ? `${unit} x monthly unit price` : "Monthly flow-log units",
              kind: "usage", amount: monthlyRate * quantity, operatorEstimate: true }], amount: monthlyRate * quantity });
        } else {
          rows.push({ ...entry, amount: 0, quoteRequired: true });
        }
      } else if (calculate) {
        rows.push(priced(entry, calculate));
      } else if (metadata.billingNote) {
        rows.push({ ...entry, amount: 0 });
      } else {
        rows.push({
          ...entry, amount: count === 0 ? 0 : null,
          issue: "A positive quantity needs a validated billing source before inclusion."
        });
      }
    }

    add({
      id: "foundry-project", group: "foundry", name: "Foundry resource & project",
      sku: "Foundry / Agent Service standard setup", unit: "resource + project",
      description: "Private Foundry account and project that own models, hosted agents and connections.",
      sizing: "<strong>Plan quota, project boundaries and private access.</strong> Project count is not hosted compute or model capacity.",
      detail: "Includes the Foundry Agent Service control-plane configuration and capability host. Runtime compute, model usage and backing resources have their own rows.",
      billingNote: "No separate project allocation added. Runtime and service usage are separate.",
      parameter: "infra/main.bicep: aiFoundry; deployAfProject; deployAAfAgentSvc"
    }, 1);
    add({
      id: "foundry-tools", group: "foundry", name: "Foundry Tools, connections & evaluations",
      sku: "Project configuration", unit: "configuration set",
      description: "Connects tools and knowledge to agents and supports evaluation workflows.",
      sizing: "<strong>Budget each tool and evaluation execution.</strong> Evaluation traffic adds model tokens and telemetry, not another project allocation.",
      billingNote: "Configuration is represented here. Executed tools, evaluations and models are not free.",
      parameter: "infra/main.bicep: aiFoundryConnectionSearch, aiFoundryConnectionStorage, aiFoundryConnectionInsights"
    }, 1);
    add({
      id: "additional-agents", group: "foundry", name: "Additional hosted agents",
      field: "additionalAgents", unit: "Additional agents", sku: "Runtime-dependent",
      description: "Additional agent runtimes beyond the default hosted orchestrator.",
      sizing: "<strong>Size each agent's CPU, memory, concurrency and tools.</strong> Do not assume one agent is one Container App or that extra agents share free compute.",
      parameter: "Separately defined and deployed hosted agents"
    }, s.additionalAgents);
    add({
      id: "embeddings", group: "foundry", name: "Embedding model",
      sku: "text-embedding-3-large / Standard", unit: "model deployment",
      description: "Creates document and query vectors. Separate from chat-model token usage.",
      settings: input("embeddingMillions", "Recurring embedding tokens (millions)", 0, 1000000, 0.1),
      sizing: "<strong>Measure extracted tokens, chunk overlap and refresh volume.</strong> Initial ingestion and monthly refresh are separate events.",
      detail: "5M recurring tokens and 50M initial-ingestion tokens are hypothetical. This row estimates recurring tokens only. Initial-ingestion spend must be budgeted separately. Shipped deployment capacity is 100, not a token allowance.",
      parameter: "main.parameters.json: modelDeploymentList[text-embedding]"
    }, 1, () => [
      bill(find("embedding", "text-embedding-3-large-regional", "text-embedding-3-large-regional Tokens", "1K", 0, s, "Azure OpenAI"),
        s.embeddingMillions * 1000, "usage", "Recurring embedding tokens / 1K")
    ]);

    add({
      id: "knowledge-base", group: "knowledge", name: "Foundry IQ knowledge base & Search index",
      sku: "Native Foundry IQ / free retrieval plan", unit: "knowledge base",
      description: "References the application Search service, index, sources and native ingestion.",
      sizing: "<strong>Size chunks, vectors, indexing and retrieval requests.</strong> Source bytes alone do not predict vector storage or retrieval cost.",
      billingNote: "No second Search allocation. Model, extraction and retrieval usage are additional.",
      detail: "The root defaults to the free knowledge-retrieval billing plan. Quotas and supported features still apply. Semantic/agentic usage and optional extraction are not priced in this sample.",
      parameter: "main.parameters.json: retrievalBackend, foundryIqKnowledgeRetrievalBillingPlan, knowledgeBaseName"
    }, 1);
    for (const [field, name, description] of [
      ["workIQ", "Work IQ knowledge integration", "Optional Microsoft 365 knowledge source accessed through configured tools."],
      ["fabricIQ", "Fabric IQ knowledge integration", "Optional Fabric-backed knowledge source, not a second application storage account."],
      ["webGrounding", "Web / Grounding with Bing", "Optional external web-grounding tool and associated account."]
    ]) {
      add({
        id: field, group: "knowledge", name, description, field, unit: "Integrations", sku: "Separately configured",
        sizing: "<strong>Size source requests and connector limits.</strong> Check permissions, licensing, data boundaries and per-tool usage rather than assigning a generic Azure instance price.",
        detail: "Shown because it is an architectural option. Microsoft 365, Fabric and web-provider billing can be outside this subscription and must not be hidden or counted twice.",
        parameter: field === "webGrounding" ? "main.parameters.json: deployGroundingWithBing=false" : "Architecture diagram: other knowledge sources, configured as needed"
      }, s[field]);
    }
    add({
      id: "backing-storage", group: "knowledge", name: "Foundry backing Storage Account",
      sku: "Standard_LRS / illustrative Hot usage", unit: "storage account",
      description: "Dedicated Agent Service backing storage, distinct from application document storage.",
      settings: input("backingStorageGB", "Backing storage GB / month", 0, 50000),
      sizing: "<strong>Measure agent artifacts, files and retention.</strong> Do not reuse the application's corpus size as measured backing storage.",
      detail: "Standard_LRS is sourced from the deployment. Hot storage and 10 GB are illustrative. This row prices base stored capacity only and caps the sample below the first 51,200 GB tier. Operations, retrieval, retained versions and transfer are excluded.",
      parameter: "main.parameters.json: aiFoundryStorageSku; infra/main.bicep: aiFoundryStorageAccount"
    }, 1, () => [bill(find("storage", "Hot LRS", "Hot LRS Data Stored", "1 GB/Month", 0, s),
      s.backingStorageGB, "usage", "Backing GB-month")]);
    add({
      id: "backing-cosmos", group: "knowledge", name: "Foundry backing Cosmos DB",
      sku: "NoSQL / service-owned data", unit: "Cosmos DB account",
      description: "Agent Service state. Not the optional application conversation/configuration database.",
      settings: select("backingCosmosMode", [["manual", "Manual provisioned throughput"], ["autoscale", "Autoscale, billed hourly RU/s"]], "Billing hypothesis") +
        input("backingCosmosRU", "Aggregate billable RU/s across distinct offers", 400, 1000000, 100) +
        input("backingCosmosGB", "Transactional data + indexes, GB-month", 0, 1000000) +
        select("backingBackupMode", [["continuous30", "Continuous 30 days (Bicep reference)"], ["periodic", "Periodic, included copies only"], ["continuous7", "Continuous 7 days"]], "Backup billing hypothesis") +
        input("backingBackupGB", "Backup data, GB-month", 0, 1000000),
      sizing: "<strong>Inspect the actual service-created databases and containers.</strong> Peak RU/s, hot partitions, 429s and retention determine capacity.",
      detail: "The fresh backing account is provisioned, not serverless. Microsoft documents three initial 1,000-RU/s containers and two more for Responses agents. The starting budget assumes five distinct manual 1,000-RU/s offers, 10 GB transactional storage and 10 GB backup, in one non-zone-redundant region. These are explicit billing hypotheses, not measured service-created settings or deployment guarantees. Sum each distinct offer once, not every container on a shared offer. For autoscale enter the average of billed hourly throughput, respecting each offer's 10% floor, not consumed RU or configured maximum alone. The 1.5x autoscale rate is applied once. Bicep inherits Continuous30Days from its pinned AVM. Terraform does not explicitly set that backup policy, so confirm the effective policy or select the included periodic-copy hypothesis. Continuous30Days backup is GB-month, not GB multiplied by retention days. Extra regions, manual-throughput zone surcharges, restores and excess periodic copies need separate scenarios.",
      parameter: "infra/modules/ai-foundry/foundry/modules/cosmosDb.bicep; infra/terraform/main.foundry.tf",
      sourceURL: "https://learn.microsoft.com/azure/foundry/agents/how-to/use-your-own-resources",
      sourceLabel: "Foundry service-created Cosmos containers and capacity"
    }, 1, () => {
      const autoscale = s.backingCosmosMode === "autoscale";
      const throughput = autoscale ?
        find("cosmos", "AP1", "AP1 100 RUs", "1/Hour", 0, s, "Azure Cosmos DB autoscale") :
        find("cosmos", "RUs", "100 RU/s", "1/Hour", 0, s, "Azure Cosmos DB");
      const lines = [
        bill(throughput, s.backingCosmosRU / 100 * s.hours, "fixed", autoscale ? "Billed autoscale 100-RU/s-hours" : "Provisioned 100-RU/s-hours"),
        bill(find("cosmos", "RUs", "Data Stored", "1 GB/Month", 0, s, "Azure Cosmos DB"), s.backingCosmosGB, "usage", "Backing GB-month")
      ];
      if (s.backingBackupMode === "continuous30") lines.push(
        bill(find("cosmos", "Backup", "Cont 30D Bckp Continuous Backup", "1 GB", 0, s, "Azure Cosmos DB - PITR"),
          s.backingBackupGB, "usage", "Continuous30Days backup GB-month"));
      return lines;
    });
    add({
      id: "application-cosmos", group: "knowledge", name: "Application Cosmos DB",
      field: "applicationCosmos", unit: "Database accounts", sku: "NoSQL / Serverless",
      description: "Optional application persistence, separate from the Foundry backing database.",
      settings: input("cosmosMRU", "Million RU / account / month", 0, 1000000, 0.1) +
        input("cosmosGB", "Stored GB / account", 0, 1000000) +
        input("cosmosBackupGB", "Continuous30Days backup GB-month / account", 0, 1000000),
      sizing: "<strong>Measure RU per operation, partition distribution and retention.</strong> Serverless consumed RU is not provisioned RU/s. Validate burst and storage limits.",
      detail: "DEPLOY_COSMOS_DB defaults to false. When enabled the account uses EnableServerless, no free tier, Session consistency and Continuous30Days backup. This what-if assumes 5M RU, 1 GB transactional storage and a separate 1 GB backup-data hypothesis per account, not measured usage. Continuous backup storage is priced per GB-month. Database/container configuration is part of the account. Restores, analytical storage and transfer require separate assumptions. Its private endpoint appears separately and follows this quantity.",
      parameter: "main.parameters.json: deployCosmosDb; infra/main.bicep: cosmosDBAccount, cosmosSqlDatabase"
    }, s.applicationCosmos, () => [
      bill(find("cosmos", "RUs", "1M RUs", "1M", 0, s, "Azure Cosmos DB serverless"), s.applicationCosmos * s.cosmosMRU, "usage", "Million consumed RU"),
      bill(find("cosmos", "RUs", "Data Stored", "1 GB/Month", 0, s, "Azure Cosmos DB"), s.applicationCosmos * s.cosmosGB, "usage", "Application GB-month"),
      bill(find("cosmos", "Backup", "Cont 30D Bckp Continuous Backup", "1 GB", 0, s, "Azure Cosmos DB - PITR"),
        s.applicationCosmos * s.cosmosBackupGB, "usage", "Application continuous backup GB-month")
    ]);

    for (const [id, name, source] of [
      ["foundry-vault", "Foundry backing Key Vault", "infra/modules/ai-foundry/foundry/modules/keyVault.bicep"],
      ["application-vault", "Application Key Vault", "main.parameters.json: deployKeyVault; infra/modules/application/key-vault.bicep"]
    ]) {
      add({
        id, group: "application", name, sku: "Standard", unit: "vault",
        description: "Secret and key boundary for its own resource group, with private access.",
        settings: input("vaultOperations", "10K secret operations / vault / month", 0, 1000000, 0.1),
        sizing: "<strong>Size request bursts and key types.</strong> Caching, startup bursts, throttling and certificate renewal matter more than user count.",
        detail: "The two vaults are distinct. Their operation-volume control is shared for this example and applies independently to each vault. This row estimates standard secret operations only. Premium/HSM keys, certificate issuance and rotation-specific operations are excluded.",
        parameter: source
      }, 1, () => [bill(find("vault", "Standard", "Operations", "10K", 0, s, "Key Vault"),
        s.vaultOperations, "usage", "10K secret operations")]);
    }
    add({
      id: "aca-environment", group: "application", name: "Container Apps Environment",
      sku: "Private / workload profiles", unit: "environment",
      description: "Shared hosting boundary for frontend and optional Container Apps.",
      sizing: "<strong>Plan subnet space, workload profiles and private ingress together.</strong> An environment is not one billed node per application.",
      detail: "The environment and its private endpoint are present in this isolated reference. Dedicated-node capacity and its plan-management meter are already in the Container Apps profile row. This row adds the service-specific Environment Private Endpoint hourly meter, distinct from the network private-endpoint allocation shown under Networking. Other environment-specific meters are not assumed included.",
      parameter: "main.parameters.json: deployContainerEnv; infra/modules/application/container-environment.bicep"
    }, 1, () => [bill(find("compute", "Environment", "Environment Private Endpoint", "1 Hour", 0, s), s.hours, "fixed", "Private environment hours")]);
    for (const [id, field, name, count, sku, detail] of [
      ["frontend-app", null, "Frontend Container App", 1, "main / 0.5 vCPU / 1 GiB", "One frontend remains in the composed hosted-no-panel application list. Min/max replicas default to 1."],
      ["extra-frontends", "extraFrontendApps", "Additional frontend Container Apps", s.extraFrontendApps, "main / illustrative 0.5 vCPU / 1 GiB each", "Additional frontend apps or copies are an architecture simulation, not a new root deployment flag."],
      ["orchestrator-app", "orchestratorApps", "Orchestrator Container App", s.orchestratorApps, "main / 0.5 vCPU / 1 GiB", "The default orchestrator is hosted in Foundry, so its Container App starts at 0. Replacing the hosted orchestrator requires a compatible topology change, not simply deploying a duplicate."],
      ["ingestion-app", "ingestionApps", "Ingestion Container App", s.ingestionApps, "main / 1 vCPU / 3 GiB", "Native Foundry IQ ingestion does not deploy this application worker by default. Enabling an application ingestion path requires compatible runtime/configuration changes."]
    ]) {
      add({
        id, field, group: "application", name, sku, unit: "Container Apps",
        description: "Visible application resource, accounted for in the shared dedicated workload profile.",
        sizing: "<strong>Size replicas, CPU and memory before increasing nodes.</strong> An extra app can fit an existing node. Adding it must not automatically bill a second full node.",
        detail: `${detail} Each included app is modelled with one replica. These requests feed the profile's fit warning. Shared-node costs are not added again here. Platform overhead and production headroom still need validation.`,
        billingNote: "Compute is counted in Container Apps profile, not charged again per app.",
        parameter: "main.parameters.json: containerAppsList; infra/main.bicep: containerApps; composed hosted-no-panel topology"
      }, count);
    }
    add({
      id: "acr-build-pool", group: "operations", name: "ACR Tasks private build agent pool",
      sku: "S1 / 1 agent while allocated", unit: "agent pool",
      description: "Runs private image builds inside the VNet. Different from a separately managed build VM.",
      settings: select("buildMode", [["daily", "Per-deployment schedule"], ["allocated", "Monthly allocated hours"]], "Allocation estimate") +
        (s.buildMode === "daily" ?
          input("buildDeploymentsPerDay", "Deployments / day", 0, 100) +
          input("buildDays", "Deployment days / month", 0, 31) +
          input("buildMinutes", "Allocated minutes / deployment, including startup and shutdown", 1, 1440) :
          input("buildHours", "Allocated pool hours, including idle / month", 0, 744, .01)) +
        `<span class="setting-hint">${number(buildHours)} allocated hours / included pool / month. ` +
        (s.buildMode === "daily" ? "Requires scaling to zero outside build windows. This planner does not automate that operation." :
          "Includes idle time. No automatic scale-to-zero is assumed.") + "</span>",
      sizing: "<strong>S1 has 2 vCPU and 3 GB per agent.</strong> Size tier for build memory/CPU, instance count for parallel jobs. All allocated time, including idle, is billable.",
      detail: "The isolated deployment creates an S1 pool with one Linux agent. The initial billing hypothesis is one deployment per day for 30 days, with 40 allocated minutes per deployment including startup, build and shutdown: 20 allocated hours/month. This is not a measured build duration or shipped scale-to-zero automation. The operator or pipeline must allocate the pool before builds and scale it to zero afterwards. If it remains allocated for 730 hours, budget all 730 hours instead. Cost = allocated hours x 3,600 x 2 vCPU x the published Dedicated agent pool allocation rate. At $0.0001/vCPU-second, 20 hours costs $14.40 and 730 hours costs $525.60. No shared-task free allowance is deducted. The feature is Preview and requires Premium ACR. Both offered regions are documented preview locations.",
      parameter: "main.parameters.json: deployAcrTaskAgentPool; infra/main.bicep: acrTaskAgentPoolTier, acrTaskAgentPoolCount"
    }, 1, () => [bill(publishedPrice("acrDedicatedPool", "allocation", s), buildHours * 3600 * 2,
      "fixed", "Allocated S1 vCPU-seconds, including idle")]);
    add({
      id: "build-vm", group: "operations", name: "Separate DevOps build agent VM",
      field: "buildVMs", unit: "Build VMs", sku: "OS / VM size to be selected",
      description: "Optional self-managed build agent shown in the architecture, separate from ACR Tasks.",
      sizing: "<strong>Choose build OS, CPU, memory, disk and concurrency.</strong> Do not reuse the Windows jumpbox as a Linux-image builder or assume it replaces the private pool.",
      detail: "The diagram marks this component as separately provisioned. Quantity 0 avoids charging for both an unused build VM and the default private pool. VM, OS licensing, disk and allocation hours must be selected before pricing.",
      parameter: "Architecture diagram: separately provisioned build agent VM"
    }, s.buildVMs);

    const endpoints = [
      ["foundry", "Foundry resource", 1], ["foundry-storage", "Foundry backing Storage", 1],
      ["foundry-search", "Foundry backing Search", 1], ["foundry-cosmos", "Foundry backing Cosmos DB", 1],
      ["foundry-vault", "Foundry backing Key Vault", 1], ["app-storage", "Application Blob storage", 1],
      ["app-search", "Application Search", 1], ["app-vault", "Application Key Vault", 1],
      ["appconfig", "App Configuration", 1], ["acr", "Container Registry", 1],
      ["aca", "Container Apps Environment", 1], ["monitor", "Azure Monitor private link scope", 1],
      ["app-cosmos", "Application Cosmos DB", s.applicationCosmos],
      ["apim", "API Management", s.apimUnits > 0 && s.apimSku === "Standard v2" ? 1 : 0],
      ["speech", "Speech service", s.speech]
    ];
    for (const [id, name, count] of endpoints) {
      add({
        id: `pe-${id}`, group: "networking", name: `${name} private endpoint`,
        sku: "Private Link", unit: "private endpoints",
        description: `Private connection for ${name}. Counts its endpoint, not one charge per private IP or DNS zone.`,
        sizing: "<strong>Count service/subresource connections.</strong> Validate DNS resolution, subnet addresses and processed data. Reuse does not make an allocated endpoint free.",
        detail: "The baseline has 12 independently identified private endpoints. Optional application Cosmos, Standard v2 APIM and Speech add linked endpoints when included. Premium v2 APIM is modelled with VNet injection instead. This row includes hourly endpoint allocation only. The API publishes the applicable commercial price under Global. Endpoint data-processing volume is priced once in its separate shared row, avoiding multiplication of the same traffic across all endpoints.",
        parameter: "infra/main.bicep: _peList, privateEndpointPrivateLinkScope; Foundry associated-resource modules"
      }, count, () => [bill(find("private", "Standard", "Standard Private Endpoint", "1 Hour", 0, s, "Virtual Network Private Link", "Global"), count * s.hours, "fixed", "Endpoint-hours")]);
    }
    add({
      id: "private-data", group: "networking", name: "Private Link data processing",
      sku: "Aggregate billed traffic", unit: "traffic estimate",
      description: "Total billable data across the listed private endpoints, not chat payload bytes alone.",
      settings: input("endpointIngressGB", "Aggregate ingress GB / month", 0, 1000000) +
        input("endpointEgressGB", "Aggregate egress GB / month", 0, 1000000),
      sizing: "<strong>Measure each chargeable traffic leg.</strong> Avoid counting 100 GB separately for every endpoint unless that is the actual measured usage.",
      detail: "50 GB ingress + 50 GB egress is an aggregate usage hypothesis across the listed endpoints, not per endpoint. Each direction has its own meter. Inputs are capped at the first 1,000,000 GB band per direction. Higher volume tiers need a separate graduated calculation. The published commercial rates are Global, not borrowed from another region.",
      parameter: "Azure Private Link billing; aggregate traffic across inventory"
    }, 1, () => [
      bill(find("private", "Standard", "Standard Data Processed - Ingress", "1 GB", 0, s, "Virtual Network Private Link", "Global"), s.endpointIngressGB, "usage", "Aggregate ingress GB"),
      bill(find("private", "Standard", "Standard Data Processed - Egress", "1 GB", 0, s, "Virtual Network Private Link", "Global"), s.endpointEgressGB, "usage", "Aggregate egress GB")
    ]);
    add({
      id: "dns", group: "networking", name: "Azure Private DNS zones",
      sku: `${dnsZones} zones / one VNet`, unit: "private DNS zones",
      description: "Private names for Foundry, application services and Azure Monitor dependencies.",
      settings: input("dnsQueries", "Private DNS queries (millions / month)", 0, 1000000, 0.1),
      sizing: "<strong>Count zones, links and queries separately.</strong> Reuse zones across matching services, not one zone per endpoint.",
      detail: "Fresh defaults create cognitive services, OpenAI, AI services, Search, Cosmos, Blob, Key Vault, App Configuration, Container Apps, ACR and five Monitor zones (Application Insights, Monitor, OMS, ODS and agentsvc). Shared Search/Blob/Cosmos zones are not duplicated for application and backing resources. This sample uses global commercial DNS zone/query rates, explicitly not another region's service price. Record-set overages and DNS Resolver are excluded.",
      parameter: "infra/main.bicep: _dnsZonesList"
    }, dnsZones, () => [
      bill(find("dns", "Private", "Private Zone", "1", 0, s, "Azure DNS", ""), dnsZones * s.hours / 730, "fixed", "Zone-months (hours / 730)"),
      bill(find("dns", "Private", "Private Queries", "1M", 0, s, "Azure DNS", ""), s.dnsQueries, "usage", "Million private DNS queries")
    ]);
    add({
      id: "network", group: "networking", name: "Virtual network & subnets",
      sku: "One VNet / isolated standalone", unit: "VNet",
      description: "Network boundary containing the agent, service, application and management subnets.",
      sizing: "<strong>Allocate IP headroom for scale and maintenance.</strong> A subnet reserves addresses but does not deploy the service named after it.",
      detail: "Default subnet inventory: agent, pe, application-pe, AzureBastion, AzureFirewall, AzureFirewallManagement, AppGateway, jumpbox, ACA environment, DevOps build agents, Power Platform and AI Gateway. GatewaySubnet is separately optional (initial 0). AppGateway and AI Gateway subnets can exist while their appliances remain at 0. Public gateway ingress does not disable private backend isolation.",
      billingNote: "No VNet/subnet allocation added. Gateways, endpoints, peering and transfer are separate.",
      parameter: "main.parameters.json: deploy*Subnet; infra/main.bicep: selectedSubnetDefinitions"
    }, 1);
    for (const [id, name, description, detail] of [
      ["nsg", "Network security groups", "Subnet traffic controls, including Bastion and AI Gateway boundaries.", "Exact NSG instances follow selected subnet definitions. App Gateway's NSG follows its optional gateway. They are configuration resources, not extra firewall instances."],
      ["routes", "Route table & UDRs", "Routes agent/application egress to the local firewall.", "Routes are not a second firewall allocation. Verify all service dependencies before changing default routes."],
      ["firewall-policy", "Firewall policy & management NIC", "Rules and the Basic firewall's management-network attachment.", "Policy, rule collections and management NIC are represented as firewall configuration, not separate VM or public-IP allocations. The public IPs are listed separately below."]
    ]) {
      add({
        id, name, description, group: "networking", sku: "Configuration", unit: "configuration set",
        sizing: "<strong>Size policy complexity and operational ownership.</strong> These controls do not replace billed packet-processing services.",
        detail, billingNote: "No separate base allocation added. Diagnostics and related network services are separate.",
        parameter: "infra/main.bicep; infra/modules/networking"
      }, 1);
    }
    const publicIPs = [
      ["firewall-ip", "Firewall data-plane public IP", 1],
      ["firewall-management-ip", "Firewall management public IP", s.firewall === "Basic" ? 1 : 0],
      ["bastion-ip", "Bastion public IP", 1], ["nat-ip", "NAT Gateway public IP", 1]
    ];
    for (const [id, name, count] of publicIPs) {
      add({
        id, name, group: "networking", sku: "Standard / Regional / static IPv4", unit: "public IPs",
        description: "Dedicated management or egress address, separate from the optional UI gateway IP.",
        sizing: "<strong>Count allocated addresses, not active requests.</strong> An idle service can retain a billable public IP.",
        detail: "Fresh Basic Firewall uses separate data-plane and management addresses. Bastion and NAT each have their own address. The optional WAF gateway address is already listed separately and is not included again here.",
        parameter: "infra/modules/networking: azure-firewall.bicep, bastion.bicep, nat-gateway.bicep"
      }, count, () => [bill(find("publicip", "Standard", "Standard IPv4 Static Public IP", "1 Hour", 0, s, "IP Addresses"),
        count * s.hours, "fixed", "Allocated public-IP-hours")]);
    }
    for (const [field, id, name, sku] of [
      ["vpnGateways", "vpn", "VPN Gateway", "VpnGw1 (illustrative)"],
      ["expressRouteGateways", "expressroute", "ExpressRoute Gateway", "Standard (illustrative)"]
    ]) {
      add({
        field, id, name, sku, group: "networking", unit: "Gateways",
        description: "Optional hybrid connectivity inside the subscription, not enabled by merely reserving GatewaySubnet.",
        sizing: "<strong>Choose tunnel/circuit bandwidth, connections, resilience and routing.</strong> ExpressRoute also has circuit/provider charges outside a gateway-only estimate.",
        detail: "Both architectural alternatives are visible at 0. They require separate integration and a suitable GatewaySubnet. Availability-zone variants, circuits, transfer, VPN connections and provider charges must be validated.",
        parameter: "Architecture diagram: ExpressRoute / VPN Gateway; main.parameters.json: deployGatewaySubnet=false"
      }, s[field]);
    }

    add({
      id: "jumpbox", group: "operations", name: "Jumpbox VM",
      sku: "Windows / Standard_D2s_v3", unit: "VM",
      description: "Private administrative workstation for the isolated standalone deployment.",
      sizing: "<strong>Size operator tools and simultaneous sessions.</strong> Chat traffic is not its workload. Allocation hours, OS and disk are independent costs.",
      detail: "With isolation enabled, no existing-resource IDs and the legacy deployVM=true fallback, the fresh reference creates jumpbox, Bastion and NAT. Windows Server 2022 and Standard_D2s_v3 are sourced defaults. This row prices Windows PAYG compute only, not Azure Hybrid Benefit or the disk listed separately.",
      parameter: "main.parameters.json: vmSize, deployVM; infra/main.bicep: _deployJumpbox, testVm"
    }, 1, () => [bill(find("vm", "D2s v3", "D2s v3", "1 Hour", 0, s, "Virtual Machines DSv3 Series Windows"), s.hours, "fixed", "Windows VM-hours")]);
    add({
      id: "jumpbox-disk", group: "operations", name: "Jumpbox OS disk",
      sku: "Standard HDD LRS / 250 GiB request", unit: "OS disk",
      description: "Persistent administrative VM disk, charged independently from VM runtime.",
      sizing: "<strong>Check provisioned tier, IOPS and throughput.</strong> A requested 250 GiB disk is billed in its managed-disk size tier.",
      detail: "The template requests Standard_LRS, 250 GiB. S15 (256 GiB) is used for this tiered size estimate. Disk allocation persists if compute is deallocated. Transactions, snapshots and backups are excluded.",
      parameter: "infra/main.bicep: testVm.osDisk"
    }, 1, () => [bill(find("disk", "S15 LRS", "S15 LRS Disk", "1/Month", 0, s, "Standard HDD Managed Disks"), s.hours / 730, "fixed", "Disk-months (hours / 730)")]);
    add({
      id: "bastion", group: "operations", name: "Azure Bastion",
      sku: "Standard", unit: "Bastion host",
      description: "Administrative access to the private jumpbox, separate from end-user application ingress.",
      sizing: "<strong>Size concurrent administrative sessions and scale units.</strong> Standard is the sourced tier. Native-client tunneling is off initially.",
      detail: "Base host allocation is priced, with its public IP listed separately. Additional scale units, outbound transfer and session-recording storage are excluded.",
      parameter: "main.parameters.json: bastionSkuName; infra/main.bicep: _deployBastion"
    }, 1, () => [bill(find("bastion", "Standard", "Standard Gateway", "1 Hour", 0, s, "Azure Bastion"), s.hours, "fixed", "Bastion-hours")]);
    add({
      id: "nat", group: "operations", name: "NAT Gateway",
      sku: "Standard", unit: "NAT Gateway",
      description: "Outbound connectivity attached to the jumpbox subnet, not a replacement for workload firewall egress.",
      settings: input("natGB", "Processed GB / month", 0, 1000000),
      sizing: "<strong>Measure SNAT port demand and processed traffic.</strong> Monthly GB does not establish connection-rate capacity.",
      detail: "The fresh isolated jumpbox path creates its own Standard NAT Gateway. 10 GB/month is hypothetical. The API publishes the applicable commercial Standard rates under Global, not a regional fallback. Its public IP is priced separately. Transfer and additional addresses are excluded.",
      parameter: "infra/main.bicep: _deployNatGateway; infra/modules/networking/nat-gateway.bicep"
    }, 1, () => [
      bill(find("nat", "Standard", "Standard Gateway", "1 Hour", 0, s, "NAT Gateway", "Global"), s.hours, "fixed", "NAT gateway-hours"),
      bill(find("nat", "Standard", "Standard Data Processed", "1 GB", 0, s, "NAT Gateway", "Global"), s.natGB, "usage", "NAT processed GB")
    ]);
    add({
      id: "bot", group: "application", name: "Azure Bot Service",
      field: "botServices", sku: "Channel / message-dependent", unit: "Bot integrations",
      description: "Optional channel integration with Microsoft 365 or Teams, shown inside the subscription.",
      sizing: "<strong>Size channel messages and authentication flows.</strong> Bot registration is not hosted-agent compute. Standard and premium channel billing differs.",
      detail: "Separately provisioned in the diagram. No automatic channel deployment is implied. Channel messages, licenses and agent/model consumption must be budgeted independently.",
      parameter: "Architecture diagram: separately provisioned Bot Service"
    }, s.botServices);
    add({
      id: "speech", group: "foundry", name: "Azure AI Speech",
      field: "speech", sku: "S0", unit: "Speech accounts",
      description: "Optional speech capability supported by the deployment, beyond the pictured text path.",
      sizing: "<strong>Measure audio duration and concurrent streams.</strong> Speech recognition, synthesis and model tokens have different billing units.",
      parameter: "main.parameters.json: deploySpeechService=false, speechServiceSku=S0"
    }, s.speech);

    for (const [id, name, description, detail] of [
      ["insights", "Application Insights", "Application traces, requests and dependencies linked to the workspace.", "Workspace-based ingestion is counted once in Log Analytics. Availability tests, exports and other features are not included."],
      ["monitor", "Azure Monitor & diagnostic settings", "Resource diagnostics and operational monitoring configuration.", "Diagnostic settings route to the workspace. Separate metrics, alerts, tests, retention and exports can incur additional usage and are excluded."],
      ["ampls", "Azure Monitor private link scope", "Private observability connection for the workspace and Application Insights.", "The scope's network private endpoint is listed and priced separately under Networking. Five Monitor DNS zones are already included in the DNS inventory."]
    ]) {
      add({
        id, name, description, group: "observability", sku: "Shared workspace / private access", unit: "configuration set",
        sizing: "<strong>Size ingestion, retention and investigation coverage.</strong> Avoid duplicate ingestion charges for workspace-based Application Insights.",
        detail, billingNote: "Shared ingestion / connectivity is counted in its own rows. Other usage is excluded.",
        parameter: "main.parameters.json: deployAppInsights, deployLogAnalytics, enablePrivateLogAnalytics"
      }, 1);
    }
    add({
      id: "network-watcher", group: "observability", name: "Network Watcher",
      sku: "Optional diagnostic usage", unit: "regional service",
      description: "Network diagnostics shown in the architecture, with separately metered features.",
      settings: input("networkWatcherGB", "Optional flow-log GB / month", 0, 1000000),
      sizing: "<strong>Enable diagnostics intentionally and size retained flow data.</strong> A regional watcher is not a flat paid observability package.",
      detail: "No flow-log volume is assumed initially. Enter the monthly price per billed GB and a source identifying the selected diagnostic feature, processing, storage and retention scope before adding volume. Registration/base presence does not include unlimited free diagnostics.",
      billingNote: s.networkWatcherGB === 0 ? "No separately metered diagnostic usage selected." : undefined,
      parameter: "Architecture diagram: Network Watcher; separately configured diagnostics"
    }, 1);
    for (const [id, name, description] of [
      ["identities", "Managed identities & role assignments", "Foundry, project and application identities and least-privilege RBAC bindings."],
      ["policies", "Workload policy", "Policy assignments governing workload resources and compliance."],
      ["tags", "Resource tags", "Ownership, deployment mode and operational metadata on subscription resources."]
    ]) {
      add({
        id, name, description, group: "governance", sku: "Platform configuration", unit: "configuration sets",
        field: id === "policies" ? "workloadPolicies" : undefined,
        sizing: "<strong>Plan scope, ownership and least privilege.</strong> Configuration objects do not represent additional application servers.",
        detail: "The inventory represents a configuration set, not an asserted count of individual role assignments or principals. Workload policy sets start at 0 because the pictured governance policy is not established by this template as an automatically deployed assignment. Service-specific policy/assessment features can have separate charges.",
        billingNote: "No separate base allocation added. Paid governance/security features remain separate.",
        parameter: "infra/main.bicep: managed identities, role-assignment modules, deploymentTags; architecture governance"
      }, id === "policies" ? s.workloadPolicies : 1);
    }
    for (const [field, name, unit, description] of [
      ["agent365", "Agent 365", "Licensed agents / integrations", "Optional enterprise agent governance integration, separately provisioned."],
      ["defender", "Defender for Cloud", "Protected resource units", "Optional paid Defender plans. Quantity alone does not choose which resource-specific plans apply."],
      ["entraLicenses", "Entra ID additional licensing", "Additional licensed users", "Authentication uses the existing Entra tenant. Zero means no added paid licenses, not disabled authentication."],
      ["purview", "Microsoft Purview", "Governance integrations", "Optional data governance integration with feature-specific consumption or licensing."]
    ]) {
      add({
        id: field, field, name, unit, description, group: "governance", sku: "Plan / license-dependent",
        sizing: "<strong>Select the actual feature and billing scope first.</strong> Agent, user, protected-resource and data-processing units are not interchangeable.",
        detail: "These cross-cutting options are included in the architecture view, but some licensing is tenant-level or billed outside this subscription. Enter the monthly unit price and a source identifying the actual plan and billing scope before adding quantity. If an existing agreement covers the incremental cost, enter 0 and document that scope instead of charging the same license twice.",
        parameter: "Architecture diagram: cross-cutting security & governance, separately provisioned"
      }, s[field]);
    }
    return rows;
  }
};
