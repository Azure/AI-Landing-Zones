"use strict";

window.applySizingGuidance = (rows, s) => {
  const learn = "https://learn.microsoft.com/azure/";
  const guide = {
    hosted: [
      "Start with the shipped 2 vCPU / 4 GiB. Increase memory for out-of-memory failures, CPU for CPU-bound orchestration. Model throttling needs model quota, not a larger host. Container Apps nodes do not resize this runtime.",
      "foundry/agents/concepts/hosted-agents"
    ],
    model: [
      "Quota is sized in peak TPM and RPM, not monthly tokens. Increase the model's assigned quota when either limit throttles requests (HTTP 429). Capacity-to-TPM/RPM ratios vary by model.",
      "ai-foundry/openai/how-to/quota"
    ],
    search: [
      "Start at S1 / 1 replica / 1 partition. Add replicas for slow queries or 429/503s, partitions for index/vector storage or indexing bottlenecks. Validate tier-specific limits before scaling.",
      "search/search-capacity-planning"
    ],
    storage: [
      "Use Hot for actively read or updated documents. Consider Cool for infrequent access retained at least 30 days. Earlier deletion/overwrite can incur a penalty, and retrieval costs more.",
      "storage/blobs/access-tiers-overview"
    ],
    compute: [
      "D4 provides 4 vCPU / 16 GiB, D8 doubles both. Add nodes when summed replica requests approach usable capacity. Reserve runtime overhead, adding an app does not necessarily add a node.",
      "container-apps/workload-profiles-overview"
    ],
    registry: [
      "Keep Premium for Private Link. It includes 500 GiB, storage above that incurs overage. Clean up obsolete images before adding capacity. Investigate HTTP 429s against registry request-rate limits.",
      "container-registry/container-registry-skus"
    ],
    appconfig: [
      "Standard: 1 GB configuration storage and 30,000 requests/hour. Cache refreshes to stay within quota. Compare Premium for higher-volume workloads or up to 4 GB, not simply more chat users.",
      "azure-app-configuration/faq"
    ],
    firewall: [
      "Basic supports up to 250 Mbps. Choose Standard for higher throughput (up to 30 Gbps) or DNS proxy. Premium adds TLS inspection/IDPS. These are service limits, not guaranteed workload throughput.",
      "firewall/choose-firewall-sku"
    ],
    appgateway: [
      "Size billed CUs from the largest of throughput / 2.22 Mbps, connections / 2,500 and compute units. A reserved instance reserves 10 CUs. Raise autoscale limits before peak load exceeds capacity.",
      "application-gateway/understanding-pricing"
    ],
    apim: [
      "Use Standard v2 for private backends, plus Private Link for private inbound access. Choose Premium v2 for VNet injection. Add units for sustained gateway CPU/memory pressure, Standard v2 scales to 10 units.",
      "api-management/v2-service-tiers-overview"
    ],
    "application-cosmos": [
      "Serverless fits intermittent traffic. A physical partition supports up to 5,000 RU/s, not a latency guarantee. For predictable sustained throughput/latency, evaluate provisioned capacity. RU consumed is not RU/s.",
      "cosmos-db/serverless-performance"
    ],
    "foundry-vault": [
      "Use Standard for secrets and software keys, Premium for HSM-backed keys. Secret reads share a 4,000-operations/10-second limit per vault/region. Cache reads and back off on 429s rather than upgrading blindly.",
      "key-vault/general/service-limits"
    ],
    bastion: [
      "Keep Standard for host scaling or native-client access. Reserve a dedicated AzureBastionSubnet of /26 or larger. Add scale units when concurrent administrative sessions exhaust the current instances.",
      "bastion/configuration-settings"
    ],
    "acr-build-pool": [
      "S1: 2 CPU / 3 GB per agent. Use S2 (4 CPU / 8 GB) or S3 (8 CPU / 16 GB) for heavier builds. Add agents for parallel jobs. Pool allocation, including idle time, is billable.",
      "container-registry/tasks-agent-pools"
    ],
    nat: [
      "One Standard NAT Gateway can serve multiple subnets in one VNet, with up to 16 IPv4 addresses. Add addresses for SNAT pressure, not monthly GB. It cannot attach to GatewaySubnet.",
      "nat-gateway/nat-gateway-resource"
    ]
  };
  guide["backing-search"] = guide.search;
  guide["backing-storage"] = guide.storage;
  guide["application-vault"] = guide["foundry-vault"];
  guide.jumpbox = [
    "The sourced D2s_v3 has 2 vCPU / 8 GiB. Move to a larger VM when operator tools exhaust CPU or memory, not as chat users grow. Check the series retirement notice before a new deployment.",
    "virtual-machines/sizes/general-purpose/dsv3-series"
  ];
  guide["jumpbox-disk"] = [
    "The 250 GiB request uses the 256 GiB S15 tier. Consider Standard SSD for responsive interactive tools, Premium SSD for higher IOPS/low latency. Increasing GB alone is not the only performance choice.",
    "virtual-machines/disks-types"
  ];
  guide.dns = [
    "Share one private zone per DNS namespace across matching services. This reference has 15 zones. Azure supports 25,000 record sets per private zone, check records and VNet links before creating duplicate zones.",
    "dns/private-dns-privatednszone"
  ];
  for (const id of ["aca-environment", "frontend-app", "extra-frontends", "orchestrator-app", "ingestion-app"]) {
    guide[id] = guide.compute;
  }
  guide.embeddings = [
    "Size embedding quota for peak ingestion TPM, not corpus GB. Budget initial ingestion separately from refresh. Re-embedding the full corpus costs more than embedding changed chunks only.",
    "ai-foundry/openai/how-to/quota"
  ];
  guide["backing-cosmos"] = [
    "Confirm the service-created throughput first. For provisioned capacity, consider increasing RU/s when multiple partitions stay at 100% normalized RU and 429s exceed 5%. One hot partition needs partition-key investigation, not blindly more RU/s.",
    "cosmos-db/monitor-normalized-request-units"
  ];
  for (const row of rows) {
    const item = guide[row.id];
    if (item) {
      row.sizing = `<strong>${item[0].split(". ")[0]}.</strong> ${item[0].split(". ").slice(1).join(". ")}`;
      row.sizingURL = learn + item[1];
    }
    if (row.id.startsWith("pe-")) {
      row.sizing = "<strong>Use one endpoint per resource/subresource for this shared DNS design.</strong> Extra private IPs do not mean extra endpoints. Reserve subnet IP headroom, do not add duplicate endpoints to increase service throughput.";
      row.sizingURL = learn + "private-link/private-endpoint-overview";
    }
    if (row.id === "logs") {
      row.sizingURL = learn + "azure-monitor/logs/cost-logs";
      row.signal = "Commitment minimum term: 31 days.";
      row.detail += " Compare tiers using the workspace Usage and estimated costs view. Commitment tiers start at 100 GB/day and lock the selected level for 31 days. The floor is not an automatic break-even threshold.";
    }
    if (["insights", "monitor", "ampls"].includes(row.id)) {
      row.sizing = row.id === "ampls" ?
        "<strong>No compute tier to scale.</strong> This reference connects the workspace and Application Insights through one scope and one private endpoint. Their five DNS zones are already counted, not one zone per log table." :
        "<strong>Use the shared Log Analytics ingestion budget.</strong> Add the selected diagnostic categories and application telemetry to its GB/day estimate, not a second copy of the same ingestion. Alerting, tests and longer retention are separate.";
      row.sizingURL = learn + "azure-monitor/logs/cost-logs";
    }
    if (row.id === "network") row.sizingURL = learn + "bastion/configuration-settings";
    if (row.id === "gateway-ip" || ["firewall-ip", "firewall-management-ip", "nat-ip", "bastion-ip"].includes(row.id)) {
      row.sizing = "<strong>Allocate one address for each listed frontend/egress role.</strong> Keep Standard static IPv4 for this reference. Scaling requests does not require one public IP per app replica.";
      row.sizingURL = learn + (row.id === "nat-ip" ? "nat-gateway/nat-gateway-resource" : "bastion/configuration-settings");
    }
  }
  return rows;
};
