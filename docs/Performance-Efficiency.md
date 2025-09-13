## Performance Efficiency

Design for efficient use of compute, tokens, memory, storage, and network so you meet latency goals without unnecessary spend. Performance and cost are tightly linked for AI workloads; measure before optimizing.

| ID     | Specification |
|--------|--------------|
| PE-R1  | **Model Right‑Sizing & Tiering**: Provide guidance to choose the smallest viable model (e.g., use gpt‑4o‑mini / small embedding model for classification, larger only when evaluation gap > agreed threshold). Maintain a decision matrix (task vs candidate models vs latency/quality deltas). |
| PE-R2  | **Prompt & Token Optimization**: Require prompt templates to track token length. Enforce max input/output token policies in APIM to prevent runaway cost & latency. Provide linting scripts to detect verbose system prompts or redundant instructions. |
| PE-R3  | **Vector Store Design**: Recommend shard/replication factors for vector DB (Cosmos DB with vector, Azure AI Search, PostgreSQL pgvector) based on QPS & index size. Include guidance on dimensionality reduction (e.g., 1536 vs 3072 embedding vectors) and periodic index rebuild schedule. |
| PE-R4  | **Caching Strategy**: Implement multi‑layer caching: (a) embedding cache (hash of input), (b) response cache for deterministic retrieval queries, (c) short‑lived model response cache for high repetition prompts where safety allows. Evaluate hit rates weekly; expire on the prompt template or model version change. |
| PE-R5  | **Streaming & Partial Responses**: Enable streaming responses for long generation tasks to reduce perceived latency in chat UI; document fallback to non‑stream for clients lacking support. |
| PE-R6  | **Autoscaling Policies**: Provide default autoscale rules for Container Apps / AKS orchestrator components based on CPU, concurrent requests, and custom metric (tokens per second). For PTU endpoints, recommend baseline capacity vs peak shaping (queue + backpressure). |
| PE-R7  | **Concurrency & Throughput Limits**: Document safe concurrency per model deployment (tokens/sec) and implement circuit breakers in APIM if P95 latency breach persists > N mins. Include a guideline to degrade gracefully (switch to a summarized answer, smaller model) under sustained pressure. |
| PE-R8  | **Latency Budget Allocation**: Define end‑to‑end latency target (e.g., <3s P95 chat response) and allocate sub‑budgets (frontend <100ms, retrieval <400ms, model inference <2s, post‑processing <300ms). Instrument spans to validate budget adherence. |
| PE-R9  | **Batching & Parallelization**: Provide guidance on when to batch (embedding generation, tool calls) vs parallelize (multi‑retriever strategies) and illustrate sample orchestration flow. Avoid over‑parallelization that increases total token usage without quality gain. |
| PE-R10 | **Content Truncation & Summarization**: Implement summarization or semantic chunk selection for long documents before embedding to reduce token & latency overhead; include heuristics (max chunk size, overlap). |
| PE-R11 | **Cold Start Mitigation**: Pre‑warm frequently used model deployments and container app revisions via scheduled synthetic requests. Track cold start frequency; if >2% of requests, adjust min replicas or prefetch strategy. |
| PE-R12 | **Region & Network Considerations**: If model region differs from data / app region, quantify additional RTT and recommend co‑locating latency‑sensitive state (session memory, vector index) with model or adding edge caching. Provide a latency impact table example (single vs cross‑region). |
| PE-R13 | **Observability for Performance**: Capture per‑request metrics (tokens in/out, latency phases, cache hit flag, model name, vector index latency). Provide default dashboard & percentile targets. |
| PE-R14 | **Load & Scenario Testing**: Include guidance to run synthetic load tests (steady, spike, burst) pre‑prod using representative prompt mix & average token size. Validate autoscale triggers & error budgeting. |
| PE-R15 | **Graceful Degradation Paths**: Document fallback hierarchy (primary PTU -> secondary PAYGO -> smaller model -> static answer / offline notice) with expected quality & latency tradeoffs. |
| PE-R16 | **Periodic Performance Review**: Monthly review to compare current latency & token efficiency vs baseline; if regression >10% without quality gain, create optimization work item. |

Tradeoffs: Aggressive caching reduces cost but risks stale answers; enforce TTL & safety re‑checks for long‑lived cache. Smaller models speed responses but may lower accuracy-use evaluation gating. Higher min replicas mitigate cold start but raise idle cost. Cross‑region optimization may add operational complexity if you duplicate data; balance latency vs data residency requirements.

