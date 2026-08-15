# AI Citadel Governance Hub sizing guide

This guide provides recommendations for sizing the AI Citadel Governance Hub based on various deployment scenarios. Proper sizing ensures optimal performance, scalability, and cost-efficiency.

The approach is based on T-Shirt Sizing Methodology, which categorizes deployments into Small, Medium, and Large sizes based on expected workloads and user counts.

>NOTE: Below estimates are based on typical usage patterns and may vary based on specific customer requirements and workloads. It is advisable to conduct a detailed assessment for precise sizing.

## Governance Hub Environment Sizing

As a centralized supplemental landing zone for AI workloads, the AI Citadel Governance Hub can be sized based on the number of environments required by the customer. Common configurations include:
•	One central for production and non-production
•	Two with one for production and one for non-production
•	Other: based on customer requirements (like have 3 or more environments)

## T-Shirt Sizing Categories

### Small: development and experimental

No SLA – development only. Can be multiple environments per customer. Full network isolation supported
(Experimental, low load)
https://azure.com/e/b23669e7f59948c488608ecab4b7c1fa

### Medium Classic: non-production with SLA (or minimum production)
Minimum-production or non-production with SLA. Can be multiple environments per customer. Full network isolation supported (uses APIM Premium)
(Estimated to handle ~300-500 PTU)
https://azure.com/e/7a539b8ef73a4b5e87b5e60c079f0835
 
### Medium v2: non-production with SLA (or minimum production)
Minimum-production or non-production with SLA. Can be multiple environments per customer. Full network isolation supported (uses APIM Standard V2)
(Estimated to handle ~200 PTU per APIM unit)
https://azure.com/e/b44716c27c054c4eb979248744bc341d
 
### Large:
Multi-zone production setup with SLA. Full network isolation supported
(Estimated to handle ~1,000-1,500 PTU)
https://azure.com/e/fed48a9999804396a7e60d31550f24bf

## Considerations for sizing

When determining the appropriate size for the AI Citadel Governance Hub, consider the following factors:

- Above calculation excludes the sizing for the agentic applications (which would be sized separately based on their own requirements) 
- LLM and other AI services which should be sized based on the expected usage patterns and workloads.
- Medium and Medium V2 tiers can be scaled out by adding additional APIM units to handle increased load as per customer requirements.

## SKUs implementation

Based on the selected T-Shirt and environment, updating the SKUs in the deployment [main.bicepparam](../bicep/infra/main.bicepparam) under the `COMPUTE SKU & SIZE` section:

```bicep
// ============================================================================
// COMPUTE SKU & SIZE - SKUs and capacity settings for services
// ============================================================================
param apimSku = readEnvironmentVariable('APIM_SKU', 'StandardV2')
param apimSkuUnits = int(readEnvironmentVariable('APIM_SKU_UNITS', '1'))
param eventHubCapacityUnits = int(readEnvironmentVariable('EVENTHUB_CAPACITY', '1'))
param cosmosDbRUs = int(readEnvironmentVariable('COSMOS_DB_RUS', '400'))
param logicAppsSkuCapacityUnits = int(readEnvironmentVariable('LOGIC_APPS_SKU_CAPACITY_UNITS', '1'))
param apicSku = readEnvironmentVariable('APIC_SKU', 'Free')
param keyVaultSkuName = readEnvironmentVariable('KEY_VAULT_SKU_NAME', 'standard')
```
>NOTE: Above is the default parameters configurations. It needs to be adjusted based on the selections made based on final sizing.