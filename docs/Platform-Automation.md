## Platform Automation

The Platform Automation design area covers DevOps, MLOps, and GenAIOps

| ID   | Specification |
|------|--------------|
| P-R1 | **MLOps & GenAIOps**: Provide prescriptive integration patterns for Azure AI Foundry / AML with CI/CD (GitHub Actions or Azure DevOps) covering data prep, model training, evaluation, safety assessment, packaging, and controlled promotion to production endpoints. |
| P-R2 | **Infrastructure as Code Parity**: Ensure Bicep and Terraform modules expose consistent variables/parameters (naming, defaults, feature flags). Maintain a parity matrix; add an automated check in CI to fail if a new Bicep parameter lacks a Terraform equivalent (or documented exception). |
| P-R3 | **Policy as Code**: Integrate Azure Policy deployment (initiatives for AI services, tagging, networking) via pipeline stage. Use EPAC or native templates; treat policy drift as a failing quality gate. |
| P-R4 | **Environment Bootstrap Automation**: Provide a reusable pipeline template to deploy a new AI project (resource groups, networking, AI Foundry hub/project, Key Vault, APIM config, Service Groups registration) with a single parameter file. |
| P-R5 | **Model & Prompt Registry Automation**: Store model deployment specs (SKU, model version, scaling) and prompt templates in source control. Pipeline generates immutable build artifacts (signed JSON manifest) published to an artifact feed; release pipeline consumes manifest only (no ad hoc edits). |
| P-R6 | **Evaluation & Safety Gates**: Add automated evaluation stage running benchmark prompt sets, safety filters (content safety APIs), and hallucination/groundedness checks. Release is blocked if metrics fall below thresholds. Store historical evaluation results for trend analysis. |
| P-R7 | **Observability as Code**: Deploy baseline dashboards (tokens, latency, cost, safety incidents) and alert rules (quota, drift, error budget burn) via IaC so every environment has consistent monitoring. |
| P-R8 | **Secrets & Identity Automation**: Pipelines use federated credentials / OIDC (no stored PATs). Automate managed identity role assignments via IaC; rotate remaining secrets through Key Vault tasks. |
| P-R9 | **Artifact Provenance & Supply Chain**: Include SBOM generation for container images (orchestrator, tools) and sign images (Notary/Azure Container Registry content trust). Verify the signature before deployment. |
| P-R10 | **Rollback & Version Pinning**: Release pipeline stores last known good model & prompt version; automated rollback job callable from incident runbook. Pin dependencies (SDK versions) and surface drift in PR via the dependency audit step. |
| P-R11 | **Data Pipeline Integration**: Provide a pattern for integrating data refresh (RAG corpus, embeddings) with incremental indexing jobs. Use change detection to embed only new/changed documents; track embedding throughput & failures. |
| P-R12 | **Cost Guardrails in Pipeline**: Pre‑deployment step estimates incremental monthly cost (PTU, storage) from manifest; requires approval when delta exceeds threshold. |
| P-R13 | **Service Groups Automation (Preview)**: After deployment, pipeline registers key resources (APIM, AI projects, vector stores) into predefined Service Groups for ops personas (e.g., "ai-core", "ai-security"). Fail gracefully (warn) if preview API unavailable; document toggle. |
| P-R14 | **Drift Detection Job**: Nightly job compares live resource properties (model version, endpoint SKU, network settings) against declared state. Create an issue/ticket on divergence. |
| P-R15 | **GenAIOps Runbook Integration**: Automatically update operational runbook index (markdown in repo) with links to new evaluation reports, model manifests, and dashboards each release. |

