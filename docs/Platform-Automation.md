## Platform Automation

The Platform Automation design area covers DevOps, MLOps, and GenAIOps

| ID   | Specification |
|------|--------------|
| P-R1 | **MLOps & GenAIOps:** Provide prescriptive integration patterns for Azure AI Foundry / AML with CI/CD (GitHub Actions or Azure DevOps) covering data prep, model training, evaluation, safety assessment, packaging, and controlled promotion to production endpoints.<br><br><strong>Best practice:</strong><br>Create a reusable pipeline template including evaluation & safety gates before production promotion. |
| P-R2 | **Infrastructure as code parity:** Ensure Bicep and Terraform modules expose consistent variables/parameters (naming, defaults, feature flags).<br><br><strong>Best practice:</strong><br>Maintain a parity matrix; CI fails if new parameter lacks equivalent or exception note. |
| P-R3 | **Policy as code:** Integrate Azure Policy deployment (initiatives for AI services, tagging, networking) via pipeline stage.<br><br><strong>Best practice:</strong><br>Treat policy drift as a failing quality gate; surface diff in PR comments. |
| P-R4 | **Environment bootstrap automation:** Provide a reusable pipeline template to deploy a new AI project (resource groups, networking, AI Foundry hub/project, Key Vault, APIM config, Service Groups registration) with a single parameter file.<br><br><strong>Best practice:</strong><br>Time-box full environment bootstrap (<30 min) and add success metric. |
| P-R5 | **Model & prompt registry automation:** Store model deployment specs (SKU, model version, scaling) and prompt templates in source control; generate signed manifest consumed by release pipeline.<br><br><strong>Best practice:</strong><br>Block release if manifest signature or checksum mismatch. |
| P-R6 | **Evaluation & safety gates:** Run benchmark prompt sets, safety filters, hallucination/groundedness checks in automated stage; block release on threshold breach.<br><br><strong>Best practice:</strong><br>Persist evaluation history and surface drift trend. |
| P-R7 | **Observability as code:** Deploy baseline dashboards (tokens, latency, cost, safety incidents) and alert rules (quota, drift, error budget burn) via IaC for consistent monitoring.<br><br><strong>Best practice:</strong><br>Embed dashboard JSON + alert rules in source control; validate post-deploy. |
| P-R8 | **Secrets & identity automation:** Use federated credentials / OIDC (no stored PATs). Automate managed identity role assignments via IaC; rotate remaining secrets via Key Vault.<br><br><strong>Best practice:</strong><br>Fail pipeline if inline secret detected. |
| P-R9 | **Artifact provenance & supply chain:** Generate SBOM for images; sign and verify before deployment.<br><br><strong>Best practice:</strong><br>Enforce signature verification gate; alert on unsigned artifact attempt. |
| P-R10 | **Rollback & version pinning:** Store last known good model & prompt version; provide automated rollback job.<br><br><strong>Best practice:</strong><br>Alert when dependency drift exceeds version policy window. |
| P-R11 | **Data pipeline integration:** Provide pattern for integrating data refresh (RAG corpus, embeddings) with incremental indexing jobs; embed only new/changed content.<br><br><strong>Best practice:</strong><br>Track embedding throughput & failures; surface SLO in dashboard. |
| P-R12 | **Cost guardrails in pipeline:** Pre-deployment step estimates incremental monthly cost (PTU, storage) from manifest; require approval when delta exceeds threshold.<br><br><strong>Best practice:</strong><br>Store actual vs. estimated cost variance for retros. |
| P-R13 | **Service groups automation (preview):** Register key resources into predefined Service Groups for ops personas; fail gracefully (warn) if preview API unavailable.<br><br><strong>Best practice:</strong><br>Provide feature flag to disable during incidents. |
| P-R14 | **Drift detection job:** Nightly job compares live resource properties against declared state; create issue on divergence.<br><br><strong>Best practice:</strong><br>Auto-label issues with severity based on impact (security, performance, reliability). |
| P-R15 | **GenAIOps runbook integration:** Auto-update runbook index with links to new evaluation reports, model manifests, dashboards each release.<br><br><strong>Best practice:</strong><br>Fail pipeline if runbook index not updated. |

