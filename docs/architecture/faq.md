# Frequently Asked Questions

## How do Azure Landing Zones and AI Landing Zones relate?

Azure Landing Zones distinguish between a **platform landing zone**, which
provides shared services and governance, and **workload landing zones**, which
contain the resources for individual workloads.

An AI Landing Zone is a workload landing zone designed for AI services and
applications. It can integrate with an existing platform landing zone or provide
a standalone foundation when shared platform services are not available.

## Should I integrate with a platform landing zone or deploy standalone?

Use platform integration when your organization already provides shared
connectivity, DNS, firewall and administrative access. This keeps those services
centrally managed while AI-specific resources remain in the workload landing zone.

A standalone deployment is useful when no shared platform exists or the workload
needs a separately managed foundation. Its team must then operate the required
networking and governance services. Standalone does not, by itself, guarantee
network isolation or remove the need for security controls.

See the [Azure Landing Zones guidance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) and
[design checklist](design-checklist.md) before choosing a deployment model.
