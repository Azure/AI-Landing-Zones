---
render_macros: false
---

# Foundry Citadel Platform - Azure Well-Architected Framework Alignment

!!! note "Original platform guide"
    This guide maps the Foundry Citadel Platform, as first published, to the Azure Well-Architected Framework. For the current layered guidance, see the [AI Citadel Blueprint overview](index.md) and its layer guides.

> **How Citadel Implements Microsoft Well-Architected Framework Principles for AI Workloads**

**Document Version:** 1.0  
**Last Updated:** November 10, 2025  
**Reference:** [Azure Well-Architected Framework - AI Design Principles](https://learn.microsoft.com/en-us/azure/well-architected/ai/design-principles)

---

## Overview

The **Foundry Citadel Platform** is architected to align with the Microsoft Well-Architected Framework (WAF) for AI workloads, delivering enterprise-grade AI solutions through three core pillars:

- **Governance & Security** - Enterprise-grade controls, responsible AI, and data protection
- **Observability & Compliance** - Comprehensive monitoring, auditing, and regulatory compliance
- **AI Development Velocity** - Accelerated development with best practices and automation

This document demonstrates how Citadel's concrete technical implementations address the five WAF pillars: **Reliability**, **Security**, **Cost Optimization**, **Operational Excellence**, and **Performance Efficiency**.

---

## Architecture Alignment Summary

| WAF Pillar | Alignment Status | Key Citadel Capabilities |
|------------|------------------|--------------------------|
| **Reliability** | 🟢 Strong | Multi-region support, high availability, automated failover, resilient architecture |
| **Security** | 🟢 Strong | Zero Trust, content safety, RBAC, encryption, network isolation |
| **Cost Optimization** | 🟢 Strong | Usage tracking, quota management, auto-scaling, cost attribution |
| **Operational Excellence** | 🟢 Strong | Automated monitoring, CI/CD integration, DevOps/AIOps support |
| **Performance Efficiency** | 🟢 Strong | Load balancing, auto-scaling, performance monitoring, quality metrics |

**Legend:** 🟢 Strong | 🟡 Partial | 🔴 Limited

---

## 1. Reliability - Building Resilient AI Workloads

### WAF Principle: Design Reliable AI Systems

Citadel ensures AI workloads remain available and can recover from failures while maintaining model performance over time.

### Citadel Implementation

#### Multi-Region High Availability
- **Multi-region LLM deployments** with automated failover for continuous service availability
- **Reliable state** for conversation history and agent state on Cosmos DB and Azure Monitor
- **Availability zones support** for critical components in supported regions

#### Fault Tolerance & Resilience
- **AI Gateway (Azure API Management)** provides circuit breakers, retry logic, and bulkhead patterns
- **Distributed architecture** with separate Citadel Governance Hub and Citadel Agents Spoke landing zones following Hub/Spoke model
- **Network isolation** with NSGs and private endpoints preventing cascading failures
- **Service isolation** through containerization and separate resource boundaries where every agentic deployment in separate Citadel Agent Spoke with central RBAC through Citadel Governance Hub

#### Operational Reliability
- **Automated workflows via Logic Apps** reducing manual intervention and human error
- **Azure AI Foundry managed runtime** providing reliable, maintained agent execution environment.
- **Version-controlled infrastructure** using Bicep and source controlled configurations (Citadel Contracts) for consistent, repeatable deployments of both central components and day-2 configurations

### Key Features

| Feature | Benefit | Implementation |
|---------|---------|----------------|
| Multi-Region LLM | Ensures API availability even during regional outages | Automated failover between LLM backends/regions |
| High-Availability Gateway | 99.95% SLA for API requests | Azure API Management Premium tier with multi-availability-zones and/or multi-region |
| Distributed Data Stores | Data remains accessible during failures | Leveraging Cosmos DB and Azure Monitor log analytics |
| Auto-Recovery | Minimizes downtime from transient failures | Circuit breakers and exponential backoff retry policies |

---

## 2. Security - Protecting AI Workloads and Data

### WAF Principle: Secure AI Systems and Earn User Trust

Citadel implements defense-in-depth security with Zero Trust architecture, content safety, and comprehensive data protection.

### Citadel Implementation

#### Earn User Trust with Responsible AI
- **Azure AI Content Safety integration** for all incoming requests and outgoing responses
- **Prompt Shield protection** against jailbreak attempts and prompt injection attacks
- **Protected content detection** screening for sensitive data at both AI Gateway level and at LLM model level (through Microsoft Purview)
- **Bidirectional content moderation** ensuring both user inputs and AI outputs are safe
- **Groundedness detection** validating AI responses against source documents to prevent hallucinations through AI Foundry Evals

#### Data Protection at All Layers
- **Encryption at rest** with platfrom managed keys
- **Encryption in transit** enforced via HTTPS/TLS 1.2+ for all communication
- **Private endpoints** for all AI services eliminating public internet exposure
- **Network security groups (NSGs)** controlling traffic flow between subnets
- **Virtual network integration** for all compute and data services

#### Robust Access Management
- **Gateway-keys pattern** - No direct API key exposure to users or applications
- **Managed identities** for service-to-service authentication eliminating stored credentials
- **Azure RBAC integration** providing granular permissions across all components
- **Role-based authorization at AI Gateway** enforcing least-privilege access per user/team
- **Azure Key Vault** for centralized secrets management with audit logging

#### Network Segmentation & Zero Trust
- **Zero Trust architecture** with assume breach mentality
- **Dedicated subnets with NSGs** for each service tier (web, app, data, AI)
- **Private networking** for container images, training data, and source code
- **Separate landing zones** (CGH for governance, CAS for agents) with controlled connectivity
- **Hub-spoke network topology** with centralized security controls

#### Security Testing & Compliance
- **CI/CD integration** for automated security scanning in deployment pipelines
- **Security policy enforcement** at gateway level before requests reach AI services
- **Container vulnerability scanning** in Azure Container Registry
- **Microsoft Purview integration** for data classification and governance
- **Audit logging** of all access and operations for compliance reporting

#### Minimize Attack Surface
- **Authentication required** for all inferencing endpoints - no anonymous access
- **Constrained API design** through AI Gateway limiting exposed functionality
- **API versioning and deprecation** allowing secure evolution of interfaces
- **Rate/token limiting and throttling** preventing abuse and resource exhaustion
- **Input validation** at multiple layers preventing injection attacks

### Key Features

| Feature | Benefit | Implementation |
|---------|---------|----------------|
| Content Safety | Prevents harmful content from entering or leaving the system | Azure AI Content Safety with custom policies |
| Zero Trust Networking | Eliminates implicit trust, reduces breach impact | Private endpoints, NSGs, no public internet access |
| Managed Identities | No credentials in code or config files | Azure Managed Identity for all service-to-service auth |
| Gateway-Keys Pattern | Centralized access control and monitoring | API keys managed at gateway, not exposed to clients |
| Data Encryption | Protects sensitive data at rest and in transit | Platform managed or with CMK encryption with Key Vault integration |

---

## 3. Cost Optimization - Maximizing ROI

### WAF Principle: Optimize Costs Without Sacrificing Quality

Citadel provides comprehensive cost visibility, tracking, and optimization to maximize return on AI investments.

### Citadel Implementation

#### Determine Cost Drivers
- **Granular usage analytics** tracking consumption by team, use case, and individual agent
- **Token consumption trends** with historical analysis in Cosmos DB
- **Cost attribution dashboard** in Citadel Governance Hub showing spend breakdown
- **Resource tagging strategy** enabling chargeback and showback models
- **Integrated Azure Cost Management** with budget alerts and forecasting

#### Pay for What You Intend to Use
- **Auto-scaling Container Apps & Foundry Agents** automatically adjusting compute based on demand
- **Multiple AI service tiers** supporting different performance and cost profiles
- **Serverless options** via Logic Apps and Azure Functions for event-driven workloads
- **Consumption-based pricing** for applicable compoenets (like Azure OpenAI pay-as-you-go)
- **Flexible deployment options** allowing teams to choose cost-performance balance

#### Use What You Pay For (Minimize Waste)
- **Token quotas and rate limiting** preventing accidental overspending
- **Auto-scaling with scale-to-zero** deallocating resources during idle periods
- **Centralized monitoring** of utilization metrics identifying underused resources
- **Cost accountability** assigned to operations teams with regular reviews
- **Automated resource cleanup** removing unused deployments and test environments

#### Optimize Operational Costs
- **Automated workflows** via Logic Apps reducing manual operational overhead
- **PaaS-first approach** minimizing infrastructure management costs
- **Shared infrastructure** across multiple agents and teams reducing duplication
- **DevOps automation** reducing time-to-market and manual deployment costs

### Key Features

| Feature | Benefit | Implementation |
|---------|---------|----------------|
| Usage Analytics | Understand where AI costs are incurred | Real-time dashboards with drill-down by dimension |
| Token Quotas | Prevent runaway costs from misbehaving agents | Configurable limits per user/team/agent |
| Auto-Scaling | Pay only for active workloads | Container Apps/Foundry Agents with scale-to-zero capability |
| Cost Attribution | Chargeback/showback to business units | Tagging and reporting by cost center |
| Monitoring & Alerts | Proactive cost anomaly detection | Azure Monitor alerts on budget thresholds |

---

## 4. Operational Excellence - Automation and Continuous Improvement

### WAF Principle: Streamline Operations and Enable Innovation

Citadel enables DevOps, and GenAIOps practices with comprehensive automation, monitoring, and safe deployment patterns.

### Citadel Implementation Recommendations

#### Minimize Operational Burden
- **PaaS-first architecture** using managed services (AI Foundry, API Management, Container Apps)
- **Managed identities** eliminating credential rotation and secret management overhead
- **Automated workflow orchestration** via Logic Apps for common operational tasks
- **Infrastructure-as-Code (Bicep)** enabling one-click deployments and consistent environments
- **Template-based agent deployment** empowering developers while maintaining governance

#### Automated Monitoring with Actionable Alerts
- **Azure Monitor Application Insights** integrated across all components
- **Comprehensive dashboards** at platform and individual agent levels
- **Actionable alerts** with context-specific remediation guidance
- **Enterprise notification integration** (Teams, email, ticketing systems)
- **Automated quality measurements** with trend analysis and anomaly detection
- **End-to-end tracing** from user request through AI processing to response

#### Detect and Mitigate Model Performance Issues
- **Automated evaluations** at platform level measuring groundedness, relevance, coherence
- **CI/CD integration** for regression testing before deployment
- **Quality metrics tracking** over time identifying model drift
- **Conversation replay capability** for debugging and quality analysis
- **Feedback collection** from users feeding continuous improvement

#### Safe Deployments
- **CI/CD pipelines** with automated testing gates
- **Multiple deployment strategies** support (blue/green, canary, rolling updates)
- **Pre-production testing environments** mirroring production configuration
- **Automated rollback capabilities** when health checks fail
- **Change tracking and audit logs** for compliance and troubleshooting

#### Evaluate and Improve User Experience
- **User feedback mechanisms** integrated into agent interfaces
- **Conversation logging with consent** enabling analysis and improvement
- **Engagement metrics** tracking user satisfaction and agent effectiveness
- **Session analytics** understanding user behavior patterns
- **Continuous improvement loop** from feedback to model refinement

### Key Features

| Feature | Benefit | Implementation |
|---------|---------|----------------|
| Comprehensive Monitoring | Full visibility into AI workload health | Application Insights with custom metrics and logs |
| Automated Evaluations | Ensure quality before and after deployment | AI Foundry evaluation pipelines in CI/CD |
| DevOps Integration | Accelerate development while maintaining quality | GitHub/Azure DevOps with automated gates |
| Feedback Loops | Continuous improvement from production insights | User feedback, conversation analytics, quality metrics |
| Infrastructure-as-Code | Consistent, repeatable deployments | Bicep templates with version control |

---

## 5. Performance Efficiency - Optimizing AI Workload Performance

### WAF Principle: Meet Performance Requirements Efficiently

Citadel ensures AI workloads meet performance targets through proper resource allocation, monitoring, and continuous optimization.

### Citadel Implementation

#### Establish Performance Benchmarks
- **Agent-level performance monitoring** tracking latency, throughput, and token consumption
- **Quality metrics tracking** measuring groundedness, relevance, coherence, fluency
- **Continuous re-evaluation** ensuring performance remains within acceptable ranges
- **Baseline establishment** for each agent type and use case
- **Performance trend analysis** identifying degradation over time

#### Evaluate and Right-Size Resources
- **Multiple SKU options** allowing teams to balance performance and cost
- **Load balancing via Application Gateway** distributing traffic for optimal resource utilization
- **Auto-scaling Container Apps** dynamically adjusting resources based on actual demand
- **Container resource quotas** preventing resource contention and ensuring fair allocation

#### Collect and Analyze Performance Metrics
- **Telemetry from all layers** - data pipeline, orchestration, model inference, and UI
- **Query latency and throughput tracking** with percentile analysis (p50, p95, p99)
- **End-to-end tracing** of agent execution identifying bottlenecks
- **Token consumption monitoring** optimizing prompt engineering for efficiency
- **Near real-time dashboards** enabling quick performance issue identification

#### Continuous Performance Improvement
- **Automated metric collection** feeding analysis and optimization
- **CI/CD integration** for performance regression testing
- **Production feedback loops** informing optimization decisions
- **Performance optimization recommendations** based on observed patterns
- **Caching strategies** reducing redundant processing and API calls

#### Load Balancing and Distribution
- **Multi-region load distribution** balancing traffic across Azure LLM deployments

### Key Features

| Feature | Benefit | Implementation |
|---------|---------|----------------|
| Performance Monitoring | Near real-time visibility into latency and throughput | Application Insights with custom telemetry |
| Auto-Scaling | Automatically match resources to demand | Container Apps with CPU/memory-based triggers |
| Load Balancing | Distribute traffic for optimal performance | Application Gateway with backend health monitoring |
| Quality Metrics | Ensure AI outputs meet standards efficiently | Automated evaluation of groundedness, relevance |
| Resource Optimization | Right-size compute for cost-performance balance | Monitoring with recommendations engine |

---

## Cross-Cutting Capabilities

### Governance & Control

Citadel Governance Hub (CGH) provides centralized governance across all WAF pillars:

- **Policy Enforcement** - Centralized security, cost, and quality policies applied consistently
- **Usage Analytics** - Real-time visibility into consumption patterns and costs
- **Compliance Reporting** - Audit trails, access logs, and regulatory compliance dashboards
- **Resource Management** - Centralized control over AI model deployments and configurations
- **Team Isolation** - Multi-tenancy with resource boundaries and access controls

### Observability

Comprehensive observability enables all WAF pillars:

- **Application Insights Integration** - Full-stack monitoring from UI to AI backend
- **Custom Dashboards** - Role-specific views for developers, operations, security, executives
- **Distributed Tracing** - End-to-end request tracking across service boundaries
- **Log Aggregation** - Centralized logging with advanced query and analysis capabilities
- **Alerting & Notification** - Context-aware alerts with automated remediation

### DevOps & Automation

Platform automation accelerates delivery while maintaining quality:

- **CI/CD Pipelines** - Automated build, test, deploy for agents and infrastructure
- **Infrastructure-as-Code** - Bicep templates for consistent environment provisioning
- **Automated Testing** - Unit, integration, and quality tests in deployment pipeline
- **Version Control** - Git-based workflow for code, configuration, and policies
- **Self-Service Deployment** - Empowering teams while maintaining governance guardrails

---

## Well-Architected Framework Trade-offs

Citadel provides balanced approaches to common WAF trade-offs:

### Security vs. Performance
- **Configurable security levels** - Adjust Content Safety strictness based on use case
- **Private endpoints optional** - Choose network isolation vs. simplified connectivity

### Cost vs. Reliability
- **Multi-region optional** - Deploy single-region for cost, multi-region for high availability
- **Tiered deployment patterns** - Basic, standard, premium configurations with clear trade-offs
- **Auto-scaling boundaries** - Set maximum scale to control costs while ensuring performance

### Performance vs. Cost
- **PTU vs. PAYG** - Choose reserved vs. consumption pricing for Azure LLM
- **Caching strategies** - Reduce costs and improve performance for repeated queries

### Developer Velocity vs. Governance
- **Template-based with guardrails** - Teams deploy reusable templates within policy boundaries
- **Automated compliance** - Security scanning and policy enforcement in centrally
- **Flexible approval gates** - Required for production, optional for development

---

## Getting Started with WAF Alignment

### 1. Assess Your Requirements

Determine your priorities across WAF pillars:

- **Mission-critical workloads** - Emphasize reliability and security
- **Cost-sensitive projects** - Focus on cost optimization and right-sizing
- **Innovation initiatives** - Prioritize developer velocity and experimentation
- **Regulated industries** - Ensure security and compliance

### 2. Configure Citadel for Your Needs

Citadel's modular architecture allows customization:

- **Network topology** - Hub-spoke vs. single VNet based on isolation needs
- **Deployment scope** - Single-region vs. multi-region based on availability requirements
- **Compute tier** - Container Apps vs. AI Foundry based on control and cost needs
- **Monitoring depth** - Adjust telemetry collection based on operational requirements

### 3. Implement Best Practices

Follow Citadel's reference implementations:

- **Use Infrastructure-as-Code** - Deploy via Bicep templates for consistency
- **Enable all security features** - Private endpoints, managed identities, Content Safety
- **Configure monitoring** - Set up dashboards and alerts appropriate for your team
- **Establish governance** - Define policies, quotas, and approval workflows

### 4. Continuous Improvement

Leverage Citadel's observability for ongoing optimization:

- **Review cost reports** - Monthly analysis of spending patterns and optimization opportunities
- **Monitor performance** - Track latency and quality metrics, adjust resources as needed
- **Security audits** - Regular review of access logs, security alerts, compliance status
- **Model quality** - Continuous evaluation and refinement based on production feedback

---

## Additional Resources

### Documentation
- [Citadel Technical Guide](platform-technical-guide.md) - Complete platform architecture and components

### External References
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)
- [Azure Well-Architected Framework for AI](https://learn.microsoft.com/en-us/azure/well-architected/ai/)
- [Azure AI Foundry Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/)
- [Responsible AI Principles](https://www.microsoft.com/en-us/ai/responsible-ai)

---

## Conclusion

The **Foundry Citadel Platform** provides comprehensive alignment with the Microsoft Well-Architected Framework for AI workloads through:

✅ **Strong Security** - Zero Trust, content safety, encryption, and access management  
✅ **High Reliability** - Multi-region support, fault tolerance, and automated recovery  
✅ **Cost Efficiency** - Granular tracking, quotas, auto-scaling, and optimization  
✅ **Operational Excellence** - Comprehensive monitoring, automation, and safe deployments  
✅ **Performance Optimization** - Load balancing, auto-scaling, and continuous monitoring  

By building on Azure's platform services and implementing proven patterns, Citadel enables organizations to deploy enterprise-grade AI solutions that balance governance, security, cost, performance, and innovation velocity—all while maintaining alignment with Microsoft's Well-Architected Framework principles.

---
