# Design Checklist

Use this checklist when designing an AI workload landing zone, before approving
a deployment, and when reviewing a significant change. For each applicable row,
record your decision, owner and how you will verify it. Use the deployment
documentation to identify which controls the selected template configures and
which your team needs to implement.

## Compute and cost

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">C-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">Where will models, agents and application components run?</td>
<td role="cell" data-label="Recommendation" markdown="span">Evaluate scaling, network and operational needs separately for models and application components, then choose compute for each. Standardize where their requirements align.</td>
<td role="cell" data-label="References" markdown="span">[Compute decision guide](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">CO-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">What is the workload's monthly cost and usage model?</td>
<td role="cell" data-label="Recommendation" markdown="span">Estimate the selected resources, model tokens, indexing and observability before deployment. Include optional services and separate shared-platform costs.</td>
<td role="cell" data-label="References" markdown="span">[Cost guide](cost-guide.md), [Foundry cost planning](https://learn.microsoft.com/azure/ai-foundry/concepts/manage-costs)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">CO-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">Is model traffic predictable enough for provisioned throughput?</td>
<td role="cell" data-label="Recommendation" markdown="span">Compare measured utilization and commitment costs with pay-as-you-go to choose the lower-cost option for the workload. If using spillover, design gateway routing and test quota exhaustion.</td>
<td role="cell" data-label="References" markdown="span">[Provisioned throughput](https://learn.microsoft.com/azure/ai-services/openai/concepts/provisioned-throughput), [Multi-backend gateway](https://learn.microsoft.com/azure/architecture/ai-ml/guide/azure-openai-gateway-multi-backend)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">CO-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">Which model deployment type meets residency, latency and cost requirements?</td>
<td role="cell" data-label="Recommendation" markdown="span">Compare regional, data-zone and global options for the chosen model. Verify processing-location requirements before choosing a lower advertised token price.</td>
<td role="cell" data-label="References" markdown="span">[Deployment types](https://learn.microsoft.com/azure/ai-services/openai/how-to/deployment-types)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">CO-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">Which nonproduction resources can stop outside working hours?</td>
<td role="cell" data-label="Recommendation" markdown="span">Schedule shutdown only for supported resources that can tolerate downtime. Check disks, networking and other charges that continue while compute is stopped.</td>
<td role="cell" data-label="References" markdown="span">[VM auto-shutdown](https://learn.microsoft.com/azure/virtual-machines/auto-shutdown-vm)</td>
</tr>
</tbody>
</table>
</div>
## Data

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">D-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">Where are agent state, uploaded files and application data stored?</td>
<td role="cell" data-label="Recommendation" markdown="span">Identify the selected Agent Service setup and its backing resources. Record retention, access, backup and deletion requirements separately for each data store.</td>
<td role="cell" data-label="References" markdown="span">[Standard agent setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">D-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">Which resources may be shared across projects?</td>
<td role="cell" data-label="Recommendation" markdown="span">Review supported resource-sharing constraints and choose explicit isolation boundaries. Separate application storage from Agent Service backing storage where required.</td>
<td role="cell" data-label="References" markdown="span">[Capability hosts and backing resources](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/capability-hosts)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">D-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">Does the workload need data from Microsoft Fabric?</td>
<td role="cell" data-label="Recommendation" markdown="span">Evaluate the Fabric data agent's supported access model, permissions and regional availability before selecting it as an agent tool.</td>
<td role="cell" data-label="References" markdown="span">[Fabric data agent tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/fabric)</td>
</tr>
</tbody>
</table>
</div>
## Governance

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">G-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">Which policies apply to the deployed services?</td>
<td role="cell" data-label="Recommendation" markdown="span">Assign relevant built-in or custom policies at the appropriate scope. Review audit results and exemptions before enforcing deny effects.</td>
<td role="cell" data-label="References" markdown="span">[AI services policies](https://learn.microsoft.com/azure/ai-services/policy-reference), [Search policies](https://learn.microsoft.com/azure/search/policy-reference)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">G-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">Which regulatory and organizational obligations apply?</td>
<td role="cell" data-label="Recommendation" markdown="span">Map each obligation to required controls and verification results. Use policy initiatives to assess supported Azure controls and document any additional reviews needed to demonstrate compliance.</td>
<td role="cell" data-label="References" markdown="span">[NIST AI RMF](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf), [Regulatory compliance initiatives](https://learn.microsoft.com/azure/governance/policy/samples/#regulatory-compliance)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">G-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">How will responsible AI risks be evaluated?</td>
<td role="cell" data-label="Recommendation" markdown="span">Define evaluation datasets, human review, acceptance thresholds and escalation for the actual agent tasks. Select evaluation tools that support the models, inputs and outputs in use.</td>
<td role="cell" data-label="References" markdown="span">[Generative AI evaluation](https://learn.microsoft.com/azure/ai-foundry/concepts/evaluation-approach-gen-ai)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">G-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">What content safety controls are needed?</td>
<td role="cell" data-label="Recommendation" markdown="span">Select supported filters and Content Safety APIs for the model and modalities in use. Test prompts, outputs and failure handling. Configure access to tools and documents separately through authorization controls.</td>
<td role="cell" data-label="References" markdown="span">[Content Safety overview](https://learn.microsoft.com/azure/ai-services/content-safety/overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">G-R5</th>
<td role="cell" data-label="Design consideration" markdown="span">Which models may teams deploy?</td>
<td role="cell" data-label="Recommendation" markdown="span">Review the applicable model-deployment policies. Start in audit mode, assess impact, then enforce approved restrictions and remediate existing noncompliant deployments separately.</td>
<td role="cell" data-label="References" markdown="span">[Model deployment policies](https://learn.microsoft.com/azure/ai-foundry/how-to/built-in-policy-model-deployment)</td>
</tr>
</tbody>
</table>
</div>
## Identity and access

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">I-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">How do services authenticate to one another?</td>
<td role="cell" data-label="Recommendation" markdown="span">Prefer managed identity where supported, with narrowly scoped roles for each runtime principal. Keep deployment, project and runtime identities distinct.</td>
<td role="cell" data-label="References" markdown="span">[Managed identities](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">I-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">How is privileged human access controlled?</td>
<td role="cell" data-label="Recommendation" markdown="span">Require MFA and use just-in-time privileged access where available. Use a private administrative path when resources are isolated.</td>
<td role="cell" data-label="References" markdown="span">[MFA](https://learn.microsoft.com/entra/identity/authentication/concept-mfa-howitworks), [Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">I-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">Can clients use Microsoft Entra ID rather than static keys?</td>
<td role="cell" data-label="Recommendation" markdown="span">Use identity-based authentication where supported. Where a key is necessary, store it securely, limit distribution and define rotation and recovery.</td>
<td role="cell" data-label="References" markdown="span">[AI services authentication](https://learn.microsoft.com/azure/ai-services/authentication)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">I-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">Which sign-in conditions should be enforced?</td>
<td role="cell" data-label="Recommendation" markdown="span">Evaluate risk, device and location policies for human access. Configure service authorization for workload identities and test those identities separately from interactive sign-in.</td>
<td role="cell" data-label="References" markdown="span">[Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">I-R5</th>
<td role="cell" data-label="Design consideration" markdown="span">What can each user and service read or modify?</td>
<td role="cell" data-label="Recommendation" markdown="span">Grant minimal control-plane and data-plane permissions at the smallest supported scope. Test retrieval with allowed and denied users to verify document access.</td>
<td role="cell" data-label="References" markdown="span">[Foundry RBAC](https://learn.microsoft.com/azure/ai-foundry/concepts/rbac-azure-ai-foundry)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">I-R6</th>
<td role="cell" data-label="Design consideration" markdown="span">Can local key authentication be disabled?</td>
<td role="cell" data-label="Recommendation" markdown="span">Inventory dependent clients, migrate them to Entra ID and verify their workflows before disabling local authentication where supported.</td>
<td role="cell" data-label="References" markdown="span">[Azure OpenAI managed identity authentication](https://learn.microsoft.com/azure/ai-services/openai/how-to/managed-identity)</td>
</tr>
</tbody>
</table>
</div>
## Monitoring

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">M-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">What signals establish workload health?</td>
<td role="cell" data-label="Recommendation" markdown="span">Define service-level objectives for availability, latency, task outcomes and data freshness. Monitor models, resources and data against those objectives.</td>
<td role="cell" data-label="References" markdown="span">[AI workload management](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/management)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">M-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">Which failures require an alert?</td>
<td role="cell" data-label="Recommendation" markdown="span">Enable applicable baseline alerts, assign a response owner and document the response procedure. Tune thresholds and test alert delivery.</td>
<td role="cell" data-label="References" markdown="span">[Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/patterns/artificial-intelligence/)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">M-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">Can one failed request be traced across dependencies?</td>
<td role="cell" data-label="Recommendation" markdown="span">Correlate application, model and retrieval calls. Protect prompts, documents and user data; content capture must be a deliberate privacy decision.</td>
<td role="cell" data-label="References" markdown="span">[Foundry tracing](https://learn.microsoft.com/azure/ai-foundry/how-to/develop/trace-local-sdk)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">M-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">Which resource logs must be retained?</td>
<td role="cell" data-label="Recommendation" markdown="span">Configure supported diagnostic categories and retention for key services. Confirm that logs reach the intended destination and restrict access to them.</td>
<td role="cell" data-label="References" markdown="span">[Diagnostic settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">M-R5</th>
<td role="cell" data-label="Design consideration" markdown="span">How will quality changes be detected?</td>
<td role="cell" data-label="Recommendation" markdown="span">Re-evaluate representative tasks after model, prompt, tool and data changes. Investigate regressions before deciding whether to change data, prompts or models.</td>
<td role="cell" data-label="References" markdown="span">[Evaluation metrics](https://learn.microsoft.com/azure/ai-foundry/concepts/evaluation-metrics-built-in)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">M-R6</th>
<td role="cell" data-label="Design consideration" markdown="span">Can private connectivity failures be diagnosed?</td>
<td role="cell" data-label="Recommendation" markdown="span">Test DNS, routes, TLS and service authorization separately from the affected network. Use network diagnostics supported by the resource.</td>
<td role="cell" data-label="References" markdown="span">[Network Watcher](https://learn.microsoft.com/azure/network-watcher/network-watcher-overview)</td>
</tr>
</tbody>
</table>
</div>
## Reliability and resource organization

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">R-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">What are the recovery time and recovery point objectives?</td>
<td role="cell" data-label="Recommendation" markdown="span">Plan backup, restore and regional recovery for each stateful dependency. For a secondary region, prepare the required services, data recovery and application routing, then test failover against the recovery objectives.</td>
<td role="cell" data-label="References" markdown="span">[Azure OpenAI continuity](https://learn.microsoft.com/azure/ai-services/openai/how-to/business-continuity-disaster-recovery), [Storage disaster recovery](https://learn.microsoft.com/azure/storage/common/storage-disaster-recovery-guidance), [Cosmos DB backup](https://learn.microsoft.com/azure/cosmos-db/online-backup-and-restore)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">RO-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">Are the required services and models available in the selected regions?</td>
<td role="cell" data-label="Recommendation" markdown="span">Check the current service, model, deployment-type and feature availability references when choosing regions and again before deployment.</td>
<td role="cell" data-label="References" markdown="span">[Products by region](https://azure.microsoft.com/explore/global-infrastructure/products-by-region/), [Model availability](https://learn.microsoft.com/azure/ai-services/openai/concepts/models)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">RO-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">Is there enough quota for every resource to be created?</td>
<td role="cell" data-label="Recommendation" markdown="span">Count all selected service instances, including separate Agent Service backing resources. Validate regional model capacity and request increases before deployment.</td>
<td role="cell" data-label="References" markdown="span">[Azure limits and quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">RO-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">How will growth affect subscription and regional limits?</td>
<td role="cell" data-label="Recommendation" markdown="span">Record capacity headroom, ownership and the process for requesting quota. Run preflight checks and confirm current service capacity when scheduling the deployment.</td>
<td role="cell" data-label="References" markdown="span">[Quota overview](https://learn.microsoft.com/azure/quotas/quotas-overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">RO-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">What are the account, project and billing boundaries?</td>
<td role="cell" data-label="Recommendation" markdown="span">Align Foundry accounts and projects with access, network and operational requirements. Identify which isolation controls apply at account level and which apply at project level.</td>
<td role="cell" data-label="References" markdown="span">[Foundry architecture](https://learn.microsoft.com/azure/ai-foundry/concepts/architecture)</td>
</tr>
</tbody>
</table>
</div>
## Security

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">S-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">Which deployed AI risks can be monitored?</td>
<td role="cell" data-label="Recommendation" markdown="span">Evaluate Defender for Cloud's supported AI posture and threat-protection features, coverage, prerequisites and cost for this workload.</td>
<td role="cell" data-label="References" markdown="span">[AI security posture](https://learn.microsoft.com/azure/defender-for-cloud/ai-security-posture)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">S-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">Which service security controls are required?</td>
<td role="cell" data-label="Recommendation" markdown="span">Map applicable Azure security baselines and Well-Architected guidance to the services actually deployed.</td>
<td role="cell" data-label="References" markdown="span">[Security baselines](https://learn.microsoft.com/security/benchmark/azure/security-baselines-overview), [Service guides](https://learn.microsoft.com/azure/well-architected/service-guides/)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">S-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">How is sensitive data discovered and protected?</td>
<td role="cell" data-label="Recommendation" markdown="span">Assess data classification, oversharing and insider-risk requirements. Evaluate Purview coverage and licensing, and configure retrieval permissions in the source and application authorization paths.</td>
<td role="cell" data-label="References" markdown="span">[Purview Insider Risk Management](https://learn.microsoft.com/purview/insider-risk-management)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">S-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">Which AI-specific attack paths need testing?</td>
<td role="cell" data-label="Recommendation" markdown="span">Threat-model tools, model calls, retrieved content and data access. Use established AI risk frameworks to define tests and mitigations.</td>
<td role="cell" data-label="References" markdown="span">[MITRE ATLAS](https://atlas.mitre.org/), [OWASP generative AI risks](https://genai.owasp.org/)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">S-R5</th>
<td role="cell" data-label="Design consideration" markdown="span">How will prompt injection be handled?</td>
<td role="cell" data-label="Recommendation" markdown="span">Evaluate Prompt Shields for supported inputs and test failures. Keep tool permissions and document authorization enforced independently of model output.</td>
<td role="cell" data-label="References" markdown="span">[Prompt Shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)</td>
</tr>
</tbody>
</table>
</div>
## Networking

<div class="design-checklist responsive-reference" markdown="1">
<table role="table" markdown="1">
<thead role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="col" role="columnheader" markdown="span">ID</th>
<th scope="col" role="columnheader" markdown="span">Design consideration</th>
<th scope="col" role="columnheader" markdown="span">Recommended decision or check</th>
<th scope="col" role="columnheader" markdown="span">References</th>
</tr>
</thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R1</th>
<td role="cell" data-label="Design consideration" markdown="span">Does public ingress need DDoS protection?</td>
<td role="cell" data-label="Recommendation" markdown="span">Identify public endpoints and check the supported protection for each resource type. Reuse platform DDoS protection for eligible public IP resources.</td>
<td role="cell" data-label="References" markdown="span">[DDoS Protection overview](https://learn.microsoft.com/azure/ddos-protection/ddos-protection-overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R2</th>
<td role="cell" data-label="Design consideration" markdown="span">How will operators reach private resources?</td>
<td role="cell" data-label="Recommendation" markdown="span">Use an approved VPN, connected runner or jumpbox. Reuse central Bastion and administrative access where available, keeping VM administration on an approved private path.</td>
<td role="cell" data-label="References" markdown="span">[Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R3</th>
<td role="cell" data-label="Design consideration" markdown="span">Which services require private endpoints?</td>
<td role="cell" data-label="Recommendation" markdown="span">Design private ingress and service-managed outbound links separately. Select networking controls for the Foundry resource type in use: account/project or hub-based. Verify DNS and the intended private path before disabling public access.</td>
<td role="cell" data-label="References" markdown="span">[Foundry private networking](https://learn.microsoft.com/azure/ai-foundry/how-to/configure-private-link)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R4</th>
<td role="cell" data-label="Design consideration" markdown="span">Where should NSGs enforce traffic policy?</td>
<td role="cell" data-label="Recommendation" markdown="span">Apply supported NSG rules to subnets or network interfaces. Preserve service-specific subnet and platform connectivity requirements.</td>
<td role="cell" data-label="References" markdown="span">[Network security groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R5</th>
<td role="cell" data-label="Design consideration" markdown="span">Is a regional or global web application firewall needed?</td>
<td role="cell" data-label="Recommendation" markdown="span">Select Application Gateway or Front Door according to ingress requirements. Verify routing, authentication and backend access as well as WAF rules.</td>
<td role="cell" data-label="References" markdown="span">[Azure WAF](https://learn.microsoft.com/azure/web-application-firewall/overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R6</th>
<td role="cell" data-label="Design consideration" markdown="span">Does the workload need an AI gateway?</td>
<td role="cell" data-label="Recommendation" markdown="span">Evaluate API Management for routing, token controls and authentication. Confirm tier support and configure policies explicitly. Avoid logging raw prompts or responses by default.</td>
<td role="cell" data-label="References" markdown="span">[AI gateway capabilities](https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R7</th>
<td role="cell" data-label="Design consideration" markdown="span">Which outbound traffic must traverse a firewall?</td>
<td role="cell" data-label="Recommendation" markdown="span">Reuse a platform firewall where appropriate. Verify routes, supported service paths and required destinations before enforcing egress restrictions.</td>
<td role="cell" data-label="References" markdown="span">[Azure Firewall](https://learn.microsoft.com/azure/firewall/overview)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R8</th>
<td role="cell" data-label="Design consideration" markdown="span">How will private service names resolve from every client network?</td>
<td role="cell" data-label="Recommendation" markdown="span">Plan zone links, conditional forwarding and connected-network resolution. Configure routes and service permissions alongside DNS so clients can reach and use the resolved endpoints.</td>
<td role="cell" data-label="References" markdown="span">[Private endpoint DNS integration](https://learn.microsoft.com/azure/private-link/private-endpoint-dns-integration)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" markdown="span">N-R9</th>
<td role="cell" data-label="Design consideration" markdown="span">What outbound destinations are allowed?</td>
<td role="cell" data-label="Recommendation" markdown="span">Restrict egress to verified service and build dependencies where supported. Review exceptions and test recovery without opening unrestricted internet access as a troubleshooting shortcut.</td>
<td role="cell" data-label="References" markdown="span">[AI services data-loss prevention](https://learn.microsoft.com/azure/ai-services/cognitive-services-data-loss-prevention)</td>
</tr>
</tbody>
</table>
</div>
