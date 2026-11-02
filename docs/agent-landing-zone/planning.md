# Deployment choices

Use this page to choose the infrastructure arrangement before provisioning.
It compares the template's options, not the commands or the application's
behavior. The [overview](index.md) explains what the template delivers.

## Choose an infrastructure provider

<span id="deployment-tooling"></span>
<span id="choose-the-deployment-tool"></span>

| Provider | When to choose it | What to account for |
| --- | --- | --- |
| Bicep, the default | Your team uses Azure-native infrastructure tooling. | Use the product's `azd` workflow for provisioning, service configuration and later updates. |
| Terraform | Your team standardizes on Terraform state and workflows. | Prepare remote storage outside workload teardown and an authorized single-writer process. Native azd disables state locking. Azure validation remains pending. |

Both use the same platform workflow. Direct Bicep deployment or
`terraform apply` does not replace its configuration and validation stages.
Choose the provider before first provision and retain it for updates and removal.
See the [Terraform overview](terraform.md) for its constraints.

The [Azure portal path](portal.md) is a separate infrastructure workflow with
its own defaults. It does not execute the full application deployment.

<span id="network-and-gateway-design"></span>
<span id="choose-the-network-and-gateway-shape"></span>

## Decide who owns the network

| Arrangement | Responsibility | Plan with the owners |
| --- | --- | --- |
| Standalone | The workload team operates its network and connectivity. | Address space, DNS, outbound access and deployment-host connectivity. |
| Integrated with an existing hub | The platform team supplies agreed shared connectivity or services. | Peering in both directions, routes, DNS, service reuse and responsibility for changes. |

Network ownership and public/private access are independent decisions.
Standalone does not mean public. An integration label alone does not connect
a hub or configure its firewall. [Network design](network-isolation.md)
explains the required connectivity.

## Decide how services are reached

Use **private networking for production and sensitive data**. The template's
isolation default is `false`, so enable the private design explicitly.
Private access needs working DNS, routes and an authorized connected host.

Public service endpoints are only for approved, short-lived evaluations
without sensitive data. Authentication remains necessary but does not make
an endpoint private. Do not remove isolation to work around deployment failures.

## Agree resource ownership and reuse

<span id="resource-selection-and-reuse"></span>
<span id="select-reuse-or-omit-resources"></span>

List the AI services, data stores, compute and monitoring required by the
workload. Decide which supported resources to create or reuse and who
operates them. Reuse requires compatible configuration and explicit ownership,
not just a resource name or a disabled creation flag.

| Area | Decision to record |
| --- | --- |
| Network and DNS | Who manages the VNet, subnets, links, forwarding and routes? |
| Foundry backing services | Will Foundry create its dedicated backing resources or reuse a supported dedicated set for the same instance? They are not arbitrary shared application stores. |
| Monitoring | Who owns the workspace, retention, access and private monitoring path? Reuse requires compatible workspace selections. |
| Optional services | Which consumers actually require them? Omitting a resource can break its consumers and does not remove existing resources or grants. |

### Resource group ownership

New environments use three logical destinations: Foundry/grounding,
application resources and workload networking. They can map to one, two or
three groups in the same subscription. Existing environments retain their mapping.

Agree owners, deployment permissions, retention and cleanup responsibilities
before first provision. Prefer pre-created groups when the deploying identity
must not create them. A single platform workflow coordinates the destinations.
See [resource group inputs](configuration.md#resource-group-destinations)
for defaults, permissions and provider-specific removal rules.

## Choose application behavior and execution host

The foundation can host the reference application **or another application**.
Choose an [application definition](build-your-own-app.md#application-binding-and-selection)
before first provision. Custom definitions supply their own components and
requirements, not implicit reference UI/orchestrator or SQL tooling.

For the reference application, choose conversation, a published workflow or
both with `APPLICATION_MODE`. Select `ORCHESTRATION_HOST` independently:

| Host | Plan its dependencies |
| --- | --- |
| `hosted` | Official Responses hosting and native Foundry persistence; separate conversational/workflow publications when both are selected |
| `container_apps` | Official Durable Extension worker/client, Durable Task Scheduler, worker availability and scheduler connectivity |

Keep UI/BFF owner mappings, history discovery and feedback separate from native
execution state. Optional product storage is not a second checkpoint engine.
Custom ingestion is disabled by default and is not required merely to retain
metadata or to select a workflow.

Workflow mode, `both`, enabled history,
feedback or private attachments selects UI metadata storage directly.
Product flags default to off; conversational mode then uses bounded volatile
owner maps lost on UI restart.

Private attachments use validated inline native input, not Blob/SAS or
ingestion. They are conversational only; verify model PDF/image understanding
separately from transport.

Confirm compatible published SDK packages, the actual product's native
SDK/contract checks, service availability and trusted user context.
Record supplemental live checks separately. A service identity is not per-user
authorization; local mocks or a public sandbox do not establish deployed
checkpoint durability, user isolation or private-network parity.
See [Agent Application](application.md) and
[native execution selection](configuration.md#native-execution-selection).

## Consider optional gateway integration

AI Gateway governs model access and can accompany either standalone or
hub-integrated networking. It is not a third network topology and is not
deployed or connected automatically. Its endpoint, policies, authentication
and network requirements need separate integration.

[AI Gateway Landing Zone](../ai-gateway-landing-zone/index.md) explains that
option. It does not replace workload networking or user/document authorization.
[Application Gateway](application-gateway.md) has a different purpose:
optional protected public web ingress.

<span id="deployment-readiness"></span>
<span id="check-readiness-before-deployment"></span>

## Review the plan and choose a guide

Use the [Design checklist](../architecture/design-checklist.md) for the
architecture review and the [Sizing & cost planner](sizing-cost-planner.md)
for capacity and budget. Planner scenarios are estimates, not deployment
settings or evidence of deployed provider parity.

Then choose [infrastructure only](index.md#infrastructure-and-application)
or full stack and follow its provider-specific guide. Those guides own the
prerequisites, quota and permission checks, preview, execution and validation.
Use [Deployment settings](configuration.md) when an input needs clarification.
