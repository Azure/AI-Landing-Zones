## Performance efficiency

Performance efficiency requirements and best practices. Design for efficient use of compute, tokens, memory, storage, and network; measure before optimizing.

| ID     | Specification |
|--------|--------------|
| PE-R1  | **Model right‑sizing & tiering:** Choose the smallest viable model (e.g., gpt‑4o‑mini) unless evaluation gap exceeds threshold. Maintain decision matrix (task vs model vs latency/quality deltas). |
| PE-R2  | **Prompt & token optimization:** Track token length per prompt template. Enforce max input/output token policies in APIM. Provide lint scripts to detect verbose or redundant instructions. |
| PE-R3  | **Vector store design:** Recommend shard/replication factors (Cosmos DB vector, Azure AI Search, pgvector) based on QPS & index size. Include dimensionality reduction guidance and index rebuild cadence. |
| PE-R4  | **Caching strategy:** Multi‑layer caching: embeddings (hash), deterministic retrieval responses, short‑lived model response cache for high repetition prompts. Evaluate hit rates weekly; invalidate on prompt or model version change. |
| PE-R5  | **Streaming & partial responses:** Enable streaming for long generations to reduce perceived latency; document fallback for non‑stream clients. |
| PE-R6  | **Autoscaling policies:** Provide default autoscale rules (CPU, concurrent requests, tokens/sec). For PTU endpoints, recommend baseline capacity vs peak shaping (queue + backpressure). |
| PE-R7  | **Concurrency & throughput limits:** Document safe concurrency (tokens/sec). Implement circuit breakers if P95 breach persists >N minutes. Provide graceful degradation (smaller model, summarised answer). |
| PE-R8  | **Latency budget allocation:** Define end‑to‑end latency target (e.g., <3s P95). Allocate sub‑budgets (frontend, retrieval, inference, post‑processing). Instrument spans to validate adherence. |
| PE-R9  | **Batching & parallelization:** Clarify when to batch (embeddings, tool calls) vs parallelize (multi‑retriever). Avoid over‑parallelization increasing token usage without quality gain. |
| PE-R10 | **Content truncation & summarization:** Summarize or semantic‑select long documents before embedding; provide heuristics (max chunk size, overlap). |
| PE-R11 | **Cold start mitigation:** Pre‑warm frequently used model deployments and container app revisions with synthetic requests. If cold starts >2%, adjust min replicas or prefetch. |
| PE-R12 | **Region & network considerations:** If model region differs from data/app region, quantify extra RTT; co‑locate latency‑sensitive state or add edge caching. Provide latency impact example. |
| PE-R13 | **Observability for performance:** Capture per‑request metrics (tokens in/out, latency phases, cache hit flag, model name, vector index latency). Provide dashboard & percentile targets. |
| PE-R14 | **Load & scenario testing:** Run synthetic steady/spike/burst tests pre‑prod with representative prompt mix & token size. Validate autoscale triggers & error budget. |
| PE-R15 | **Graceful degradation paths:** Document fallback hierarchy (primary PTU → secondary pay-as-you-go → smaller model → static answer / offline notice) with tradeoffs. |
| PE-R16 | **Periodic performance review:** Monthly compare latency & token efficiency vs baseline; if >10% regression without quality gain, open optimization work item. |

Trade-offs: Aggressive caching reduces cost but risks staleness; enforce TTL & safety re‑checks. Smaller models improve latency yet may reduce accuracy-evaluate before downgrading. Higher min replicas mitigate cold start but raise idle cost. Cross‑region optimization adds complexity; balance latency vs residency requirements.

