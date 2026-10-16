---
hide:
  - toc
---

# AI Landing Zones

AI Landing Zones provides reference architectures and deployable implementations
for secure, resilient AI applications and agents on Azure. Choose Agent Landing
Zone, AI Gateway Landing Zone, or both.

![AI Landing Zones overview](https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone.png)

This [application landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/#platform-landing-zones-vs-application-landing-zones)
can run with or without a platform landing zone. Its Bicep and Terraform
implementations use [Azure Verified Modules](https://aka.ms/AVM) and focus on
[AI on Azure Platform](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures).

Designed and tested for Azure public cloud, it requires environment-specific
validation for government and sovereign deployments. Some Azure services used
by the solution may be in preview.

<span id="use-cases-scenarios"></span>

## Use cases

Build AI applications and agents on a secure Azure foundation for scenarios such as:

| Use case | Example scenario |
| --- | --- |
| **Knowledge assistants** | Help employees find answers in organizational policies, procedures, and technical documentation. |
| **Document processing** | Extract, classify, and summarize information from invoices, contracts, and reports. |
| **Business process agents** | Coordinate tasks across business systems, such as handling service requests and approval workflows. |

## Reference Architectures

### Agent Landing Zone

Agent Landing Zone provides an Azure foundation for AI applications and agents,
with a default application built on Microsoft Foundry. Deploy the infrastructure,
the application, or both using the [Agent Landing Zone guide](agent-landing-zone/index.md).

![Agent Landing Zone reference architecture](https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone-Foundry.png)

### AI Gateway Landing Zone

AI Gateway Landing Zone provides a shared gateway for AI applications and agents,
using Azure API Management to centrally manage access to Microsoft Foundry models.
Choose a Bicep or Terraform implementation [below](#extensible-implementations).

![AI Gateway Landing Zone reference architecture](https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zones-APIM.png)

<span id="foundry-modules"></span>
<span id="agent-landing-zone_1"></span>
<span id="ai-gateway-landing-zone_1"></span>

## Extensible Implementations

Choose an implementation for your deployment:

| Implementation | Bicep | Terraform | Portal |
| --- | --- | --- | --- |
| **Agent Landing Zone** | [View implementation](https://aka.ms/ailz/bicep) | [View implementation](https://aka.ms/ailz/terraform) | [![Deploy to Azure](https://learn.microsoft.com/en-us/azure/templates/media/deploy-to-azure.svg)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAI-Landing-Zones%2Frefs%2Fheads%2Fportal%2Fportal%2Ftemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAI-Landing-Zones%2Frefs%2Fheads%2Fportal%2Fportal%2Fform.json) |
| **AI Gateway Landing Zone** | [View implementation](https://aka.ms/ailz/apim) | [View implementation](https://aka.ms/ailz/aigateway/terraform) | &mdash; |
| **Foundry AVM Modules** | [View module](https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/ai-ml/ai-foundry) | [View module](https://registry.terraform.io/modules/Azure/avm-ptn-aiml-ai-foundry/azurerm/latest) | &mdash; |

<span id="whats-new"></span>
<span id="frequently-asked-questions"></span>

<span id="design-checklist"></span>

## Design areas

Use the [AI Landing Zone Checklist](architecture/design-checklist.md) to plan a new
environment or assess an existing one across the following design areas.

![AI Landing Zone design areas](https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone-design-area-checklist.png)

## Design and resources

### Cloud Adoption Framework

Start with the [CAF AI Scenario](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/),
[AI checklist](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/#ai-checklists),
and [AI strategy](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/strategy).
For generative and non-generative workloads, consult the
[resource selection guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/resource-selection).
For infrastructure-based AI workloads, see [AI on Azure Infrastructure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/infrastructure/cycle-cloud).

![Cloud Adoption Framework AI Ready guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg)

### Well-Architected Framework

Review the design principles and recommendations for
[AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/).

![Well-Architected Framework AI architecture patterns](https://learn.microsoft.com/en-us/azure/well-architected/ai/images/ai-architecture-pattern.png)

## Roadmap

AI Landing Zones continues to evolve with new Azure capabilities and customer
requirements. Explore the [project roadmap](https://aka.ms/ailz/roadmap) to follow
planned improvements and upcoming work across the reference architectures and
implementations.

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
