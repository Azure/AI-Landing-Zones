# AI/ML Landing Zone — Bicep parameter examples

This page provides four complete examples of parameter files for deploying the AI/ML Landing Zone (Bicep AVM).

## Table of Contents

1. [Greenfield — full new and isolated deployment](#1-greenfield--full-new-and-isolated-deployment)
2. [Existing VNet — reuse an existing virtual network](#2-existing-vnet--reuse-an-existing-virtual-network)
3. [Platform Landing Zone — PDNS/PE managed by the platform](#3-platform-landing-zone--pdnspe-managed-by-the-platform)
4. [Minimal APIM — test APIM only](#4-minimal-apim--test-apim-only)

---

## 1. Greenfield — full new and isolated deployment

Use this scenario for a **new environment from scratch**.

Use the parameter file:

- [bicep/infra/sample.greenfield.bicepparam](../infra/sample.greenfield.bicepparam)
- (Same as) [bicep/infra/main.bicepparam](../infra/main.bicepparam)

---

## 2. Existing VNet — reuse an existing virtual network

Use this when you already have a **pre-existing VNet** and only need to add the AI/ML Landing Zone subnets and resources.
The deployment **does not create a new VNet**; instead, it creates required subnets and NSGs inside the specified VNet, while still deploying platform services like Cosmos DB, Storage, Key Vault, App Insights, Log Analytics, and Container Registry/Env.
**In this example, it is assumed that the existing VNet has the address space `192.168.0.0/22` (or equivalent prefixes consistently adjusted), since the subnets below follow this structure.**
Infra such as App Gateway, APIM, Firewall, Bastion, and Jumpbox is skipped.

Use the parameter file:

- [bicep/infra/sample.existing-vnet.bicepparam](../infra/sample.existing-vnet.bicepparam)

---

## 3. Platform Landing Zone — PDNS/PE managed by the platform

Choose this scenario when your **platform landing zone already manages Private DNS Zones and Private Endpoints**.
The AI/ML Landing Zone consumes the existing DNS zones you provide and does not create new ones.
You still deploy platform services like Cosmos DB, Storage, Key Vault, App Insights, Log Analytics, and Container Registry/Env, but network infra such as App Gateway, APIM, Firewall, Bastion, and Jumpbox is skipped.

Use the parameter file:

- [bicep/infra/sample.platform-landing-zone.bicepparam](../infra/sample.platform-landing-zone.bicepparam)

---

## 4. Minimal APIM — test APIM only

Use this scenario when you want a **minimal deployment focused on API Management**.
It deploys only:

- Virtual Network (with default subnets)
- API Management (default: **PremiumV2 + Internal VNet injection**)

This is useful for validating APIM provisioning and networking behavior without deploying the full stack.

Use the parameter file:

- [bicep/infra/sample.apim-minimal.bicepparam](../infra/sample.apim-minimal.bicepparam)

This file also includes a commented optional variant to test the **APIM Private Endpoint** path (StandardV2 + `virtualNetworkType: None`).
