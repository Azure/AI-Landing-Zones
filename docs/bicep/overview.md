# Bicep foundation overview

The AI Landing Zone Bicep foundation is maintained in
[Azure/agent-landing-zone under `infra/`](https://github.com/Azure/agent-landing-zone/tree/main/infra).
It is repository-owned source, reviewed and released with Agent Landing Zone,
alongside application composition, service configuration and deployment hooks.
Run the lifecycle from the Agent Landing Zone repository root, not `infra/`.

![Architecture Diagram](https://raw.githubusercontent.com/Azure/agent-landing-zone/main/infra/media/Architecture%20Diagram.png)

## Deployment modes

The network design is distinct from the Agent application's orchestrator topology.
`deploymentMode` records intent; explicit flags and resource IDs determine the
actual resources, routing and reuse.

| Foundation shape | Intent | Reference |
| --- | --- | --- |
| Self-contained | `standalone`; public service endpoints or an explicitly isolated local network | [Standalone network](standalone.md) |
| Existing hub integration | `ailz-integrated`; explicit private networking, hub routing, peering, DNS and shared-service inputs | [Hub-and-spoke network](hub-and-spoke.md) |

The hub test fixture is not a third production topology. Neither preset
automatically supplies an operational hub, DNS resolver or connected deployment
host.

## What gets deployed

Enabled parameters select Foundry/model services, workload data services,
container runtimes, configuration/secrets, observability, network resources and
optional add-ons. Service-specific conditions and existing-resource inputs
determine which are created, reused or omitted.

Infrastructure-only provisioning can leave selected Container Apps running
placeholder images; these are not the deployed Agent Application.
Foundry Agent Service backing resources are distinct from workload data stores. Review the
[resource inventory and cost scenarios](deployed-resources.md) for foundation
scope and the [parameter reference](parameterization.md) for supported inputs.
Do not infer the selected application footprint from native Bicep defaults alone.

## Access and validation

Managed identities and scoped role assignments provide service-to-service
access; [Permissions](permissions.md) describes the foundation's default
assignments. Effective application grants depend on the selected definition,
capabilities and topology.

The preprovision hook checks inputs, BYO resource references, network constraints
and regional readiness. A passing check is not proof of regional capacity,
private DNS resolution, data-plane authorization or application readiness.
Resolve findings instead of skipping the checks.

## Use the canonical runbooks

- [Deploy infrastructure only](../agent-landing-zone/deploy-infra-only.md)
  — provision the incorporated foundation without application image deployment.
- [Deploy the full stack](../agent-landing-zone/deploy-full-stack.md)
  — deploy the Agent foundation and selected application.

For implementation details, see [Bicep deployment considerations](how-to-deploy.md),
[parameterization](parameterization.md) and
[Application Gateway ingress](public-ingress.md).
