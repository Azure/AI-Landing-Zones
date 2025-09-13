# AI Landing Zone Bill of Materials (BoM)

The AI Landing Zone Service Inventory is a curated list of Azure services that form the architecture of the AI Landing Zone. It defines which services are deployed by default, which are feature-flagged, and how they align across Bicep, Terraform, and Portal implementations. This inventory ensures consistency, feature parity, and modularity across deployment options, supporting both generative and non-generative AI workloads.

## Service Inventory
| Category | Service | Purpose | Deploy Default | Feature Flag | Notes |
|----------|---------|---------|----------------|--------------|-------|
| Core AI  | Azure AI Foundry Hub / Project | Model catalog, prompt flow, orchestration | Yes | Hub add-ons | Multi-project supported |
| Core AI  | Azure OpenAI deployments | LLM & embedding models | Yes | Extra models / regions | PTU + PAYGO pairing |
| Orchestration | Azure Container Apps | Agent / API services hosting | Yes | GPU workload profile | Scale rules standardized |
| Gateway | Azure API Management | GenAI gateway, routing, auth, usage control | Yes | Multi-region | Token & latency policies |
| Security | Key Vault | Secrets, keys, certs | Yes | HSM / CMK | Rotation automation |
| Data | Cosmos DB | Chat state, agent memory, RAG metadata | Yes | Analytical store | Multi-region optional |
| Data | Azure AI Search | Vector & hybrid search | Optional | Enabled for RAG | Alternative to Cosmos vector |
| Data | Storage Account | Artifacts, logs, prompt assets | Yes | – | Lifecycle rules |
| Networking | Private Endpoints | Private access to PaaS | Yes | – | All supported services |
| Networking | Application Gateway / Front Door + WAF | Ingress & protection | Yes | Additional region | TLS, routing |
| Networking | Azure Firewall | Egress filtering | Optional | Enabled when internet egress restricted | Manifest-driven rules |
| Monitoring | Log Analytics Workspace | Central logs & metrics | Yes | – | Regional pairing guidance |
| Monitoring | Application Insights | App telemetry | Yes | – | Linked to workspace |
| Governance | Service Groups (Preview) | Cross-subscription grouping | Optional | Enabled in pilot | Auto registration |
| Governance | Azure Policy Initiatives | Guardrails | Yes | – | Policy as code |
| DevOps | Container Registry | Image storage | Yes | Geo-replication | Signed images |
| DevOps | CI/CD (GitHub / ADO) | Pipelines & evaluations | Yes | – | Templates provided |

## Service Configuration

This section normalizes service-level configuration across the Terraform pattern [(`terraform-azurerm-avm-ptn-aiml-landing-zone`)](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone) and the Bicep pattern [(`bicep-avm-ptn-aiml-landing-zone`)](https://github.com/Azure/bicep-avm-ptn-aiml-landing-zone). For each service, we list: purpose, object/parameter mapping, deploy flags, principal configuration domains, notable defaults, and recommended adjustments. Only salient (landing-zone-shaping) parameters are included—fine‑grained, rarely changed properties (e.g., individual Application Gateway path rule details) remain the source of truth in upstream pattern docs.

### Legend / Cross-Cutting
- Deploy Toggle (Bicep): `deployToggles.*` (e.g. `deployToggles.apim`). Terraform typically uses an object-level `deploy` bool or optional presence.
- Reuse (BYOR): Terraform: `existing_resource_id` inside each `*_definition` map entry or higher-level `resource_id`; Bicep: `resourceIds.*` or per-object `existingResourceId` plus `shareResources.*` for shared backing services.
- Role Assignments: Both patterns accept a map keyed arbitrarily → object containing `role_definition_id_or_name` (Terraform) / `roleDefinitionIdOrName` (Bicep), `principal_id` / `principalId`, with optional conditional, skip AAD check, delegated managed identity, principal type, description.
- Network Isolation: Common flags: `public_network_access_enabled` (Terraform) / `publicNetworkAccessEnabled` (Bicep); private endpoints and `private_dns_zone_resource_id(s)` (Terraform) / `privateDnsZoneResourceId(s)` (Bicep); VNet injection handled centrally via `vnet_definition` / `vnetDefinition` and subnet references.
- Local Auth Hardening: Many services default to local auth disabled in Bicep pattern (secure-by-default) and may be enabled in Terraform BYOR maps (check before enabling for production). Key fields: `disable_local_auth`, `local_authentication_enabled`, `shared_access_key_enabled`.
- Observability: `enable_diagnostic_settings` (Terraform) / `enableDiagnosticSettings` (Bicep); central Log Analytics reference via `law_definition` / `lawDefinition` or existing workspace id; Application Insights typically auto-linked.
- High Availability / Scale: Zone redundancy flags (`zone_redundancy_enabled`, `zoneRedundant`), replica/partition counts (Search), capacity units (APIM), autoscale or SKU constructs (Application Gateway, Model deployments).

---

### Virtual Network
| Aspect | Terraform | Bicep | Notes |
|--------|-----------|-------|-------|
| Object | `vnet_definition` | `vnetDefinition` | Provides address space, subnets, peering, and optional VWAN hub peering. |
| Peering | `vnet_peering_configuration`, `vwan_hub_peering_configuration`, separate `hub_vnet_peering_definition` | `hubVnetPeeringDefinition` | Use only when integrating with platform landing zone hub. |
| Subnets | Map with `enabled`, `address_prefix`, etc. | Same conceptual map | Each downstream service consumes named subnets; keep reserved ranges for private endpoints & firewall. |
| DDoS | `ddos_protection_plan_resource_id` | `ddosProtectionPlanResourceId` | Attach if elevated L3/L4 protection required. |

Recommended: Reserve at least /27 per high-traffic private endpoint set; document growth plan for vector DB / search scaling.

### Azure AI Foundry (Hub & Projects)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object Root | `ai_foundry_definition` | `aiFoundryDefinition` |
| Hub Settings | `ai_foundry` (name, `disable_local_auth`, `allow_project_management`, `create_ai_agent_service`) | `aiFoundryDefinition.hub` | Secure baseline keeps local auth enabled=false where possible. |
| Projects | `ai_projects` map (connections to BYOR) | `aiFoundryDefinition.aiProjects` | Connections resolve new vs existing resource via `new_resource_map_key` / `existing_resource_id`. |
| Model Deployments | `ai_model_deployments` (`model{format,name,version}`, `scale{type,tier,size,capacity}`) | `aiFoundryDefinition.aiModelDeployments[]` | Scale type may be ProvisionedManaged / Serverless – align to quota strategy. |
| BYOR Associated | `ai_search_definition`, `cosmosdb_definition`, `key_vault_definition`, `storage_account_definition` within AI Foundry def | Use shared backing via `shareResources` / separate top-level definitions | Set `create_byor` / `includeAssociatedResources` (Bicep) to reduce duplication. |
| Purge on Destroy | `purge_on_destroy` | `purgeOnDestroy` | Enable only in ephemeral/non-prod. |
| Telemetry | `enable_telemetry` (module-wide) | `enableTelemetry` (per resource) | Leave enabled for usage insights unless policy forbids. |

Defaults & Guidance: Hub SKU `S0`; consider capacity planning when enabling multi-project model eval flows. Enforce tagging for cost allocation at the project level. Use project connections for principle-of-least-privilege secrets retrieval rather than broad role assignments on the hub.

### Azure OpenAI / AI Model Deployments
(Covered inside AI Foundry model deployments.) Ensure version upgrade strategy (`version_upgrade_option` / `versionUpgradeOption`) is set to controlled for regulated workloads. Apply RAI policy names where available.

### Azure API Management (Gateway)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `apim_definition` | `apimDefinition` |
| Deploy Flag | `apim_definition.deploy` | `deployToggles.apim` |
| SKU / Capacity | `sku_root`, `sku_capacity` | `apimDefinition.sku{,Capacity}` | Default Premium x3 (Terraform). Bicep is a similar secure baseline. |
| Multi-Region | `additional_locations[]` | `additionalLocations[]` | Provide zones & capacity for each region; plan for latency-based routing policies. |
| Hostnames & Certs | `hostname_configuration` (management, portal, proxy, scm) + Key Vault refs | Same object | Centralize cert rotation in Key Vault with user-assigned identity. |
| Auth (Portal) | `sign_in`, `sign_up`, `tenant_access` | same | Keep developer portal disabled in prod until hardened. |
| Protocols | `protocols.enable_http2` | `protocols.enableHttp2` | Enable HTTP/2 for latency (idempotent). |
| Role Assignments | Map | Map | Use granular built-in APIM roles rather than Owner. |

Guidance: For GenAI token control, enforce custom policies (rate, quota) in separate named policy fragments; store model endpoints as products with subscription requirements to control usage.

### Application Gateway + WAF Policy
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Gateway Object | `app_gateway_definition` | `appGatewayDefinition` |
| Deploy Flag | `app_gateway_definition.deploy` | `deployToggles.appGateway` |
| SKU / Scale | `sku` or `autoscale_configuration` | `appGatewayDefinition.sku` / `autoscaleConfiguration` | Autoscale recommended; min 2, max sized to peak concurrency. |
| Backend Pools | `backend_address_pools` | same | For Container Apps, prefer internal FQDN over IP for resilience. |
| Routing Rules | `request_routing_rules`, `url_path_map_configurations` | same | Keep rule priorities unique and documented. |
| Probes | `probe_configurations` | same | Short intervals (<=30s) plus 3 threshold for faster failover. |
| WAF Policy | Separate `waf_policy_definition` or `firewall_policy_id` link | `wafPolicyDefinition` or reference ID | Centralize managed rule overrides; start Detection in test → Prevention in prod. |
| SSL/TLS | `ssl_certificates`, `ssl_policy` | same | Enforce `min_protocol_version` TLS1_2; prefer custom policy if legacy ciphers not needed. |

WAF Policy Defaults: Mode `Prevention`, OWASP 3.2 baseline; adjust file upload limit for large embeddings ingestion if needed.

### Azure Firewall & Firewall Policy
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Firewall | `firewall_definition` | `firewallDefinition` |
| Policy | `firewall_policy_definition` | `firewallPolicyDefinition` |
| Network Rules | `network_rules[]` inside policy | `firewallPolicyDefinition.networkRules[]` | Define egress allowlist (OpenAI endpoints, Azure container registry, Microsoft graph). |
| SKU/Tier | `sku`, `tier` | `sku`, `tier` | Use Premium only if TLS inspection required (watch cost). |
| Zones | `zones` default [1,2,3] | `zones` | Maintain multi-AZ for resilience. |

Guidance: Combine firewall route table with UDR directing 0.0.0.0/0 from private subnets to firewall if strict egress is mandated; otherwise, rely on service tags and private endpoints.

### Container Apps Managed Environment
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `container_app_environment_definition` | `containerAppEnvDefinition` |
| Deploy Flag | `.deploy` | `deployToggles.containerAppEnv` |
| Workload Profiles | `workload_profile[]` | `workloadProfiles[]` | Provide Consumption + Dedicated (e.g. D4) baseline; add GPU profile when needed. |
| Zone Redundancy | `zone_redundancy_enabled` | `zoneRedundancyEnabled` | Keep enabled for prod latency-critical agents. |
| Internal LB | `internal_load_balancer_enabled` | `internalLoadBalancerEnabled` | True by default for private ingress; expose via App Gateway/APIM. |
| Diagnostics | `enable_diagnostic_settings` | `enableDiagnosticSettings` | Always send logs to Log Analytics for autoscale tuning. |
| App Logs | `app_logs_configuration` | `appLogsConfiguration` | Prefer Log Analytics destination; use sampling for high-traffic chat endpoints. |

Container Apps (per app) are defined separately (`containerAppsList` in Bicep vs downstream module definitions in Terraform) – standardize scale rules (HTTP concurrency, KEDA event sources) and secrets retrieval via Key Vault references.

### Container Registry (ACR)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `genai_container_registry_definition` | `containerRegistryDefinition` |
| Deploy Flag | `.deploy` | `deployToggles.containerRegistry` |
| SKU | `sku` (default Premium) | `sku` | Premium allows geo-rep & private link. |
| Zone Redundancy | `zone_redundancy_enabled` | `zoneRedundancyEnabled` | Enable in primary region for resilience. |
| Network | `public_network_access_enabled` | `publicNetworkAccessEnabled` | Keep false + private endpoints when firewall present. |
| Purge Protection | `soft_delete_retention_in_days`, implicit protections | `softDeleteRetentionInDays` equivalent | Align retention with supply chain audit policy. |
| Local Auth | (not explicitly in snippet) | `adminUserEnabled` (if exposed) | Prefer disabling admin user; use managed identities. |

### Cosmos DB (State / Memory)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `genai_cosmosdb_definition` or BYOR in `cosmosdb_definition` | `cosmosDbDefinition` |
| Deploy Flag | `.deploy` | `deployToggles.cosmosDb` |
| Multi-Region | `secondary_regions[]` | `secondaryRegions[]` | Add at least one read region for global chat distribution; enable automatic failover if HA required. |
| Consistency | `consistency_policy.consistency_level` (Session default) | same | Adjust to Strong only if strict ordering needed (cost/latency). |
| Analytical Store | `analytical_storage_enabled` | `analyticalStorageEnabled` | Enable if using Synapse Link / vector enrichment. |
| Local Auth | `local_authentication_disabled` (true default) | `localAuthenticationDisabled` | Keep disabled (AAD RBAC). |
| Network | `public_network_access_enabled` | `publicNetworkAccessEnabled` | False + private endpoint for production. |

Partition strategy: Pre-create containers for chat sessions, embedding metadata with partition keys (`/sessionId`, `/docCollection`) to avoid hot partitions.

### Azure AI Search (Vector / Hybrid)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `ks_ai_search_definition` (main) or BYOR `ai_search_definition` | `searchDefinition` |
| Deploy Flag | `.deploy` | `deployToggles.search` |
| Capacity | `replica_count`, `partition_count` | same | Adjust replicas for query throughput, partitions for index size—start 2x1. |
| Semantic | `semantic_search_enabled`, `semantic_search_sku` | `semanticSearchEnabled`, `semanticSearchSku` | Enable only when semantic ranking adds value; monitor cost. |
| Local Auth | `local_authentication_enabled` (true default) | `localAuthenticationEnabled` | Consider disabling for enterprise RBAC control. |
| Network | `public_network_access_enabled` (default false) | `publicNetworkAccessEnabled` | Keep false + private endpoint. |

If using Cosmos DB vectors, decide on a single vs dual index strategy (hybrid search vs dedicated vector-only) document per-skill index schema.

### Storage Account
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `genai_storage_account_definition` or BYOR `storage_account_definition` | `storageAccountDefinition` |
| Deploy Flag | `.deploy` | `deployToggles.storage` |
| Replication | `account_replication_type` (ZRS/GRS) | `accountReplicationType` | Use ZRS for low-latency multi-AZ; GRS if DR mandatory. |
| Network | `public_network_access_enabled` (false) | `publicNetworkAccessEnabled` | Keep false; private endpoints per service (blob, file). |
| Shared Keys | `shared_access_key_enabled` (false default in module variant) | `sharedAccessKeyEnabled` | Keep disabled; use SAS only if required, rotate. |
| Endpoints | `endpoints` map | `endpoints` | Enable only required subservices (Blob primarily). |

Lifecycle: Define external blob lifecycle rules (not yet surfaced) for archiving chat transcripts over 90 days.

### Key Vault
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `genai_key_vault_definition` or BYOR `key_vault_definition` | `keyVaultDefinition` |
| Network ACLs | `network_acls` | `networkAcls` | Default deny, allow selected subnets. |
| Public Access | `public_network_access_enabled` (false) | `publicNetworkAccessEnabled` | Keep false; use private endpoint. |
| SKU | `sku` (standard) | `sku` | Upgrade premium only for HSM backed keys. |
| Purge Protection | (inherent; set via soft-delete retention) | `purgeProtectionEnabled` (if exposed) | Must be on for production compliance. |
| Role Assignments | Map | Map | Prefer RBAC over access policies (modern pattern). |

### Log Analytics & Application Insights
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Workspace | `law_definition` | `lawDefinition` |
| Retention | `retention` (30) | `retentionInDays` | Increase to 60–90 for incident forensics; archive beyond. |
| App Insights | (not isolated object—often implicit) | `appInsightsDefinition` (if exposed) | Link to workspace (Continuous Export or DCR). |
| Diagnostic Settings | Per-resource `enable_diagnostic_settings` | `enableDiagnosticSettings` | Ensure categories: `Audit`, `Request`, `ConsoleLogs` (Container Apps), `GatewayLogs` (APIM). |

### Container Apps (Individual Services / Agents)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Definition | (Module composition or separate files) | `containerAppsList[]` | Include image, targetPort, ingress, scale rules, secrets. |
| Ingress | (via YAML/params) | `ingress.external`, `ingress.targetPort` | Keep internal; front with APIM / App Gateway. |
| Scale | KEDA rules (HTTP, CPU) | `scale.rules`, `scale.minReplicas`, `scale.maxReplicas` | Start 1–3 min / 10–15 max, refine with load testing. |
| Identity | Managed identity enabling Key Vault refs | `identity.type/userAssigned` | Use user-assigned for consistent RBAC binding. |

### Bastion / Jump / Build VMs
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Build VM | `buildvm_definition` | `buildVmDefinition` |
| Jump VM | `jumpvm_definition` | `jumpVmDefinition` |
| Bastion | `bastion_definition` | `bastionDefinition` |
| Telemetry | `.enable_telemetry` | `enableTelemetry` | Keep on except in air-gapped scenarios. |
| Hardening | Use baseline image + extension policies | Apply custom script / Defender | Restrict NSG inbound to admin IP ranges only. |

### Network Security Groups (NSGs)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `nsgs_definition` | `nsgsDefinition` |
| Rules | `security_rules` map | `securityRules` | Use service tags (`AzureAIService`, `AzureOpenAI`, `AzureContainerRegistry`) where possible. |
| Timeouts | `timeouts` | `timeouts` | Rarely modified; increase for large rule sets. |

### Private DNS Zones
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `private_dns_zones` | `privateDnsZones` |
| Links | `network_links` | `networkLinks` | Ensure resolution policy stays `Default` unless split-horizon required. |
| Existing RG | `existing_zones_resource_group_resource_id` | `existingZonesResourceGroupResourceId` | Set when central platform owns zones. |

### Web Application Firewall (Standalone Policy)
| Aspect | Terraform | Bicep |
|--------|-----------|-------|
| Object | `waf_policy_definition` | `wafPolicyDefinition` |
| Managed Rule Set | `managed_rules.managed_rule_set` (OWASP 3.2 default) | Same | Track overrides separately (change log). |
| Exclusions | `managed_rules.exclusion` | Same | Limit scope to required parameters (e.g., JSON fields for embeddings). |
| Mode | `policy_settings.mode` (Prevention) | `policySettings.mode` | Start in Detection for initial tuning. |

### Governance & Policy
Azure Policy Initiatives are not parameterized as a simple object in these pattern repos (applied externally or as separate artifacts). Maintain versioned policy set definitions referencing resource naming, network, data exfiltration restrictions, and AI model approval tags.

### Telemetry & Tagging
| Concern | Terraform | Bicep | Recommendation |
|---------|-----------|-------|---------------|
| Module Telemetry | Root `enable_telemetry` | Global per-resource `enableTelemetry` | Keep enabled; aggregate usage for sizing budgets. |
| Tags | Root `tags` + per-resource maps | `tags` maps | Enforce mandatory keys: `env`, `owner`, `costCenter`, `dataClass`, `pii`. |

### Security Baseline Quick Reference
- Disable public network access everywhere unless explicitly required for controlled ingress (APIM, App Gateway public IP, optional Firewall PIP).
- Prefer private DNS zones for all PaaS endpoints; ensure zone links are established before deploying dependent services to avoid resolution race.
- Enforce Microsoft Entra ID RBAC (disable local/shared keys) for Storage, Cosmos DB, Key Vault, Search. Rotate any remaining keys via automation.
- Use managed identity for all outbound calls from Container Apps and automation scripts; avoid embedding keys/secrets.
- Centralize egress filtering either with Azure Firewall or service tags + NSGs; document exceptions.

### Performance & Scale Notes
- Model Deployments: Monitor token throughput; adjust `scale.capacity` or switch to ProvisionedManaged for predictable high load.
- Search: Increase replicas for query latency, partitions for index size. Rebalance before major ingestion events.
- Cosmos DB: Monitor RU consumption; use autoscale (if enabled upstream) or plan throughput increments aligned with traffic waves.
- Container Apps: Start with HTTP concurrency 100 (if using KEDA HTTP scaler) and adapt after load test.

### Operational Recommendations
- Maintain an IaC parameter catalog (this document) versioned alongside deployment pipelines.
- Use environment-specific parameter overlays (dev/stage/prod) that differ only where required (e.g., capacity, retention, feature flags).
- Implement drift detection (e.g., nightly `terraform plan` or Bicep what-if) and alert on configuration divergence from declared state.
- Capture WAF rule overrides and APIM policy revisions in the changelog for auditing.

---
