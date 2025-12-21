# AI Landing Zone — Bicep Implementation

This repository contains a **Bicep template** that is built on top of **Azure Verified Modules (AVM)** together with a few custom modules. It provisions a secure and configurable environment for **generative AI workloads** on Azure.

## Architecture

 This architecture delivers a full **AI Landing Zone** built around **Azure AI Foundry**. The **AI Foundry Agent service**, together with **AI Search, Cosmos DB, Storage, and Key Vault**, operates securely and seamlessly. A dedicated **Azure Container Apps** environment enables custom **GenAI applications**, and supporting services cover configuration, data, and observability. Thanks to its modular design, you can deploy everything or only the components you need.

![Architecture](./docs/architecture.png)
*AI Landing Zone*

Flexibility comes from **deployment options**: you choose whether to create or reuse each service. This approach supports both greenfield deployments and integration with an existing platform landing zone.

Network isolation is enabled by default. Most PaaS connectivity uses Private Endpoints and Private DNS zones created during deployment (or linked to existing platform zones). API Management is deployed as **PremiumV2 + Internal VNet injection** by default (no APIM Private Endpoint).

## Documentation

* [**How to deploy the Landing Zone.**](./docs/how_to_use.md)
  Step-by-step instructions on creating or reusing resources, setting up isolation, and configuring parameters. Includes a minimal example and notes on running `azd provision`.

  ![Demo](./docs/demo.gif)

* [**Parameter reference.**](./docs/parameters.md)
  A complete list of parameters and outputs, along with the related resources and modules, aligned with the strongly typed contracts defined in [`types.bicep`](./infra/common/types.bicep).