# AI Landing Zones

The AI Landing Zone provides an enterprise-scale production ready reference architecture with implementation (Portal, Bicep & Terraform) to deploy secure and resilient AI Apps & Agents solutions in Azure.

- The AI Landing Zone is an [application landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/#platform-landing-zones-vs-application-landing-zones) meant to act as a foundation for various use cases, scenarios and patterns of AI Apps & Agents based solutions which can be deployed with or without [platform landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/#platform-landing-zones-vs-application-landing-zones).
- The IaC implementations of the AI Landing Zone i.e. Bicep and Terraform are based on [Azure Verified Modules](https://aka.ms/AVM).
- The AI Landing Zone focuses on [AI on Azure Platform](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures). A future version of it will cover [AI on Azure Infrastructure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/infrastructure/cycle-cloud).
- The AI Landing Zone has been designed and tested for Azure Public Cloud but can be leveraged in the Azure Government and Sovereign Cloud.
- The AI Landing Zone is able to cover both generative and non-generative scenario per [resource selection guidance CAF AI Scenario](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/resource-selection).
- The AI Landing Zone leverages [Semantic Kernel](https://learn.microsoft.com/en-us/semantic-kernel/overview/) as the orchestration framework.
- Given the pace of innovation and change in AI, the AI Landing Zone may leverage services in Preview to provide an architecture with latest features.

## Reference Architectures

### AI Landing Zone with Platform Landing Zone

The below diagram represents the reference architecture of the AI Landing Zone with Platform Landing Zone which is our recommended configuration.
![image](/media/AI-Landing-Zone-with-platform.png)

### AI Landing Zone without Platform Landing Zone

The below diagram represents the reference architecture of the AI Landing Zone without Platform Landing Zone as a standalone application landing zone.
![image](/media/AI-Landing-Zone-without-platform.png)

## Extensible Implementations

The table represents the various reference implementations of the AI Landing Zone based on the service inventory & configuration

| Type | Description |
| ----------- | ----------- |
| Terraform | [Repo](https://aka.ms/ailz/terraform) |
| Bicep | [Repo](https://aka.ms/ailz/bicep) |
| Portal | Coming Soon |

## Design Checklist

The AI Landing Zone cover the following design areas which are across the Cloud Adoption Framework and the Well-Architected Framework. In each design area there are design considertion and design recommendations to help you design a greenfield environment and assess a brown field environment using the [AI Landing Zone Checklist](/docs/AI-Landing-Zones-Design-Checklist.md).

![image](/media/AI-Landing-Zone-design-area-checklist.png)

## Use cases & Scenarios
The AI Landing Zone act as a foundation architecture which can be leveraged to deploy a particular AI usecase & scenario on Azure, such as the below, either with its default architecture or by extending it with additional Azure services as needed.

- Chat Using Microsoft Foundry
- Agents Using Microsoft Foundry
- Document generation
- Conversational Agent
- Build your own copilot
- Content processing
- Conversation knowledge mining
- Modernize your code

## Roadmap
The AI Landing Zone is currently in preview. The roadmap for the project is available [here](https://aka.ms/ailz/roadmap).

## What's New
The latest updates to the AI Landing Zone are documented [here](./docs/AI-Landing-Zones-Whats-New.md).

## Frequently Asked Questions
The frequently asked questions about the AI Landing Zone are documented [here](./docs/AI-Landing-Zones-FAQ.md).

## Cloud Adoption Framework

The AI landing Zone aligns with the guidance in the [CAF AI Scenario](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/). For a holistic implementation of the AI Landing Zone, we recommend to review the [AI Checklist](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/#ai-checklists). To understand how to leverage the AI Landing Zone as part of a wider strategy, review the guidance on [AI Strategy](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/strategy). AI Landing Zone is part of the AI Ready stage in particular the [AI on Azure platforms (PaaS)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures).

![image](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg)

## Well-Architected Framework

The AI landing Zone aligns with the guidance in the WAF AI workload. For a holistic implementation of the AI Landing Zone, we recommend to review the design methodology, principles and areas of [AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/).
![image](https://learn.microsoft.com/en-us/azure/well-architected/ai/images/ai-architecture-pattern.png)

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
