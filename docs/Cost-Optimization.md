## Cost optimization

| ID    | Specification |
|-------|--------------|
| CO-R1 | **Costing & pricing:** Provide guidance on deployment cost and planning for [Azure AI Foundry](https://learn.microsoft.com/azure/ai-studio/how-to/costs-plan-manage), [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/how-to/manage-costs), and [Azure Machine Learning](https://learn.microsoft.com/azure/machine-learning/concept-plan-manage-cost). |
| CO-R2 | **PTU & pay-as-you-go pairing:** Provide guidance for two model endpoints (provisioned + consumption).<br><br><strong>Best practice:</strong> Use [provisioned throughput units](https://learn.microsoft.com/azure/ai-services/openai/concepts/provisioned-throughput) for steady baseline and a standard (pay-as-you-go) endpoint for burst/failover. Front with APIM to route overflow and exhaust PTU first. |
| CO-R3 | **Deployment types (global / data zone / standard / batch):** Selection criteria for [deployment types](https://learn.microsoft.com/azure/ai-foundry/model-inference/concepts/deployment-types).<br><br><strong>Best practice:</strong> Start with Global Standard; move to Global Provisioned (PTU) for predictable high volume. Use Batch for large asynchronous workloads. Record chosen SKU (for example `GlobalProvisionedManaged`) in IaC. |
| CO-R4 | **Developer / lower-cost environments:** Strategy using low-cost models (for example, `gpt-4o-mini`, `gpt-5-nano`, model router) and consumption endpoints.<br><br><strong>Best practice:</strong> Enforce environment-specific allow lists; restrict high-cost or preview models in dev/test. Set APIM quotas <10% of prod token rate. Fail CI if PR introduces disallowed models. |
| CO-R5 | **Model type governance & allow/deny lists:** Control model families for cost and data risk.<br><br><strong>Best practice:</strong> Use Azure Policy to enforce allowed `modelName` / `skuName` patterns. Maintain versioned JSON allow list used by policy & CI. Block preview models in production unless exception ticket approved. Monthly review to remove retired versions. |
| CO-R6 | **Token budget & rate limiting:** Implement token-per-minute and daily/monthly quotas per consumer.<br><br><strong>Best practice:</strong> Use APIM [token limit policy](https://learn.microsoft.com/azure/api-management/azure-openai-token-limit-policy) and [emit token metric policy](https://learn.microsoft.com/azure/api-management/azure-openai-emit-token-metric-policy). Set conservative defaults (for example 500 TPM dev). Pre-validate prompt tokens before backend call. |
| CO-R7 | **Semantic caching & reuse:** Reduce cost for repeat prompts using APIM semantic cache for deterministic prompts.<br><br><strong>Best practice:</strong> Enable [semantic caching](https://learn.microsoft.com/azure/api-management/azure-openai-enable-semantic-caching) with dedicated Redis. Cache only low-variance prompt combinations; TTL aligns to content update cadence. Target >40% hit ratio. |
| CO-R8 | **Service selection:** Balance spend & performance in hosting/runtime choices.<br><br><strong>Best practice:</strong> Use serverless for sporadic workloads; move to dedicated/GPU when utilization >60%. Prefer built-in Foundry Agent Service unless custom orchestration reduces token use >10%. |
| CO-R9 | **Auto shutdown / idle cleanup:** Enforce auto-shutdown on dev/test compute and cleanup of unused deployments & stale agents.<br><br><strong>Best practice:</strong> Policy requires `properties.autoShutdown` tags. Weekly job flags deployments <1% traffic; mark for removal then delete after review. Remove unused indexes & embeddings beyond retention SLA. |
| CO-R10 | **Quota & forecasting:** Track PTU utilization, standard endpoint throttling (429), batch backlog daily.<br><br><strong>Best practice:</strong> Export APIM token + model metrics to Log Analytics, forecast 30 days, alert at >70% projected utilization; request capacity before 80% sustained. |
| CO-R11 | **Fine‑tuning & training cost control:** Gate fine‑tune jobs via approval and batch scheduling.<br><br><strong>Best practice:</strong> Restrict fine-tuning to allowed regions/models. Queue off‑peak jobs. Store expected vs actual token count. Archive models unused >90 days. |
| CO-R12 | **Observability for cost:** Standardize cost KPIs (tokens per success, cost per conversation, cache hit %, rejection %).<br><br><strong>Best practice:</strong> Emit custom metrics (APIM policies + app code) with dimensions: environment, model, deploymentType, consumerId. Dashboards + anomaly alerts (>30% spike hour over hour). |


### Implementation Notes
1. APIM Layer
	- Import each model endpoint as an API; attach token limit + emit token metric policies.
	- Define policy fragments: `rate-limits`, `semantic-cache`, `routing-priority` (PTU first, fallback standard).
2. Policy as Code
	- Author Azure Policy definitions restricting disallowed model names/preview SKUs; deploy via initiative.
	- Add a CI job that parses IaC parameter files and validates model selections against `allowed-models.json`.
3. Batch vs Online
	- Move evaluation / bulk enrichment jobs to Global Batch or Data Zone Batch; store job specs in source control.
4. Semantic Cache
	- Deploy Redis (Enterprise) with persistence; enable APIM semantic cache store/lookup policies for selected APIs only.
5. Cost Dashboards
	- KQL workbook: aggregate `OpenAITokenUsage` + custom dimensions; derive cost using latest meter rates (parameterized).
6. Idle Reaper
	- Scheduled function: list deployments via Azure REST; tag `pendingRemoval=true` after 30d inactivity; delete at 45d unless `retain=true` tag present.
7. Developer Guardrails
	- Separate APIM products: `dev` (low quota, mini models) vs `prod` (approved models). Issue subscription keys per team for chargeback.

### Edge Cases & Pitfalls
* Model retirement: add automated check against model retirement API/announcements to flag soon‑to‑retire versions.
* Preview model auto‑upgrade: avoid unexpected spend changes-disallow preview in production or pin version via controlled upgrade option.
* Token limit false positives: very large tool definitions can inflate context size; pre-validate function/tool token counts in CI.
* Cache poisoning: restrict semantic cache to deterministic prompts; do not cache personalized or PII‑bearing prompts.
* PTU underutilization: alert if rolling 7‑day average utilization <40%; consider resizing or converting portion to standard.

### Success Measures
* <5% monthly variance between forecasted and actual model spend.
* >35% semantic cache hit ratio for eligible workloads within 60 days.
* 0 unapproved high‑cost model deployments in non‑prod environments.
* Mean token cost per conversation reduced ≥15% after implementing governance & caching.

