## Governance

Governance requirements and best practices.

| ID   | Specification |
|------|--------------|
| G-R1 | **Enforce built-in policies:** Implement and continuously enforce curated Azure Policy initiatives for AI services.<br><br><strong>Best practice:</strong> Assign a baseline initiative set (Azure AI Foundry, Azure Machine Learning, Azure AI services, Azure AI Search). Automate assignment at management group scope. Use an audit → deny lifecycle (switch to deny when noncompliance <5%). Map relevant [regulatory compliance initiatives](https://learn.microsoft.com/azure/governance/policy/samples/#regulatory-compliance). Include workload-specific initiatives (for example, OpenAI, Machine Learning guardrails). Store initiative version & assignment parameters in source control. |
| G-R2 | **Adopt industry standards:** Map platform controls to [NIST AI RMF](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf) core functions; use the [playbook](https://airc.nist.gov/AI_RMF_Knowledge_Base/Playbook) to evidence coverage. Maintain a versioned control matrix updated with each material architecture change. |
| G-R3 | **Operationalize responsible AI:** Implement an evaluation pipeline using the [Responsible AI dashboard](https://learn.microsoft.com/azure/machine-learning/concept-responsible-ai-dashboard). Gate production promotion on safety & fairness thresholds aligned to risk classification. Retain evaluation artifacts ≥6 months. |
| G-R4 | **Content safety enforcement:** Integrate [Azure AI Content Safety](https://learn.microsoft.com/azure/ai-services/content-safety/overview) pre and post inference for high-risk workloads (public chat, user-generated content). Maintain severity thresholds; review monthly; changes require security approval. |
| G-R5 | **Model allow list governance:** Use Azure Policy to enforce an approved model list. Phases: (1) Audit new deployments (2) Deny non-approved (3) Auto notify & remediation workflow for existing unauthorized deployments. Keep a documented runbook. |
| G-R6 | **Service Groups (preview):** Automate registration of core AI resources (projects, AML workspaces, APIM, vector stores, Key Vault) into defined Service Groups (ai-core, ai-security, ai-network). Provide script/pipeline task and rollback query. |
| G-R7 | **Cross-region parity:** Mirror policy assignments, RBAC mappings, tagging schema, and diagnostic settings in every active AI region. Dashboard highlights drift (missing initiative or diagnostic). |
| G-R8 | **Time-boxed waivers:** Provide a waiver workflow (issue template: owner, expiry, compensating control). Dashboard surfaces active waivers; auto notify 7 days pre-expiry. No open-ended waivers. |
| G-R9 | **Data residency control:** Maintain a residency decision checklist (data category, encryption, replication scope). Do not replicate sensitive embeddings across sovereign boundaries without approved data sharing request. Reference sovereign landing zone patterns where applicable. |

