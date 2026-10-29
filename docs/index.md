---
template: home.html
description: Azure reference architectures and deployable foundations for AI applications and agents.
hide:
  - toc
---

<svg class="home-sr-only" aria-hidden="true"><symbol id="home-arrow" viewBox="0 0 24 24"><path d="M5 12h14m-5-5 5 5-5 5" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></symbol><symbol id="home-chevron" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></symbol></svg>

<section class="hero" id="top" markdown="1">

# Build AI.<span>On solid ground.</span> { #ai-landing-zones }

Reference architectures and deployable Azure foundations for your AI applications and agents.

<div class="actions">
<a class="home-button home-button--primary" href="#implementations">Deploy AI Landing Zone <svg aria-hidden="true"><use href="#home-arrow"/></svg></a>
<a class="home-button" href="#reference-architectures">Explore the architectures <svg aria-hidden="true"><use href="#home-arrow"/></svg></a>
</div>

<p class="foundation-note">Bicep and Terraform &nbsp;&middot;&nbsp; Built on <a href="https://aka.ms/AVM">Azure Verified Modules</a></p>

</section>

<section class="section" markdown="1">

## Choose your landing zone. { #choose-your-path }

<div class="paths" markdown="1">
<div class="path" markdown="1">
<span class="home-anchor" id="architecture"></span>
<h3 id="agent-landing-zone">Agent Landing Zone</h3>
<p>An Azure foundation for AI applications and agents, with a default application built on Microsoft Foundry.</p>
<p markdown="span">[Read the Agent guide :octicons-arrow-right-24:](agent-landing-zone/index.md){ .text-link }</p>
</div>
<div class="path" markdown="1">
<h3 id="ai-gateway-landing-zone">AI Gateway Landing Zone</h3>
<p>Shared model access for AI applications and agents, using Azure API Management.</p>
<a class="text-link" href="#gateway-implementation">Explore gateway implementations <svg aria-hidden="true"><use href="#home-arrow"/></svg></a>
</div>
</div>

<details class="home-disclosure overview-diagram">
<summary>How the landing zones connect <svg aria-hidden="true"><use href="#home-chevron"/></svg></summary>
<figure>
<img src="https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone.png" alt="AI Gateway Landing Zone centralizes models as a hub; Agent Landing Zone provides a workload spoke for agents. They can be used together or independently." width="1321" height="743" loading="lazy">
<figcaption>Use either landing zone independently, or combine them. <a href="https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone.png">Open the original diagram</a>.</figcaption>
</figure>
</details>

</section>

<section class="section" markdown="1">

## Reference architectures. { #reference-architectures }

<div class="architecture-workbench" data-home-tabs markdown="1">
<div class="home-tabs" role="tablist" aria-label="Reference architecture" hidden>
<button type="button" role="tab" id="tab-standalone" aria-selected="true" aria-controls="architecture-standalone">Standalone</button>
<button type="button" role="tab" id="tab-hub" aria-selected="false" aria-controls="architecture-hub" tabindex="-1">Platform Hub</button>
<button type="button" role="tab" id="tab-gateway" aria-selected="false" aria-controls="architecture-gateway" tabindex="-1">AI Gateway</button>
</div>

<div id="architecture-standalone" class="architecture-panel" role="tabpanel" aria-labelledby="tab-standalone" tabindex="0" markdown="1">
<div class="home-anchor" id="standalone"></div>
<h3 class="home-panel-title" id="standalone-panel-title">Standalone</h3>

The workload uses its own virtual network and networking services, without a shared platform hub.

<figure class="architecture-figure" markdown="1">
![Standalone Agent Landing Zone reference architecture](architecture/media/AI-Landing-Zone-without-platform.png?v=aa651551c880){ width=6400 height=3946 loading=lazy }
<figcaption markdown="block">
[Open the full-size standalone diagram](architecture/media/AI-Landing-Zone-without-platform.png?v=aa651551c880)

Resource selection and reuse depend on your implementation and settings. This reference shows the default hosted application without application Cosmos DB or its private endpoint; Foundry Agent Service's separate backing resources are retained.
</figcaption>
</figure>
</div>

<div id="architecture-hub" class="architecture-panel" role="tabpanel" aria-labelledby="tab-hub" tabindex="0" markdown="1">
<div class="home-anchor" id="with-platform-hub"></div>
<h3 class="home-panel-title" id="platform-hub-panel-title">With Platform Hub</h3>

The workload connects to a platform hub that provides shared connectivity, DNS and egress services.

<figure class="architecture-figure" markdown="1">
![Agent Landing Zone with Platform Hub reference architecture](architecture/media/AI-Landing-Zone-with-platform.png?v=e868bb76bceb){ width=6400 height=3822 loading=lazy }
<figcaption markdown="block">
[Open the full-size platform hub diagram](architecture/media/AI-Landing-Zone-with-platform.png?v=e868bb76bceb)

Resource selection and reuse depend on your implementation and settings. This reference shows the default hosted application without application Cosmos DB or its private endpoint; Foundry Agent Service's separate backing resources are retained.
</figcaption>
</figure>
</div>

<div id="architecture-gateway" class="architecture-panel" role="tabpanel" aria-labelledby="tab-gateway" tabindex="0" markdown="1">
<h3 class="home-panel-title">AI Gateway</h3>

Combine Agent Landing Zone, a platform hub and a separate AI Gateway Landing Zone. The gateway has its own deployment and connectivity requirements; Agent Landing Zone does not provision it automatically.

<figure class="architecture-figure" markdown="1">
![AI Gateway and Platform Hub integrated reference architecture](architecture/media/AI-Landing-Zones-APIM.png?v=27769aa5cbf0){ width=6400 height=5867 loading=lazy }
<figcaption markdown="block">
[Open the full-size integrated gateway diagram](architecture/media/AI-Landing-Zones-APIM.png?v=27769aa5cbf0)

Resource selection and reuse depend on your implementation and settings. The Agent Landing Zone portion shows the default hosted application without application Cosmos DB or its private endpoint; Foundry Agent Service's separate backing resources are retained.
</figcaption>
</figure>
</div>
</div>

[Choose your deployment approach :octicons-arrow-right-24:](agent-landing-zone/planning.md){ .text-link }

</section>

<section class="section" markdown="1">
<span class="home-anchor" id="implementation"></span>
<span class="home-anchor" id="extensible-implementations"></span>
<span class="home-anchor" id="agent-landing-zone_1"></span>
<span class="home-anchor" id="ai-gateway-landing-zone_1"></span>

## Choose your implementation. { #implementations }

<table class="implementation-table" role="table" markdown="1">
<caption class="home-sr-only">Implementation guides and modules for Bicep and Terraform</caption>
<thead role="rowgroup"><tr role="row"><th scope="col" role="columnheader">Implementation</th><th scope="col" role="columnheader">Bicep</th><th scope="col" role="columnheader">Terraform</th></tr></thead>
<tbody role="rowgroup" markdown="1">
<tr role="row" markdown="1">
<th scope="row" role="rowheader">Agent Landing Zone</th>
<td role="cell" data-label="Bicep" markdown="block">[Full stack runbook](agent-landing-zone/deploy-full-stack.md)

[Infrastructure only](agent-landing-zone/deploy-infra-only.md)</td>
<td role="cell" data-label="Terraform" markdown="block">[Full stack runbook](agent-landing-zone/deploy-terraform-full-stack.md)

[Infrastructure only](agent-landing-zone/deploy-terraform-infra-only.md)</td>
</tr>
<tr role="row" id="gateway-implementation" markdown="1">
<th scope="row" role="rowheader">AI Gateway Landing Zone</th>
<td role="cell" data-label="Bicep" markdown="span">[View implementation](https://aka.ms/ailz/apim)</td>
<td role="cell" data-label="Terraform" markdown="span">[View implementation](https://aka.ms/ailz/aigateway/terraform)</td>
</tr>
<tr role="row" markdown="1">
<th scope="row" role="rowheader" id="foundry-modules">Foundry AVM modules</th>
<td role="cell" data-label="Bicep" markdown="span">[Explore the module](https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/ai-ml/ai-foundry)</td>
<td role="cell" data-label="Terraform" markdown="span">[Explore the module](https://registry.terraform.io/modules/Azure/avm-ptn-aiml-ai-foundry/azurerm/latest)</td>
</tr>
</tbody>
</table>

<p class="portal-option">Prefer Azure Portal? <a href="https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAI-Landing-Zones%2Frefs%2Fheads%2Fportal%2Fportal%2Ftemplate.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAI-Landing-Zones%2Frefs%2Fheads%2Fportal%2Fportal%2Fform.json">Open the Agent Landing Zone deployment</a>.</p>
<p class="notice">Designed and tested for Azure public cloud. Validate government and sovereign deployments separately. Some included services may be in preview.</p>
<details class="home-disclosure" markdown="1">
<summary>Additional implementation references <svg aria-hidden="true"><use href="#home-chevron"/></svg></summary>

The [Bicep implementation](https://aka.ms/agenlz) and [Agent Landing Zone Terraform reference](agent-landing-zone/terraform.md) provide additional implementation details. The [shared AI Landing Zone Terraform foundation reference](terraform/index.md) is separate from Agent Landing Zone's integrated application lifecycle.

</details>
</section>

<section class="section" markdown="1">
<span class="home-anchor" id="workloads"></span>
<span class="home-anchor" id="use-cases-scenarios"></span>

## What will you build? { #use-cases }

<div class="use-case"><h3>Knowledge assistants</h3><p>Help employees find answers in organizational policies, procedures and technical documentation.</p></div>
<div class="use-case"><h3>Document processing</h3><p>Extract, classify and summarize information from invoices, contracts and reports.</p></div>
<div class="use-case"><h3>Business process agents</h3><p>Coordinate tasks across business systems, such as service requests and approval workflows.</p></div>

</section>

<section class="section" markdown="1">
<span class="home-anchor" id="design-and-resources"></span>
<div class="guidance-layout" markdown="1">
<header markdown="1">

## Design guidance. { #design-guidance }

Checklist and architecture guidance for your Azure environment.
</header>
<div class="resources" markdown="1">
<span class="home-anchor" id="design-checklist"></span>
<span class="home-anchor" id="design-areas"></span>
<p markdown="span">[**Design checklist** <small>Review identity, networking, data, operations and other design areas.</small> :octicons-arrow-right-24:](architecture/design-checklist.md)</p>
<p id="cloud-adoption-framework" markdown="span">[**Cloud Adoption Framework** <small>Plan AI adoption, from strategy to operations.</small> :octicons-arrow-right-24:](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/)</p>
<p id="well-architected-framework" markdown="span">[**Well-Architected Framework** <small>Evaluate AI workload quality and architectural trade-offs.</small> :octicons-arrow-right-24:](https://learn.microsoft.com/en-us/azure/well-architected/ai/)</p>
</div>
</div>

<details class="home-disclosure supporting-diagrams">
<summary>Supporting diagrams <svg aria-hidden="true"><use href="#home-chevron"/></svg></summary>
<div data-home-tabs>
<div class="home-tabs" role="tablist" aria-label="Supporting diagram" hidden>
<button type="button" role="tab" id="tab-design" aria-selected="true" aria-controls="diagram-design">Design areas</button>
<button type="button" role="tab" id="tab-caf" aria-selected="false" aria-controls="diagram-caf" tabindex="-1">CAF</button>
<button type="button" role="tab" id="tab-waf" aria-selected="false" aria-controls="diagram-waf" tabindex="-1">WAF</button>
</div>
<div id="diagram-design" role="tabpanel" aria-labelledby="tab-design" tabindex="0"><h3 class="home-panel-title" id="diagram-design-title">Design areas</h3><figure><img src="https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone-design-area-checklist.png" alt="AI Landing Zone design areas" width="1013" height="590" loading="lazy"><figcaption><a href="https://raw.githubusercontent.com/Azure/AI-Landing-Zones/main/media/AI-Landing-Zone-design-area-checklist.png">Open the original design areas diagram</a></figcaption></figure></div>
<div id="diagram-caf" role="tabpanel" aria-labelledby="tab-caf" tabindex="0"><h3 class="home-panel-title" id="diagram-caf-title">Cloud Adoption Framework</h3><figure><img src="https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg" alt="Cloud Adoption Framework AI Ready guidance" width="4681" height="906" loading="lazy"><figcaption><a href="https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/images/ai-ready.svg">Open the original Cloud Adoption Framework diagram</a></figcaption></figure></div>
<div id="diagram-waf" role="tabpanel" aria-labelledby="tab-waf" tabindex="0"><h3 class="home-panel-title" id="diagram-waf-title">Well-Architected Framework</h3><figure><img src="https://learn.microsoft.com/en-us/azure/well-architected/ai/images/ai-architecture-pattern.png" alt="Well-Architected Framework AI architecture patterns" width="1957" height="779" loading="lazy"><figcaption><a href="https://learn.microsoft.com/en-us/azure/well-architected/ai/images/ai-architecture-pattern.png">Open the original Well-Architected Framework diagram</a></figcaption></figure></div>
</div>
</details>

<details class="home-disclosure" markdown="1">
<summary>More Azure guidance <svg aria-hidden="true"><use href="#home-chevron"/></svg></summary>

Start with the [CAF AI Scenario](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/), [AI adoption steps](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/#5-how-to-adopt-ai), and [AI strategy](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/strategy). For generative and non-generative workloads, consult [AI on Azure Platform](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/architectures) and the [resource selection guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/resource-selection). For infrastructure-based AI workloads, see [AI on Azure Infrastructure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ai/infrastructure/ai-azure-infrastructure).

AI Landing Zones provides [workload landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) reference architectures and deployable implementations.

</details>

<details class="home-disclosure home-project-notes" markdown="1">
<summary>Project and legal information <svg aria-hidden="true"><use href="#home-chevron"/></svg></summary>
<span class="home-anchor" id="whats-new"></span>
<span class="home-anchor" id="frequently-asked-questions"></span>
<h3 id="roadmap">Roadmap</h3>

AI Landing Zones continues to evolve with new Azure capabilities and workload requirements. Explore the [project roadmap](https://aka.ms/ailz/roadmap) to follow planned improvements and upcoming work across the reference architectures and implementations.

<h3 id="contributing">Contributing</h3>

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

<h3 id="trademarks">Trademarks</h3>

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

</details>
</section>

<footer class="home-footer">
<div><a class="home-footer-brand" href="#top">AI Landing Zones</a><p class="home-copyright">&copy; 2026 Azure AI Landing Zones</p></div>
<nav class="home-footer-links" aria-label="Project resources"><a href="https://aka.ms/ailz/roadmap">Roadmap</a><a href="#contributing">Contributing</a><a href="#trademarks">Trademarks</a><a href="https://github.com/Azure/AI-Landing-Zones">GitHub</a></nav>
</footer>
