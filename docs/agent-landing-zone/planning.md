# Deployment choices

Deployment design covers **network ownership, deployment tooling and resource
selection**. It is separate from whether a runbook stops at infrastructure or
also deploys application code.

[How it works](how-it-works.md) introduces the concepts and input formats.
This page explains design choices, not their execution order.
[Deploy infra only](deploy-infra-only.md) and
[Deploy full stack](deploy-full-stack.md) are the deployment runbooks;
[Sizing and capacity](sizing.md) and [Cost planning](cost-planning.md)
cover capacity and spending.

<span id="choose-the-network-and-gateway-shape"></span>

## Network and gateway design

An Azure **virtual network (VNet)** contains private address ranges and
**subnets**, smaller ranges assigned to services. **Domain Name System (DNS)**
resolution turns a service hostname into an IP address. A **hub** is a shared
network; a **spoke** is a workload network connected to it. **Peering** connects
VNets, while routes determine where traffic goes. **Egress** means outbound
traffic. A **NAT gateway** translates private outbound addresses to a public
address.

| Choice | Purpose | Configuration and dependencies |
| --- | --- | --- |
| Standalone (default) | The workload team owns its network, DNS and operations, without a platform hub dependency. | `DEPLOYMENT_MODE=standalone`. Public endpoints are the default; `NETWORK_ISOLATION=true` adds private networking, with egress, private DNS and a connected deployment host. |
| Hub integration | A platform team owns shared connectivity, firewall, DNS or monitoring. | `DEPLOYMENT_MODE=ailz-integrated` plus explicit isolation, peering, routing, DNS and reuse inputs. Spoke resources can be omitted where the hub supplies them. |
| AI Gateway | Multiple workloads need centrally governed model access, such as routing, authentication or token policies. | The separate [AI Gateway implementation](../index.md#ai-gateway-landing-zone) has its own endpoint, authentication, supported APIs, policies and network requirements. Agent Bicep does not deploy or connect it automatically. |

AI Gateway governs model access and can accompany either network topology.
Workload connectivity and user/document authorization remain separate requirements.
[Application Gateway](application-gateway.md) serves a different purpose:
optional web application firewall (WAF) protection for access to the web UI.

Hub integration needs agreement with the platform team on:

- **Routes and peering:** owners for both directions and a hub ID in
  `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID`. Egress uses either
  `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` or
  `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID`, not both, with matching
  return routes and gateway-transit settings.
- **Spoke resources:** `DEPLOY_AZURE_FIREWALL`, `DEPLOY_BASTION` and
  `DEPLOY_NAT_GATEWAY` can be disabled where the hub supplies those services
  under agreed ownership.
- **DNS:** template-owned zones, supported
  `EXISTING_PRIVATE_DNS_ZONE_*_RESOURCE_ID` inputs, or
  `POLICY_MANAGED_PRIVATE_DNS=true`. Policy-managed DNS and bring-your-own
  (BYO) zone IDs are alternative modes. Zone owners must supply the required
  links/forwarding;
  peering alone does not propagate DNS.
- **Runner:** the host that executes deployment commands needs private
  connectivity and service DNS resolution. This connection is
  required separately from the private Azure Container Registry (ACR) pool
  used for image builds. The registry stores those images.

See [Network isolation](network-isolation.md) for connectivity requirements and
[hub-and-spoke design](../bicep/hub-and-spoke.md) for supported network settings.

<span id="choose-the-deployment-tool"></span>

## Deployment tooling

Azure **role-based access control (RBAC)** grants an identity a role at a
resource scope. Deployment roles can differ from application data-access roles.

| Tool | Available path | Boundary to understand |
| --- | --- | --- |
| Bicep with `azd` (default) | [Deploy infra only](deploy-infra-only.md) or [Deploy full stack](deploy-full-stack.md). | The Agent Application workflow includes parameter composition, service configuration, RBAC and hosted image preparation. Deployment uses the platform's own `infra/`, not a separate upstream checkout. |
| Terraform | [Terraform overview](terraform.md). | Infrastructure building blocks, not parity with the Agent platform lifecycle. `terraform apply` does not deploy/configure the Agent Application. Security settings and state need separate review and protection. |
| Azure portal | [Portal overview](portal.md). | ARM-based infrastructure with its own defaults and platform-integration behavior. It can create placeholder application resources; it does not execute Agent platform hooks or the hosted image/version workflow. |

The [Deploy infra only](deploy-infra-only.md) runbook distinguishes the
independent Bicep infrastructure from the Agent platform.
Different implementations are not interchangeable owners of the same
environment; resource reuse needs explicit state and dependency ownership.

## Resource group ownership

The default remains one workload resource group. The optional
[resource group destinations](configuration.md#resource-group-destinations)
separate application, Foundry/grounding and workload networking ownership,
with one, two or three distinct groups in the same subscription. This is an
**Agent Bicep/azd feature available from v4.4.0**, not a Terraform or portal parity claim.
Network isolation and hub/BYO integration remain separate decisions.

Agree names, owners, scoped deployment/RBAC/data permissions and retention
before a new deployment. Prefer pre-created groups when the deploying identity
must not create groups at subscription scope. Optional creation is explicit
and off by default for additional destinations. One root provisioning workflow
coordinates the groups; three independent manual deployments are not required.
Existing-environment migration and automatic deletion of shared groups are
outside this feature.

<span id="select-reuse-or-omit-resources"></span>

## Resource selection and reuse

The selected application's definition and generated `infra/main.parameters.json`
describe the resolved resources. The default is **`hosted-no-panel`**, with
`maf_lite` orchestration and native Foundry IQ Blob ingestion.

| Resource family | Selection or reuse decision |
| --- | --- |
| Agent Application hosts and stores | Fresh environments use `DEPLOYMENT_TOPOLOGY=hosted-no-panel`: hosted orchestrator, frontend, no panel and no Agent Application Cosmos DB. [Agent hosting](hosted-agents.md) explains this layout's capabilities and limits. Existing selections are retained unless explicitly changed. |
| Agent App Ingestion | `DEPLOY_INGESTION_CONTAINER_APP=false` is the fresh default for native Blob ingestion. The optional component supports custom processing and conversation uploads; [Ingestion](ingestion.md) describes those requirements and independently populated indexes. Omitting the component leaves existing resources and grants in place. |
| Search, Storage and Foundry agent backing services | Agent Application Search/Storage and Agent Service backing resources are separate. Where enabled and not reused, Agent Service can add another Search, Storage and Cosmos DB. Native parameters `aiSearchResourceId`, `aiFoundryStorageAccountResourceId` and `aiFoundryCosmosDBAccountResourceId` reuse a dedicated backing trio for the same Foundry instance, not arbitrary shared workload stores. |
| Network and access infrastructure | `USE_EXISTING_VNET=true` requires `EXISTING_VNET_RESOURCE_ID` and agreed subnet/delegation ownership for `DEPLOY_SUBNETS`. Supported jumpbox, Bastion and NAT reuse have their own `EXISTING_*` inputs. Existing VNet peerings are externally managed. |
| Monitoring | Supported existing Log Analytics/Application Insights inputs require workspace compatibility, owner agreement and the intended private monitoring path. Mixing sources is not a substitute for those requirements. |
| Optional add-ons | Speech, Bing grounding and public ingress require explicit selection. Disabling a service is not a reuse mechanism and can break its consumers. |

The Foundry backing IDs above are **native root `main.parameters.json`
parameters**, not automatically mapped `azd` environment variables. See
[Deployment settings](configuration.md) for mapped inputs and
[the shared inventory](../bicep/deployed-resources.md) for broader resource detail.
`DEPLOY_AAF_AGENT_SVC` is required by the default Foundry hosting path, not an
optional resource-count reduction.

<span id="check-readiness-before-deployment"></span>

## Deployment readiness

A deployment plan identifies the platform Git commit or release tag, selected
application, topology, enabled/reused services, regions and
[naming inputs](resource-naming.md). A Git commit identifies the exact code;
the manifest records the compatible component code. The environment also
records the selected application definition, as explained in
[How it works](how-it-works.md#parameters-describe-the-environment).

Readiness includes regional service/model quota, supported
[host capabilities](hosted-agents.md) and resource-creation permissions.
Role assignment needs additional scoped permissions; Contributor alone is
insufficient. Hosted authoring needs project data-plane access. Hub and DNS
access requires approval from the resource owners.

Private deployments additionally require working runner DNS and routes.
Transport Layer Security (TLS) encrypts connections and verifies service
certificates. Native Blob shared links need administrator approval.
Sign-in and retrieval
validation includes both allowed and denied users, not only endpoint access.
The runbooks include these checks, the deployment preview and the execution
sequence for the reviewed capacity and cost plan.
