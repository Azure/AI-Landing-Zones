# Agent Landing Zone What's new

Release highlights, grouped by month with the newest releases first.
Select a version to read its full release notes. For current deployment
instructions, see [Deploy full stack](deploy-full-stack.md).

## October 2026

### [v5.3.0](https://github.com/Azure/agent-landing-zone/releases/tag/v5.3.0) - 27 October

- Added all twelve architecture subnets to the defaults for isolated
  deployments, including dedicated Power Platform and AI Gateway subnets.
- Added individual subnet creation switches, configurable names and address
  ranges, and checks for existing-network compatibility.
- Separated application private endpoints from Foundry and grounding private
  endpoints by default. Existing deployments are not automatically migrated.

<span id="simpler-hosted-deployment"></span>

### [v5.2.0](https://github.com/Azure/agent-landing-zone/releases/tag/v5.2.0) - 27 October

- Simplified hosted deployment to `azd provision` followed by `azd deploy`,
  or a single `azd up`. No separate image-preparation command or second
  provision is required.
- Added automatic image preparation during deployment: reuse generated images
  when their source and startup settings match, and rebuild them when needed.
- Preserved operator-provided immutable images and the existing private-build,
  runtime-permission and deployment checks.

### [v5.1.1](https://github.com/Azure/agent-landing-zone/releases/tag/v5.1.1) - 27 October

- Fixed SharePoint permission synchronization when document content has not
  changed. Permission grants, revocations and inherited file permissions now
  update existing indexed content without reprocessing it.
- Added retries for incomplete permission reads and failed Search updates.

### [v5.1.0](https://github.com/Azure/agent-landing-zone/releases/tag/v5.1.0) - 27 October

- Added optional outbound network requirements to application component
  definitions, with a plan operators can review before provisioning.
- Added automatic reconciliation of application-owned Azure Firewall rules
  while preserving unrelated rules. Externally managed firewalls receive a
  report rather than automatic changes.
- Declared the tokenizer download endpoint required by the orchestrator and
  ingestion components.

### [v5.0.0](https://github.com/Azure/agent-landing-zone/releases/tag/v5.0.0) - 27 October

- Made Foundry and grounding the deployment root, with separate resource
  groups for application and networking resources by default in new environments.
- Aligned deployment, image builds, identities and configuration with each
  resource group's ownership.
- Preserved existing destination mappings. Changing the deployment-root
  ownership of an existing split environment requires a new environment.

### [v4.4.0](https://github.com/Azure/agent-landing-zone/releases/tag/v4.4.0) - 27 October

- Added configurable resource-group destinations for the application,
  Foundry/grounding and networking through one provisioning workflow.
- Added optional dedicated application private-endpoint subnet settings.
- Added destination binding checks and explicit cleanup requirements for
  deployments spread across resource groups.

<span id="14th-october-2026"></span>
<span id="ingestion-and-private-connectivity"></span>

### [v4.3.0](https://github.com/Azure/agent-landing-zone/releases/tag/v4.3.0) - 14 October

- Made native Foundry IQ ingestion the default for fresh supported
  deployments; the separate ingestion application became an explicit choice.
- Added readiness checks for Search shared private links used by private
  native Blob ingestion, plus opt-in firewall DNS proxy configuration.
- Updated upload controls when the ingestion application is disabled and
  completed package-feed access for isolated image builds.

### [v4.2.3](https://github.com/Azure/agent-landing-zone/releases/tag/v4.2.3) - 14 October

- Updated hosted UI API and conversation compatibility, and added opt-in
  verified App Configuration and Key Vault transport compatibility.
- Included deployment fixes for structured environment values, custom
  applications, managed identities, registry access and quota checks.

### [v4.2.2](https://github.com/Azure/agent-landing-zone/releases/tag/v4.2.2) - 9 October

- Updated the validated default UI component to Agent App UI v3.2.1.

### [v4.2.1](https://github.com/Azure/agent-landing-zone/releases/tag/v4.2.1) - 8 October

- Renamed the hosted user-identity impersonation role to use Agent Landing
  Zone naming, with setup updating the role in existing environments.
- Updated evaluation automation and documentation for the Agent Landing Zone
  name and broader conversational-agent scope.

### [v4.2.0](https://github.com/Azure/agent-landing-zone/releases/tag/v4.2.0) - 6 October

- Completed the App Configuration label transition: runtime components read
  only the `agent-lz` label.
- Aligned component versions and documentation with Agent Landing Zone naming.

### [v4.1.3](https://github.com/Azure/agent-landing-zone/releases/tag/v4.1.3) - 6 October

- Fixed first-run `azd up` failures caused by missing generated parameter inputs.
- Kept automatically regenerated infrastructure parameters out of normal
  Git working-tree changes.

### [v4.1.2](https://github.com/Azure/agent-landing-zone/releases/tag/v4.1.2) - 6 October

- Fixed fresh deployment failures by aligning application-definition source
  commits with the component commits in the release manifest.

### [v4.1.1](https://github.com/Azure/agent-landing-zone/releases/tag/v4.1.1) - 6 October

- Enabled the private ACR Tasks build pool by default when network isolation
  is enabled, with an early deployment check if the pool is missing.
- Fixed keyless UI-to-orchestrator authentication for the default
  system-assigned frontend identity.

### [v4.1.0](https://github.com/Azure/agent-landing-zone/releases/tag/v4.1.0) - 6 October

- Added managed-identity authentication from the UI to the orchestrator in
  classic deployments.
- Made the orchestrator API key optional instead of a chat prerequisite.

<span id="3rd-october-2026"></span>

### [v4.0.0](https://github.com/Azure/agent-landing-zone/releases/tag/v4.0.0) - 3 October

- Renamed GPT-RAG to **Agent Landing Zone**, with renamed application
  components and documentation on the central AI Landing Zones site.
- Separated foundation deployment from application deployment, supporting
  infrastructure-only and full-application scenarios.
- Brought the foundation infrastructure into this repository as owned source.
  This release required a new deployment rather than an in-place GPT-RAG upgrade.

## September 2026

These releases were published under the former **GPT-RAG** name.

### [v3.8.11](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.11) - 28 September

- Added guidance for the Key Vault permissions needed to resolve application
  configuration secrets, and for client-secret expiry and rotation.
- Documentation-only release; runtime code was unchanged.

### [v3.8.10](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.10) - 25 September

- Fixed the hosted-agent deployment hook path for azd 1.34 and later.
- Clarified where UI OAuth settings and Key Vault secret references belong.

### [v3.8.9](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.9) - 25 September

- Fixed provisioning failures when an existing Cosmos DB account uses
  continuous backup.
- Updated the foundation to AI Landing Zone v2.7.3.

### [v3.8.8](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.8) - 25 September

- Replaced the temporary foundation hotfix with the published AI Landing Zone
  v2.7.2 release.

### [v3.8.7](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.7) - 25 September

- Included a temporary foundation hotfix, subsequently replaced by v3.8.8
  after that foundation version was withdrawn.

### [v3.8.6](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.6) - 25 September

- Fixed ingestion image builds by updating the ingestion frontend lockfile.

### [v3.8.5](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.5) - 22 September

- Replaced the jumpbox declaration requirement with checks of actual private
  DNS resolution, TCP connectivity and TLS certificates.
- Applied the checks at the relevant configuration, deployment and image-build
  stages, and tightened selected-environment loading.

### [v3.8.4](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.4) - 21 September

- Automated the limited runtime permissions needed by the deployed hosted
  agent identity.
- Added a greeting check before switching the UI to a hosted agent and
  improved hosted-version discovery.

### [v3.8.3](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.3) - 3 September

- Fixed administrative-panel exposure in hosted deployments that did not
  enable the panel.
- Hardened panel startup checks and feedback handling.

### [v3.8.2](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.2) - 3 September

- Fixed ingestion container startup and authorized citation downloads.
- Delivered the corrected component combination for the v3.8 hosted-default
  deployment cycle, replacing v3.8.0 and v3.8.1 for deployment.

### [v3.8.1](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.1) - 3 September

- Fixed the orchestrator frontend image build. Superseded by v3.8.2, which
  also corrected ingestion startup.

### [v3.8.0](https://github.com/Azure/agent-landing-zone/releases/tag/v3.8.0) - 3 September

- Introduced Foundry-hosted agents as the default for new deployments, with
  explicit classic, hosted-with-panel and hosted-without-panel choices.
- Added optional message-content capture in Application Insights, hosted
  administrative-panel integration and an isolated hosted-agent deployment project.
- Superseded by v3.8.2 for deployment because of component build and startup fixes.

## Earlier releases

For releases before September 2026, see the
[complete release history](https://github.com/Azure/agent-landing-zone/releases).
