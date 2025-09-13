## Operational excellence

Operational excellence requirements and best practices for day‑2 operations, change management, readiness, and continuous improvement.

| ID     | Specification |
|--------|--------------|
| OE-R1  | **Environment strategy & rings:** Define a minimal set of environments (sandbox, dev, test, prod) with promotion gates for models, prompts, vector indexes. Use separate Azure AI Foundry projects or AML workspaces per environment; avoid mixing experimental and production artifacts. Maintain a promotion checklist (security scan, evaluation thresholds met, cost review). |
| OE-R2  | **Runbooks & playbooks:** Provide runbooks for common incidents (quota exhaustion, model latency spike, vector index corruption, key rotation failure) and playbooks for rollback (switch to pay-as-you-go endpoint, fail over region, revert model/prompt/agent config). Store in source control; link from alerts. |
| OE-R3  | **SLOs / SLIs:** Define SLOs for median & P95 response latency, success rate, and groundedness / evaluation score. Collect SLIs from APIM, Azure Monitor traces, evaluation pipelines. Publish current vs target in a dashboard. Trigger review if >50% error budget consumed mid‑period. |
| OE-R4  | **Capacity & quota management:** Weekly job queries model quotas, PTU utilization, vector index growth. Warn at 70% forecast within 30 days. Document escalation path for increases. |
| OE-R5  | **Change management (models & prompts):** Version prompts, model deployments, orchestration flows. Require automated evaluation (quality & safety metrics) before merging production-impacting change. Store deployment manifests in source control for immutable redeploy & drift detection. |
| OE-R6  | **Operational tags & metadata:** Enforce tagging (service, owner, dataSensitivity, environment, costCenter, businessCriticality). Use tags in cost & incident queries and to aggregate assets for runbooks. |
| OE-R7  | **Resilient release workflow:** Use progressive rollout (canary) for high‑impact changes; auto‑promote only if latency/error deltas within thresholds. Provide feature flag guidance for model/endpoint selection. |
| OE-R8  | **Secrets & key rotation:** Where keys remain, automate rotation (≤90 days) using Key Vault policies; track expirations. Include emergency revoke runbook. |
| OE-R9  | **Observability baseline:** Define minimal instrumentation (correlation ID, model name, deployment, token counts, prompt template version). Require structured logs from all services; provide sample middleware / SDK config. |
| OE-R10 | **Incident response & post‑incident reviews:** Define severity categories with time‑to‑ack & time‑to‑mitigate targets. After Sev‑1/2, conduct blameless review with actionable follow-ups tracked to closure. |
| OE-R11 | **Preview feature evaluation:** Isolate preview services to non‑prod or pilot until risk assessment & rollback path documented. |
| OE-R12 | **Regional divergence handling:** When model region differs from platform region, document data flow & latency impact. Keep stateful data close to inference or add caching to reduce cross‑region hops. |
| OE-R13 | **Cost & efficiency reviews:** Monthly review PTU utilization vs spend, idle compute, low‑value deployments. Decommission endpoints with no traffic for 30 days. |
| OE-R14 | **Drift & configuration compliance:** Nightly pipeline compares deployed resources vs source. Flag drift (e.g., manual SKU change); create remediation work item within SLA. |
| OE-R15 | **AI safety operations integration:** Integrate evaluation metrics & red team findings into dashboards and gating logic; treat safety regressions as incidents. |

Trade-offs: A richer environment/promotion model adds governance overhead-start lean (dev + prod) then expand. Progressive rollout reduces blast radius but adds routing complexity. Central quotas accelerate approvals yet can become contention-monitor lead times.

