# Deployment choices

Decide **where the workload connects, which deployment tool owns it and what
resources it needs** before provisioning. Capacity and spending are separate
steps: [Sizing and capacity](sizing.md), then [Cost planning](cost-planning.md).

## Choose the network and gateway shape

| Choice | Use it when | What you must arrange |
| --- | --- | --- |
| Standalone | The workload team owns its network, DNS and operations, without a platform hub dependency. | `DEPLOYMENT_MODE=standalone`. Choose public service endpoints or `NETWORK_ISOLATION=true` explicitly; standalone does not mean public. For private deployments, plan egress, private DNS and a connected runner. |
| Integrate with a hub | A platform team already owns connectivity, firewall, DNS or monitoring. | `DEPLOYMENT_MODE=ailz-integrated` plus explicit isolation, hub peering, routing, DNS and reuse inputs. The mode alone connects nothing and does not suppress duplicate spoke resources. |
| Add AI Gateway | Multiple workloads need centrally governed model access, such as routing, authentication or token policies. | Use the separate [AI Gateway implementation](../index.md#ai-gateway-landing-zone). Agree endpoint/authentication contracts, supported APIs, policies and network reachability with its owner. Agent Bicep does not automatically deploy or wire this gateway. |

AI Gateway is an additional decision, not a third network security mode. It
can accompany a standalone or hub-integrated deployment. It does not replace
Private Link, DNS, firewall controls, Entra ID/OBO or document authorization.
It is also different from [Application Gateway](application-gateway.md), which
provides optional WAF-protected ingress to the web UI.

For a hub, agree these items **before** running the deployment:

- **Routes and peering:** identify both peering owners. Use
  `HUB_INTEGRATION_HUB_VNET_RESOURCE_ID`; choose either
  `HUB_INTEGRATION_EGRESS_NEXT_HOP_IP` or
  `HUB_INTEGRATION_EXISTING_ROUTE_TABLE_RESOURCE_ID`, not both. Confirm return
  routes and any gateway-transit settings.
- **Spoke resources:** disable `DEPLOY_AZURE_FIREWALL`, `DEPLOY_BASTION` or
  `DEPLOY_NAT_GATEWAY` only where the agreed hub design provides the replacement.
- **DNS:** choose template-owned zones, supported
  `EXISTING_PRIVATE_DNS_ZONE_*_RESOURCE_ID` inputs, or
  `POLICY_MANAGED_PRIVATE_DNS=true`. Policy-managed DNS and BYO zone IDs are
  alternative modes. Zone owners must supply the required links/forwarding;
  peering alone does not propagate DNS.
- **Runner:** confirm the deployment host can resolve and reach private
  services for lifecycle hooks. A private ACR build pool does not connect it.

See [Network isolation](network-isolation.md) for the reviewed warnings and
[hub-and-spoke design](../bicep/hub-and-spoke.md) for the shared network contract.

## Choose the deployment tool

| Tool | Available path | Boundary to understand |
| --- | --- | --- |
| Bicep with `azd` | Agent platform [infra-only](deploy-infra-only.md) or [full-stack](deploy-full-stack.md) runbook. | The documented Agent Application workflow, including composition, post-provision configuration, RBAC and hosted image handoff. The platform owns its `infra/`; upstream provenance is not a substitute checkout. |
| Terraform | Separate [Terraform foundation templates](../terraform/index.md). | Strategy is under review. Examples provide foundation building blocks, not parity with the Agent platform lifecycle. `terraform apply` does not deploy/configure the Agent Application. Review example security settings and protect state. |
| Azure portal | Separate [portal wizard](../portal/Readme.md). | ARM-based foundation with its own defaults and platform-integration behavior. It can create placeholder application resources; it does not execute Agent platform hooks or the hosted image/version workflow. |

For the independent Bicep foundation rather than the Agent platform, follow the
source choice in [Deploy infrastructure only](deploy-infra-only.md).
Do not run different deployment implementations over the same environment as
if they were interchangeable. Reuse or migration needs explicit ownership,
state and dependency planning.

## Select, reuse or omit resources

Start from the selected application's definition and composed parameters, not
the shared foundation's all-resources catalog.

| Resource family | Selection or reuse decision |
| --- | --- |
| Agent Application hosts and stores | Fresh environments use `DEPLOYMENT_TOPOLOGY=hosted-no-panel`: hosted orchestrator, frontend, no panel and no Agent Application Cosmos DB. `hosted-panel` adds panel metadata storage; `classic` uses a Container App orchestrator and that database. Existing/migrated resources can remain. See [Agent hosting](hosted-agents.md). |
| Agent App Ingestion | `DEPLOY_INGESTION_CONTAINER_APP=false` is the fresh default. Select this component for supported application-managed processing or conversation uploads. Native Blob ingestion and independently populated indexes have different contracts; see [Ingestion](ingestion.md). Omitting the component does not delete old resources or grants. |
| Search, Storage and Foundry agent backing services | Agent Application Search/Storage and Agent Service backing resources are separate. Where enabled and not reused, Agent Service can add another Search, Storage and Cosmos DB. Native parameters `aiSearchResourceId`, `aiFoundryStorageAccountResourceId` and `aiFoundryCosmosDBAccountResourceId` reuse a dedicated backing trio for the same Foundry instance, not arbitrary shared workload stores. |
| Network and access infrastructure | `USE_EXISTING_VNET=true` requires `EXISTING_VNET_RESOURCE_ID`. Agree subnet/delegation ownership before setting `DEPLOY_SUBNETS`. Supported jumpbox, Bastion and NAT reuse have their own `EXISTING_*` inputs. Existing VNet peerings are externally managed. |
| Monitoring | Use supported existing Log Analytics/Application Insights inputs with their owners. Preserve workspace compatibility and the intended private monitoring path; do not mix sources merely to avoid creating a workspace. |
| Optional add-ons | Speech, Bing grounding and public ingress require explicit selection. Disabling a service is not a reuse mechanism and can break its consumers. |

The Foundry backing IDs above are **native root `main.parameters.json`
parameters**, not automatically mapped `azd` environment variables. See
[Configuration](configuration.md) for mapped inputs and
[the shared inventory](../bicep/deployed-resources.md) for broader resource detail.
Do not disable `DEPLOY_AAF_AGENT_SVC` just to reduce resource count when the
selected hosting/strategy depends on it.

## Check readiness before deployment

1. Record the source revision, application ID, topology, enabled/reused services,
   regions and [naming inputs](resource-naming.md). One azd environment binds to
   one application ID.
2. Confirm regional service/model availability and quota. Hosted strategies,
   history and image preparation have specific [host limitations](hosted-agents.md);
   selecting a host does not select a strategy.
3. Obtain resource creation and scoped role-assignment permissions. Contributor
   alone cannot assign roles. Agree access to shared hub/DNS resources with
   their owners; hosted authoring also needs project data-plane access.
4. Verify runner DNS, routes and TLS, plus administrator approval for private
   native Blob shared links where required. An ARM deployment or greeting is
   not evidence of real-user access or document allow/deny behavior.
5. Review the deployment preview, [size each service](sizing.md), and approve
   a dated [cost plan](cost-planning.md). Then execute
   [Deploy infra only](deploy-infra-only.md) or [Deploy full stack](deploy-full-stack.md).
