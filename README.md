# AI Landing Zone (preview)

AI Landing Zone (preview) provides an enterprise-scale reference architecture and infrastructure as code (Bicep, Terraform, planned Portal experience) to deploy secure, resilient AI applications and agent-based solutions on Azure. It can be used as a standalone application landing zone or integrated with an existing platform landing zone and aligns with Cloud Adoption Framework (CAF) and Well-Architected Framework (WAF) guidance.

> Preview: Scope and content may change. Some referenced Azure services are in preview. Evaluate feature maturity and compliance needs before production use in regulated environments.

Key characteristics:
- Application landing zone foundation (with or without a platform landing zone) per [CAF landing zone types](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone#platform-landing-zones-vs-application-landing-zones).
- Uses [Azure Verified Modules (AVM)](https://aka.ms/AVM) for Terraform and Bicep implementations.
- Focuses on [AI on Azure platform services](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/architectures); future versions will extend to infrastructure-based workloads.
- Designed for Azure public cloud; adaptable for government and sovereign clouds.
- Supports generative and traditional AI scenarios (see [resource selection guidance](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/resource-selection)).
- Uses [Semantic Kernel](https://learn.microsoft.com/semantic-kernel/overview/) for orchestration.
- Incorporates select preview services where they enable essential capabilities.

## Reference architectures

### With platform landing zone
Recommended configuration integrating shared enterprise platform services.
![AI Landing Zone architecture integrated with platform landing zone](/media/AI-Landing-Zone-with-platform.png)

### Standalone (without platform landing zone)
For organizations starting with an application-focused footprint before adopting a broader platform.
![AI Landing Zone standalone architecture (no platform landing zone)](/media/AI-Landing-Zone-without-platform.png)

## Reference implementations

Infrastructure as code implementations based on the defined service inventory and configuration.

| Implementation | Repository / status |
| -------------- | ------------------- |
| Terraform (AVM) | https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-landing-zone |
| Bicep (AVM) | https://github.com/Azure/bicep-avm-ptn-aiml-landing-zone |
| Portal experience | Planned (target: September 2025) |

## Design areas
The landing zone maps to CAF and WAF design areas. Each link provides guidance and implementation alignment.

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

## Use cases and scenarios
Foundation for building AI solutions on Azure. Extend with additional services as needed.

- Chat with Azure AI Foundry
- Agent-based orchestration with Azure AI Foundry
- Document generation
- Conversational copilots
- Custom copilot development
- Content processing and enrichment
- Conversational knowledge mining
- Application modernization with AI

## Cloud Adoption Framework alignment
Aligns with the [CAF AI scenario](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/). For implementation readiness, review the [AI checklists](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/#ai-checklists) and [AI strategy guidance](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/strategy). This landing zone is part of the AI Ready stage, especially [AI on Azure platforms (PaaS)](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/architectures).

![CAF AI readiness stages illustration](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg)

## Well-Architected Framework alignment
Follows workload guidance for design methodology, principles, and architectural areas in [AI workloads on Azure](https://learn.microsoft.com/azure/well-architected/ai/).
![AI architecture pattern illustration](https://learn.microsoft.com/azure/well-architected/ai/images/ai-architecture-pattern.png)

## Roadmap (planned)
The following scenarios are planned for future iterations:
- Azure Government Cloud variant
- Azure Sovereign Cloud variant
- Multi-region (BCDR)
- Multi-environment (dev / test / prod)
- Multi-application workloads
- Multi-cloud and hybrid integration
- Integration with data landing zone

## Next steps
1. Review a reference implementation (Terraform or Bicep).
2. Select required design areas and adapt configuration.
3. Prototype in a non-production subscription.
4. Establish monitoring, cost management, and governance baselines.
5. Progress to multi-region or regulated extensions as needed.

> Contributions for additional patterns (e.g., sustainability, regulated data, advanced governance) are welcome-see contributing section below.

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
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not confuse or imply Microsoft sponsorship.
Any use of third-party trademarks or logos is subject to those third parties' policies.
