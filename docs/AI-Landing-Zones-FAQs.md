# Frequently Asked Questions

## What is the difference between version Azure Landing Zone and AI Landing Zone?
The Azure Landing Zone is comprise of platform landing zone and application landing zone. The platform landing zone provides the foundational infrastructure and services required to support workloads in Azure, while the application landing zone is tailored for specific applications or workloads, ensuring they have the necessary resources and configurations to operate effectively. The AI landing zone is an application landing zone specifically designed to support AI workloads, incorporating specialized resources, configurations, and best practices for deploying and managing AI applications in Azure.

## What is the recommended reference architecture for AI Landing Zones, with or with out Platform Landing Zone?
The AI Landing Zone with Platform Landing Zone is the recommend reference architecture where shared services like firewall, DDoS, Bastion, jump boxes are centralized in the Platform Landing Zone whereas resources specific to an Agentic AI Application are in the AI Landing Zones. AI Landing Zone without Platform Landing Zone is suitable for scenarios where an organization either wants their AI Application to be independent and isolated from the rest of their platform and applications or for an organization that will only have a single AI Application hosted on Azure.

## What is the primary purpose of API Management service in AI Landing Zones?
The primary purpose for APIM in the AI landing zone is to act as the AI Gateway for models. For details refer to documentation [here](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/ai-gateway?view=foundry)
