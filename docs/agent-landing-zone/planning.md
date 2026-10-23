# Deployment choices

Decide **where the workload connects, which deployment tool owns it and what
resources it needs** before provisioning. Capacity and spending are separate
steps: [Sizing and capacity](sizing.md), then [Cost planning](cost-planning.md).

Start with [How it works](how-it-works.md#how-to-read-deployment-settings) for
the deployment flow and the two forms of input used below. Uppercase names
such as `DEPLOYMENT_MODE` are `azd` inputs; set them in the selected environment
with `azd env set`. Record your choices here, then apply them using a deployment
runbook.

## Choose the network and gateway shape

| Choice | Use it when | What you must arrange |
| --- | --- | --- |
| Standalone | The workload team owns its network, DNS and operations, without a platform hub dependency. | Set `DEPLOYMENT_MODE=standalone` and choose service access separately: public endpoints or `NETWORK_ISOLATION=true`. For private deployments, plan egress, private DNS and a deployment host connected to the network. |
| Integrate with a hub | A platform team already owns connectivity, firewall, DNS or monitoring. | Set `DEPLOYMENT_MODE=ailz-integrated`, then supply isolation, peering, routing, DNS and reuse inputs. Select which spoke resources to omit when the hub provides them. |
| Add AI Gateway | Multiple workloads need centrally governed model access, such as routing, authentication or token policies. | Use the separate [AI Gateway implementation](../index.md#ai-gateway-landing-zone). Confirm its endpoint, authentication method, supported APIs, policies and network access with the gateway owner, then plan the application integration. Agent Bicep does not deploy or connect this gateway automatically. |

AI Gateway governs model access and can accompany either network topology.
Plan workload connectivity and user/document authorization separately.
[Application Gateway](application-gateway.md) serves a different purpose:
optional web application firewall (WAF) protection for access to the web UI.

For a hub, confirm the network design with the platform team, then record the
corresponding deployment inputs:

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
- **Runner:** connect the host that executes deployment commands to the
  private network and verify service DNS resolution. This connection is
  required separately from the private ACR pool used for image builds.

See [Network isolation](network-isolation.md) for connectivity requirements and
[hub-and-spoke design](../bicep/hub-and-spoke.md) for supported network settings.

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

Use the selected application's definition and the generated
`infra/main.parameters.json` to identify the resources your deployment selects.

| Resource family | Selection or reuse decision |
| --- | --- |
| Agent Application hosts and stores | Fresh environments use `DEPLOYMENT_TOPOLOGY=hosted-no-panel`: hosted orchestrator, frontend, no panel and no Agent Application Cosmos DB. `hosted-panel` adds panel metadata storage; `classic` uses a Container App orchestrator and that database. Existing/migrated resources can remain. See [Agent hosting](hosted-agents.md). |
| Agent App Ingestion | `DEPLOY_INGESTION_CONTAINER_APP=false` is the fresh default. Select this component for supported application-managed processing or conversation uploads. For native Blob ingestion or an independently populated index, follow the corresponding [Ingestion](ingestion.md) path. Omitting the component leaves existing resources and grants in place. |
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
   history and image preparation have specific [host requirements](hosted-agents.md).
   Choose a strategy supported by that host.
3. Obtain resource creation and scoped role-assignment permissions. Contributor
   alone cannot assign roles. Agree access to shared hub/DNS resources with
   their owners; hosted authoring also needs project data-plane access.
4. Verify runner DNS, routes and TLS, plus administrator approval for private
   native Blob shared links where required. After deploying the Agent
   Application, also test sign-in and retrieval with allowed and denied users.
5. Review the deployment preview, [size each service](sizing.md), and approve
   a dated [cost plan](cost-planning.md). Then execute
   [Deploy infra only](deploy-infra-only.md) or [Deploy full stack](deploy-full-stack.md).
