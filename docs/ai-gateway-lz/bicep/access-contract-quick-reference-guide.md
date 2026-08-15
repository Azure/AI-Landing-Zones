# 🚀 Citadel Access Contracts - Quick Reference Guide

## Overview

This quick reference guide provides a consistent and secure approach to managing **Citadel Access Contracts** for onboarding AI use cases to your APIM-based AI Gateway. It summarizes the key concepts, folder conventions, and deployment commands so you can onboard a new use case in minutes.

For the full walkthrough, parameter reference, and architecture, see the [Access Contract Guide](./README.md).

> 🧩 **Mixed asset types:** a contract can grant **LLM + Tools (MCP) + Agents (A2A)** in one product. Set the service `code` to `TOOL` / `AGENT` for a single published type, or `MULTI` when mixing types (e.g. `MULTI-HR-ChatAgent-DEV`), and list every granted API under `apiNameMapping[code]`. `TOOL` / `AGENT` / `MULTI` products get the asset-type-aware policy automatically. See [citadel-access-contracts-policy.md](./citadel-access-contracts-policy.md#asset-type-aware-policies-llm--tools--agents-in-one-product).

> 🔑 **One shared key, one endpoint per asset:** a multi-asset contract shares a **single** `apiKeySecretName` across all assets. Publish an endpoint secret **per asset** with `assetEndpoints: [{ apiName, endpointSecretName? }]` (empty name auto-generates `<code>-<bu>-<useCase>-<env>-<apiName>-endpoint`) or `publishAllAssetEndpoints: true`. Set `foundryApiName` to the LLM API so the Foundry connection targets the LLM endpoint. Pure-LLM contracts with just `endpointSecretName` + `apiKeySecretName` are unchanged. See the [service schema](./README.md#shared-key-one-endpoint-secret-per-asset).

## 📁 Folder Structure

Organize your access contracts by **business unit**, **use case**, and **environment** for clean source control and predictable deployments:

```
citadel-access-contracts/
├── main.bicep                          # Main orchestration template
├── base-contracts/
│   └── common/                         # Base default contract (Governance Hub coordinates)
│       ├── ai-product-policy.xml
│       └── main.bicepparam
└── contracts/                          # Use-case contracts for source control
    ├── business-unit-1/
    │   ├── use-case-1/
    │   │   ├── dev/
    │   │   │   ├── ai-product-policy.xml
    │   │   │   └── main.bicepparam
    │   │   └── prod/
    │   │       ├── ai-product-policy.xml
    │   │       └── main.bicepparam
    │   └── use-case-2/
    │       ├── dev/
    │       └── prod/
    └── business-unit-2/
        └── use-case-A/
            └── ...
```

- 🧱 **`base-contracts/common`**: Holds the base default access contract with shared Governance Hub coordinates (subscription, APIM name, and resource group of the Governance Hub deployment). The `citadel-access-contracts` folder ships sample `base-contracts/common` files you can customize.
- 📦 **`contracts/<business-unit>/<use-case>/<env>`**: One folder per environment, each containing a `main.bicepparam` and an optional `ai-product-policy.xml`.

## 🛠️ Onboarding Steps

1. **Create the use-case contract folder**: Under `contracts/`, follow the `<business-unit>/<use-case>` pattern (e.g., `sales/assistant`, `hr/chat-agent`).
2. **Add an environment subfolder**: Create a subfolder per environment (e.g., `dev`, `test`, `prod`).
3. **Prepare the parameter file**: Copy `main.bicepparam` as a base and customize it for your use case.
4. **Create/customize the APIM policy**: Use the default policy or author a custom `ai-product-policy.xml` placed alongside the parameter file.
5. **Deploy** using the command below.

## 🚀 Deployment Command

Ensure your terminal's active folder is the `citadel-access-contracts` folder, then deploy:

```bash
# This can be executed in CLI or through a DevOps pipeline
az deployment sub create \
  --name <ACCESS-CONTRACT-NAME> \
  --location <location> \
  --template-file main.bicep \
  --parameters contracts/<business-unit>/<use-case>/<env>/main.bicepparam
```

> **NOTE:** Replace the `<...>` placeholders with your specific access contract name, location, and the path to the parameters file for the desired business unit, use case, and environment.

## 📚 Additional Resources

Check out the following resources for more information on access contracts and best practices:
- [Access Contract Guide](./README.md)
- [Access Contract Policies](./citadel-access-contracts-policy.md)