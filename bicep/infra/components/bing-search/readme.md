# bing-search `[AiMl/LandingZoneComponentsBingSearch]`

Create-or-reuse a Bing Grounding account and its Cognitive Services connection to be used by Microsoft Foundry.

## Navigation

- [Resource Types](#Resource-Types)
- [Parameters](#Parameters)
- [Outputs](#Outputs)

## Resource Types

| Resource Type | API Version | References |
| :-- | :-- | :-- |
| `Microsoft.Bing/accounts` | 2025-05-01-preview | <ul style="padding-left: 0px;"><li>[AzAdvertizer](https://www.azadvertizer.net/azresourcetypes/microsoft.bing_accounts.html)</li><li>[Template reference](https://learn.microsoft.com/en-us/azure/templates)</li></ul> |
| `Microsoft.CognitiveServices/accounts/connections` | 2025-06-01 | <ul style="padding-left: 0px;"><li>[AzAdvertizer](https://www.azadvertizer.net/azresourcetypes/microsoft.cognitiveservices_accounts_connections.html)</li><li>[Template reference](https://learn.microsoft.com/en-us/azure/templates/Microsoft.CognitiveServices/2025-06-01/accounts/connections)</li></ul> |

## Parameters

**Conditional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`accountName`](#parameter-accountname) | string | The name of the Azure Cognitive Services account to be used for the Bing Search tool. Required if `enableBingSearchConnection` is true. |
| [`bingConnectionName`](#parameter-bingconnectionname) | string | The name to assign to the Bing Search connection in the project. Required if `enableBingSearchConnection` is true. |
| [`bingSearchName`](#parameter-bingsearchname) | string | The name to assign to the Bing Search resource instance (used when creating a new account). Required if `enableBingSearchConnection` is true. |
| [`projectName`](#parameter-projectname) | string | The name of the Azure Cognitive Services Project. Required if `enableBingSearchConnection` is true. |

**Optional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`existingResourceId`](#parameter-existingresourceid) | string | Existing Bing Grounding account resource ID to reuse instead of creating a new one. |

### Parameter: `accountName`

The name of the Azure Cognitive Services account to be used for the Bing Search tool. Required if `enableBingSearchConnection` is true.

- Required: Yes
- Type: string

### Parameter: `bingConnectionName`

The name to assign to the Bing Search connection in the project. Required if `enableBingSearchConnection` is true.

- Required: No
- Type: string
- Default: `[format('{0}-connection', parameters('bingSearchName'))]`

### Parameter: `bingSearchName`

The name to assign to the Bing Search resource instance (used when creating a new account). Required if `enableBingSearchConnection` is true.

- Required: Yes
- Type: string

### Parameter: `projectName`

The name of the Azure Cognitive Services Project. Required if `enableBingSearchConnection` is true.

- Required: Yes
- Type: string

### Parameter: `existingResourceId`

Existing Bing Grounding account resource ID to reuse instead of creating a new one.

- Required: No
- Type: string
- Default: `''`

## Outputs

| Output | Type | Description |
| :-- | :-- | :-- |
| `bingConnectionId` | string | Connection ID path under the AI services project. |
| `resourceGroupName` | string | Name of the resource group where the Bing Grounding account is deployed (same as the deployment resource group when creating a new account, or the existing account resource group when reusing). |
| `resourceId` | string | Resource ID of the Bing Grounding account (created or reused). |