# Frequently Asked Questions

## What is the difference between version Azure Landing Zone and AI Landing Zone?
The Azure Landing Zone is comprise of platform landing zone and application landing zone. The platform landing zone provides the foundational infrastructure and services required to support workloads in Azure, while the application landing zone is tailored for specific applications or workloads, ensuring they have the necessary resources and configurations to operate effectively. The AI landing zone is an application landing zone specifically designed to support AI workloads, incorporating specialized resources, configurations, and best practices for deploying and managing AI applications in Azure.

## What is the recommended reference architecture for AI Landing Zones, with or with out Platform Landing Zone?
The AI Landing Zone with Platform Landing Zone is the recommend reference architecture where shared services like firewall, DDoS, Bastion, jump boxes are centralized in the Platform Landing Zone whereas resources specific to an Agentic AI Application are in the AI Landing Zones.
