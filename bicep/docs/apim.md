# API Management (APIM)

This repo can deploy an Azure API Management (APIM) service as part of the landing zone.

## Defaults

By default, [infra/main.bicep](../infra/main.bicep) deploys APIM as:

- `sku`: `PremiumV2`
- `virtualNetworkType`: `Internal`
- `subnetResourceId`: the dedicated `apim-subnet`

This is **VNet injection (Internal)**: the APIM gateway is reachable only from inside the virtual network.

## Networking options supported by this template

This template supports the following APIM connectivity patterns via `apimDefinition`:

### 1) VNet injection (Internal/External)

Use this when you want APIM deployed inside the VNet.

- Internal: private gateway endpoint (no public gateway)
- External: internet-facing gateway endpoint (public)

When using VNet injection, the APIM subnet must be delegated to `Microsoft.Web/hostingEnvironments`.
This repo applies this delegation automatically for the default `apim-subnet` and for the existing-VNet subnet helper.

Key parameters:

- `apimDefinition.virtualNetworkType`: `Internal` or `External`
- `apimDefinition.subnetResourceId`: resource ID of the APIM subnet

### 2) Private Endpoint to the APIM gateway (inbound)

Use this when you want clients to reach the APIM gateway over **Private Link**.

Important constraints:

- This template will only deploy the APIM Private Endpoint when `apimDefinition.virtualNetworkType = 'None'`.
  - Azure does not support creating an APIM Private Endpoint when APIM is configured as `Internal` VNet injection.

Key parameters:

- `apimDefinition.virtualNetworkType`: `None`
- `apimPrivateEndpointDefinition`: enabled (and Private DNS zones enabled)

### 3) Public (no VNet injection, no Private Endpoint)

Use this when you want a public APIM gateway and you do not want Private Link.

Key parameters:

- `apimDefinition.virtualNetworkType`: `None`
- Don’t enable `apimPrivateEndpointDefinition`

## How to configure (examples)

### PremiumV2 + Internal VNet injection (default)

```bicep
param apimDefinition = {
  name: 'apim-${baseName}'
  publisherEmail: 'admin@contoso.com'
  publisherName: 'Contoso'
  sku: 'PremiumV2'
  skuCapacity: 3
  virtualNetworkType: 'Internal'
  subnetResourceId: '<apim-subnet-resource-id>'
}
```

### StandardV2 + Private Endpoint (inbound)

```bicep
param apimDefinition = {
  name: 'apim-${baseName}'
  publisherEmail: 'admin@contoso.com'
  publisherName: 'Contoso'
  sku: 'StandardV2'
  skuCapacity: 1
  virtualNetworkType: 'None'
}

// Also provide apimPrivateEndpointDefinition + privateDnsZonesDefinition.apimZoneId (or let the template create them)
```

## Implementation note (PremiumV2)

The AVM module currently used in this repo for APIM does not expose `PremiumV2` as an allowed SKU.

To support `PremiumV2`, this repo deploys the APIM **service resource** using a native resource module:

- [infra/components/apim/main.bicep](../infra/components/apim/main.bicep)

For non-`PremiumV2` SKUs, the template continues to use the AVM wrapper.

## PremiumV2 regional availability

API Management **v2 tiers** (including **Premium v2**) are only available in a subset of Azure regions.
Microsoft keeps an up-to-date table here (last updated **Nov 18, 2025** at the time of writing):

- https://learn.microsoft.com/en-us/azure/api-management/api-management-region-availability

Even in supported regions, Microsoft notes that **regional capacity/availability can vary**, so deployments may still fail if capacity is constrained.
