## Cost Optimization

| ID    | Specification |
|-------|--------------|
| CO-R1 | **Costing & Pricing**: The AI Landing Zone must provide clear guidance on the cost of deploying it and follow best practices for planning and managing cost in [Azure AI Foundry](https://learn.microsoft.com/azure/ai-studio/how-to/costs-plan-manage), [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/how-to/manage-costs), and [Azure Machine Learning](https://learn.microsoft.com/azure/machine-learning/concept-plan-manage-cost). |
| CO-R2 | **PTU & PAYGO Pairing**: Provide guidance and implementation of two model endpoints (provisioned & consumption).<br><br>Best Practice:<br><br>Use [provisioned throughput units](https://learn.microsoft.com/azure/ai-services/openai/concepts/provisioned-throughput) for steady baseline traffic and a consumption (standard) endpoint for burst or failover. Front both with APIM to route overflow (priority / weighted backends) and exhaust committed PTU capacity first. |
| CO-R3 | **Deployment Types (Global / Data Zone / Standard / Batch)**: Document selection criteria for [deployment types](https://learn.microsoft.com/azure/ai-foundry/model-inference/concepts/deployment-types) (Global Standard, Global Provisioned, Data Zone variants, Batch).<br><br>Best Practice:<br><br>Pick Global Standard early for simplicity and higher default quota. For predictable high volume, migrate to Global Provisioned (PTU). Use Batch (Global/Data Zone) for large asynchronous workloads (evaluations, backfills) to cut token cost. Record chosen SKU name (e.g. `GlobalProvisionedManaged`) in IaC to avoid drift. |
| CO-R4 | **Developer / Lower-Cost Environments**: Provide a “Developer” deployment strategy using low-cost models (e.g. `gpt-4o-mini`, `gpt-5-nano`, or model-router) and consumption endpoints.<br><br>Best Practice:<br><br>Enforce environment‑specific allow lists (policy) so dev/test cannot deploy high-cost reasoning or preview models. Set APIM subscription quotas that are <10% of prod token rate. Fail fast in CI if a pull request attempts to introduce disallowed model SKUs outside prod manifest. |
| CO-R5 | **Model Type Governance & Allow / Deny Lists**: Control model families (e.g., full GPT-5 vs mini/nano) for cost and data handling risk.<br><br>Best Practice:<br><br>Use custom Azure Policy (deployIfNotExists) scoped to the AI resource to enforce allowed `modelName` / `skuName` patterns. Surface a central JSON allow list (versioned) consumed by both policy and CI lint. Block preview models in production unless an approved exception ticket is linked. Review list monthly to remove retired versions. |
| CO-R6 | **Token Budget & Rate Limiting**: Implement token-per-minute (TPM) and daily/monthly quotas per consumer to prevent cost runaway.<br><br>Best Practice:<br><br>Use APIM [Azure OpenAI token limit policy](https://learn.microsoft.com/azure/api-management/azure-openai-token-limit-policy) for TPM and quota windows; emit token metrics with the [emit token metric policy](https://learn.microsoft.com/azure/api-management/azure-openai-emit-token-metric-policy) to Application Insights for chargeback. Set conservative defaults (e.g., 500 TPM per dev key) and adjust via automation. Deny requests before backend call if prompt token estimate already exceeds limits. |
| CO-R7 | **Semantic Caching & Reuse**: Reduce repeat prompt cost using APIM semantic cache for deterministic prompts (FAQ, policy text, static RAG embeddings).<br><br>Best Practice:<br><br>Enable [semantic caching](https://learn.microsoft.com/azure/api-management/azure-openai-enable-semantic-caching) with a dedicated Redis Enterprise or Managed Redis instance. Cache only low‑variance system+user prompt combinations; set TTL aligned to content change cadence. Track cache hit ratio; target >40% for eligible flows. |
| CO-R8 | **Service Selection**: Provide guidance on selecting hosting/runtime to balance spend & performance.<br><br>Best Practice:<br><br>Use serverless (Container Apps consumption) for sporadic workloads; move to dedicated / GPU profile only when sustained utilization >60%. Prefer built‑in Foundry Agent Service unless deterministic orchestration reduces downstream token usage measurably (>10%). |
| CO-R9 | **Auto Shutdown / Idle Cleanup**: Enforce auto-shutdown on dev/test compute (VMs, AML compute) and scheduled cleanup of unused model deployments & stale agents.<br><br>Best Practice:<br><br>Azure Policy: require `properties.autoShutdown` tags on eligible compute. Weekly job: list model deployments with <1% of monthly traffic; mark for removal after review. Delete unused vector indexes & embeddings older than retention SLA. |
| CO-R10 | **Quota & Forecasting**: Track PTU utilization, standard endpoint throttling (429), and batch backlog daily.<br><br>Best Practice:<br><br>Export APIM token metrics + model deployment metrics to Log Analytics. Build a 30‑day forecast (simple linear) and alert at >70% projected utilization. File capacity increase tickets before 80% sustained. |
| CO-R11 | **Fine‑Tuning & Training Cost Control**: Gate fine‑tune jobs via approval and batch scheduling.
<br><br>Best Practice:<br><br>Restrict fine-tuning to allowed regions & models (policy). Queue jobs to run during off‑peak (lower opportunity cost vs PTU commitments). Store training data size & expected token count; compare actual post‑run. Archive old fine‑tuned models (>90 days unused). |
| CO-R12 | **Observability for Cost**: Standardize cost KPIs (tokens per successful response, cost per conversation, cache hit %, rejection %).
<br><br>Best Practice:<br><br>Emit custom metrics (via APIM policies + application code) with dimensions: environment, model, deploymentType, consumerId. Set dashboards & anomaly alerts (e.g., >30% spike hour-over-hour). |


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

