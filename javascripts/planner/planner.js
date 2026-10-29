"use strict";

(() => {
  const root = document.getElementById("agent-lz-planner");
  if (!root) return;
  const defaults = Object.freeze({
    ...window.architecture.defaults,
    ...window.scenarios.defaults,
    region: "eastus2", users: 100, turns: 10, days: 22,
    concurrency: 5, calls: 2, inputTokens: 3000, outputTokens: 500, hours: 730,
    model: "gpt-5-nano", searchSku: "Standard S1", searchReplicas: 1,
    searchPartitions: 1, backingReplicas: 1, backingPartitions: 1,
    storageTier: "Hot LRS", storageGB: 10, reads: 5, writes: 1,
    profile: "D4", nodes: 1, appconfig: "Standard",
    firewall: "Basic", firewallGB: 100, logsGB: 3, logAllowance: 0,
    appGateway: 0, gatewayCU: 1, apimUnits: 0, apimSku: "Standard v2"
  });
  let state = { ...defaults };
  let catalog;
  let latest;
  let referenceRows;
  let referenceState;
  let assessment;
  const groups = [
    ["foundry", "Foundry & models"],
    ["knowledge", "Knowledge & data"],
    ["application", "Application"],
    ["networking", "Networking & access"],
    ["operations", "Operations & build"],
    ["observability", "Observability"],
    ["governance", "Security & governance"]
  ];
  const money = value => new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 2 }).format(value);
  const number = value => new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(value);
  const rate = value => "$" + new Intl.NumberFormat("en-US", { maximumFractionDigits: 6 }).format(value);
  const escape = value => String(value).replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]));
  const byId = id => root.querySelector(`#${CSS.escape(id)}`);
  class MissingPrice extends Error {}

  function demand(s = state) {
    const turns = s.users * s.turns * s.days;
    const calls = turns * s.calls;
    return { turns, calls, input: calls * s.inputTokens, output: calls * s.outputTokens };
  }

  function records(service, s = state) {
    const data = catalog.data[s.region]?.[service];
    if (!data) throw new MissingPrice(`No ${service} catalog for ${s.region}.`);
    return data.items;
  }

  function find(service, sku, meter, unit, tier = 0, s = state, product, billingRegion = s.region) {
    const items = (service === "model" ? catalog.modelDiscovery.items : records(service, s))
      .filter(item => item.armRegionName === billingRegion && item.skuName === sku &&
        item.meterName === meter && item.unitOfMeasure === unit &&
        item.tierMinimumUnits === tier && item.type === "Consumption" &&
        item.currencyCode === "USD" && (!product || item.productName === product));
    if (items.length !== 1) {
      throw new MissingPrice(`${sku} / ${meter}: ${items.length ? "ambiguous" : "no matching"} regional price.`);
    }
    return items[0];
  }

  function select(field, options, label) {
    return `<label>${escape(label)}<select data-field="${field}">${options.map(option => {
      const [value, text] = Array.isArray(option) ? option : [option, option];
      return `<option value="${escape(value)}"${state[field] === value ? " selected" : ""}>${escape(text)}</option>`;
    }).join("")}</select></label>`;
  }

  function firewallSkus(region) {
    return ["Basic", "Standard", "Premium"].filter(sku => {
      try {
        find("firewall", sku, `${sku} Deployment`, "1 Hour", 0, { region });
        find("firewall", sku, `${sku} Data Processed`, "1 GB", 0, { region });
        return true;
      } catch (error) {
        if (!(error instanceof MissingPrice)) throw error;
        return false;
      }
    });
  }

  function referenceFor(region) {
    const skus = firewallSkus(region);
    if (!skus.length) throw new MissingPrice("No supported regional standalone Firewall price.");
    return { ...defaults, region, firewall: skus.includes(defaults.firewall) ? defaults.firewall : skus[0] };
  }

  function publishedPrice(key, column, s = state) {
    const source = catalog.publishedPrices?.[key];
    const value = source?.prices?.[s.region]?.[column];
    if (source?.sourceType !== "OfficialPricingPage" || !Number.isFinite(value) || value <= 0) {
      throw new MissingPrice(`The official published ${key}/${column} price is missing for ${s.region}.`);
    }
    return {
      retailPrice: value, sourceType: source.sourceType, sourceUrl: source.sourceUrl,
      sourceLabel: source.sourceLabel, retrievedAt: source.retrievedAt,
      unitOfMeasure: source.unit.replace(/^USD\//, ""), meterName: `${source.sourceLabel}: ${column}`,
      productName: source.sourceLabel, skuName: key, armRegionName: s.region,
      currencyCode: "USD", type: "PublishedPrice"
    };
  }

  function input(field, label, min = 0, max = 1000000, step = 1, disabled = false) {
    return `<label>${escape(label)}<input type="number" data-field="${field}" value="${state[field]}" min="${min}" max="${max}" step="${step}"${disabled ? " disabled" : ""}></label>`;
  }

  function bill(meter, quantity, kind, description) {
    return { meter, quantity, kind, description, amount: meter.retailPrice * quantity };
  }

  function priced(resource, calculate) {
    try {
      const lines = calculate();
      return { ...resource, lines, amount: lines.reduce((sum, line) => sum + line.amount, 0) };
    } catch (error) {
      if (!(error instanceof MissingPrice)) throw error;
      return { ...resource, lines: [], amount: resource.optional && !resource.included ? 0 : null, issue: error.message };
    }
  }

  function resources(s = state) {
    const d = demand(s);
    const rows = [];
    rows.push(priced({
      id: "model", group: "foundry", name: "Chat model", tag: s.model === defaults.model ? "Deployment default" : "What-if model",
      description: "Generates responses and supports assumed planning/retrieval calls.",
      setting: select("model", [["gpt-5-nano", "gpt-5-nano (default)"], ["gpt-4.1-nano", "gpt-4.1-nano (what-if)"]], "Global Standard") +
        '<span class="setting-hint">Quota capacity: 100 in the reference. Not a token budget.</span>',
      sizing: "<strong>Size quota for peak token and request rates.</strong> Monthly tokens estimate spend, not throughput. Model choice also needs quality and tool-use evaluation.",
      signal: "Concurrency alone cannot prove quota sufficiency.",
      quantity: `${number(d.input / 1e6)}M input<br>${number(d.output / 1e6)}M output / month`,
      detail: "The default is gpt-5-nano, version 2025-08-07, GlobalStandard, capacity 100. Its input/output rates are captured from Microsoft's exact GPT-5-nano Global pricing row, not substituted from another model. The same published Global rates apply in both offered regions. The alternative gpt-4.1-nano uses Global Retail API meters as a what-if, not a deployment recommendation. Two calls per turn and token volumes are hypothetical. Output tokens must include billable reasoning tokens. No cache-hit discount is assumed. The separate embedding row prices recurring ingestion. Retries, evaluations and extra tools need additional entered usage.",
      parameter: "main.parameters.json: modelDeploymentList"
    }, () => {
      if (s.model === defaults.model) return [
        bill(publishedPrice("gpt-5-nano", "input", s), d.input / 1e6, "usage", "Input tokens / million"),
        bill(publishedPrice("gpt-5-nano", "output", s), d.output / 1e6, "usage", "Output + reasoning tokens / million")
      ];
      return [
        bill(find("model", "gpt 4.1 nano Inp glbl", "gpt 4.1 nano Inp glbl Tokens", "1K", 0, s), d.input / 1000, "usage", "Input tokens / 1K"),
        bill(find("model", "gpt 4.1 nano Outp glbl", "gpt 4.1 nano Outp glbl Tokens", "1K", 0, s), d.output / 1000, "usage", "Output tokens / 1K")
      ];
    }));
    rows.push(priced({
      id: "hosted", group: "foundry", name: "Hosted agent runtime", tag: "Deployment default",
      description: "Runs the orchestrator. Separate from frontend Container Apps compute.",
      setting: '<span class="setting-static">2 vCPU / 4 GiB</span><span class="setting-hint">Foundry hosted agent</span>',
      sizing: "<strong>Measure concurrent turns, memory peaks and streaming latency.</strong> CPU alone does not capture slow tools or model throttling.",
      signal: "No validated concurrency capacity is asserted.",
      quantity: input("hostedHours", "Aggregate billed runtime hours / month", 0, 1000000, 0.1) +
        `<span class="setting-hint">${number(s.concurrency)} peak turns, not billed hours</span>`,
      detail: "The reference requests 2 CPU / 4Gi for the hosted orchestrator. This estimate uses captured Hosted vCPU Usage and Hosted Memory Usage rates, multiplied by aggregate billable runtime hours, 2 CPU and 4 GiB. The initial 200 runtime-hours is an editable cost hypothesis, not a deployment default or a conversion from users/concurrency. Include all billed allocation/session activity and idle overhead in that input. Resizing needs a compatible hosted-agent version. Container Apps nodes do not resize this runtime. Backing resources and extra session/storage features are separate.",
      parameter: "main.parameters.json: hostedAgent.runtime; pinned child hosted-agent/azure.yaml",
    }, () => [
      bill(find("hosted", "Hosted", "Hosted vCPU Usage", "1 Hour", 0, s, "Foundry Agents"), 2 * s.hostedHours, "usage", "Hosted vCPU-hours"),
      bill(find("hosted", "Hosted", "Hosted Memory Usage", "1 Hour", 0, s, "Foundry Agents"), 4 * s.hostedHours, "usage", "Hosted GiB-hours")
    ]));

    for (const backing of [false, true]) {
      const replicas = backing ? s.backingReplicas : s.searchReplicas;
      const partitions = backing ? s.backingPartitions : s.searchPartitions;
      const sku = backing ? "Standard S1" : s.searchSku;
      rows.push(priced({
        id: backing ? "backing-search" : "search", group: "knowledge",
        name: backing ? "Foundry backing Search" : "Application AI Search", tag: "Separate service",
        description: backing ? "Dedicated backing Search for Foundry Agent Service, not the application index." : "Indexes knowledge and serves the application's retrieval queries.",
        setting: (backing ? '<span class="setting-static">Standard S1</span>' : select("searchSku", ["Basic", "Standard S1", "Standard S2"], "Tier")) +
          '<span class="setting-hint">Default: S1, 1 replica, 1 partition. Changes require IaC edits.</span>',
        sizing: "<strong>Partitions: index and vector footprint.</strong> Replicas: query/indexing load and availability. Raw document size does not equal index size.",
        signal: replicas === 1 ? "One replica is the default, not a high-availability recommendation." : "Check the service SLA requirements and test peak query + indexing load.",
        quantity: input(backing ? "backingReplicas" : "searchReplicas", "Replicas (simulation)", 1, 12) +
          input(backing ? "backingPartitions" : "searchPartitions", "Partitions (simulation)", 1, 12),
        detail: `Monthly capacity = ${replicas} replicas x ${partitions} partitions x ${s.hours} hours. Both Search services start at Standard with one replica and one partition. SKU and counts are literals in the shipped Bicep, not root environment scaling parameters. Changes here are cost simulations, not validated deployable combinations. Availability requirements, vector/index limits, regional quota and query latency must be checked. Semantic ranker, agentic retrieval and native ingestion need separate usage assumptions. Model tokens are priced in their own rows.`,
        parameter: `infra/main.bicep: ${backing ? "Foundry Agent Service backing Search" : "searchService"}`
      }, () => [bill(find("search", sku, `${sku} Unit`, "1 Hour", 0, s), replicas * partitions * s.hours, "fixed", "Search units x hours")]));
    }

    rows.push(priced({
      id: "storage", group: "knowledge", name: "Application Blob storage", tag: "Capacity + operations",
      description: "Stores source documents and application blobs. Foundry backing storage is additional.",
      setting: select("storageTier", ["Hot LRS", "Cool LRS"], "Access tier / redundancy") +
        '<span class="setting-hint">Standard_LRS is shipped. Hot usage is an explicit assumption.</span>',
      sizing: "<strong>Size for corpus growth and operation rates.</strong> Hot fits frequent access. Cool trades storage price for access/retrieval costs and retention constraints.",
      signal: s.storageTier === "Cool LRS" ? "Cool retrieval and early-delete fees are not priced in this sample." : "10 GB corpus is hypothetical, not measured index or total platform storage.",
      quantity: input("storageGB", "Stored GB / month", 0, 1000000) +
        input("reads", "Read operations (10K units)", 0, 1000000, 0.1) +
        input("writes", "Write operations (10K units)", 0, 1000000, 0.1),
      detail: "Storage uses tiered GB-month prices plus read/write operation units. The example is 10,000 text documents / 10 GB, 50,000 reads and 10,000 writes per month. The separate embedding row includes 5M recurring tokens. Initial ingestion of 50M tokens is a separate one-time budget. Document bytes do not reliably predict tokens, chunks, vectors or index bytes. List operations, retained versions, extractions, Cool data retrieval, early deletion and transfer require separate usage assumptions. Changing access tier may require changes beyond a deployment parameter.",
      parameter: "main.parameters.json: deployStorageAccount; infra/main.bicep: storage account Standard_LRS"
    }, () => {
      const tier = s.storageTier.split(" ")[0];
      const tiers = records("storage", s).filter(r => r.skuName === s.storageTier &&
        r.meterName === `${s.storageTier} Data Stored` && r.unitOfMeasure === "1 GB/Month")
        .sort((a, b) => a.tierMinimumUnits - b.tierMinimumUnits);
      if (!tiers.length || tiers[0].tierMinimumUnits !== 0 ||
          new Set(tiers.map(r => r.tierMinimumUnits)).size !== tiers.length) {
        throw new MissingPrice("Missing or ambiguous storage capacity tiers.");
      }
      const storageLines = tiers.filter(r => r.tierMinimumUnits < s.storageGB || r.tierMinimumUnits === 0)
        .map(r => {
          const index = tiers.indexOf(r);
          const upper = tiers[index + 1]?.tierMinimumUnits ?? Infinity;
          return bill(r, Math.max(0, Math.min(s.storageGB, upper) - r.tierMinimumUnits), "usage", "GB-month in capacity tier");
        });
      return [...storageLines,
        bill(find("storage", s.storageTier, `${tier} Read Operations`, "10K", 0, s), s.reads, "usage", "10K read operations"),
        bill(find("storage", s.storageTier, `${s.storageTier} Write Operations`, "10K", 0, s), s.writes, "usage", "10K write operations")
      ];
    }));

    const cpus = s.profile === "D4" ? 4 : 8;
    const memory = cpus * 4;
    const appsIncluded = s.containerEnvironments > 0 && s.frontendDeployments > 0;
    const requestedCPU = appsIncluded ? 0.5 * (1 + s.extraFrontendApps + s.orchestratorApps) + s.ingestionApps : 0;
    const requestedMemory = appsIncluded ? 1 + s.extraFrontendApps + s.orchestratorApps + 3 * s.ingestionApps : 0;
    rows.push(priced({
      id: "compute", group: "application", name: "Container Apps profile", tag: "Allocated capacity",
      description: "Dedicated compute for the frontend, not the hosted orchestrator.",
      setting: select("profile", [["D4", "D4 / 4 vCPU, 16 GiB"], ["D8", "D8 / 8 vCPU, 32 GiB"]], "Dedicated workload profile") +
        '<span class="setting-hint">Shipped main profile: D4, min 0 / max 1 node. Frontend min/max: 1.</span>',
      sizing: "<strong>Size app replicas and the node pool together.</strong> Placement, CPU and memory determine node demand. Minimum app replicas can retain a billable node.",
      signal: appsIncluded && (requestedCPU >= s.nodes * cpus || requestedMemory >= s.nodes * memory) ?
        "App requests meet/exceed selected node capacity. Increase nodes/profile and reserve runtime headroom." :
        `${number(requestedCPU)} vCPU / ${number(requestedMemory)} GiB app requests before runtime overhead. More than one node requires raising the shipped maximum.`,
      quantity: input("nodes", "Allocated nodes (simulation)", 0, 100) + `<span class="setting-hint">${number(s.hours)} hours / node / month</span>`,
      detail: `Sample includes ${cpus} vCPU + ${memory} GiB per ${s.profile} node and the dedicated plan management meter when nodes are allocated. Formula: nodes x hours x (vCPU rate x CPU + memory rate x GiB), plus management hours. The example assumes continuous allocation because frontend minimum replicas may keep a node running. Nodes = 0 is an idle cost simulation, not compatible with an always-running frontend. Service availability, profile sizing and node limits need validation. Optional environment/endpoint, maintenance and other charges are excluded.`,
      parameter: "main.parameters.json: workloadProfiles, containerAppsList"
    }, () => [
      bill(find("compute", "Dedicated", "Dedicated vCPU Usage", "1 Hour", 0, s), s.nodes * cpus * s.hours, "fixed", "vCPU-hours"),
      bill(find("compute", "Dedicated", "Dedicated Memory Usage", "1 Hour", 0, s), s.nodes * memory * s.hours, "fixed", "GiB-hours"),
      bill(find("compute", "Dedicated", "Dedicated Plan Management", "1 Hour", 0, s), s.nodes > 0 ? s.hours : 0, "fixed", "Plan management hours")
    ]));
    rows.push(priced({
      id: "registry", group: "application", name: "Container Registry", tag: "Isolated reference",
      description: "Stores application images and supports the build/deploy flow.",
      setting: '<span class="setting-static">Premium</span>' +
        '<span class="setting-hint">Premium is fixed for private connectivity. Lower tiers are not offered.</span>',
      sizing: "<strong>Image storage, pulls and build concurrency matter.</strong> Private endpoints require Premium. Runtime replica count alone does not size the registry.",
      signal: "Premium is retained for private connectivity, not an optional cost upgrade.",
      quantity: `1 registry<br><span class="setting-hint">${number(s.hours / 24)} billed days / month</span>`,
      detail: "The isolated deployment uses Premium for private connectivity. Network isolation cannot be disabled in this planner, and the registry cannot be downgraded. This row prices base registry allocation. The dedicated ACR build pool is priced separately under Operations & build. Image storage beyond the Premium allowance, shared-task executions, additional replicas and transfer need additional usage assumptions.",
      parameter: "infra/main.bicep: containerRegistry.skuName"
    }, () => [bill(find("registry", "Premium", "Premium Registry Unit", "1/Day", 0, s), s.hours / 24, "fixed", "Registry-days")]));
    rows.push(priced({
      id: "appconfig", group: "application", name: "App Configuration", tag: "Deployment default",
      description: "Publishes runtime settings consumed by the application.",
      setting: select("appconfig", ["Standard", "Premium"], "Tier (what-if)") +
        '<span class="setting-hint">Shipped Standard is a literal in the module.</span>',
      sizing: "<strong>Check request bursts and refresh patterns.</strong> Restarts and many replicas can raise request rates. Cache appropriately without weakening configuration consistency.",
      signal: "Capacity selection is not based on end-user count alone.",
      quantity: `1 store<br><span class="setting-hint">${number(s.hours / 24)} billed days / month</span>`,
      detail: "The shipped App Configuration module declares Standard. Other choices require a reviewed IaC change. Sample prices only the base instance, not operations or snapshot overages, replica instances or multi-region failover.",
      parameter: "infra/modules/application/app-configuration-store.bicep: store.sku"
    }, () => [bill(find("appconfig", s.appconfig, `${s.appconfig} Instance`, "1/Day", 0, s), s.hours / 24, "fixed", "Store-days")]));

    const firewall = {
      id: "firewall", group: "networking", name: "Azure Firewall", tag: "Isolated standalone",
      description: "Controls outbound network traffic in an isolated standalone deployment.",
      setting: select("firewall", firewallSkus(s.region), "Firewall SKU") +
        `<span class="setting-hint">${firewallSkus(s.region).includes("Basic") ?
          "Shipped SKU: Basic when a local firewall is created." :
          "No standalone Basic price is published for this region. Standard is the regional cost reference, not the shipped Basic default. Change the IaC SKU before deploying this scenario."}</span>`,
      sizing: "<strong>Choose required security features first.</strong> Then validate peak throughput and connections. Monthly processed GB estimates usage charges, not throughput.",
      signal: s.firewall === "Basic" ? "Basic is not interchangeable with Standard DNS proxy or advanced features." : "Additional capacity-unit charges are not included.",
      quantity: input("firewallGB", "Processed GB / month", 0, 1000000) +
        `<span class="setting-hint">${number(s.hours)} allocated hours / month</span>`,
      detail: "Network isolation and a local firewall remain part of this standalone reference. Basic is a firewall SKU, not a non-isolated deployment mode. Only standalone regional SKUs with exact deployment and data-processing prices are offered. Sweden Central's published Basic secured-virtual-hub rate is not borrowed for this VNet topology. Where standalone Basic pricing is absent, the regional comparison explicitly uses Standard, which needs an AZURE_FIREWALL_SKU IaC change. Basic has management networking prerequisites. Public IP allocation and entered log ingestion are priced in separate rows. Extra Standard/Premium capacity units and transfer require additional assumptions.",
      parameter: "main.parameters.json: AZURE_FIREWALL_SKU; infra/main.bicep: _localFirewall"
    };
    rows.push(priced(firewall, () => [
        bill(find("firewall", s.firewall, `${s.firewall} Deployment`, "1 Hour", 0, s), s.hours, "fixed", "Firewall deployment hours"),
        bill(find("firewall", s.firewall, `${s.firewall} Data Processed`, "1 GB", 0, s), s.firewallGB, "usage", "Processed GB")
      ]));
    rows.push(priced({
      id: "appgateway", group: "networking", name: "Application Gateway + WAF",
      tag: "Optional / default: 0", optional: true, included: s.appGateway > 0,
      description: "Public HTTPS ingress for the UI, with private backends. Does not publish Foundry APIs.",
      setting: '<span class="setting-static">WAF_v2 / Prevention</span>' +
        '<span class="setting-hint">Runbook default: disabled. Autoscale: min 0 / max 2 instances.</span>',
      sizing: "<strong>Size for throughput, connections and WAF processing.</strong> Watch consumed capacity units and latency. Autoscale instance bounds are not billable capacity units.",
      signal: "A provisioned gateway has a fixed hourly charge, even with no traffic.",
      quantity: input("gatewayCU", "Average billed CUs / gateway", 0, 10000, 0.1),
      detail: "The public-ingress runbook uses WAF_v2, Prevention, OWASP CRS 3.2 and autoscale minCapacity 0 / maxCapacity 2. This fresh-deployment reference starts with publicIngress.enabled=false, so gateway and associated public IP quantities start at 0. When included, cost = hours x (fixed gateway rate + average billed capacity units x CU rate). The initial 1 CU is a hypothetical usage input, not a deployed setting or a conversion from autoscale instances. The Standard Regional static IPv4 public IP is priced separately below. WAF policy is part of this WAF_v2 design, not another gateway allocation. Dedicated subnet default: /27, with /24 recommended for growth. Live HTTPS needs a hostname, Key Vault certificate and explicit client CIDRs. Certificate operations, diagnostics, transfer and optional CAPTCHA are excluded. Setting quantity back to 0 only removes this simulated allocation. Setting publicIngress.enabled=false in an incremental deployment does not delete existing ingress resources.",
      parameter: "main.parameters.json: publicIngress.enabled; infra/modules/networking/public-ingress.bicep",
      sourceURL: "https://azure.github.io/AI-Landing-Zones/agent-landing-zone/application-gateway/",
      sourceLabel: "Application Gateway runbook"
    }, () => [
      bill(find("appgateway", "Standard", "Standard Fixed Cost", "1/Hour", 0, s, "Application Gateway WAF v2"),
        s.appGateway * s.hours, "fixed", "Gateway-hours"),
      bill(find("appgateway", "Standard", "Standard Capacity Units", "1/Hour", 0, s, "Application Gateway WAF v2"),
        s.appGateway * s.gatewayCU * s.hours, "usage", "Capacity-unit-hours")
    ]));
    rows.push(priced({
      id: "gateway-ip", group: "networking", name: "Gateway public IP",
      tag: "Linked to Application Gateway", optional: true, included: s.appGateway > 0,
      description: "Dedicated public frontend address for the optional UI gateway.",
      setting: '<span class="setting-static">Standard / Regional / IPv4</span><span class="setting-hint">Static allocation, following the runbook.</span>',
      sizing: "<strong>One address per included gateway.</strong> Quantity follows the gateway automatically. This address does not replace firewall, NAT or other public IPs.",
      signal: "The address is billed while allocated, not only while serving requests.",
      quantity: `${number(s.appGateway)} public IP${s.appGateway === 1 ? "" : "s"}<br><span class="setting-hint">Linked quantity, default: 0</span>`,
      detail: "The public-ingress module creates one Standard Regional static IPv4 public IP for its WAF_v2 gateway. Quantity follows the gateway selector to prevent omitting or double-counting this dependency. Hourly address allocation is priced separately from WAF_v2 fixed and capacity-unit charges. No DNS, data-transfer or other platform public IP costs are included in this row. Quantity 0 describes omission from this fresh estimate, not deletion of an existing address.",
      parameter: "infra/modules/networking/public-ingress.bicep: publicIp",
      sourceURL: "https://azure.github.io/AI-Landing-Zones/agent-landing-zone/application-gateway/",
      sourceLabel: "Application Gateway runbook"
    }, () => [
      bill(find("publicip", "Standard", "Standard IPv4 Static Public IP", "1 Hour", 0, s, "IP Addresses"),
        s.appGateway * s.hours, "fixed", "Allocated public-IP-hours")
    ]));
    rows.push(priced({
      id: "apim", group: "networking", name: "API Management / AI Gateway",
      tag: "Optional integration / default: 0", optional: true, included: s.apimUnits > 0,
      description: "Adds API policies, routing and governance in front of model or application APIs.",
      setting: select("apimSku", ["Standard v2", "Premium v2"], "Tier (integration what-if)") +
        '<span class="setting-hint">Separate integration, not automatically deployed here. Initial tier is illustrative.</span>',
      sizing: "<strong>Choose network isolation features, then test gateway CPU, memory and latency.</strong> Standard v2 supports private backends. Premium v2 also supports VNet injection.",
      signal: "Outbound integration alone does not close public ingress. Validate private endpoint / injection and public-access settings.",
      quantity: input("apimUnits", "Scale units, one instance (0 = none)", 0, 10) +
        '<span class="setting-hint">First unit + additional units, not separate APIM instances.</span>',
      detail: `Starts at 0 units because API Management is optional and separately integrated. The ${s.apimSku} selection is a pricing hypothesis, not a shipped APIM default. Base allocation = one first unit when included + max(0, units - 1) additional units, each multiplied by hours and its own meter rate. Units represent capacity within one APIM instance. A second independent instance would need its own first-unit allocation. This sample allows up to 10 units and does not infer a supported workload from the unit count. Standard v2 private ingress needs an inbound private endpoint and appropriate public-access settings in addition to outbound VNet integration. Premium v2 can instead use VNet injection. The platform AI Gateway subnet is not an APIM deployment. Private endpoints/DNS, request overages, workspaces, self-hosted gateways, model tokens, diagnostics and data transfer are excluded. This row estimates base capacity only, not the complete AI Gateway cost.`,
      parameter: "Separate AI Gateway integration; infra/main.bicep: AI Gateway subnet",
      sourceURL: "https://learn.microsoft.com/azure/api-management/v2-service-tiers-overview",
      sourceLabel: "API Management tiers and networking"
    }, () => [
      bill(find("apim", s.apimSku, `${s.apimSku} Unit`, "1 Hour", 0, s, "API Management"),
        s.apimUnits > 0 ? s.hours : 0, "fixed", "First-unit-hours"),
      bill(find("apim", s.apimSku, `${s.apimSku} Secondary Unit`, "1 Hour", 0, s, "API Management"),
        Math.max(0, s.apimUnits - 1) * s.hours, "fixed", "Additional-unit-hours")
    ]));
    rows.push(priced({
      id: "logs", group: "observability", name: "Log Analytics", tag: "Usage-based",
      description: "Stores application and resource telemetry used for operations.",
      setting: '<span class="setting-static">Analytics Logs / PAYG</span><span class="setting-hint">Gross ingestion rate before any shared free allowance.</span>',
      sizing: `<strong>${number(s.logsGB)} GB/month is about ${number(s.logsGB / (730 / 24))} GB/day.</strong> ${s.logsGB / (730 / 24) < 100 ? "Start with PAYG for this example." : "Compare commitment tiers against PAYG."} Commitments start at 100 GB/day. Analytics includes 31 retention days, longer retention costs extra.`,
      sourceURL: "https://learn.microsoft.com/azure/azure-monitor/logs/cost-logs",
      sourceLabel: "Log Analytics sizing and commitment tiers",
      signal: "Do not count Application Insights ingestion again when billed to this workspace.",
      quantity: input("logsGB", "Ingested GB / month", 0, 1000000, 0.1) +
        input("logAllowance", "Available free GB allocated here", 0, 5, 0.1),
      detail: "The API includes a zero-priced initial band and a paid rate. This sample conservatively assumes no account-wide allowance remains available unless you explicitly allocate up to 5 GB here. Cost = max(0, ingestion - allocated allowance) x paid rate. Do not reuse the same free allowance across workspaces. Extended retention, export, alerting, separate tests and other monitoring charges are not included.",
      parameter: "main.parameters.json: deployLogAnalytics; resource diagnostic settings"
    }, () => [bill(find("logs", "Analytics Logs", "Analytics Logs Data Ingestion", "1 GB", 5, s), Math.max(0, s.logsGB - s.logAllowance), "usage", "GB after allocated allowance")]));
    rows.push(...window.architecture.resources(s, { priced, bill, find, publishedPrice, input, select, number, escape, MissingPrice }));
    applyOperatorEstimates(rows, s, d);
    const included = window.architecture.included(s);
    for (const row of rows) {
      const options = window.architecture.deploymentOptions.filter(option => option.id === row.id);
      if (Object.hasOwn(included, row.id)) {
        row.scopeControlled = true;
        row.optional = true;
        row.included = included[row.id] && row.included !== false;
        if (!row.included) {
          row.amount = 0;
          row.lines = row.lines.map(line => ({ ...line, quantity: 0, amount: 0 }));
          row.quantity = `<fieldset disabled><legend>Retained inputs, not allocated in this scenario</legend>${row.quantity}</fieldset>`;
        }
      }
      if (options.length) {
        row.quantity = options.map(option => input(option.field, `${option.label} (0 = exclude from this estimate)`, 0, 1)).join("") +
          '<span class="setting-hint">Zero excludes new allocation and its linked costs. Existing or shared services are not free. Check feature and deployment dependencies before applying this scenario.</span>' + row.quantity;
        row.detail += ` Allocation controls: ${options.map(option => `${option.label}: ${option.parameter}`).join(", ")}. ` +
          "Zero is a fresh-budget scope choice, not deletion or deallocation of existing resources. Reuse IDs require a separately budgeted existing service. Bastion and NAT follow the jumpbox in this reference. Excluding a parent also excludes dependent allocations, while retaining their inputs.";
      }
    }
    return window.applySizingGuidance(rows, s);
  }

  function applyOperatorEstimates(rows, s, d) {
    if (!s.priceEvidence.trim()) return;
    const quotes = [
      ["model", s.modelInputRate > 0 && s.modelOutputRate > 0 ? [
        [s.modelInputRate, d.input / 1e6, "Input / million tokens"],
        [s.modelOutputRate, d.output / 1e6, "Output / million tokens"]
      ] : []],
      ["hosted", s.hostedMonthly > 0 ? [[s.hostedMonthly, 1, "Monthly runtime estimate"]] : []],
      ["acr-build-pool", s.buildMonthly > 0 ? [[s.buildMonthly, 1, "Monthly allocated-pool estimate"]] : []]
    ];
    for (const [id, values] of quotes) {
      if (!values.length) continue;
      const row = rows.find(r => r.id === id);
      row.lines = values.map(([retailPrice, quantity, description]) => ({
        meter: { retailPrice, meterName: description, unitOfMeasure: id === "model" ? "1M tokens" : "1 month",
          productName: "Operator estimate", skuName: id === "model" ? s.model : row.name, armRegionName: s.region,
          currencyCode: "USD", type: "OperatorEstimate", tierMinimumUnits: 0 },
        quantity, description, kind: id === "acr-build-pool" ? "fixed" : "usage",
        amount: retailPrice * quantity, operatorEstimate: true
      }));
      row.amount = row.lines.reduce((sum, line) => sum + line.amount, 0);
      row.operatorEstimate = true;
      row.estimateSource = s.priceEvidence;
      delete row.issue;
    }
  }

  function totals(rows) {
    return rows.flatMap(row => row.lines).reduce((sum, line) => {
      sum[line.kind] += line.amount;
      sum[line.operatorEstimate ? "operator" : "public"] += line.amount;
      sum.total += line.amount;
      return sum;
    }, { fixed: 0, usage: 0, operator: 0, public: 0, total: 0 });
  }

  function groupSummary(rows) {
    const active = rows.filter(row => !row.disabled && !(row.optional && !row.included));
    if (!active.length) return "Not allocated";
    if (active.every(row => row.amount === null)) return active.length === 1 ? "Cost to confirm" : "Costs to confirm";
    const suffix = active.some(row => row.amount === null) ? " / mo (partial)" : " / mo";
    return money(totals(rows).total) + suffix;
  }

  function rowHTML(row, expanded) {
    const optionField = { appgateway: "appGateway", apim: "apimUnits", "application-cosmos": "applicationCosmos" }[row.id];
    let preview = "";
    if (optionField && state[optionField] === 0) {
      const withOption = resources({ ...state, [optionField]: 1 });
      if (withOption.find(resource => resource.id === row.id).included !== false &&
          withOption.every(resource => resource.amount !== null)) {
        preview = `<p class="option-preview">One unit adds <strong>${money(totals(withOption).total - latest.sum.total)}/month</strong>, including linked resources. Change the quantity to include it.</p>`;
      }
    }
    const price = row.disabled ? '<span class="excluded">Not allocated</span>' :
      row.quoteRequired ? '<span class="setting-hint">Enter the monthly unit price for your plan.</span>' :
      row.issue ? '<span class="unpriced">Price to confirm</span>' :
      row.billingNote ? `<span class="setting-hint">${escape(row.billingNote)}</span>` :
      row.lines.map(line => `<span class="price-unit">${rate(line.meter.retailPrice)}<small>${escape(line.meter.meterName)}<br>/ ${escape(line.meter.unitOfMeasure)}</small></span>`).join("");
    const total = row.disabled ? '<span class="excluded">Not included</span>' :
      row.amount === null ? '<span class="unpriced">Not included in subtotal</span>' : `<span class="money">${money(row.amount)}</span>`;
    const meters = row.lines.map(line => {
      const meter = line.meter;
      if (line.operatorEstimate) return `<div class="meter"><strong>Operator estimate, not a public meter</strong><br>${number(line.quantity)} ${escape(line.description)} x ${rate(meter.retailPrice)} = ${money(line.amount)}<br>Source/date: ${escape(row.estimateSource)}<br>Applies to ${escape(state.region)}, selected model/runtime and workload assumptions. Not an independently verified quote.</div>`;
      if (meter.sourceType === "OfficialPricingPage") return `<div class="meter"><strong>${escape(meter.meterName)}</strong><br>${number(line.quantity)} ${escape(line.description)} x ${rate(meter.retailPrice)} = ${money(line.amount)}<br>Unit: ${escape(meter.unitOfMeasure)} | Captured: ${escape(meter.retrievedAt)} | Region: ${escape(meter.armRegionName)}<br>Official published pricing row, not a Retail API meter. <a href="${escape(meter.sourceUrl)}" target="_blank" rel="noopener">Inspect ${escape(meter.sourceLabel)} pricing &#8599;</a></div>`;
      const url = "https://prices.azure.com/api/retail/prices?$filter=" + encodeURIComponent(`meterId eq '${meter.meterId}' and armRegionName eq '${meter.armRegionName}' and priceType eq 'Consumption'`);
      return `<div class="meter"><strong>${escape(meter.meterName)}</strong><br>${number(line.quantity)} ${escape(line.description)} x ${rate(meter.retailPrice)} = ${money(line.amount)}<br>Product: ${escape(meter.productName)} | SKU: ${escape(meter.skuName)}<br>Meter: <code>${escape(meter.meterId)}</code> | Effective: ${escape(meter.effectiveStartDate)} | Captured: ${escape(meterCapturedAt(meter))} | Region: ${escape(meter.armRegionName || "Global commercial rate")} | Tier starts: ${number(meter.tierMinimumUnits)}<br><a href="${escape(url)}" target="_blank" rel="noopener">Inspect source meter query &#8599;</a></div>`;
    }).join("");
    const inclusion = row.scopeControlled ? row.included ? row.sku || "Included in this scenario" : "Not included in this scenario" :
      row.optional ? row.included ? "Optional, included" : "Optional, quantity 0" :
      row.billingNote ? "Configuration / shared billing" : row.sku || "Included in the starting architecture";
    const pricing = row.quoteRequired ? "Your plan's price" : row.amount === null ? "Price to confirm" : row.operatorEstimate ? "Operator estimate" :
      row.billingNote ? "Shared / configuration" : "Public rates";
    return `<details class="resource" id="entry-${row.id}" data-resource="${row.id}"${expanded.has(`entry-${row.id}`) ? " open" : ""}>
      <summary><span class="resource-identity"><span class="resource-name">${escape(row.name)}</span><small>${escape(inclusion)}${rowChanged(row) ? " / modified" : ""}</small></span><span class="resource-cost" data-row-total="${row.id}">${total}<small>/ month</small></span><span class="disclosure" aria-hidden="true">+</span></summary>
      <div class="resource-body"><p class="resource-description">${escape(row.description)}</p>
      <div class="resource-inputs"><div><h4>Configuration</h4>${row.setting}</div><div><h4>Quantity &amp; usage</h4>${preview}${row.quantity}</div></div>
      <div class="sizing-text"><h4>Sizing guidance</h4>${row.sizing}</div>${row.sizingURL || row.sourceURL ? `<a class="sizing-source" href="${escape(row.sizingURL || row.sourceURL)}" target="_blank" rel="noopener">Product guidance &#8599;</a>` : ""}<span class="sizing-alert">${row.signal || ""}</span>
      <details class="resource-sources" id="detail-${row.id}"${expanded.has(`detail-${row.id}`) ? " open" : ""}><summary>Price calculation, assumptions &amp; sources</summary><div class="detail-content">
      <p class="fine">${escape(pricing)}</p>${price}
      <p>${row.detail}</p><p><strong>Configuration source:</strong> <code>${escape(row.parameter)}</code></p>
      ${row.sourceURL ? `<p><a href="${escape(row.sourceURL)}" target="_blank" rel="noopener">${escape(row.sourceLabel)} &#8599;</a></p>` : ""}
      ${row.issue ? `<p class="unpriced">${escape(row.issue)} ${row.optional && !row.included ? "Not included at quantity 0. A regional price is needed before adding it to the estimate." : "Excluded from the sample subtotal, not assumed free."}</p>` : ""}
      ${meters}
    </div></details></div></details>`;
  }

  function render() {
    const open = new Set([...document.querySelectorAll("#capabilities details[open]")].map(element => element.id));
    const rows = resources();
    referenceState = referenceFor(state.region);
    referenceRows = resources(referenceState);
    assessment = window.scenarios.assess(state);
    const sum = totals(rows);
    latest = { rows, sum, demand: demand() };
    byId("capabilities").innerHTML = groups.map(([id, name]) => {
      const items = rows.filter(row => row.group === id);
      const pendingNames = items.filter(row => row.amount === null).map(row => row.name);
      return `<details class="capability" id="${id}"${open.has(id) ? " open" : ""}><summary><h3>${name}</h3><span class="group-count">${items.length} resources</span><span class="group-total">${escape(groupSummary(items))}${pendingNames.length ? `<small class="group-pending">Not included: ${escape(pendingNames.join(", "))}</small>` : ""}</span><span class="disclosure" aria-hidden="true">+</span></summary>
      <div class="capability-resources">${items.map(row => rowHTML(row, open)).join("")}</div></details>`;
    }).join("");
    for (const id of open) {
      const element = byId(id);
      if (element) element.open = true;
    }
    document.querySelectorAll("#planner [data-field]").forEach(element => { element.value = state[element.dataset.field]; });
    byId("region").value = state.region;
    const d = demand();
    byId("workload-summary").textContent = `${number(d.turns)} turns / month · ${number(state.concurrency)} peak concurrent`;
    byId("workload-math").textContent = `${number(state.users)} users × ${number(state.turns)} turns × ${state.days} days = ${number(d.turns)} turns / month. ${number(d.calls)} calls → ${number(d.input / 1e6)}M input + ${number(d.output / 1e6)}M output tokens.`;
    byId("total-price").textContent = money(sum.total);
    byId("fixed-price").textContent = money(sum.fixed);
    byId("usage-price").textContent = money(sum.usage);
    byId("estimate-breakdown").innerHTML = groups.map(([id, name]) => {
      const selected = rows.filter(row => row.group === id);
      const baseline = referenceRows.filter(row => row.group === id);
      const delta = totals(selected).total - totals(baseline).total;
      return `<div><dt>${name}</dt><dd>${escape(groupSummary(selected))}<small>Reference ${escape(groupSummary(baseline))} / delta ${escape(signedMoney(delta))}</small></dd></div>`;
    }).join("");
    const count = rows.filter(row => row.lines.length > 0 && !row.operatorEstimate).length;
    byId("coverage-count").textContent = `${count} resources have publicly sourced prices, including optional resources at quantity 0. ${rows.filter(r => r.operatorEstimate).length} use sourced plan estimates. All included costs have a price. See the scope for additional usage assumptions.`;
    byId("configuration-status").textContent = window.scenarios.changes(state, referenceState).length ?
      "Edited scenario" : "Starting configuration";
    renderDecisions();
    filterResources();
    byId("input-error").hidden = true;
  }

  function signedMoney(value) {
    return (value > .000001 ? "+" : value < -.000001 ? "-" : "") + money(Math.abs(value));
  }

  function meterCapturedAt(meter) {
    if (meter.sourceType === "OfficialPricingPage") return meter.retrievedAt;
    const sets = [catalog.modelDiscovery, ...Object.values(catalog.data[state.region] || {})];
    return sets.find(set => set?.items.some(item => item.meterId === meter.meterId &&
      item.armRegionName === meter.armRegionName))?.retrievedAt || catalog.retrievedAt;
  }

  function renderDecisions() {
    const { rows, sum } = latest;
    const baseSum = totals(referenceRows);
    const delta = sum.total - baseSum.total;
    const pending = rows.filter(r => r.amount === null);
    const quotesEntered = state.modelInputRate > 0 || state.modelOutputRate > 0 || state.hostedMonthly > 0 || state.buildMonthly > 0;
    byId("quote-status").hidden = !quotesEntered || (!!state.priceEvidence.trim() &&
      ((state.modelInputRate === 0 && state.modelOutputRate === 0) || (state.modelInputRate > 0 && state.modelOutputRate > 0)));
    byId("quote-status").textContent = "Estimates need a source/date note. Model pricing needs both positive input and output rates. Incomplete estimates are not applied, and missing prices are not assumed free.";
    byId("live-total").textContent = money(sum.total);
    byId("live-scope").textContent = "Selected resources and entered usage";
    const costChanges = rows.map(row => ({ row, delta: row.amount - referenceRows.find(r => r.id === row.id).amount }))
      .filter(change => Math.abs(change.delta) > .000001).sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));
    byId("cost-change-summary").hidden = costChanges.length === 0;
    byId("cost-change-link").hidden = costChanges.length === 0;
    byId("starting-point-note").hidden = costChanges.length > 0;
    byId("live-delta").textContent = Math.abs(delta) > .000001 ?
      `${money(Math.abs(delta))}/month ${delta > 0 ? "more" : "less"} than the starting point (${money(baseSum.total)}).` :
      `The total is unchanged from the starting point (${money(baseSum.total)}).`;
    const shown = costChanges.slice(0, 4);
    byId("cost-change-items").innerHTML = shown.map(({ row, delta: change }) =>
      `<li data-cost-delta="${change}"><a href="#entry-${row.id}" data-jump="${row.id}">${escape(row.name)}</a><strong>${escape(signedMoney(change))}</strong></li>`).join("");
    if (costChanges.length > shown.length) {
      const remainder = costChanges.slice(shown.length);
      byId("cost-change-items").insertAdjacentHTML("beforeend", `<li data-cost-delta="${remainder.reduce((sum, item) => sum + item.delta, 0)}"><a href="#estimate">Other ${remainder.length} resource changes</a><strong>${escape(signedMoney(remainder.reduce((sum, item) => sum + item.delta, 0)))}</strong></li>`);
    }
    const drivers = rows.filter(row => row.amount > 0).sort((a, b) => b.amount - a.amount);
    const leaders = drivers.slice(0, 6);
    byId("cost-driver-note").textContent = `${number(sum.total ? sum.fixed / sum.total * 100 : 0)}% of this estimate is allocated capacity. Running hours and throughput are editable billing assumptions, not measured consumption.`;
    byId("build-budget-note").textContent = buildBudgetNote();
    const excluded = window.architecture.deploymentOptions.filter(option => state[option.field] === 0);
    byId("excluded-scope-note").hidden = excluded.length === 0;
    byId("excluded-scope-note").textContent = `${excluded.length} allocation option(s) excluded from this budget. Linked allocations follow their parent. Shared resources still need a separate budget, and omitting a resource can require a different application configuration or private connectivity design. No Azure resource was changed.`;
    byId("cost-driver-items").innerHTML = leaders.map(row => {
      const assumption = row.id === "acr-build-pool" ? `${number(window.architecture.buildAllocatedHours(state))} allocated hours, including idle` :
        row.id === "backing-cosmos" ? `${number(state.backingCosmosRU)} RU/s billing hypothesis, not discovered throughput` : "";
      return `<li data-driver-amount="${row.amount}"><span><a href="#entry-${row.id}" data-jump="${row.id}">${escape(row.name)}</a>${assumption ? `<small>${escape(assumption)}</small>` : ""}</span><strong>${money(row.amount)}</strong></li>`;
    }).join("");
    const otherCosts = drivers.slice(leaders.length).reduce((sum, row) => sum + row.amount, 0);
    if (otherCosts > 0) byId("cost-driver-items").insertAdjacentHTML("beforeend",
      `<li data-driver-amount="${otherCosts}"><a href="#estimate">Other resources</a><strong>${money(otherCosts)}</strong></li>`);
    byId("live-sizing").textContent = assessment.actions ? `${assessment.actions} checks need attention` : "Quotas, capacity and availability";
    byId("live-sizing").classList.toggle("needs-attention", assessment.actions > 0);
    byId("sizing-alert").hidden = assessment.actions === 0;
    byId("sizing-alert").innerHTML = `${assessment.actions} capacity checks need attention. <a href="#decision">Review sizing</a>`;
    byId("demand-metrics").innerHTML = [
      ["Peak turns / minute", assessment.turnsPerMinute],
      ["Model calls / minute", assessment.rpm], ["Planning tokens / minute", assessment.tpm],
      ["Application Search QPS", assessment.qps]
    ].map(([label, value]) => `<div><span>${label}</span><strong>${number(value)}</strong></div>`).join("");
    byId("assessment-verdict").innerHTML = `<strong>${escape(assessment.status)}</strong><span>${escape(assessment.explanation)}</span>`;
    byId("assessment-verdict").classList.toggle("needs-attention", assessment.actions > 0);
    byId("assessment-summary").textContent = `${assessment.findings.length} checks / ${assessment.unknown} inputs to confirm${assessment.actions ? ` / ${assessment.actions} actions` : ""}`;
    const statusLabels = { action: "Action needed", unknown: "To confirm", checked: "Documented check", evidence: "Operator evidence" };
    byId("assessment-findings").innerHTML = assessment.findings.map(f =>
      `<article class="finding ${f.status}"><div><strong>${escape(f.title)}</strong><span class="row-tag">${statusLabels[f.status]}</span></div><p>${escape(f.detail)}</p><a href="${escape(f.source)}" target="_blank" rel="noopener">Product constraints &#8599;</a></article>`).join("");
    byId("reference-price").textContent = money(baseSum.total);
    const coverageDiffers = rows.some(r => {
      const b = referenceRows.find(v => v.id === r.id);
      return (r.amount === null) !== (b.amount === null) || !!r.operatorEstimate !== !!b.operatorEstimate;
    });
    byId("comparison-note").textContent = `${signedMoney(delta)}/month compared with the starting point. This difference is already included in the selected scenario total. ` +
      (coverageDiffers ? "Price sources differ, so review their scope." : "Both scenarios use this region's price catalog.") +
      " The starting point keeps its original workload and usage assumptions.";
    byId("cost-composition").textContent = `${money(sum.public)} public rates + ${money(sum.operator)} your plan estimates.`;
    byId("cost-composition").hidden = sum.operator === 0;
    byId("pending-title").textContent = pending.length ? `${pending.length} active costs still outside this subtotal` : "No active row missing a price; excluded usage still applies";
    byId("pending-prices").innerHTML = pending.map(r => `<li><a href="#entry-${r.id}" data-jump="${r.id}">${escape(r.name)}</a><span>${escape(r.issue || "Exact billing not confirmed.")}</span></li>`).join("");
    byId("pending-prices").closest(".pending-prices").hidden = pending.length === 0;
    const diff = window.scenarios.changes(state, referenceState);
    byId("scenario-changes").innerHTML = diff.length ? `<h3>${diff.length} input changes from reference</h3><div class="table-scroll"><table class="comparison-table"><thead><tr><th>Setting / assumption</th><th>Reference</th><th>Your scenario</th></tr></thead><tbody>${diff.map(c => `<tr><th>${escape(c.field)}</th><td>${escape(c.reference)}</td><td>${escape(c.value)}</td></tr>`).join("")}</tbody></table></div>` :
      "<p>No input changes from the same-region reference.</p>";
    const handoff = window.scenarios.handoff(state, referenceState);
    byId("deployment-handoff").innerHTML = handoff.length ? handoff.map(c => `<li><strong>${escape(c.field)}</strong>: ${escape(c.guidance)}</li>`).join("") :
      "<li>No mapped infrastructure setting differs. Workload, usage and supplied quotes are planning assumptions, not deployment commands.</li>";
  }

  function filterResources() {
    const query = byId("resource-search").value.trim().toLowerCase();
    const mode = byId("resource-filter").value;
    let visible = 0;
    for (const row of latest.rows) {
      const changed = rowChanged(row);
      const matches = (!query || `${row.name} ${row.description} ${groups.find(g => g[0] === row.group)[1]}`.toLowerCase().includes(query)) &&
        (mode === "all" || mode === "included" && !(row.optional && !row.included) ||
          mode === "optional" && row.optional || mode === "unpriced" && (row.quoteRequired || row.operatorEstimate) || mode === "changed" && changed);
      byId(`entry-${row.id}`).hidden = !matches;
      if (matches) visible++;
    }
    for (const [id] of groups) {
      const group = byId(id);
      group.hidden = ![...group.querySelectorAll("[data-resource]")].some(row => !row.hidden);
      if ((query || mode !== "all") && !group.hidden) group.open = true;
    }
    byId("resource-count").textContent = query || mode !== "all" ?
      `${visible} of ${latest.rows.length} resources shown. Filters do not change the estimate.` :
      `${latest.rows.length} resources across ${groups.length} capabilities`;
    byId("no-resources").hidden = visible !== 0;
  }

  function rowChanged(row) {
    const baseline = referenceRows.find(r => r.id === row.id);
    return Math.abs((row.amount || 0) - (baseline.amount || 0)) > .000001 ||
      row.included !== baseline.included || (row.amount === null) !== (baseline.amount === null) ||
      row.operatorEstimate !== baseline.operatorEstimate || row.quantity !== baseline.quantity ||
      JSON.stringify(row.lines.map(l => [l.meter.skuName, l.meter.meterName, l.quantity])) !==
        JSON.stringify(baseline.lines.map(l => [l.meter.skuName, l.meter.meterName, l.quantity]));
  }

  function notify(message, error = false) {
    const element = byId("scenario-message");
    element.textContent = message;
    element.setAttribute("role", error ? "alert" : "status");
    element.hidden = false;
    if (byId("action-message")) {
      byId("action-message").textContent = message;
      byId("action-message").setAttribute("role", error ? "alert" : "status");
      byId("action-message").hidden = false;
    }
  }

  function scenarioURL() {
    const url = new URL(location.href);
    url.search = "";
    url.searchParams.set("scenario", JSON.stringify(window.scenarios.pack(state, defaults)));
    url.hash = "main";
    return url;
  }

  function restoreLink() {
    const params = new URLSearchParams(location.search);
    if (!params.has("scenario")) return;
    try {
      const raw = params.get("scenario");
      if (params.getAll("scenario").length !== 1 || raw.length > 20000) throw new Error("Scenario link is duplicated or too large.");
      const candidate = checkedState(JSON.parse(raw));
      state = candidate;
      notify("Shared scenario restored. Public prices are recalculated from this page's current catalog, not frozen by the link.");
    } catch (error) {
      console.warn("Scenario link rejected", error);
      notify(`Scenario rejected: ${error.message} The reference is shown instead, not the requested scenario.`, true);
    }
  }

  function exportReport() {
    const buildIncluded = window.architecture.included(state)["acr-build-pool"];
    const reportRows = rows => rows.map(row => ({
      id: row.id, name: row.name, capability: row.group,
      included: !(row.optional && !row.included), optional: !!row.optional,
      monthlyUSD: row.amount, pricing: row.amount === null ? "unpriced" : row.operatorEstimate ? "operator" :
        row.billingNote ? "shared-or-configuration" : "public",
      outstanding: row.issue || null, operatorSource: row.estimateSource || null,
      configurationSource: row.parameter,
      lines: row.lines.map(line => ({
        amountUSD: line.amount, quantity: line.quantity, description: line.description, kind: line.kind,
        source: line.operatorEstimate ? "operator" : line.meter.sourceType === "OfficialPricingPage" ?
          line.meter.sourceUrl : "Azure Retail Prices API",
        meter: line.meter,
        capturedAt: line.operatorEstimate ? null : meterCapturedAt(line.meter)
      }))
    }));
    return {
      reportVersion: 1, generatedAt: new Date().toISOString(), currency: "USD",
      deploymentReference: catalog.deploymentVersion, networkIsolation: "enabled-standalone",
      warning: "PLANNING ESTIMATE, NOT A QUOTE OR CAPACITY GUARANTEE. Costs reflect the selected resources and entered usage. Your plan estimates are not public meters.",
      scenario: window.scenarios.pack(state, defaults), state: { ...state },
      buildAllocation: { included: buildIncluded, mode: state.buildMode,
        allocatedHoursPerMonth: buildIncluded ? window.architecture.buildAllocatedHours(state) : 0,
        assumption: buildBudgetNote() },
      reference: { state: referenceState, subtotal: totals(referenceRows), resources: reportRows(referenceRows) },
      subtotal: latest.sum, demand: latest.demand, assessment: window.scenarios.assess(state),
      differences: window.scenarios.changes(state, referenceState),
      deploymentHandoff: window.scenarios.handoff(state, referenceState),
      priceCatalog: { retrievedAt: catalog.retrievedAt, source: catalog.source,
        services: Object.fromEntries(Object.entries(catalog.data[state.region]).map(([name, entry]) =>
          [name, { retrievedAt: entry.retrievedAt || catalog.retrievedAt, query: entry.query }])),
        modelDiscovery: { retrievedAt: catalog.modelDiscovery.retrievedAt || catalog.retrievedAt, query: catalog.modelDiscovery.query } },
      outstandingActiveCosts: latest.rows.filter(r => r.amount === null).map(r => ({ id: r.id, name: r.name, reason: r.issue })),
      exclusions: ["Discounts, taxes and credits", "Unmapped model, build, license and integration prices unless explicitly supplied",
        "Foundry backing Cosmos uses an explicit throughput and backup billing hypothesis, not discovery of service-created offers",
        "Data transfer, Search semantic/agentic usage, extraction and extra tool/model calls",
        "Storage operations not listed, retention, diagnostics, registry overages and session/storage extras",
        "Production performance, quota availability and complete deployment compatibility are not validated"],
      resources: reportRows(latest.rows)
    };
  }

  function readableReport() {
    const report = exportReport();
    const lines = [
      "# Agent Landing Zone planning scenario", "",
      "**PLANNING ESTIMATE - selected resources and entered usage, not an invoice or capacity guarantee.**",
      `Reference: ${report.deploymentReference}, isolated hosted-no-panel. Region: ${state.region}. Currency: USD.`,
      `Generated: ${report.generatedAt}. Base price snapshot: ${catalog.retrievedAt}.`,
      `Monthly subtotal: ${money(latest.sum.total)} (${money(latest.sum.public)} public + ${money(latest.sum.operator)} operator).`,
      `Same-region reference: ${money(totals(referenceRows).total)}. Monthly difference: ${signedMoney(latest.sum.total - totals(referenceRows).total)}.`,
      "Pricing coverage may differ. A delta is not a verified saving.", "",
      "## Build pool operation", report.buildAllocation.assumption, "",
      "## Sizing assessment", assessment.status, assessment.explanation,
      ...assessment.findings.map(f => `- ${f.title}: ${f.status}. ${f.detail} Source: ${f.source}`),
      "", "## Active prices still missing",
      ...report.outstandingActiveCosts.map(r => `- ${r.name}: ${r.reason}`),
      "", "## Capability breakdown",
      ...groups.map(([id, name]) => `- ${name}: ${groupSummary(latest.rows.filter(r => r.group === id))}`),
      "", "## Changes from same-region reference",
      ...report.differences.map(c => `- ${c.field}: ${c.reference} -> ${c.value}`),
      "", "## Deployment handoff (review, not executable IaC)",
      ...report.deploymentHandoff.map(c => `- ${c.field}: ${c.guidance}`),
      "", "## Complete input assumptions", "```json", JSON.stringify(state, null, 2), "```",
      "", "## Operator estimates", `Source/date: ${state.priceEvidence || "None supplied"}`,
      "", "## Exclusions", ...report.exclusions.map(text => `- ${text}`)
    ];
    return lines.join("\n");
  }

  function buildBudgetNote() {
    if (!window.architecture.included(state)["acr-build-pool"]) return "No new private build pool is included. Provide a compatible private build path and budget any reused capacity separately.";
    return state.buildMode === "daily" ?
      `Build pool: ${number(state.buildDeploymentsPerDay)} deployment(s)/day x ${number(state.buildDays)} days/month x ${number(state.buildMinutes)} allocated minutes = ${number(window.architecture.buildAllocatedHours(state))} hours/month. Startup, build, shutdown and any idle allocation belong in that time. Scaling to zero between build windows is an operating assumption, not automation provided by this planner or the default deployment.` :
      `Build pool: ${number(state.buildHours)} allocated hours/month, including idle. No automatic scale-to-zero is assumed.`;
  }

  async function copyText(text, description) {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard API unavailable.");
      await navigator.clipboard.writeText(text);
      byId("copy-fallback").hidden = true;
      notify(`${description} copied. It includes assumptions and exclusions, not deployment-ready IaC.`);
    } catch (error) {
      console.warn("Clipboard write failed", error);
      byId("copy-output").value = text;
      byId("copy-fallback").hidden = false;
      byId("copy-output").focus();
      byId("copy-output").select();
      notify(`Clipboard could not be written. Select and copy the ${description.toLowerCase()} in the text box below.`, true);
    }
  }

  function revealTarget(id) {
    const target = byId(id);
    if (!target) return;
    if (target.matches("details")) target.open = true;
    let parent = target.parentElement.closest("details");
    while (parent && root.contains(parent)) {
      parent.open = true;
      parent = parent.parentElement.closest("details");
    }
  }

  function installScenarioActions() {
    byId("resource-search").addEventListener("input", filterResources);
    byId("resource-filter").addEventListener("change", filterResources);
    byId("clear-filters").addEventListener("click", () => {
      byId("resource-search").value = "";
      byId("resource-filter").value = "all";
      filterResources();
    });
    root.addEventListener("click", event => {
      const link = event.target.closest("a");
      if (!link) return;
      const group = groups.find(([id]) => link.getAttribute("href") === `#${id}`);
      if (link.dataset.jump || group) {
        byId("clear-filters").click();
        revealTarget(group ? group[0] : `entry-${link.dataset.jump}`);
      } else if (link.getAttribute("href")?.startsWith("#")) {
        revealTarget(link.getAttribute("href").slice(1));
      }
    });
    byId("save-scenario").addEventListener("click", () => {
      try {
        localStorage.setItem(window.scenarios.storageKey, JSON.stringify(window.scenarios.pack(state, defaults)));
        notify("Scenario saved on this device. Use Load saved to restore it. Unsaved edits are not stored.");
      } catch (error) {
        console.error("Scenario save failed", error);
        notify(`Could not save this scenario: ${error.message} Use a shared link or export instead.`, true);
      }
    });
    byId("load-scenario").addEventListener("click", () => {
      try {
        const raw = localStorage.getItem(window.scenarios.storageKey);
        if (raw === null) throw new Error("No saved scenario on this device.");
        if (raw.length > 20000) throw new Error("Saved scenario is too large.");
        const candidate = checkedState(JSON.parse(raw));
        const url = new URL(location.href);
        url.search = "";
        url.searchParams.set("scenario", JSON.stringify(window.scenarios.pack(candidate, defaults)));
        url.hash = "main";
        history.replaceState(null, "", url);
        state = candidate;
        render();
        notify("Saved scenario restored. Prices use the current catalog. The URL now preserves this configuration on reload.");
      } catch (error) {
        console.warn("Scenario restore failed", error);
        notify(`Could not load the saved scenario: ${error.message} Your current scenario is unchanged.`, true);
      }
    });
    byId("share-scenario").addEventListener("click", () => {
      const url = scenarioURL();
      history.replaceState(null, "", url);
      void copyText(url.href, "Scenario link");
    });
    byId("copy-summary").addEventListener("click", () => { void copyText(readableReport(), "Planning summary"); });
    byId("export-scenario").addEventListener("click", () => {
      const blob = new Blob([JSON.stringify(exportReport(), null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "agent-lz-planning-scenario.json";
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      notify("JSON report download requested. It includes input assumptions, source meters, pending costs and handoff guidance.");
    });
  }

  function change(event) {
    const element = event.target;
    const field = element.dataset.field;
    if (!field || !Object.hasOwn(defaults, field)) return;
    if (!element.checkValidity()) {
      byId("input-error").textContent = "This input is outside its supported range. Correct it to update the estimate. The figures below still reflect the last valid inputs.";
      byId("input-error").hidden = false;
      element.reportValidity();
      return;
    }
    const value = typeof defaults[field] === "number" ? Number(element.value) : element.value;
    if (typeof value === "number" && (!Number.isFinite(value) || element.value.trim() === "")) {
      byId("input-error").textContent = "Enter a finite number. The estimate has not been updated.";
      byId("input-error").hidden = false;
      return;
    }
    const candidate = { ...state, [field]: value };
    if (field === "region" && state.region !== value) {
      for (const quotedField of window.architecture.quoteFields) {
        candidate[quotedField] = 0;
        candidate[`${quotedField}MonthlyRate`] = 0;
        candidate[`${quotedField}PriceSource`] = "";
      }
    }
    if (["region", "model"].includes(field) && state[field] !== value) {
      Object.assign(candidate, { modelInputRate: 0, modelOutputRate: 0, hostedMonthly: 0, buildMonthly: 0, priceEvidence: "",
        modelTPM: 0, modelRPM: 0, testedHostedConcurrency: 0, hostedBenchmarkKey: "" });
      notify("Region/model changed. Operator quotes, assigned quotas and hosted benchmark were cleared. Region changes also reset plan-priced options to quantity 0. Reconfirm prices and scope for this target.");
    }
    if (field === "region" && !firewallSkus(value).includes(candidate.firewall)) {
      candidate.firewall = referenceFor(value).firewall;
      notify(`Region changed. No standalone ${state.firewall} price is published here, so Firewall is explicitly set to ${candidate.firewall}. This differs from the shipped Basic default and requires an IaC change. Plan-priced options and target-specific evidence were reset.`);
    }
    if (["region", "searchSku", "searchReplicas", "searchPartitions", "searchServices"].includes(field) && state[field] !== value) {
      candidate.testedSearchQPS = 0;
      candidate.searchBenchmarkKey = "";
    }
    if (["inputTokens", "outputTokens", "calls"].includes(field) && state[field] !== value) {
      candidate.testedHostedConcurrency = 0;
      candidate.hostedBenchmarkKey = "";
    }
    if (field === "testedSearchQPS") candidate.searchBenchmarkKey = window.scenarios.searchKey(candidate);
    if (field === "testedHostedConcurrency") candidate.hostedBenchmarkKey = window.scenarios.hostedKey(candidate);
    try {
      state = checkedState({ version: window.scenarios.version, state: candidate });
    } catch (error) {
      console.warn("Input rejected", error);
      byId("input-error").textContent = `${error.message} The estimate still reflects your last valid inputs.`;
      byId("input-error").hidden = false;
      return;
    }
    render();
    root.querySelector(`[data-field="${field}"]`)?.focus({ preventScroll: true });
  }

  function checkedState(payload) {
    const next = window.scenarios.validate(payload, defaults, catalog.regions);
    const missing = resources(next).filter(row => row.amount === null);
    if (missing.length) throw new Error(`Complete the pricing inputs before including: ${missing.map(row => row.name).join(", ")}.`);
    return next;
  }

  async function init() {
    const response = await fetch(new URL(root.dataset.catalogUrl, location.href), { cache: "no-cache" });
    if (!response.ok) throw new Error(`Price snapshot could not be loaded (HTTP ${response.status}).`);
    catalog = await response.json();
    if (catalog.currency !== "USD" || !catalog.retrievedAt || !catalog.data || !catalog.regions) {
      throw new Error("Price snapshot has an unexpected shape.");
    }
    byId("region").innerHTML = Object.entries(catalog.regions).map(([id, label]) => `<option value="${escape(id)}">${escape(label)}</option>`).join("");
    const timestamp = new Date(catalog.retrievedAt);
    if (!Number.isFinite(timestamp.getTime())) throw new Error("The snapshot retrieval date is invalid.");
    byId("price-date").textContent = `Prices retrieved ${timestamp.toLocaleString("en-US", { dateStyle: "medium", timeStyle: "short", timeZone: "UTC" })} UTC`;
    if (Date.now() - timestamp.getTime() > 48 * 3600000) {
      byId("stale-warning").textContent = "The public price catalog is more than 48 hours old. The last validated catalog is shown. Confirm current rates before using the estimate for purchasing.";
      byId("stale-warning").hidden = false;
    }
    root.addEventListener("change", change);
    byId("reset").addEventListener("click", () => {
      state = { ...defaults };
      const url = new URL(location.href);
      url.searchParams.delete("scenario");
      history.replaceState(null, "", url);
      for (const id of ["scenario-message", "action-message", "copy-fallback"]) byId(id).hidden = true;
      render();
    });
    document.querySelectorAll("[data-preset]").forEach(button => button.addEventListener("click", () => {
      const profile = button.dataset.preset;
      const users = profile === "small" ? 10 : profile === "larger" ? 1000 : defaults.users;
      state = { ...state, users, concurrency: profile === "small" ? 1 : profile === "larger" ? 25 : defaults.concurrency };
      render();
    }));
    installScenarioActions();
    restoreLink();
    state = checkedState({ version: window.scenarios.version, state });
    render();
    byId("load-status").hidden = true;
    byId("planner").hidden = false;
    if (location.hash) revealTarget(location.hash.slice(1));
    window.planner = {
      get state() { return { ...state }; },
      get snapshot() { return latest; },
      defaults, demand, totals, groupSummary, referenceFor, firewallSkus,
      calculate: overrides => resources({ ...state, ...overrides }),
      catalog, assessment: () => window.scenarios.assess(state),
      exportReport, pack: () => window.scenarios.pack(state, defaults),
      validate: checkedState
    };
  }

  init().catch(error => {
    console.error("Planner initialization failed", error);
    byId("load-status").textContent = `${error.message} Check the local server and price snapshot, then reload. No estimate is available.`;
    byId("load-status").setAttribute("role", "alert");
  });
})();
