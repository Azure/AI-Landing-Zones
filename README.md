# AI Landing Zone - Preview

The AI Landing Zone provides an enterprise-scale production-ready reference architecture with implementation (Portal, Bicep & Terraform) to deploy secure and resilient AI Apps & Agents solutions in Azure.

- The AI Landing Zone is an [application landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/#platform-landing-zones-vs-application-landing-zones) meant to act as a foundation for various use cases, scenarios, and patterns of AI Apps & Agents-based solutions which can be deployed with or without [platform landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/#platform-landing-zones-vs-application-landing-zones).
- The IaC implementations of the AI Landing Zone, i.e., Bicep and Terraform, are based on [Azure Verified Modules](https://aka.ms/AVM).
- The AI Landing Zone focuses on [AI on Azure Platform](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures). A future version of it will cover [AI on Azure Infrastructure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/infrastructure/cycle-cloud).
- The AI Landing Zone has been designed and tested for Azure Public Cloud, but can be leveraged in the Azure Government and Sovereign Cloud.
- The AI Landing Zone can cover both generative and non-generative scenarios per [resource selection guidance CAF AI Scenario](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/resource-selection).
- The AI Landing Zone leverages [Semantic Kernel](https://learn.microsoft.com/en-us/semantic-kernel/overview/) as the orchestration framework.
- Given the pace of innovation and change in AI, the AI Landing Zone may leverage services in Preview to provide an architecture with the latest features.

## Reference Architectures

### AI Landing Zone with Platform Landing Zone
The diagram below represents the reference architecture of the AI Landing Zone with Platform Landing Zone, which is our recommended configuration.
![image](/media/AI-Landing-Zone-with-platform.png)

### AI Landing Zone without Platform Landing Zone
The diagram below represents the reference architecture of the AI Landing Zone without Platform Landing Zone as a standalone application landing zone.
![image](/media/AI-Landing-Zone-without-platform.png)

### Upcoming AI Landing Zone Architectures
- AI Landing Zone in Azure Government Cloud
- AI Landing Zone in Azure Sovereign Cloud
- AI Landing Zone in Multi-Region for BCDR
- AI Landing Zone in Multi-Environment (Dev, Test, Prod)
- AI Landing Zone in Multi-App workloads
- AI Landing Zone in Multi-cloud & Hybrid environments
- AI Landing Zone with Data Landing Zone

## Extensible Implementations

The table represents the various reference implementations of the AI Landing Zone based on the service inventory & configuration.

| Type | Description |
| ----------- | ----------- |
| Terraform | [AVM Repo](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone) |
| Bicep | [AVM Repo](https://github.com/Azure/bicep-avm-ptn-aiml-landing-zone) |
| Portal | Coming Soon in September 2025 |

## Design Framework
The AI Landing Zone covers the following design areas, which are across the Cloud Adoption Framework and the Well-Architected Framework. In each design area, the AI Landing Zone aligns with design recommendations and best practices.

- [Security](/docs/Security.md)
- [Identity](/docs/Identity.md)
- [Compute](/docs/Compute.md)
- [Data](/docs/Data.md)
- [Reliability](/docs/Reliability.md)
- [Networking](/docs/Networking.md)
- [Governance](/docs/Governance.md)
- [Monitoring](/docs/Monitoring.md)
- [Cost Optimization](/docs/Cost-Optimization.md)
- [Platform Automation](/docs/Platform-Automation.md)
- [Resource Organization](/docs/Resource-Organization.md)
- [Operational Excellence](/docs/Operational-Excellence.md)
- [Performance Efficiency](/docs/Performance-Efficiency.md)

## Use cases & Scenarios
The AI Landing Zone serves as a foundational architecture for deploying specific AI use cases and scenarios on Azure, as illustrated below. It can be utilized with its default architecture or extended with additional Azure services as necessary.

- Chat Using Azure AI Foundry
- Agents Using Azure AI Foundry
- Document generation
- Conversational Agent
- Build your own copilot
- Content processing
- Conversation knowledge mining
- Modernize your code

## Cloud Adoption Framework
The AI Landing Zone aligns with the guidance in the [CAF AI Scenario](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/). For a holistic implementation of the AI Landing Zone, we recommend reviewing the [AI Checklist](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/#ai-checklists). To understand how to leverage the AI Landing Zone as part of a wider strategy, review the guidance on [AI Strategy](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/strategy). AI Landing Zone is part of the AI Ready stage, in particular, the [AI on Azure platforms (PaaS)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures).

![image](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg)

## Well-Architected Framework
The AI Landing Zone aligns with the guidance in the WAF AI workload. For a holistic implementation of the AI Landing Zone, we recommend reviewing the design methodology, principles, and areas of [AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/).
![image](https://learn.microsoft.com/en-us/azure/well-architected/ai/images/ai-architecture-pattern.png)

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos are subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not confuse or imply Microsoft sponsorship.
Any use of third-party trademarks or logos is subject to those third parties' policies.
