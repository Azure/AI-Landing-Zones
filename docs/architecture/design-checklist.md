# Design Checklist

Use this checklist when designing an AI workload landing zone, before approving
a deployment, and when reviewing a significant change. For each applicable row,
record your decision, owner and how you will verify it. Use the deployment
documentation to identify which controls the selected template configures and
which your team needs to implement.

## Compute and cost

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| C-R1 | Where will models, agents and application components run? | Evaluate scaling, network and operational needs separately for models and application components, then choose compute for each. Standardize where their requirements align. | [Compute decision guide](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree) |
| CO-R1 | What is the workload's monthly cost and usage model? | Estimate the selected resources, model tokens, indexing and observability before deployment. Include optional services and separate shared-platform costs. | [Cost guide](cost-guide.md), [Foundry cost planning](https://learn.microsoft.com/azure/ai-foundry/concepts/manage-costs) |
| CO-R2 | Is model traffic predictable enough for provisioned throughput? | Compare measured utilization and commitment costs with pay-as-you-go to choose the lower-cost option for the workload. If using spillover, design gateway routing and test quota exhaustion. | [Provisioned throughput](https://learn.microsoft.com/azure/ai-services/openai/concepts/provisioned-throughput), [Multi-backend gateway](https://learn.microsoft.com/azure/architecture/ai-ml/guide/azure-openai-gateway-multi-backend) |
| CO-R3 | Which model deployment type meets residency, latency and cost requirements? | Compare regional, data-zone and global options for the chosen model. Verify processing-location requirements before choosing a lower advertised token price. | [Deployment types](https://learn.microsoft.com/azure/ai-services/openai/how-to/deployment-types) |
| CO-R4 | Which nonproduction resources can stop outside working hours? | Schedule shutdown only for supported resources that can tolerate downtime. Check disks, networking and other charges that continue while compute is stopped. | [VM auto-shutdown](https://learn.microsoft.com/azure/virtual-machines/auto-shutdown-vm) |

## Data

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| D-R1 | Where are agent state, uploaded files and application data stored? | Identify the selected Agent Service setup and its backing resources. Record retention, access, backup and deletion requirements separately for each data store. | [Standard agent setup](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/standard-agent-setup) |
| D-R2 | Which resources may be shared across projects? | Review supported resource-sharing constraints and choose explicit isolation boundaries. Separate application storage from Agent Service backing storage where required. | [Capability hosts and backing resources](https://learn.microsoft.com/azure/ai-foundry/agents/concepts/capability-hosts) |
| D-R3 | Does the workload need data from Microsoft Fabric? | Evaluate the Fabric data agent's supported access model, permissions and regional availability before selecting it as an agent tool. | [Fabric data agent tool](https://learn.microsoft.com/azure/ai-foundry/agents/how-to/tools/fabric) |

## Governance

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| G-R1 | Which policies apply to the deployed services? | Assign relevant built-in or custom policies at the appropriate scope. Review audit results and exemptions before enforcing deny effects. | [AI services policies](https://learn.microsoft.com/azure/ai-services/policy-reference), [Search policies](https://learn.microsoft.com/azure/search/policy-reference) |
| G-R2 | Which regulatory and organizational obligations apply? | Map each obligation to required controls and verification results. Use policy initiatives to assess supported Azure controls and document any additional reviews needed to demonstrate compliance. | [NIST AI RMF](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf), [Regulatory compliance initiatives](https://learn.microsoft.com/azure/governance/policy/samples/#regulatory-compliance) |
| G-R3 | How will responsible AI risks be evaluated? | Define evaluation datasets, human review, acceptance thresholds and escalation for the actual agent tasks. Select evaluation tools that support the models, inputs and outputs in use. | [Generative AI evaluation](https://learn.microsoft.com/azure/ai-foundry/concepts/evaluation-approach-gen-ai) |
| G-R4 | What content safety controls are needed? | Select supported filters and Content Safety APIs for the model and modalities in use. Test prompts, outputs and failure handling. Configure access to tools and documents separately through authorization controls. | [Content Safety overview](https://learn.microsoft.com/azure/ai-services/content-safety/overview) |
| G-R5 | Which models may teams deploy? | Review the applicable model-deployment policies. Start in audit mode, assess impact, then enforce approved restrictions and remediate existing noncompliant deployments separately. | [Model deployment policies](https://learn.microsoft.com/azure/ai-foundry/how-to/built-in-policy-model-deployment) |

## Identity and access

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| I-R1 | How do services authenticate to one another? | Prefer managed identity where supported, with narrowly scoped roles for each runtime principal. Keep deployment, project and runtime identities distinct. | [Managed identities](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) |
| I-R2 | How is privileged human access controlled? | Require MFA and use just-in-time privileged access where available. Use a private administrative path when resources are isolated. | [MFA](https://learn.microsoft.com/entra/identity/authentication/concept-mfa-howitworks), [Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure) |
| I-R3 | Can clients use Microsoft Entra ID rather than static keys? | Use identity-based authentication where supported. Where a key is necessary, store it securely, limit distribution and define rotation and recovery. | [AI services authentication](https://learn.microsoft.com/azure/ai-services/authentication) |
| I-R4 | Which sign-in conditions should be enforced? | Evaluate risk, device and location policies for human access. Configure service authorization for workload identities and test those identities separately from interactive sign-in. | [Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/overview) |
| I-R5 | What can each user and service read or modify? | Grant minimal control-plane and data-plane permissions at the smallest supported scope. Test retrieval with allowed and denied users to verify document access. | [Foundry RBAC](https://learn.microsoft.com/azure/ai-foundry/concepts/rbac-azure-ai-foundry) |
| I-R6 | Can local key authentication be disabled? | Inventory dependent clients, migrate them to Entra ID and verify their workflows before disabling local authentication where supported. | [Azure OpenAI managed identity authentication](https://learn.microsoft.com/azure/ai-services/openai/how-to/managed-identity) |

## Monitoring

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| M-R1 | What signals establish workload health? | Define service-level objectives for availability, latency, task outcomes and data freshness. Monitor models, resources and data against those objectives. | [AI workload management](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/management) |
| M-R2 | Which failures require an alert? | Enable applicable baseline alerts, assign a response owner and document the response procedure. Tune thresholds and test alert delivery. | [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/patterns/artificial-intelligence/) |
| M-R3 | Can one failed request be traced across dependencies? | Correlate application, model and retrieval calls. Protect prompts, documents and user data; content capture must be a deliberate privacy decision. | [Foundry tracing](https://learn.microsoft.com/azure/ai-foundry/how-to/develop/trace-local-sdk) |
| M-R4 | Which resource logs must be retained? | Configure supported diagnostic categories and retention for key services. Confirm that logs reach the intended destination and restrict access to them. | [Diagnostic settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings) |
| M-R5 | How will quality changes be detected? | Re-evaluate representative tasks after model, prompt, tool and data changes. Investigate regressions before deciding whether to change data, prompts or models. | [Evaluation metrics](https://learn.microsoft.com/azure/ai-foundry/concepts/evaluation-metrics-built-in) |
| M-R6 | Can private connectivity failures be diagnosed? | Test DNS, routes, TLS and service authorization separately from the affected network. Use network diagnostics supported by the resource. | [Network Watcher](https://learn.microsoft.com/azure/network-watcher/network-watcher-overview) |

## Reliability and resource organization

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| R-R1 | What are the recovery time and recovery point objectives? | Plan backup, restore and regional recovery for each stateful dependency. For a secondary region, prepare the required services, data recovery and application routing, then test failover against the recovery objectives. | [Azure OpenAI continuity](https://learn.microsoft.com/azure/ai-services/openai/how-to/business-continuity-disaster-recovery), [Storage disaster recovery](https://learn.microsoft.com/azure/storage/common/storage-disaster-recovery-guidance), [Cosmos DB backup](https://learn.microsoft.com/azure/cosmos-db/online-backup-and-restore) |
| RO-R1 | Are the required services and models available in the selected regions? | Check the current service, model, deployment-type and feature availability references when choosing regions and again before deployment. | [Products by region](https://azure.microsoft.com/explore/global-infrastructure/products-by-region/), [Model availability](https://learn.microsoft.com/azure/ai-services/openai/concepts/models) |
| RO-R2 | Is there enough quota for every resource to be created? | Count all selected service instances, including separate Agent Service backing resources. Validate regional model capacity and request increases before deployment. | [Azure limits and quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits) |
| RO-R3 | How will growth affect subscription and regional limits? | Record capacity headroom, ownership and the process for requesting quota. Run preflight checks and confirm current service capacity when scheduling the deployment. | [Quota overview](https://learn.microsoft.com/azure/quotas/quotas-overview) |
| RO-R4 | What are the account, project and billing boundaries? | Align Foundry accounts and projects with access, network and operational requirements. Identify which isolation controls apply at account level and which apply at project level. | [Foundry architecture](https://learn.microsoft.com/azure/ai-foundry/concepts/architecture) |

## Security

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| S-R1 | Which deployed AI risks can be monitored? | Evaluate Defender for Cloud's supported AI posture and threat-protection features, coverage, prerequisites and cost for this workload. | [AI security posture](https://learn.microsoft.com/azure/defender-for-cloud/ai-security-posture) |
| S-R2 | Which service security controls are required? | Map applicable Azure security baselines and Well-Architected guidance to the services actually deployed. | [Security baselines](https://learn.microsoft.com/security/benchmark/azure/security-baselines-overview), [Service guides](https://learn.microsoft.com/azure/well-architected/service-guides/) |
| S-R3 | How is sensitive data discovered and protected? | Assess data classification, oversharing and insider-risk requirements. Evaluate Purview coverage and licensing, and configure retrieval permissions in the source and application authorization paths. | [Purview Insider Risk Management](https://learn.microsoft.com/purview/insider-risk-management) |
| S-R4 | Which AI-specific attack paths need testing? | Threat-model tools, model calls, retrieved content and data access. Use established AI risk frameworks to define tests and mitigations. | [MITRE ATLAS](https://atlas.mitre.org/), [OWASP generative AI risks](https://genai.owasp.org/) |
| S-R5 | How will prompt injection be handled? | Evaluate Prompt Shields for supported inputs and test failures. Keep tool permissions and document authorization enforced independently of model output. | [Prompt Shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection) |

## Networking

| ID | Design consideration | Recommended decision or check | References |
| --- | --- | --- | --- |
| N-R1 | Does public ingress need DDoS protection? | Identify public endpoints and check the supported protection for each resource type. Reuse platform DDoS protection for eligible public IP resources. | [DDoS Protection overview](https://learn.microsoft.com/azure/ddos-protection/ddos-protection-overview) |
| N-R2 | How will operators reach private resources? | Use an approved VPN, connected runner or jumpbox. Reuse central Bastion and administrative access where available, keeping VM administration on an approved private path. | [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview) |
| N-R3 | Which services require private endpoints? | Design private ingress and service-managed outbound links separately. Select networking controls for the Foundry resource type in use: account/project or hub-based. Verify DNS and the intended private path before disabling public access. | [Foundry private networking](https://learn.microsoft.com/azure/ai-foundry/how-to/configure-private-link) |
| N-R4 | Where should NSGs enforce traffic policy? | Apply supported NSG rules to subnets or network interfaces. Preserve service-specific subnet and platform connectivity requirements. | [Network security groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview) |
| N-R5 | Is a regional or global web application firewall needed? | Select Application Gateway or Front Door according to ingress requirements. Verify routing, authentication and backend access as well as WAF rules. | [Azure WAF](https://learn.microsoft.com/azure/web-application-firewall/overview) |
| N-R6 | Does the workload need an AI gateway? | Evaluate API Management for routing, token controls and authentication. Confirm tier support and configure policies explicitly. Avoid logging raw prompts or responses by default. | [AI gateway capabilities](https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities) |
| N-R7 | Which outbound traffic must traverse a firewall? | Reuse a platform firewall where appropriate. Verify routes, supported service paths and required destinations before enforcing egress restrictions. | [Azure Firewall](https://learn.microsoft.com/azure/firewall/overview) |
| N-R8 | How will private service names resolve from every client network? | Plan zone links, conditional forwarding and connected-network resolution. Configure routes and service permissions alongside DNS so clients can reach and use the resolved endpoints. | [Private endpoint DNS integration](https://learn.microsoft.com/azure/private-link/private-endpoint-dns-integration) |
| N-R9 | What outbound destinations are allowed? | Restrict egress to verified service and build dependencies where supported. Review exceptions and test recovery without opening unrestricted internet access as a troubleshooting shortcut. | [AI services data-loss prevention](https://learn.microsoft.com/azure/ai-services/cognitive-services-data-loss-prevention) |
