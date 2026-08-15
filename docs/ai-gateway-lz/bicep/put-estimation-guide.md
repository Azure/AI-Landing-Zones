# Azure OpenAI / Foundry LLM Sizing Guide (PTU vs Pay-as-you-Go)

> **Audience**: Enterprise architects, platform engineers, and cloud capacity planners  
> **Scope**: Azure OpenAI / Foundry LLM deployments using **Provisioned Throughput Units (PTUs)** and **Pay‑As‑You‑Go (PAYG)**  
> **Models**: GPT‑4o, GPT‑5 family (GPT‑5, GPT‑5.1, GPT‑5 mini)

A tool that can be leveraged to do the sizing can be found here: [AzurePTU Sizing Calculator](https://modelavailability.com/tools/azure-ptu-calculator)

***

## 1. What a PTU Really Is (and What It Is Not)

A **Provisioned Throughput Unit (PTU)** represents **reserved, dedicated model-side compute capacity**.

✅ PTU guarantees:

*   Sustained throughput
*   Predictable latency
*   Isolation from noisy neighbors
*   No throttling up to allocated capacity

❌ PTU is **not**:

*   A fixed token quota
*   A prepaid token bucket
*   A guaranteed monthly token allowance

**Key principle**

> PTUs reserve *capacity* (tokens / second), not *usage* (tokens / month).

Unused PTU capacity is **not carried forward**.

***

## 2. Baseline: Tokens per Second per PTU

Microsoft publishes exact throughput mappings **only for GPT‑4o today**.  
For newer Foundry models, the numbers below are **planning guidance**, not contractual SLAs.

### GPT‑4o (Reference Baseline)

```text
1 PTU ≈ 30 tokens / second (input + output combined)
```

This value is widely validated in production Azure OpenAI PTU deployments and is used as the **normalization anchor** for all other models.

***

## 3. PTU Planning Ranges by Model (Foundry)

| Model          | Tokens/sec per PTU (planning) | Relative to GPT‑4o | Profile                           |
| -------------- | ----------------------------- | ------------------ | --------------------------------- |
| **GPT‑4o**     | \~30                          | 1.0×               | Multimodal, real‑time             |
| **GPT‑5**      | \~10–15                       | \~0.3–0.5×         | Frontier reasoning, heavy compute |
| **GPT‑5.1**    | \~18–25                       | \~0.6–0.8×         | Balanced flagship                 |
| **GPT‑5 mini** | \~45–70                       | \~1.5–2.3×         | High‑throughput, cost‑efficient   |

> ⚠️ Exact throughput varies with:
>
> *   Input vs output ratio
> *   Context window size
> *   Tool / function calling
> *   Multimodal inputs

Always size with **30–40% headroom**.

***

## 4. Translating PTUs → Tokens Over Time

### Example: GPT‑4o

```text
1 PTU = 30 tokens/sec
100 PTU = 3,000 tokens/sec
```

| Time Window            | Tokens @ 100 PTU |
| ---------------------- | ---------------- |
| Per second             | 3,000            |
| Per minute             | 180,000          |
| Per hour               | 10.8 million     |
| Per day (24h)          | 259 million      |
| Per 30‑day month (max) | \~7.8 billion    |

> This is a **theoretical maximum** assuming **24×7 sustained utilization**.

### Realistic Utilization Scenarios

| Pattern                  | Estimated Monthly Tokens (100 PTU) |
| ------------------------ | ---------------------------------- |
| 24×7 at 100%             | \~7.8B                             |
| 50% average load         | \~3.9B                             |
| Business hours (10h/day) | \~3.2B                             |
| Event‑driven / spiky     | \~1.5–3B                           |

***

## 5. Input vs Output Token Considerations

Typical enterprise workloads are **not 50/50**.

| Use Case          | Input  | Output |
| ----------------- | ------ | ------ |
| Chat / RAG        | 60–70% | 30–40% |
| Summarization     | 40–50% | 50–60% |
| Agentic workflows | 70–80% | 20–30% |

> PTU throughput counts **combined input + output tokens**.

***

## 6. How to Size PTUs Correctly (Recommended Method)

### Step‑by‑step formula

```text
PTUs required =
(RPS × Avg tokens per request)
÷
(Tokens/sec per PTU for the model)
```

### Add safety margins

*   +30–40% capacity headroom
*   Separate PTUs per critical workload tier (do not share blindly)

### Common enterprise pattern

| Tier       | Model      | Reason                          |
| ---------- | ---------- | ------------------------------- |
| Tier 1     | GPT‑5      | Critical reasoning, decisions   |
| Tier 2     | GPT‑5.1    | General assistant               |
| Tier 3     | GPT‑5 mini | RAG, summarization, chat volume |
| Multimodal | GPT‑4o     | Voice, vision, real‑time        |

***

## 7. Translating PTU Sizing to Pay‑As‑You‑Go (PAYG)

### Key Differences

| Dimension           | PTU                         | Pay‑As‑You‑Go        |
| ------------------- | --------------------------- | -------------------- |
| Billing             | Reserved capacity           | Tokens used          |
| Latency             | Stable                      | Best‑effort          |
| Throttling          | None within allocation      | Possible             |
| Best for            | Regulated, high concurrency | Bursty, low baseline |
| Cost predictability | High                        | Usage‑dependent      |

***

Perfect catch 👍 — you’re absolutely right.  
For **PAYG**, the **enforced limit and operational control is TPM (Tokens Per Minute)**, *not* monthly totals.

Below is a **surgically corrected replacement for Point 8**, written so it can drop straight into your guide and be used as a **sizing + governance reference**.

I’ll **only rewrite Point 8**, keeping everything else intact.

***

## 8. Translating PTU Sizing to Pay‑As‑You‑Go (TPM‑Based)

In **Pay‑As‑You‑Go (PAYG)** deployments, Azure enforces limits using **Tokens Per Minute (TPM)** and **Requests Per Minute (RPM)** — **not monthly token quotas**.

### Key Mental Model

> **PTU = guaranteed tokens per second**  
> **PAYG = capped tokens per minute (*TPM*)**

To translate PTU capacity into PAYG limits, **convert throughput into TPM**.

***

### 8.1 PTU → TPM Conversion Formula

```text
TPM ≈ Tokens per second × 60
```

***

### 8.2 Reference Conversion (GPT‑4o)

Baseline (validated):

```text
1 PTU ≈ 30 tokens / second
```

Therefore:

```text
1 PTU ≈ 1,800 TPM
```

***

### 8.3 Common Reference Table (GPT‑4o)

| PTUs | Tokens/sec | TPM     |
| ---- | ---------- | ------- |
| 1    | 30         | 1,800   |
| 10   | 300        | 18,000  |
| 25   | 750        | 45,000  |
| 50   | 1,500      | 90,000  |
| 100  | 3,000      | 180,000 |

✅ **180k TPM** is the PAYG equivalent of **100 PTU GPT‑4o sustained capacity**.

***

### 8.4 PAYG TPM Planning for Foundry Models

Using the planning throughput ranges:

| Model      | Tokens/sec per PTU | TPM per PTU   |
| ---------- | ------------------ | ------------- |
| GPT‑4o     | \~30               | \~1,800       |
| GPT‑5      | \~10–15            | \~600–900     |
| GPT‑5.1    | \~18–25            | \~1,080–1,500 |
| GPT‑5 mini | \~45–70            | \~2,700–4,200 |

⚠️ These values are **planning guidance**, not hard guarantees.

***

### 8.5 Practical PAYG Limit Setting Strategy

When configuring PAYG:

1.  **Set TPM slightly below theoretical maximum**
    *   (e.g., 70–85%) to avoid burst throttling
2.  **Set RPM independently**
    *   Avoid many small requests overwhelming TPM
3.  **Split TPM per workload**
    *   Frontend chat
    *   Background RAG
    *   Batch summarization

***

### 8.6 Example: PTU → PAYG Decision Comparison

**Scenario**:  
A workload sized at **100 PTU GPT‑4o**

Equivalent PAYG configuration:

```text
Target TPM: 150k–180k
RPM: sized separately based on request profile
```

| Dimension              | PTU                         | PAYG            |
| ---------------------- | --------------------------- | --------------- |
| Throughput guarantee   | Yes                         | No              |
| Enforced limit         | Tokens/sec                  | TPM             |
| Latency predictability | High                        | Variable        |
| Best for               | Regulated, high concurrency | Bursty, elastic |

***

### 8.7 Final Decision Rule (Enterprise‑Friendly)

> **If you design in PTU, validate in TPM.**  
> **If you deploy PAYG, enforce in TPM.**

This ensures:

*   Correct throttling expectations
*   Clean migration path PTU ↔ PAYG
*   No surprises during peak load


## 9. When PTU Makes Financial Sense

✅ PTU is usually justified when:

*   Consistent traffic ≥ 30–40% utilization
*   Latency SLOs are strict
*   Throttling is unacceptable
*   Regulated / banking workloads
*   Large user concurrency

✅ PAYG is better when:

*   Traffic is bursty
*   Low baseline usage
*   Non‑critical workloads
*   Early experimentation

***

## 10. Practical Rule of Thumb

> **Size with PTU for concurrency and latency.  
> Size with PAYG for exploration and variability.**

Many production platforms use **both** together and leverage AI Gateway to manage and optimize their AI workloads effectively.

***