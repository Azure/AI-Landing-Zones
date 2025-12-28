# AI/ML Landing Zone — Bicep parameter examples

This page provides the supported parameter examples for deploying the AI/ML Landing Zone (Bicep AVM).

## Table of Contents

1. [Greenfield — full new and isolated deployment](#1-greenfield--full-new-and-isolated-deployment)
2. [Existing VNet — reuse an existing virtual network](#2-existing-vnet--reuse-an-existing-virtual-network)
3. [Platform Landing Zone — PDNS/PE managed by the platform](#3-platform-landing-zone--pdnspe-managed-by-the-platform)

---

## 1. Greenfield — full new and isolated deployment

Use this scenario for a **new environment from scratch**.

This is the default recommended starting point.

Use the parameter file:

- [bicep/infra/sample.greenfield.bicepparam](../infra/sample.greenfield.bicepparam)
- [bicep/infra/main.bicepparam](../infra/main.bicepparam) (kept aligned with Greenfield)

Notes:
- This example enables an Azure Firewall + forced-tunneling UDRs so the Jump VM can reach the internet via the firewall (includes DNS + web egress rules). This is costlier but works out-of-the-box.

---

## 2. Existing VNet — reuse an existing virtual network

Use this when you already have a **pre-existing VNet** and only need to add the AI/ML Landing Zone subnets and resources.
The deployment **does not create a new VNet**; instead, it creates required subnets and NSGs inside the specified VNet, while still deploying platform services like Cosmos DB, Storage, Key Vault, App Insights, Log Analytics, and Container Registry/Env.
**In this example, it is assumed that the existing VNet has the address space `192.168.0.0/22` (or equivalent prefixes consistently adjusted), since the subnets below follow this structure.**
If you want Jump VM + forced tunneling, the existing VNet must contain the infra subnets (Firewall/Bastion/Jumpbox) and you must provide consistent next hop IPs.

Use the parameter file:

- [bicep/infra/sample.existing-vnet.bicepparam](../infra/sample.existing-vnet.bicepparam)

Notes:
- This example enables an Azure Firewall + forced-tunneling UDRs and includes DNS + web egress rules for jumpbox-subnet.

---

## 3. Platform Landing Zone — PDNS/PE managed by the platform

Choose this scenario when your **platform landing zone already manages Private DNS Zones and Private Endpoints**.
The AI/ML Landing Zone consumes the existing DNS zones you provide and does not create new ones.
You still deploy platform services like Cosmos DB, Storage, Key Vault, App Insights, Log Analytics, and Container Registry/Env.

In this mode, when you enable forced tunneling in the workload (spoke), outbound internet access from a jumpbox is typically controlled by the platform firewall policy (hub side).

Use the parameter file:

- [bicep/infra/sample.platform-landing-zone.bicepparam](../infra/sample.platform-landing-zone.bicepparam)
