# Operational Excellence

This document outlines the operational excellence specifications for AI Landing Zones.

## Specifications

| ID  | Specification |
|-----|---------------|
| O-1 | **Infrastructure-as-Code (IaC) & Deployment Automation**<br/>Use Bicep, Terraform templates to automate AI deployments.<br/>Reference: [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)<br/>Learn: [Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/) | [Terraform on Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/) |
| O-2 | **Monitoring & Observability**<br/>Integrate Azure Monitor natively with services like Azure OpenAI and APIM to track:<br/>• Request/response payloads<br/>• Latency<br/>• Throughput<br/>• Error rates [GenAI gate...using APIM]<br/><br/>Use custom events via Event Hubs for near real-time monitoring and alerting.<br/>Learn: [Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/) | [Event Hubs](https://learn.microsoft.com/en-us/azure/event-hubs/) |
| O-3 | *To be defined* |
| O-4 | *To be defined* |
| O-5 | *To be defined* |

## Additional Resources

### Infrastructure & Deployment
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Terraform on Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/)
- [Infrastructure as Code best practices](https://learn.microsoft.com/en-us/azure/architecture/framework/devops/iac)

### Monitoring & Observability
- [Azure Monitor overview](https://learn.microsoft.com/en-us/azure/azure-monitor/)
- [Azure Event Hubs documentation](https://learn.microsoft.com/en-us/azure/event-hubs/)
- [API Management monitoring](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-use-azure-monitor)
- [Azure OpenAI monitoring](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/monitoring)

### General Operational Excellence
- [Azure Well-Architected Framework - Operational Excellence](https://learn.microsoft.com/en-us/azure/architecture/framework/devops/overview)
- [Azure landing zones design principles](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-principles)
- [Cloud Adoption Framework - Operational Excellence](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/)
