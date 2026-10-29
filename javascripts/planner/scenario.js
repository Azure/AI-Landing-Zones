"use strict";

window.scenarios = (() => {
  const version = 2;
  // Keep the storage key so saved version 1 scenarios remain recoverable.
  const storageKey = "agent-lz-planner-scenario-v1";
  const defaults = {
    turnSeconds: 30, searchQueries: 1, availability: "evaluation",
    indexGB: 10, vectorGB: 1, modelTPM: 0, modelRPM: 0,
    testedSearchQPS: 0, testedHostedConcurrency: 0,
    searchBenchmarkKey: "", hostedBenchmarkKey: "",
    modelInputRate: 0, modelOutputRate: 0, hostedMonthly: 0, buildMonthly: 0,
    priceEvidence: "", hostedHours: 200
  };
  const searchURL = "https://learn.microsoft.com/azure/search/search-limits-quotas-capacity";
  const quotaURL = "https://learn.microsoft.com/azure/ai-foundry/openai/how-to/quota";
  const hostedURL = "https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents";
  const searchKey = s => [s.region, s.searchSku, s.searchReplicas, s.searchPartitions].join("|");
  const hostedKey = s => [s.region, s.model, s.inputTokens, s.outputTokens, s.calls].join("|");

  function assess(s) {
    const included = window.architecture.included(s);
    const turnsPerMinute = s.concurrency / s.turnSeconds * 60;
    const rpm = turnsPerMinute * s.calls;
    const tpm = rpm * (s.inputTokens + s.outputTokens);
    const qps = s.concurrency / s.turnSeconds * s.searchQueries;
    const findings = [];
    const add = (id, status, title, detail, source) => findings.push({ id, status, title, detail, source });
    const fmt = n => new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(n);
    const quotaStatus = !included.model ? "unknown" :
      (s.modelTPM && tpm > s.modelTPM) || (s.modelRPM && rpm > s.modelRPM) ? "action" :
      s.modelTPM && s.modelRPM ? "checked" : "unknown";
    add("model", quotaStatus, "Model quota",
      `${fmt(rpm)} calls/min and ${fmt(tpm)} planning tokens/min. ` +
      (quotaStatus === "action" ? "Raise assigned quota or reduce peak demand. " :
        quotaStatus === "unknown" ? "Enter the actual assigned TPM and RPM to compare. " : "Within the entered quota. ") +
      "Azure admission estimates can differ from billable tokens; retries and burst windows still need testing.", quotaURL);
    const modern = {
      "Basic": { replicas: 3, partitions: 3, units: 9, storage: 15, vectors: 5 },
      "Standard S1": { replicas: 12, partitions: 12, units: 36, storage: 160, vectors: 35 },
      "Standard S2": { replicas: 12, partitions: 12, units: 36, storage: 512, vectors: 150 }
    };
    const tier = modern[s.searchSku];
    const requiredReplicas = s.availability === "query-index" ? 3 : s.availability === "queries" ? 2 : 1;
    for (const [id, label, r, p, limits] of [
      ["search", "Application Search", s.searchReplicas, s.searchPartitions, tier],
      ["backing-search", "Backing Search", s.backingReplicas, s.backingPartitions, modern["Standard S1"]]
    ]) {
      if (!included[id]) {
        add(`${id}-scope`, "unknown", `${label}: outside this budget`,
          "No new Search service is included. The selected retrieval path needs a compatible service or configuration. Any existing service needs separate capacity checks and budgeting.", searchURL);
        continue;
      }
      const valid = r <= limits.replicas && p <= limits.partitions && r * p <= limits.units;
      add(`${id}-topology`, valid ? "checked" : "action", `${label}: topology`,
        `${r} replicas x ${p} partitions = ${r * p} search units. ` +
        (valid ? "Within documented fresh-service topology limits. " : "Exceeds this tier's replica, partition or search-unit limit. ") +
        (r < requiredReplicas ? `Selected availability needs at least ${requiredReplicas} replicas.` :
          s.availability === "evaluation" ? "Evaluation selected, not an HA design." : "Meets the selected replica floor, not a workload guarantee."), searchURL);
      if (r < requiredReplicas) findings[findings.length - 1].status = "action";
    }
    const storage = tier.storage * s.searchPartitions;
    const vectors = tier.vectors * s.searchPartitions;
    if (included.search) add("search-storage", s.indexGB > storage || s.vectorGB > vectors || s.vectorGB > s.indexGB ? "action" : "checked",
      "Application Search: index footprint",
      `${fmt(s.indexGB)} GB index / ${fmt(storage)} GB disk; ${fmt(s.vectorGB)} GB vector index / ${fmt(vectors)} GB vector quota. ` +
      "Entered footprints are hypotheses, not derived from corpus bytes. Limits assume a new service in the selected region. Verify actual quotas and single-index limits.", searchURL);
    const searchEvidence = s.testedSearchQPS > 0 && s.searchBenchmarkKey === searchKey(s);
    if (included.search) add("search-throughput", !searchEvidence ? "unknown" : qps > s.testedSearchQPS ? "action" : "evidence",
      "Application Search: peak queries",
      `${fmt(qps)} estimated QPS. ` + (searchEvidence ?
        `Compare with ${fmt(s.testedSearchQPS)} QPS reported for this exact region/tier/replica/partition configuration. ` :
        "Enter measured QPS for this exact configuration; there is no universal QPS per replica. ") +
      "Re-test with your index, retrieval path, indexing load and latency target.", searchURL);
    const hostedEvidence = s.testedHostedConcurrency > 0 && s.hostedBenchmarkKey === hostedKey(s);
    if (included.hosted) add("hosted", !hostedEvidence ? "unknown" : s.concurrency > s.testedHostedConcurrency ? "action" : "evidence",
      "Hosted runtime: concurrent turns",
      `${fmt(s.concurrency)} peak turns on the shipped 2 vCPU / 4 GiB runtime. ` + (hostedEvidence ?
        `Operator-reported tested concurrency: ${fmt(s.testedHostedConcurrency)}. ` :
        "No compatible load-test result supplied. ") +
      "Model/tool waits, CPU, memory, sessions and latency must be measured. No vCPU-per-user formula is assumed.", hostedURL);
    const apps = included["frontend-app"];
    const cpu = apps ? .5 * (1 + s.extraFrontendApps + s.orchestratorApps) + s.ingestionApps : 0;
    const memory = apps ? 1 + s.extraFrontendApps + s.orchestratorApps + 3 * s.ingestionApps : 0;
    const cpus = s.profile === "D4" ? 4 : 8;
    if (included.compute) add("compute", apps && (cpu >= cpus * s.nodes || memory >= cpus * 4 * s.nodes) ? "action" : "checked",
      "Container Apps: placement",
      `${fmt(cpu)} vCPU / ${fmt(memory)} GiB requested on ${s.nodes} ${s.profile} node(s). ` +
      "Nominal placement only, before runtime reserves. It does not establish frontend throughput. " +
      (!apps ? "No application deployment is included in this budget." :
        s.nodes > 1 ? "Raise the shipped max of one node in IaC." : s.nodes === 0 ? "Zero nodes cannot host the included frontend." : "Keep CPU and memory headroom."),
      "https://learn.microsoft.com/azure/container-apps/workload-profiles-overview");
    const actions = findings.filter(f => f.status === "action").length;
    const unknown = findings.filter(f => f.status === "unknown").length;
    return { turnsPerMinute, rpm, tpm, qps, findings, actions, unknown,
      status: actions ? "Action needed" : "Sizing baseline",
      explanation: actions ? `${actions} selected constraint(s) need attention. No automatic resizing was applied.` :
        "Use this configuration as a starting point. Refine it with your quotas and workload tests before production." };
  }

  function bounds(allDefaults) {
    const limits = Object.fromEntries(Object.entries(allDefaults).filter(([, v]) => typeof v === "number")
      .map(([k]) => [k, [0, 1000000, 1]]));
    for (const k of ["applicationCosmos", "orchestratorApps", "ingestionApps", "extraFrontendApps", "additionalAgents",
      "vpnGateways", "expressRouteGateways", "buildVMs", "botServices", "workIQ", "fabricIQ", "webGrounding", "speech",
      "agent365", "defender", "entraLicenses", "purview", "workloadPolicies", "nodes"]) limits[k] = [0, 100, 1];
    Object.assign(limits, {
      days: [1, 31, 1], turns: [0, 10000, 1], calls: [0, 100, .1],
      inputTokens: [0, 10000000, 1], outputTokens: [0, 10000000, 1], hours: [0, 744, 1],
      searchReplicas: [1, 12, 1], searchPartitions: [1, 12, 1], backingReplicas: [1, 12, 1], backingPartitions: [1, 12, 1],
      appGateway: [0, 1, 1], gatewayCU: [0, 10000, .1], apimUnits: [0, 10, 1],
      logAllowance: [0, 5, .1], logsGB: [0, 1000000, .1], reads: [0, 1000000, .1], writes: [0, 1000000, .1],
      cosmosMRU: [0, 1000000, .1], embeddingMillions: [0, 1000000, .1], dnsQueries: [0, 1000000, .1],
      vaultOperations: [0, 1000000, .1], backingCosmosRU: [400, 1000000, 100], backingStorageGB: [0, 50000, 1],
      buildHours: [0, 744, .01], buildDeploymentsPerDay: [0, 100, 1], buildDays: [0, 31, 1],
      buildMinutes: [1, 1440, 1],
      hostedHours: [0, 1000000, .1], turnSeconds: [1, 3600, 1], searchQueries: [0, 100, .1],
      indexGB: [0, 1000000, .1], vectorGB: [0, 1000000, .1], modelTPM: [0, 1000000000, 1],
      modelRPM: [0, 10000000, 1], testedSearchQPS: [0, 1000000, .1], testedHostedConcurrency: [0, 1000000, 1],
      modelInputRate: [0, 100000, .000001], modelOutputRate: [0, 100000, .000001],
      hostedMonthly: [0, 10000000, .01], buildMonthly: [0, 10000000, .01]
    });
    for (const { field } of window.architecture.deploymentOptions) limits[field] = [0, 1, 1];
    for (const field of Object.keys(allDefaults).filter(key => key.endsWith("MonthlyRate"))) limits[field] = [0, 10000000, .01];
    return limits;
  }

  function validate(payload, allDefaults, regions) {
    if (!payload || ![1, version].includes(payload.version) || !payload.state || Array.isArray(payload.state) ||
        typeof payload.state !== "object" || Object.keys(payload).some(k => !["version", "state"].includes(k))) {
      throw new Error("Unsupported scenario format. Use a version 1 or 2 planner link or saved scenario.");
    }
    const enums = {
      region: Object.keys(regions), model: ["gpt-5-nano", "gpt-4.1-nano"],
      searchSku: ["Basic", "Standard S1", "Standard S2"], storageTier: ["Hot LRS", "Cool LRS"],
      profile: ["D4", "D8"], appconfig: ["Standard", "Premium"], firewall: ["Basic", "Standard", "Premium"],
      apimSku: ["Standard v2", "Premium v2"], backingCosmosMode: ["manual", "autoscale"],
      backingBackupMode: ["continuous30", "periodic", "continuous7"],
      availability: ["evaluation", "queries", "query-index"], buildMode: ["daily", "allocated"]
    };
    const rules = bounds(allDefaults);
    const next = { ...allDefaults, ...(payload.version === 1 ? { buildMode: "allocated" } : {}) };
    for (const [key, value] of Object.entries(payload.state)) {
      if (!Object.hasOwn(allDefaults, key)) throw new Error(`Unknown scenario field: ${key}. No scenario was loaded.`);
      if (typeof value !== typeof allDefaults[key]) throw new Error(`Invalid type for ${key}. No scenario was loaded.`);
      if (typeof value === "number") {
        const [min, max, step] = rules[key];
        const units = (value - min) / step;
        if (!Number.isFinite(value) || value < min || value > max || Math.abs(units - Math.round(units)) > .00001) {
          throw new Error(`Invalid range or increment for ${key}. No scenario was loaded.`);
        }
      } else if (enums[key] ? !enums[key].includes(value) : value.length > (key === "priceEvidence" || key.endsWith("PriceSource") ? 300 : 180)) {
        throw new Error(`Invalid value for ${key}. No scenario was loaded.`);
      }
      next[key] = value;
    }
    if (next.buildMode === "daily" && next.buildDeploymentsPerDay * next.buildMinutes > 1440) {
      throw new Error("A single build agent cannot be allocated for more than 24 hours per deployment day. Reduce deployments or allocated minutes.");
    }
    return next;
  }

  function pack(s, allDefaults) {
    return { version, state: Object.fromEntries(Object.entries(s).filter(([k, v]) =>
      Object.hasOwn(allDefaults, k) && v !== allDefaults[k])) };
  }

  function changes(s, reference) {
    const evidence = new Set(["searchBenchmarkKey", "hostedBenchmarkKey"]);
    return Object.entries(s).filter(([key, value]) => value !== reference[key] && !evidence.has(key))
      .map(([field, value]) => ({ field, reference: reference[field], value }));
  }

  const surfaces = {
    model: "main.parameters.json: modelDeploymentList; validate model quality, quota and region.",
    searchSku: "Application Search tier is an IaC literal. Update the Search module composition and validate migration.",
    searchReplicas: "Application Search replicas are IaC literals, not a new root deployment parameter.",
    searchPartitions: "Application Search partitions are IaC literals; validate tier combinations and index quotas.",
    backingReplicas: "Foundry backing Search replicas require an IaC change.",
    backingPartitions: "Foundry backing Search partitions require an IaC change.",
    profile: "main.parameters.json: workloadProfiles; validate subnet IP space and application placement.",
    nodes: "Allocated nodes are a billing hypothesis. More than one needs a workloadProfiles maxCount change.",
    appconfig: "App Configuration tier is declared in its module, not a root scaling flag.",
    storageTier: "Storage access tier changes need a reviewed storage/lifecycle change.",
    firewall: "main.parameters.json: AZURE_FIREWALL_SKU; revalidate security features and management networking.",
    appGateway: "publicIngress.enabled plus hostname, Key Vault certificate and client CIDRs. Disabling incremental deployment does not delete existing ingress.",
    apimUnits: "Separate APIM integration, not automatically deployed by this platform.",
    apimSku: "Separate APIM networking and SKU integration; Standard v2 needs private ingress, Premium v2 can use injection.",
    applicationCosmos: "main.parameters.json: deployCosmosDb; configure compatible application persistence and its linked endpoint.",
    orchestratorApps: "Orchestrator topology/runtime migration, not simply a duplicate of the hosted agent.",
    ingestionApps: "Compatible application-ingestion path and containerAppsList changes.",
    extraFrontendApps: "Additional containerAppsList entries; replicas and node limits need validation.",
    additionalAgents: "Separately versioned hosted-agent definitions and runtime configuration."
  };

  function handoff(s, reference) {
    return changes(s, reference).filter(c => surfaces[c.field] ||
      window.architecture.deploymentOptions.some(option => option.field === c.field)).map(c => {
      const option = window.architecture.deploymentOptions.find(option => option.field === c.field);
      return { ...c, guidance: option ?
        `Review ${option.parameter} for ${option.label}. Zero omits new allocation from this estimate, not existing charges or resources. Validate dependent features, explicit flags and any reused service budget. Keep private connectivity and authorization intact.` :
        surfaces[c.field] };
    });
  }

  return { version, storageKey, defaults, assess, bounds, validate, pack, changes, handoff, searchKey, hostedKey };
})();
