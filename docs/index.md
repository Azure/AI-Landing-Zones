---
hide:
  - toc
---

# AI Landing Zones

Build AI applications and agents on a secure, resilient Azure foundation.
AI Landing Zones provides [workload landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
reference architectures and deployable implementations. Start with Agent Landing
Zone, centralize model access with AI Gateway Landing Zone, or combine both.

![AI Landing Zones overview](https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone.png)

<div class="landing-zone-overview" markdown="1">

<div markdown="1">

## Architecture

Agent Landing Zone provides the workload foundation, while AI Gateway Landing
Zone centralizes model access.

</div>

<div markdown="1">

## Implementation

Bicep and Terraform implementations built on [Azure Verified Modules](https://aka.ms/AVM).

</div>

<div markdown="1">

## Workloads

A foundation for generative and non-generative AI workloads, focused on
[AI on Azure Platform](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures).

</div>

</div>

!!! note
    Designed and tested for Azure public cloud. Validate government and sovereign
    deployments separately. Some included services may be in preview.

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

These reference architectures show private-network deployment options. Resource
selection and reuse depend on the implementation and deployment settings.
The Agent Landing Zone portions show the default hosted application without
application Cosmos DB or its private endpoint. Foundry Agent Service's separate
backing Cosmos DB is retained.

#### Standalone

The workload owns its networking and supporting services without a shared platform hub.

[![Standalone Agent Landing Zone reference architecture](architecture/media/AI-Landing-Zone-without-platform.png?v=23ad082c751c)](architecture/media/AI-Landing-Zone-without-platform.png?v=23ad082c751c)

#### With Platform Hub

The workload connects to a platform hub that provides shared connectivity, DNS
and egress services.

[![Agent Landing Zone with Platform Hub reference architecture](architecture/media/AI-Landing-Zone-with-platform.png?v=3bc5ea7251a1)](architecture/media/AI-Landing-Zone-with-platform.png?v=3bc5ea7251a1)

### AI Gateway Landing Zone

AI Gateway Landing Zone provides a shared gateway for AI applications and agents,
using Azure API Management to centrally manage access to Microsoft Foundry models.
Choose a Bicep or Terraform implementation [below](#extensible-implementations).

The integrated scenario below combines an Agent Landing Zone, a Platform Hub and
a separate AI Gateway Landing Zone. The gateway has its own deployment and
connectivity requirements; it is not provisioned automatically by Agent Landing Zone.

[![AI Gateway and Platform Hub integrated reference architecture](architecture/media/AI-Landing-Zones-APIM.png?v=95111fb4caec)](architecture/media/AI-Landing-Zones-APIM.png?v=95111fb4caec)

<span id="foundry-modules"></span>
<span id="agent-landing-zone_1"></span>
<span id="ai-gateway-landing-zone_1"></span>

## Extensible Implementations

Deploy with or without an existing Azure platform landing zone. Choose an
implementation below.

| Implementation | Bicep | Terraform | Portal |
| --- | --- | --- | --- |
| **Agent Landing Zone** | [View implementation](https://aka.ms/agenlz) | [View implementation](https://aka.ms/ailz/terraform) | [![Deploy to Azure](https://learn.microsoft.com/en-us/azure/templates/media/deploy-to-azure.svg)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAI-Landing-Zones%2Frefs%2Fheads%2Fportal%2Fportal%2Ftemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAI-Landing-Zones%2Frefs%2Fheads%2Fportal%2Fportal%2Fform.json) |
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
[AI adoption steps](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/#5-how-to-adopt-ai),
and [AI strategy](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/strategy).
For generative and non-generative workloads, consult the
[resource selection guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/resource-selection).
For infrastructure-based AI workloads, see [AI on Azure Infrastructure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ai/infrastructure/ai-azure-infrastructure).

![Cloud Adoption Framework AI Ready guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg)

### Well-Architected Framework

Review the design principles and recommendations for
[AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/).

![Well-Architected Framework AI architecture patterns](https://learn.microsoft.com/en-us/azure/well-architected/ai/images/ai-architecture-pattern.png)

## Roadmap

AI Landing Zones continues to evolve with new Azure capabilities and workload
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
