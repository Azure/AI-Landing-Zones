# AI Landing Zone for Azure Container Apps

## High-Level Architecture Design: AI Workloads on Azure Container Apps

### Executive Summary

This article defines a production-ready landing zone architecture for deploying AI workloads on Azure Container Apps. It lists the design considerations and recommendations when using Azure Container Apps for AI workloads.

![Screenshot showing the AI Landing zone for Azure Container Apps](../media/AI%20Landing%20Zones%20-%20ACA.png)

### Infrastructure & Compute

This section covers the recommendations for the infrastructure and compute design area for the landing zone.

#### Environments & Workload Profiles

The Container App Environment serves as the administrative and security boundary. To cater for different workload performance and cost requirements, we utilize multiple workload profiles within a single environment:

- **Consumption Profiles:** Best for variable or unpredictable traffic patterns. scale to zero to minimize costs during idle periods.
- **Dedicated Profiles:** Best for steady-state workloads or background workers that require reserved compute for consistent latency.
- **Serverless GPUs vs. Dedicated GPUs:**
  - [Serverless GPUs](https://learn.microsoft.com/azure/container-apps/gpu-serverless-overview): Ideal for bursty inference where you only pay for the duration of the request.
  - [Dedicated GPUs](https://learn.microsoft.com/azure/container-apps/plans#dedicated): Necessary for long-running training, fine-tuning, or high-throughput production inference requiring guaranteed availability.

The architecture organizes workloads into five distinct workload profiles:

| Workload Profile | Resource Type | GPU Strategy | Typical Workloads |
|---|---|---|---|
| **Latency-sensitive inferencing** | Container Apps | Dedicated GPUs | Real-time inference with Ollama, Foundry Models, or similar open-source inference runtimes requiring guaranteed low-latency responses |
| **Cost-sensitive inferencing** | Container Apps | Serverless GPUs | Bursty inference workloads using Ollama, Foundry Models, or similar open-source inference runtimes where pay-per-request is more economical |
| **ML and training** | Container App Jobs | Serverless GPUs | Batch training jobs, fine-tuning, embedding generation, and periodic model retraining as run-to-completion tasks. Use dedicated GPUs when latency is critical. Design jobs to be idempotent with checkpointing so that retries or restarts resume safely without reprocessing completed work or corrupting artifacts |
| **Apps** | Container Apps | Consumption (CPU) | Front-end UIs, MCP servers, and AI agents |
| **AI Gateway** | Container Apps | Dedicated (CPU) | AI Gateway for routing and load balancing across model endpoints. Runs on a dedicated profile with minimum replicas to avoid cold starts and ensure consistent latency on the critical inference path |

### Networking & Security

This section covers the recommendations for the networking and security design area for the landing zone.

#### VNet Integration & Egress Control
For enterprise security, we implement "Bring Your Own VNet" to apply custom security controls:
- **Dedicated Subnet:** The Azure Container Apps environment requires a dedicated subnet delegated to `Microsoft.App/environments`.
- **Internal vs. External Access:**
  - Internal: The environment is hidden from the public internet; traffic is routed via a Private IP.
  - External: The environment is reachable via a public load balancer managed by Azure Container Apps.
- **Egress Control:** Route all outbound traffic through an Azure Firewall for inspection and centralized policy enforcement.

> **Note:** Azure NAT Gateway is also supported for egress in workload profile environments with custom VNet integration. Use NAT Gateway when the primary requirement is a static outbound IP without the need for Layer-7 traffic inspection. For scenarios requiring outbound traffic filtering, FQDN-based rules, or threat intelligence, Azure Firewall remains the recommended approach.

#### Private Access & Secret Management
- **Private Endpoints:** Ensure all communication to back-end services (Cosmos DB, Storage, Key Vault) stays on the Microsoft backbone.
- **Key Vault:** All sensitive data (API keys, access tokens, SSL certs) must be stored in Azure Key Vault and referenced as secrets in Azure Container Apps.
- **Managed Identities:** Use User-Assigned Managed Identities for all resource-to-resource authentication (e.g., Azure Container Apps pulling from ACR) to eliminate the need for hardcoded credentials.

#### Ingress Security
- **HTTPS Enforcement:** Set `allowInsecure: false` on all ingress configurations to enforce TLS and automatically redirect HTTP to HTTPS.
- **[IP Restrictions](https://learn.microsoft.com/azure/container-apps/ip-restrictions):** Configure IP allow/deny rules when relevant to restrict inbound access to known CIDR ranges (e.g., corporate VPN, Azure Front Door backend IPs).
- **[Mutual TLS (mTLS)](https://learn.microsoft.com/azure/container-apps/mtls):** Enable mTLS for service-to-service communication between container apps within the environment to encrypt traffic and verify both client and server identities.
- **[CORS](https://learn.microsoft.com/azure/container-apps/cors):** Configure Cross-Origin Resource Sharing policies for front-end AI chat UIs that call backend inference APIs from browser clients.

#### GenAI Application Dependencies

The architecture relies on a set of Azure services that support the AI workloads:

- **Azure Cosmos DB:** Persistent storage for conversation history, agent state, session metadata, and application data.
- **Azure Key Vault:** Centralized secret management for API keys, model access tokens, and certificates.
- **Azure Storage Account:** Durable storage for model weights (via Azure Files mounts), training datasets, and artifacts.
- **Azure Container Registry (ACR):** Private registry for container images. Deploy in the same region as the Azure Container Apps environment for minimal pull latency.
- **Managed Identities:** User-Assigned Managed Identities for all service-to-service authentication, eliminating hardcoded credentials.
- **Azure App Configuration:** Centrally manage applications' configuration.

### AI Workload Optimization

This section covers the recommendations for optimizing the AI workloads to be deployed in the landing zone.

#### Model Serving & Deployment

- **Foundry Models:** Leverage built-in integrations for turnkey deployment of Microsoft-managed [foundry models](https://learn.microsoft.com/azure/container-apps/gpu-serverless-overview#deploy-foundry-models-to-serverless-gpus-preview).
- **Open-Source Model Serving:** Deploy open-source model serving runtimes such as Ollama, vLLM, or Hugging Face Text Generation Inference (TGI) as container apps on GPU-enabled workload profiles. These runtimes provide flexible, self-hosted inference for open-weight models (e.g., Llama, Mistral, Phi) and can be paired with either dedicated or serverless GPUs depending on latency and cost requirements.
- **AI Gateway:** Deploy an AI Gateway (e.g., Azure API Management, Envoy-based proxies, or custom routing middleware) to centralize traffic management across model endpoints. The gateway enables load balancing, rate limiting, request routing, and failover across multiple backend model deployments.
- **[Dynamic Sessions](https://learn.microsoft.com/azure/container-apps/sessions):** Provide secure, isolated sandboxes (Hyper-V based) for executing AI-generated code safely.
- **MCP (Model Context Protocol) Servers:** Host MCP servers within Azure Container Apps to allow AI agents to securely query internal databases or execute tools via a standardized interface.

#### Reducing Cold Starts & Storage

Loading multi-gigabyte models (Foundry or open-source) into memory can lead to significant latency.
- **[Azure Files Volume Mounts](https://learn.microsoft.com/azure/container-apps/storage-mounts-azure-files?tabs=bash):** Download model weights to a persistent Azure File Share once. Mount this share to the container so the model is available instantly on startup without re-downloading.
- **Azure Container Registry (ACR):** Deploy Azure Container Registry in the same region as the Azure Container Apps environment to reduce latency.
  - Use the Premium SKU for [global distribution](https://learn.microsoft.com/azure/container-registry/container-registry-geo-replication) and [Artifact Streaming](https://learn.microsoft.com/azure/container-registry/container-registry-artifact-streaming?tabs=azure-cli) to further accelerate container startup times.
- **Optimize Container Image Size:** Audit inference container images to remove training-only dependencies, development tools, and unnecessary libraries. Use multi-stage Docker builds to minimize image size.
- **Custom Startup Probes:** For AI model containers that take minutes to load large models into GPU memory, configure custom [startup probes](https://learn.microsoft.com/azure/container-apps/health-probes) with extended `initialDelaySeconds` and `failureThreshold` to prevent premature container kills during initialization.
- **Proactive Wake-Up:** Use scheduled [Container App Jobs](https://learn.microsoft.com/azure/container-apps/jobs) to send warm-up requests to inference endpoints ahead of peak usage (e.g., a daily job at 9 AM) to eliminate cold starts while still benefiting from scale-to-zero during off-hours.

#### AI Agents & Orchestration

Deploy AI agents as individual container apps within the Apps workload profile. Each agent runs as an independent, scalable microservice that can be updated and versioned separately. Use open-source agent orchestration frameworks to build and manage agent workflows, such as Microsoft Agent Framework, LangGraph, and others.

Agents communicate with model endpoints via the AI Gateway, and leverage MCP servers for tool access and external data retrieval.

#### Autoscaling

- **[Scaling Rules](https://learn.microsoft.com/azure/container-apps/scale-app):** Define KEDA-based autoscaling rules tailored to each workload profile:
  - **HTTP scaling** for front-end UIs and AI Gateway (based on concurrent request count).
  - **Custom scaling** for event-driven workloads.
- **Min/Max Replicas:** Set minimum replicas ≥ 1 for latency-sensitive inference endpoints to avoid cold starts. Set maximum replicas based on GPU availability and cost budget.
- **[Session Affinity](https://learn.microsoft.com/azure/container-apps/sticky-sessions):** Enable sticky sessions for stateful AI chat applications that maintain conversation context in-memory, ensuring subsequent requests from the same user route to the same replica.

#### Deployment & Release Strategy

- **[Blue-Green Deployment](https://learn.microsoft.com/azure/container-apps/blue-green-deployment):** Use revision labels and traffic weights to implement blue-green deployments. Deploy new model versions or application code to a "green" revision, validate via the labeled FQDN, then shift 100% of traffic. Roll back instantly by re-routing traffic to the "blue" revision.
- **[Traffic Splitting](https://learn.microsoft.com/azure/container-apps/traffic-splitting):** Use percentage-based traffic splitting to gradually roll out new revisions, enabling canary testing of updated inference endpoints.
- **Revision Management:** Set `maxInactiveRevisions` to automatically clean up old revisions and avoid hitting the revision limit (default max of 100 per container app).

### Resiliency & Global Availability

This section covers the recommendations for resiliency and availabilitys for the workloads to be deployed in the landing zone.

#### Availability Zones

Enable zone redundancy on the Container App Environment to distribute replicas across multiple physical availability zones within a region. This protects against datacenter-level failures.

- **Environment-Level Setting:** Zone redundancy must be enabled at environment creation time — it cannot be added after the fact.
- **Minimum Replicas:** Configure a minimum of three replicas for critical workloads to ensure at least one replica runs in each zone.
- **Dependency Alignment:** Ensure dependent services (Cosmos DB, Key Vault, Storage) are also configured for zone redundancy to avoid single-zone bottlenecks.

#### Service Resiliency & Health

- **[Health Probes](https://learn.microsoft.com/azure/container-apps/health-probes?tabs=arm-template):** Define liveness, readiness, and startup probes to detect unhealthy instances and enable automatic recovery.
- **[Resiliency Policies (Preview)](https://learn.microsoft.com/azure/container-apps/service-discovery-resiliency?tabs=bicep):** Configure retries, timeouts, and circuit breakers for service-to-service communication. Ensure services (inference endpoints, databases, MCP tool,..etc) are idempotent so that retried requests do not cause duplicate side effects.

#### Operational Excellence

- **[Planned Maintenance Windows](https://learn.microsoft.com/azure/container-apps/planned-maintenance):** Configure maintenance windows on the Container App Environment to schedule non-critical platform updates during off-peak hours, minimizing disruption to AI inference workloads.
- **[Service Discovery](https://learn.microsoft.com/azure/container-apps/connect-apps):** Container apps within the same environment can communicate using their app names as internal DNS hostnames. Use internal ingress for backend services to restrict access to within-environment traffic only.

#### Multi-Region Architecture

For business continuity against full regional outages, deploy across two or more Azure regions:

- **Active-Active:** Both regions serve production traffic simultaneously via Azure Front Door. Provides near-instant failover (seconds) but requires globally replicated data stores and synchronized deployments. Best for mission-critical serving workloads (inference endpoints, front-end apps, AI agents, AI Gateway). Training and batch jobs should remain single-region due to data locality requirements and run in the secondary region only during failover.
- **Active-Passive:** The secondary region remains on warm standby, activated during failover. Lower cost and complexity, with failover measured in minutes. Suitable for most production workloads. However, cost savings depend on the workload profile types deployed in the standby region. Pre-deploy the environment with consumption-based and serverless GPU profiles in the standby region. Use Infrastructure as Code (Bicep/Terraform) to rapidly provision dedicated GPU profiles only during failover, balancing cost efficiency against recovery time.

**Key design considerations:**

- Deploy one Container App Environment per region, each with zone redundancy enabled.
- Use [Azure Front Door](https://learn.microsoft.com/azure/container-apps/how-to-integrate-with-azure-front-door?pivots=azure-portal) for global Layer-7 traffic routing, SSL termination, and automatic health-probe-based failover.
- Replicate stateful data (conversation history, agent state, model weights) across regions using geo-redundant services (e.g., Cosmos DB multi-region writes, GRS storage accounts).
- Mirror network topology (VNets, subnets, firewall rules) and identity configuration (Managed Identities, RBAC) consistently across regions.
- Ensure CI/CD pipelines deploy to all regions in sync to avoid version drift.

### Observability & Monitoring

This section covers the recommendations for monitoring, logging, and observability for the workloads deployed in the landing zone.

#### Logging & Diagnostics

- **[Log Analytics Integration](https://learn.microsoft.com/azure/container-apps/log-monitoring):** Configure a Log Analytics workspace as the default log destination for the Container App Environment. Use KQL queries to analyze system logs, container console output, and scaling events.
- **[Diagnostic Settings](https://learn.microsoft.com/azure/container-apps/log-options):** Configure Azure Monitor diagnostic settings to stream logs and metrics.
- **[Azure Monitor Alerts](https://learn.microsoft.com/azure/container-apps/alerts):** Set up alerts for critical conditions: failed health probes, high error rates, replica restarts, GPU utilization thresholds, and scaling failures. Use action groups to trigger automated incident response.

#### Distributed Tracing & Metrics

- **[OpenTelemetry](https://learn.microsoft.com/azure/container-apps/opentelemetry-agents):** Configure OpenTelemetry data agents at the environment level to collect distributed traces and metrics from AI agent workflows. This provides end-to-end visibility across multi-agent orchestration chains.
- **[Metrics](https://learn.microsoft.com/azure/container-apps/metrics):** Monitor platform metrics including CPU/memory utilization, replica count, request count, and response latency. Use these metrics to validate scaling rules and detect performance regressions in model inference endpoints.