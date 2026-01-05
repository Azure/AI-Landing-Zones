// Slim types.

// ---------------------------------------------
// Helpers
// ---------------------------------------------
@export()
@description('Open-ended tags map')
type tagsType = {
  *: string
}

// ---------------------------------------------
// Resource config types
// ---------------------------------------------
@export()
@description('Configuration object for AI Foundry and its associated resources.')
type aiFoundryDefinitionType = {
  // Optional
  @description('Optional. A friendly application/environment name to serve as the base when using the default naming for all resources in this deployment.')
  baseName: string?

  @description('Optional. A unique text value for the application/environment. Used to ensure resource names are unique for global resources. Defaults to a 5-character substring of the unique string generated from the subscription ID, resource group name, and base name.')
  baseUniqueName: string?

  @description('Optional. Enable/Disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Whether to include associated resources (Key Vault, AI Search, Storage Account, Cosmos DB). Defaults to true.')
  includeAssociatedResources: bool?

  @description('Optional. Location for all resources. Defaults to the resource group location.')
  location: string?

  @description('Optional. Lock configuration for the AI resources.')
  lock: {
    @description('Optional. Lock type.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. The Resource ID of the subnet to establish Private Endpoint(s). If provided, private endpoints will be created for the AI Foundry account and associated resources. Each resource will also require supplied private DNS zone resource ID(s).')
  privateEndpointSubnetResourceId: string?

  @description('Optional. Specifies the resource tags for all the resources.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  // Optional - AI Foundry Configuration
  @description('Optional. Custom configuration for the AI Foundry account.')
  aiFoundryConfiguration: {
    @description('Optional. The name of the AI Foundry account.')
    accountName: string?
    @description('Optional. Whether to allow project management in the account. Defaults to true.')
    allowProjectManagement: bool?
    @description('Optional. Whether to create capability hosts for the AI Agent Service. Requires includeAssociatedResources = true. Defaults to true.')
    createCapabilityHosts: bool?
    @description('Optional. Disables local authentication methods so that the account requires Microsoft Entra ID identities exclusively for authentication. Defaults to false for backward compatibility.')
    disableLocalAuth: bool?
    @description('Optional. Location of the AI Foundry account. Defaults to resource group location.')
    location: string?
    @description('Optional. Networking configuration for the AI Foundry account and project.')
    networking: {
      @description('Required. Private DNS Zone Resource ID for Azure AI Services.')
      aiServicesPrivateDnsZoneResourceId: string
      @description('Required. Private DNS Zone Resource ID for Cognitive Services.')
      cognitiveServicesPrivateDnsZoneResourceId: string
      @description('Required. Private DNS Zone Resource ID for OpenAI.')
      openAiPrivateDnsZoneResourceId: string
      @description('Optional. Subnet Resource ID for Azure AI Services. Required if you want to deploy AI Agent Service.')
      agentServiceSubnetResourceId: string?
    }?
    @description('Optional. Default AI Foundry project.')
    project: {
      @description('Optional. Project description.')
      description: string?
      @description('Optional. Friendly/display name of the project.')
      displayName: string?
      @description('Optional. Name of the project.')
      name: string?
    }?
    @description('Optional. Role assignments to apply to the AI Foundry account.')
    roleAssignments: object[]?
    @description('Optional. SKU of the AI Foundry / Cognitive Services account. Defaults to S0.')
    sku: 'F0' | 'S0'?
  }?

  // Optional - AI Model Deployments
  @description('Optional. Specifies the OpenAI deployments to create.')
  aiModelDeployments: {
    @description('Required. Deployment model configuration.')
    model: {
      @description('Required. Format of the deployment model.')
      format: string
      @description('Required. Name of the deployment model.')
      name: string
      @description('Required. Version of the deployment model.')
      version: string
    }
    @description('Optional. Name of the deployment.')
    name: string?
    @description('Optional. Responsible AI policy name.')
    raiPolicyName: string?
    @description('Optional. SKU configuration for the deployment.')
    sku: {
      @description('Required. SKU name.')
      name: string
      @description('Optional. SKU capacity.')
      capacity: int?
      @description('Optional. SKU family.')
      family: string?
      @description('Optional. SKU size.')
      size: string?
      @description('Optional. SKU tier.')
      tier: string?
    }?
    @description('Optional. Version upgrade option.')
    versionUpgradeOption: string?
  }[]?

  // Optional - Associated Resources
  @description('Optional. Custom configuration for AI Search.')
  aiSearchConfiguration: {
    @description('Optional. Existing AI Search resource ID. If provided, other properties are ignored.')
    existingResourceId: string?
    @description('Optional. Name for the AI Search resource.')
    name: string?
    @description('Optional. Private DNS Zone Resource ID for AI Search. Required if private endpoints are used.')
    privateDnsZoneResourceId: string?
    @description('Optional. Role assignments for the AI Search resource.')
    roleAssignments: object[]?
  }?

  @description('Optional. Custom configuration for Cosmos DB.')
  cosmosDbConfiguration: {
    @description('Optional. Existing Cosmos DB resource ID. If provided, other properties are ignored.')
    existingResourceId: string?
    @description('Optional. Name for the Cosmos DB resource.')
    name: string?
    @description('Optional. Private DNS Zone Resource ID for Cosmos DB. Required if private endpoints are used.')
    privateDnsZoneResourceId: string?
    @description('Optional. Role assignments for the Cosmos DB resource.')
    roleAssignments: object[]?
  }?

  @description('Optional. Custom configuration for Key Vault.')
  keyVaultConfiguration: {
    @description('Optional. Existing Key Vault resource ID. If provided, other properties are ignored.')
    existingResourceId: string?
    @description('Optional. Name for the Key Vault.')
    name: string?
    @description('Optional. Private DNS Zone Resource ID for Key Vault. Required if private endpoints are used.')
    privateDnsZoneResourceId: string?
    @description('Optional. Role assignments for the Key Vault resource.')
    roleAssignments: object[]?
  }?

  @description('Optional. Custom configuration for Storage Account.')
  storageAccountConfiguration: {
    @description('Optional. Existing Storage Account resource ID. If provided, other properties are ignored.')
    existingResourceId: string?
    @description('Optional. Name for the Storage Account.')
    name: string?
    @description('Optional. Private DNS Zone Resource ID for blob endpoint. Required if private endpoints are used.')
    blobPrivateDnsZoneResourceId: string?
    @description('Optional. Role assignments for the Storage Account.')
    roleAssignments: object[]?
  }?
}

@export()
@description('Configuration object for Azure App Configuration.')
type appConfigurationDefinitionType = {
  @description('Required. Name of the Azure App Configuration.')
  name: string

  @description('Optional. Indicates whether the configuration store needs to be recovered.')
  createMode: 'Default' | 'Recover'?

  @description('Optional. Customer Managed Key definition.')
  customerManagedKey: {
    @description('Required. Key name used for encryption.')
    keyName: string

    @description('Required. Resource ID of the Key Vault containing the key.')
    keyVaultResourceId: string

    @description('Optional. Enable or disable auto-rotation (default true).')
    autoRotationEnabled: bool?

    @description('Optional. Specific key version to use.')
    keyVersion: string?

    @description('Optional. User-assigned identity resource ID if system identity is not available.')
    userAssignedIdentityResourceId: string?
  }?

  @description('Optional. Data plane proxy configuration for ARM.')
  dataPlaneProxy: {
    @description('Required. Whether private link delegation is enabled.')
    privateLinkDelegation: 'Disabled' | 'Enabled'

    @description('Optional. Authentication mode for data plane proxy.')
    authenticationMode: 'Local' | 'Pass-through'?
  }?

  @description('Optional. Diagnostic settings for the service.')
  diagnosticSettings: {
    @description('Optional. Resource ID of the diagnostic event hub authorization rule.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Name of the diagnostic Event Hub.')
    eventHubName: string?

    @description('Optional. Destination type for Log Analytics. Allowed values: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Log categories and groups to stream.')
    logCategoriesAndGroups: {
      @description('Optional. Name of a diagnostic log category.')
      category: string?
      @description('Optional. Name of a diagnostic log category group.')
      categoryGroup: string?
      @description('Optional. Enable or disable the category. Default true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace partner resource ID.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metric categories to stream.')
    metricCategories: {
      @description('Required. Diagnostic metric category name.')
      category: string
      @description('Optional. Enable or disable the metric category. Default true.')
      enabled: bool?
    }[]?

    @description('Optional. Diagnostic setting name.')
    name: string?

    @description('Optional. Storage account resource ID for diagnostic logs.')
    storageAccountResourceId: string?

    @description('Optional. Log Analytics workspace resource ID for diagnostic logs.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. Disable all non-AAD authentication methods.')
  disableLocalAuth: bool?

  @description('Optional. Enable purge protection (default true, except Free SKU).')
  enablePurgeProtection: bool?

  @description('Optional. Enable or disable usage telemetry for module.')
  enableTelemetry: bool?

  @description('Optional. List of key/values to create (requires local auth).')
  keyValues: array?

  @description('Optional. Location for the resource (default resourceGroup().location).')
  location: string?

  @description('Optional. Lock settings.')
  lock: {
    @description('Optional. Lock type.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Managed identity configuration.')
  managedIdentities: {
    @description('Optional. Enable system-assigned managed identity.')
    systemAssigned: bool?
    @description('Optional. User-assigned identity resource IDs.')
    userAssignedResourceIds: array?
  }?

  @description('Optional. Private endpoint configuration.')
  privateEndpoints: {
    @description('Required. Subnet resource ID for the private endpoint.')
    subnetResourceId: string

    @description('Optional. Application Security Group resource IDs.')
    applicationSecurityGroupResourceIds: array?

    @description('Optional. Custom DNS configs.')
    customDnsConfigs: {
      @description('Required. Private IP addresses for the endpoint.')
      ipAddresses: array
      @description('Optional. FQDN that maps to the private IPs.')
      fqdn: string?
    }[]?

    @description('Optional. Custom network interface name.')
    customNetworkInterfaceName: string?

    @description('Optional. Enable or disable usage telemetry for the module.')
    enableTelemetry: bool?

    @description('Optional. Explicit IP configurations for the Private Endpoint.')
    ipConfigurations: {
      @description('Required. Name of this IP configuration.')
      name: string
      @description('Required. Object defining groupId, memberName, and privateIPAddress for the private endpoint IP configuration.')
      properties: {
        @description('Required. Group ID from the remote resource.')
        groupId: string
        @description('Required. Member name from the remote resource.')
        memberName: string
        @description('Required. Private IP address from the PE subnet.')
        privateIPAddress: string
      }
    }[]?

    @description('Optional. Use manual Private Link approval flow.')
    isManualConnection: bool?

    @description('Optional. Location to deploy the Private Endpoint to.')
    location: string?

    @description('Optional. Lock settings for the Private Endpoint.')
    lock: {
      @description('Optional. Lock type.')
      kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
      @description('Optional. Lock name.')
      name: string?
      @description('Optional. Lock notes.')
      notes: string?
    }?

    @description('Optional. Manual connection request message.')
    manualConnectionRequestMessage: string?

    @description('Optional. Name of the Private Endpoint resource.')
    name: string?

    @description('Optional. Private DNS Zone group configuration.')
    privateDnsZoneGroup: {
      @description('Required. Configs for linking PDNS zones.')
      privateDnsZoneGroupConfigs: {
        @description('Required. Private DNS Zone resource ID.')
        privateDnsZoneResourceId: string
        @description('Optional. Name of this DNS zone config.')
        name: string?
      }[]
      @description('Optional. Name of the Private DNS Zone group.')
      name: string?
    }?

    @description('Optional. Private Link service connection name.')
    privateLinkServiceConnectionName: string?

    @description('Optional. Resource group resource ID to place the PE in.')
    resourceGroupResourceId: string?

    @description('Optional. Role assignments for the Private Endpoint.')
    roleAssignments: object[]?

    @description('Optional. Target service group ID (as string).')
    service: string?

    @description('Optional. Tags to apply to the Private Endpoint.')
    tags: {
      @description('Required. Arbitrary key for each tag.')
      *: string
    }?
  }[]?

  @description('Optional. Whether public network access is allowed.')
  publicNetworkAccess: 'Disabled' | 'Enabled'?

  @description('Optional. Replica locations.')
  replicaLocations: {
    @description('Required. Azure region name for the replica.')
    replicaLocation: string
    @description('Optional. Replica name.')
    name: string?
  }[]?

  @description('Optional. Role assignments for App Configuration.')
  roleAssignments: object[]?

  @description('Optional. Pricing tier of App Configuration.')
  sku: 'Developer' | 'Free' | 'Premium' | 'Standard'?

  @description('Optional. Retention period in days for soft delete (1–7). Default 1.')
  softDeleteRetentionInDays: int?

  @description('Optional. Tags for the resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
}

@export()
@description('Configuration object for an Application Gateway resource.')
type appGatewayDefinitionType = {
  @description('Required. Name of the Application Gateway.')
  name: string

  @description('Conditional. Resource ID of the associated firewall policy. Required if SKU is WAF_v2.')
  firewallPolicyResourceId: string?

  @description('Optional. Authentication certificates of the Application Gateway.')
  authenticationCertificates: array?
  @description('Optional. Maximum autoscale capacity.')
  autoscaleMaxCapacity: int?
  @description('Optional. Minimum autoscale capacity.')
  autoscaleMinCapacity: int?
  @description('Optional. Availability zones used by the gateway.')
  availabilityZones: int[]?
  @description('Optional. Backend address pools of the Application Gateway.')
  backendAddressPools: array?
  @description('Optional. Backend HTTP settings.')
  backendHttpSettingsCollection: array?
  @description('Optional. Backend settings collection (see limits).')
  backendSettingsCollection: array?
  @description('Optional. Static instance capacity. Default is 2.')
  capacity: int?
  @description('Optional. Custom error configurations.')
  customErrorConfigurations: array?
  @description('Optional. Diagnostic settings for the Application Gateway.')
  diagnosticSettings: array?
  @description('Optional. Whether FIPS is enabled.')
  enableFips: bool?
  @description('Optional. Whether HTTP/2 is enabled.')
  enableHttp2: bool?
  @description('Optional. Enable request buffering.')
  enableRequestBuffering: bool?
  @description('Optional. Enable response buffering.')
  enableResponseBuffering: bool?
  @description('Optional. Enable or disable telemetry (default true).')
  enableTelemetry: bool?
  @description('Optional. Frontend IP configurations.')
  frontendIPConfigurations: array?
  @description('Optional. Frontend ports.')
  frontendPorts: array?
  @description('Optional. Gateway IP configurations (subnets).')
  gatewayIPConfigurations: array?
  @description('Optional. HTTP listeners.')
  httpListeners: array?
  @description('Optional. Listeners (see limits).')
  listeners: array?
  @description('Optional. Load distribution policies.')
  loadDistributionPolicies: array?
  @description('Optional. Location of the Application Gateway.')
  location: string?
  @description('Optional. Lock settings.')
  lock: {
    @description('Optional. Lock type.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?
  @description('Optional. Managed identities for the Application Gateway.')
  managedIdentities: {
    @description('Optional. User-assigned managed identity resource IDs.')
    userAssignedResourceIds: string[]?
  }?
  @description('Optional. Private endpoints configuration.')
  privateEndpoints: array?
  @description('Optional. Private link configurations.')
  privateLinkConfigurations: array?
  @description('Optional. Probes for backend health monitoring.')
  probes: array?
  @description('Optional. Redirect configurations.')
  redirectConfigurations: array?
  @description('Optional. Request routing rules.')
  requestRoutingRules: array?
  @description('Optional. Rewrite rule sets.')
  rewriteRuleSets: array?
  @description('Optional. Role assignments for the Application Gateway.')
  roleAssignments: object[]?
  @description('Optional. Routing rules.')
  routingRules: array?
  @description('Optional. SKU of the Application Gateway. Default is WAF_v2.')
  sku: 'Basic' | 'Standard_v2' | 'WAF_v2'?
  @description('Optional. SSL certificates.')
  sslCertificates: array?
  @description('Optional. SSL policy cipher suites.')
  sslPolicyCipherSuites: (
    | 'TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA'
    | 'TLS_DHE_DSS_WITH_AES_128_CBC_SHA'
    | 'TLS_DHE_DSS_WITH_AES_128_CBC_SHA256'
    | 'TLS_DHE_DSS_WITH_AES_256_CBC_SHA'
    | 'TLS_DHE_DSS_WITH_AES_256_CBC_SHA256'
    | 'TLS_DHE_RSA_WITH_AES_128_CBC_SHA'
    | 'TLS_DHE_RSA_WITH_AES_128_GCM_SHA256'
    | 'TLS_DHE_RSA_WITH_AES_256_CBC_SHA'
    | 'TLS_DHE_RSA_WITH_AES_256_GCM_SHA384'
    | 'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA'
    | 'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256'
    | 'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
    | 'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA'
    | 'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384'
    | 'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
    | 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA'
    | 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256'
    | 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
    | 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA'
    | 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384'
    | 'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
    | 'TLS_RSA_WITH_3DES_EDE_CBC_SHA'
    | 'TLS_RSA_WITH_AES_128_CBC_SHA'
    | 'TLS_RSA_WITH_AES_128_CBC_SHA256'
    | 'TLS_RSA_WITH_AES_128_GCM_SHA256'
    | 'TLS_RSA_WITH_AES_256_CBC_SHA'
    | 'TLS_RSA_WITH_AES_256_CBC_SHA256'
    | 'TLS_RSA_WITH_AES_256_GCM_SHA384')[]?
  @description('Optional. Minimum SSL protocol version.')
  sslPolicyMinProtocolVersion: 'TLSv1_0' | 'TLSv1_1' | 'TLSv1_2' | 'TLSv1_3'?
  @description('Optional. Predefined SSL policy name.')
  sslPolicyName:
    | ''
    | 'AppGwSslPolicy20150501'
    | 'AppGwSslPolicy20170401'
    | 'AppGwSslPolicy20170401S'
    | 'AppGwSslPolicy20220101'
    | 'AppGwSslPolicy20220101S'?
  @description('Optional. SSL policy type.')
  sslPolicyType: 'Custom' | 'CustomV2' | 'Predefined'?
  @description('Optional. SSL profiles.')
  sslProfiles: array?
  @description('Optional. Resource tags.')
  tags: {
    @description('Optional. Arbitrary tag keys and values.')
    *: string
  }?
  @description('Optional. Trusted client certificates.')
  trustedClientCertificates: array?
  @description('Optional. Trusted root certificates.')
  trustedRootCertificates: array?
  @description('Optional. URL path maps.')
  urlPathMaps: array?
}

@export()
@description('Application Insights config (open).')
type appInsightsDefinitionType = object

@export()
@description('APIM additional location item (open).')
type apimAdditionalLocationType = object

@export()
@description('APIM hostname configuration item (open).')
type apimHostnameConfigurationItemType = object

@export()
@description('Configuration object for the Azure API Management service to be deployed.')
type apimDefinitionType = {
  // Required
  @description('Required. Name of the API Management service.')
  name: string
  @description('Required. Publisher email address.')
  publisherEmail: string

  @description('Required. Publisher display name.')
  publisherName: string
  // Conditional
  @description('Conditional. SKU capacity. Required if SKU is not Consumption.')
  skuCapacity: int?
  // Optional
  @description('Optional. Additional locations for the API Management service.')
  additionalLocations: array?

  @description('Optional. API diagnostics for APIs.')
  apiDiagnostics: array?

  @description('Optional. APIs to create in the API Management service.')
  apis: array?

  @description('Optional. API version sets to configure.')
  apiVersionSets: array?

  @description('Optional. Authorization servers to configure.')
  authorizationServers: array?

  @description('Optional. Availability Zones for HA deployment.')
  availabilityZones: int[]?

  @description('Optional. Backends to configure.')
  backends: array?

  @description('Optional. Caches to configure.')
  caches: array?

  @description('Optional. Certificates to configure for API Management. Maximum of 10 certificates.')
  certificates: array?

  @description('Optional. Custom properties to configure.')
  customProperties: object?

  @description('Optional. Diagnostic settings for the API Management service.')
  diagnosticSettings: array?

  @description('Optional. Disable gateway in a region (for multi-region setup).')
  disableGateway: bool?

  @description('Optional. Enable client certificate for requests (Consumption SKU only).')
  enableClientCertificate: bool?

  @description('Optional. Enable developer portal for the service.')
  enableDeveloperPortal: bool?

  @description('Optional. Enable/disable usage telemetry for module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Hostname configurations for the API Management service.')
  hostnameConfigurations: array?

  @description('Optional. Identity providers to configure.')
  identityProviders: array?

  @description('Optional. Location for the API Management service. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the API Management service.')
  lock: {
    @description('Optional. Type of lock. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Name of the lock.')
    name: string?

    @description('Optional. Notes for the lock.')
    notes: string?
  }?

  @description('Optional. Loggers to configure.')
  loggers: array?

  @description('Optional. Managed identity settings for the API Management service.')
  managedIdentities: {
    @description('Optional. Enables system-assigned managed identity.')
    systemAssigned: bool?

    @description('Optional. User-assigned identity resource IDs.')
    userAssignedResourceIds: string[]?
  }?

  @description('Optional. Minimum ARM API version to use for control-plane operations.')
  minApiVersion: string?

  @description('Optional. Named values to configure.')
  namedValues: array?

  @description('Optional. Notification sender email address.')
  notificationSenderEmail: string?

  @description('Optional. Helper for generating new GUID values.')
  newGuidValue: string?

  @description('Optional. Policies to configure.')
  policies: array?

  @description('Optional. Portal settings for the developer portal.')
  portalsettings: array?

  @description('Optional. Products to configure.')
  products: array?

  @description('Optional. Public IP address resource ID for API Management.')
  publicIpAddressResourceId: string?

  @description('Optional. Restore configuration for undeleting API Management services.')
  restore: bool?

  @description('Optional. Role assignments for the API Management service.')
  roleAssignments: array?

  @description('Optional. SKU of the API Management service. Allowed values: Basic, BasicV2, Consumption, Developer, Premium, PremiumV2, Standard, StandardV2.')
  sku: 'Basic' | 'BasicV2' | 'Consumption' | 'Developer' | 'Premium' | 'PremiumV2' | 'Standard' | 'StandardV2'?


  @description('Optional. Subnet resource ID for VNet integration.')
  subnetResourceId: string?

  @description('Optional. Subscriptions to configure.')
  subscriptions: array?

  @description('Optional. Tags to apply to the API Management service.')
  tags: object?

  @description('Optional. Virtual network type. Allowed values: None, External, Internal.')
  virtualNetworkType: 'None' | 'External' | 'Internal'?
}

@export()
@description('Configuration object for the Azure Bastion service to be deployed.')
type bastionDefinitionType = {
  @description('Optional. Bastion host name.')
  name: string?
  @description('Required. Azure Bastion SKU.')
  sku: string
  @description('Optional. Tags to apply to the Bastion resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
  @description('Required. Availability zones to use for Bastion (if supported).')
  zones: string[]
}

@export()
@description('Marketplace image reference.')
type vmImageReferenceType = {
  @description('Optional. Publisher name.')
  publisher: string?
  @description('Optional. Offer name.')
  offer: string?
  @description('Optional. SKU name.')
  sku: string?
  @description('Optional. Image version (e.g., latest).')
  version: string?
  @description('Optional. Community gallery image ID.')
  communityGalleryImageId: string?
  @description('Optional. Resource ID.')
  id: string?
  @description('Optional. Shared gallery image ID.')
  sharedGalleryImageId: string?
}

@export()
@description('Unified VM configuration for both Build and Jump VMs.')
type vmDefinitionType = {
  @description('Optional. VM name.')
  name: string?
  @description('Optional. VM size SKU (e.g., Standard_B2s, Standard_D2s_v5).')
  sku: string?
  @description('Optional. Admin username to create (e.g., azureuser).')
  adminUsername: string?
  @description('Optional. Network interface configurations.')
  nicConfigurations: array?
  @description('Optional. OS disk configuration.')
  osDisk: object?
  @description('Optional. Location for all resources.')
  location: string?
  @description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
  enableTelemetry: bool?
  @description('Optional. OS type for the VM.')
  osType: ('Linux' | 'Windows')?
  @description('Optional. Marketplace image reference for the VM.')
  imageReference: vmImageReferenceType?

  @description('Optional. Enable/disable EncryptionAtHost for the VM.')
  encryptionAtHost: bool?
  @description('Optional. Admin password for the VM.')
  @secure()
  adminPassword: string?
  @description('Optional. Availability zone.')
  availabilityZone: int?
  @description('Optional. Lock configuration.')
  lock: object?
  @description('Optional. Managed identities.')
  managedIdentities: object?
  @description('Optional. Enable system-assigned managed identity for the VM. Default is true.')
  enableSystemAssignedManagedIdentity: bool?
  @description('Optional. Role assignments for the VM managed identity. Each assignment can specify roleDefinitionIdOrName and principalType. Scope defaults to resource group if resourceGroupName is specified, otherwise uses the VM resource scope.')
  roleAssignments: array?
  @description('Optional. Force password reset on first login.')
  requireGuestProvisionSignal: bool?
  @description('Optional. Tags to apply to the VM resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
  
  // Build VM specific properties
  @description('Optional. Which agent to install (Build VM only).')
  runner: ('azdo' | 'github')?
  @description('Optional. Azure DevOps settings (required when runner = azdo, Build VM only).')
  azdo: {
    @description('Required. Azure DevOps organization URL (e.g., https://dev.azure.com/contoso).')
    orgUrl: string
    @description('Required. Agent pool name.')
    pool: string
    @description('Optional. Agent name.')
    agentName: string?
    @description('Optional. Working folder.')
    workFolder: string?
  }?
  @description('Optional. GitHub settings (required when runner = github, Build VM only).')
  github: {
    @description('Required. GitHub owner (org or user).')
    owner: string
    @description('Required. Repository name.')
    repo: string
    @description('Optional. Runner labels (comma-separated).')
    labels: string?
    @description('Optional. Runner name.')
    agentName: string?
    @description('Optional. Working folder.')
    workFolder: string?
  }?
  @description('Optional. Disable password authentication (Build VM only).')
  disablePasswordAuthentication: bool?
  @description('Optional. SSH public keys (Build VM only).')
  publicKeys: array?
  
  // Jump VM specific properties
  @description('Optional. When true (default), runs the Jump VM Custom Script Extension to download and execute bicep/infra/install.ps1 (Jump VM only).')
  enableAutoInstall: bool?
  @description('Optional. When true (default), creates a Contributor role assignment for the Jump VM managed identity at the deployment resource group scope (Jump VM only).')
  assignContributorRoleAtResourceGroup: bool?
  @description('Optional. Resource ID of the maintenance configuration (Jump VM only).')
  maintenanceConfigurationResourceId: string?
  @description('Optional. Patch mode for the VM (Jump VM only).')
  patchMode: '' | 'AutomaticByOS' | 'AutomaticByPlatform' | 'ImageDefault' | 'Manual'?
  @description('Optional. Enable automatic updates (Jump VM only).')
  enableAutomaticUpdates: bool?
}

// Keep backward compatibility aliases
@export()
@description('Build VM configuration (alias for vmDefinitionType).')
type buildVmDefinitionType = vmDefinitionType

@export()
@description('Jump VM configuration (alias for vmDefinitionType).')
type jumpVmDefinitionType = vmDefinitionType

@export()
@description('Configuration object for a Container Apps Managed Environment.')
type containerAppEnvDefinitionType = {
  @description('Required. Name of the Container Apps Managed Environment.')
  name: string

  @description('Conditional. Docker bridge CIDR range for the environment. Must not overlap with other IP ranges. Required if zoneRedundant is set to true to be WAF compliant.')
  dockerBridgeCidr: string?

  @description('Conditional. Infrastructure resource group name. Required if zoneRedundant is set to true to be WAF compliant.')
  infrastructureResourceGroupName: string?

  @description('Conditional. Resource ID of the subnet for infrastructure components. Required if "internal" is true. Required if zoneRedundant is set to true to be WAF compliant.')
  infrastructureSubnetResourceId: string?

  @description('Conditional. Boolean indicating if only internal load balancer is used. Required if zoneRedundant is set to true to be WAF compliant.')
  internal: bool?

  @description('Conditional. Reserved IP range in CIDR notation for infrastructure. Required if zoneRedundant is set to true to be WAF compliant.')
  platformReservedCidr: string?

  @description('Conditional. Reserved DNS IP within platformReservedCidr for internal DNS. Required if zoneRedundant is set to true to be WAF compliant.')
  platformReservedDnsIP: string?

  @description('Conditional. Workload profiles for the Managed Environment. Required if zoneRedundant is set to true to be WAF compliant.')
  workloadProfiles: array?

  @secure()
  @description('Optional. Application Insights connection string.')
  appInsightsConnectionString: string?

  @description('Optional. App Logs configuration for the Managed Environment.')
  appLogsConfiguration: {
    @description('Conditional. Log Analytics configuration. Required if destination is log-analytics.')
    logAnalyticsConfiguration: {
      @description('Required. Log Analytics Workspace ID.')
      customerId: string

      @secure()
      @description('Required. Shared key of the Log Analytics workspace.')
      sharedKey: string
    }?

    @description('Optional. Destination of the logs. Allowed values: azure-monitor, log-analytics, none.')
    destination: 'azure-monitor' | 'log-analytics' | 'none'?
  }?

  @description('Optional. Managed Environment Certificate configuration.')
  certificate: {
    @description('Optional. Key Vault reference for certificate.')
    certificateKeyVaultProperties: {
      @description('Required. Identity resource ID used to access Key Vault.')
      identityResourceId: string

      @description('Required. Key Vault URL referencing the certificate.')
      keyVaultUrl: string
    }?

    @description('Optional. Certificate password.')
    certificatePassword: string?

    @description('Optional. Certificate type. Allowed values: ImagePullTrustedCA, ServerSSLCertificate.')
    certificateType: 'ImagePullTrustedCA' | 'ServerSSLCertificate'?

    @description('Optional. Certificate value (PFX or PEM).')
    certificateValue: string?

    @description('Optional. Certificate name.')
    name: string?
  }?

  @secure()
  @description('Optional. Password of the certificate used by the custom domain.')
  certificatePassword: string?

  @secure()
  @description('Optional. Certificate to use for the custom domain (PFX or PEM).')
  certificateValue: string?

  @secure()
  @description('Optional. Application Insights connection string for Dapr telemetry.')
  daprAIConnectionString: string?

  @secure()
  @description('Optional. Azure Monitor instrumentation key for Dapr telemetry.')
  daprAIInstrumentationKey: string?

  @description('Optional. DNS suffix for the environment domain.')
  dnsSuffix: string?

  @description('Optional. Enable or disable telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the Managed Environment.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Lock name.')
    name: string?

    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Managed identity configuration for the Managed Environment.')
  managedIdentities: {
    @description('Optional. Enable system-assigned managed identity.')
    systemAssigned: bool?

    @description('Optional. User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.')
    userAssignedResourceIds: array?
  }?

  @description('Optional. Open Telemetry configuration.')
  openTelemetryConfiguration: object?

  @description('Optional. Whether peer traffic encryption is enabled. Default is true.')
  peerTrafficEncryption: bool?

  @description('Optional. Whether to allow or block public network traffic. Allowed values: Disabled, Enabled.')
  publicNetworkAccess: 'Disabled' | 'Enabled'?

  @description('Optional. Role assignments to create for the Managed Environment.')
  roleAssignments: object[]?

  @description('Optional. List of storages to mount on the environment.')
  storages: {
    @description('Required. Access mode for storage. Allowed values: ReadOnly, ReadWrite.')
    accessMode: 'ReadOnly' | 'ReadWrite'

    @description('Required. Type of storage. Allowed values: NFS, SMB.')
    kind: 'NFS' | 'SMB'

    @description('Required. File share name.')
    shareName: string

    @description('Required. Storage account name.')
    storageAccountName: string
  }[]?

  @description('Optional. Tags to apply to the Managed Environment.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. Whether the Managed Environment is zone redundant. Default is true.')
  zoneRedundant: bool?
}

@export()
@description('Container App Definition Type')
type containerAppDefinitionType = {
  @description('Required. The name of the Container App.')
  name: string

  @description('Required. Resource ID of the Container App Environment.')
  environmentResourceId: string

  @description('Optional. Workload profile name to pin for container app execution.')
  workloadProfileName: string?

  @description('Optional. Collection of private container registry credentials used by a Container app.')
  containers: object?

  @description('Optional. ActiveRevisionsMode controls how active revisions are handled for the Container app.')
  activeRevisionsMode: ('Multiple' | 'Single')?

  @description('Optional. Additional port mappings for the container app.')
  additionalPortMappings: object[]?

  @description('Optional. AuthConfig of the Container App.')
  authConfig: object?

  @description('Optional. Client certificate mode for mTLS authentication.')
  clientCertificateMode: ('accept' | 'ignore' | 'require')?

  @description('Optional. CORS policy configuration.')
  corsPolicy: object?

  @description('Optional. Custom domain configuration for the Container App.')
  customDomains: object[]?

  @description('Optional. Dapr configuration for the Container App.')
  dapr: object?

  @description('Optional. The diagnostic settings of the service.')
  diagnosticSettings: object[]?

  @description('Optional. Managed identities for the Container App.')
  identitySettings: object?

  @description('Optional. Init containers which run before the app container.')
  initContainersTemplate: object[]?

  @description('Optional. Rules to restrict incoming IP address.')
  ipSecurityRestrictions: object[]?

  @description('Optional. The lock settings of the service.')
  lock: object?

  @description('Optional. Location for all resources.')
  location: string?

  @description('Optional. The managed identity definition for this resource.')
  managedIdentities: object?

  @description('Optional. Collection of private container registry credentials used by a Container app.')
  registries: object[]?

  @description('Optional. User provided suffix to append to revision of the Container App.')
  revisionSuffix: string?

  @description('Optional. Array of role assignments.')
  roleAssignments: object[]?

  @description('Optional. Container App runtime.')
  runtime: object?

  @description('Optional. Container App scaling settings.')
  scaleSettings: object?

  @description('Optional. The secrets of the Container App.')
  secrets: object?

  @description('Optional. Container App service configuration.')
  service: object?

  @description('Optional. Container App service binds.')
  serviceBinds: object[]?

  @description('Optional. Sticky Sessions Affinity.')
  stickySessionsAffinity: ('none' | 'sticky')?

  @description('Optional. Tags of the resource.')
  tags: object?

  @description('Optional. Traffic label for the revision.')
  trafficLabel: string?

  @description('Optional. Flag to send traffic to latest revision.')
  trafficLatestRevision: bool?

  @description('Optional. Name of the revision to send traffic.')
  trafficRevisionName: string?

  @description('Optional. Percentage of traffic to send to the revision.')
  trafficWeight: int?

  @description('Optional. List of volume definitions for the Container App.')
  volumes: object[]?
}

@export()
@description('Configuration object for the Azure Container Registry (ACR).')
type containerRegistryDefinitionType = {
  @description('Required. Name of your Azure Container Registry.')
  name: string

  @description('Optional. Enable admin user that has push/pull permission to the registry. Default is false.')
  acrAdminUserEnabled: bool?

  @description('Optional. Tier of your Azure Container Registry. Default is Premium.')
  acrSku: 'Basic' | 'Standard' | 'Premium'?

  @description('Optional. Enables registry-wide pull from unauthenticated clients (preview, Standard/Premium only). Default is false.')
  anonymousPullEnabled: bool?

  @description('Optional. Indicates whether the policy for using ARM audience token is enabled. Default is enabled.')
  azureADAuthenticationAsArmPolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Array of Cache Rules.')
  cacheRules: {
    @description('Required. Source repository pulled from upstream.')
    sourceRepository: string

    @description('Optional. Resource ID of the credential store associated with the cache rule.')
    credentialSetResourceId: string?

    @description('Optional. Name of the cache rule. Defaults to the source repository name if not set.')
    name: string?

    @description('Optional. Target repository specified in docker pull command.')
    targetRepository: string?
  }[]?

  @description('Optional. Array of Credential Sets.')
  credentialSets: {
    @description('Required. List of authentication credentials (primary and optional secondary).')
    authCredentials: {
      @description('Required. Name of the credential.')
      name: string

      @description('Required. KeyVault Secret URI for the password.')
      passwordSecretIdentifier: string

      @description('Required. KeyVault Secret URI for the username.')
      usernameSecretIdentifier: string
    }[]

    @description('Required. Login server for which the credentials are stored.')
    loginServer: string

    @description('Required. Name of the credential set.')
    name: string

    @description('Optional. Managed identity definition for this credential set.')
    managedIdentities: {
      @description('Optional. Enables system-assigned managed identity.')
      systemAssigned: bool?
    }?
  }[]?

  @description('Optional. Customer managed key definition.')
  customerManagedKey: {
    @description('Required. Name of the key.')
    keyName: string

    @description('Required. Resource ID of the Key Vault.')
    keyVaultResourceId: string

    @description('Optional. Enable or disable auto-rotation to the latest version. Default is true.')
    autoRotationEnabled: bool?

    @description('Optional. Key version. Used if autoRotationEnabled=false.')
    keyVersion: string?

    @description('Optional. User-assigned identity for fetching the key. Required if no system-assigned identity.')
    userAssignedIdentityResourceId: string?
  }?

  @description('Conditional. Enable a single data endpoint per region (Premium only). Default is false. Required if acrSku is Premium.')
  dataEndpointEnabled: bool?

  @description('Optional. Diagnostic settings for the service.')
  diagnosticSettings: {
    @description('Optional. Event Hub authorization rule resource ID.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Event Hub name for logs.')
    eventHubName: string?

    @description('Optional. Destination type for Log Analytics (AzureDiagnostics or Dedicated).')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Log categories and groups.')
    logCategoriesAndGroups: {
      @description('Optional. Diagnostic log category.')
      category: string?

      @description('Optional. Diagnostic log category group.')
      categoryGroup: string?

      @description('Optional. Enable or disable this category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace partner resource ID.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metric categories.')
    metricCategories: {
      @description('Required. Diagnostic metric category.')
      category: string

      @description('Optional. Enable or disable this metric. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Name of the diagnostic setting.')
    name: string?

    @description('Optional. Storage account resource ID.')
    storageAccountResourceId: string?

    @description('Optional. Log Analytics workspace resource ID.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. Enable or disable telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Export policy status. Default is disabled.')
  exportPolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings.')
  lock: {
    @description('Optional. Type of lock (CanNotDelete, None, ReadOnly).')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Name of the lock.')
    name: string?

    @description('Optional. Notes for the lock.')
    notes: string?
  }?

  @description('Optional. Managed identity definition for the registry.')
  managedIdentities: {
    @description('Optional. Enable system-assigned managed identity.')
    systemAssigned: bool?

    @description('Optional. User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.')
    userAssignedResourceIds: string[]?
  }?

  @description('Optional. Network rule bypass options. Default is AzureServices.')
  networkRuleBypassOptions: 'AzureServices' | 'None'?

  @description('Optional. Default action when no network rule matches. Default is Deny.')
  networkRuleSetDefaultAction: 'Allow' | 'Deny'?

  @description('Conditional. IP ACL rules (Premium only). Required if acrSku is Premium.')
  networkRuleSetIpRules: array?

  @description('Conditional. Private endpoint configuration (Premium only). Required if acrSku is Premium.')
  privateEndpoints: array?

  @description('Conditional. Public network access (Premium only). Disabled by default if private endpoints are set and no IP rules). Required if acrSku is Premium.')
  publicNetworkAccess: 'Disabled' | 'Enabled'?

  @description('Conditional. Quarantine policy status (Premium only). Default is disabled. Required if acrSku is Premium.')
  quarantinePolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Replications to create.')
  replications: array?

  @description('Optional. Number of days to retain untagged manifests. Default is 15.')
  retentionPolicyDays: int?

  @description('Optional. Retention policy status. Default is enabled.')
  retentionPolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Role assignments for this registry.')
  roleAssignments: array?

  @description('Optional. Scope maps configuration.')
  scopeMaps: array?

  @description('Optional. Number of days after which soft-deleted items are permanently deleted. Default is 7.')
  softDeletePolicyDays: int?

  @description('Optional. Soft delete policy status. Default is disabled.')
  softDeletePolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Resource tags.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Conditional. Trust policy status (Premium only). Default is disabled. Required if acrSku is Premium.')
  trustPolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Webhooks to create.')
  webhooks: array?

  @description('Optional. Zone redundancy setting. Default is Enabled. Conditional: requires acrSku=Premium.')
  zoneRedundancy: 'Enabled' | 'Disabled'?
}

// ---------------------------------------------
// Deploy Toggles — kept strict because main.bicep likely references keys directly
// ---------------------------------------------
@export()
@description('Per-service deployment toggles; set false to skip creating that service (reusing via resourceIds still works).')
type deployTogglesType = {
  @description('Required. Toggle to deploy Log Analytics (true) or not (false).')
  logAnalytics: bool

  @description('Required. Toggle to deploy Application Insights (true) or not (false).')
  appInsights: bool

  @description('Required. Toggle to deploy Container Apps Environment (true) or not (false).')
  containerEnv: bool

  @description('Required. Toggle to deploy Azure Container Registry (true) or not (false).')
  containerRegistry: bool

  @description('Required. Toggle to deploy Cosmos DB (true) or not (false).')
  cosmosDb: bool

  @description('Required. Toggle to deploy Key Vault (true) or not (false).')
  keyVault: bool

  @description('Required. Toggle to deploy Storage Account (true) or not (false).')
  storageAccount: bool

  @description('Required. Toggle to deploy AI Foundry (true) or not (false).')
  aiFoundry: bool

  @description('Required. Toggle to deploy Azure AI Search (true) or not (false).')
  searchService: bool

  @description('Required. Toggle to deploy Bing Grounding with Search (true) or not (false).')
  groundingWithBingSearch: bool

  @description('Required. Toggle to deploy App Configuration (true) or not (false).')
  appConfig: bool

  @description('Required. Toggle to deploy API Management (true) or not (false).')
  apiManagement: bool

  @description('Required. Toggle to deploy Application Gateway (true) or not (false).')
  applicationGateway: bool

  @description('Required. Toggle to deploy a Public IP address for the Application Gateway (true) or not (false).')
  applicationGatewayPublicIp: bool

  @description('Required. Toggle to deploy Azure Firewall (true) or not (false).')
  firewall: bool

  @description('Required. Toggle to deploy User Defined Routes (UDR) (Route Table + association).')
  userDefinedRoutes: bool

  @description('Required. Toggle to deploy Container Apps (true) or not (false).')
  containerApps: bool

  @description('Required. Toggle to deploy Build VM (true) or not (false).')
  buildVm: bool

  @description('Required. Toggle to deploy an Azure Bastion host (true) or not (false).')
  bastionHost: bool

  @description('Required. Toggle to deploy Jump VM (true) or not (false).')
  jumpVm: bool

  @description('Required. Toggle to deploy a new Virtual Network (true) or not (false).')
  virtualNetwork: bool

  @description('Required. Toggle to deploy an Application Gateway WAF policy (true) or not (false).')
  wafPolicy: bool

  @description('Required. Toggle to deploy NSG for agent (workload) subnet (true) or not (false).')
  agentNsg: bool

  @description('Required. Toggle to deploy NSG for private endpoints (PE) subnet (true) or not (false).')
  peNsg: bool

  @description('Required. Toggle to deploy NSG for Application Gateway subnet (true) or not (false).')
  applicationGatewayNsg: bool

  @description('Required. Toggle to deploy NSG for API Management subnet (true) or not (false).')
  apiManagementNsg: bool

  @description('Required. Toggle to deploy NSG for Azure Container Apps environment subnet (true) or not (false).')
  acaEnvironmentNsg: bool

  @description('Required. Toggle to deploy NSG for jumpbox (bastion-accessed) subnet (true) or not (false).')
  jumpboxNsg: bool

  @description('Required. Toggle to deploy NSG for DevOps build agents subnet (true) or not (false).')
  devopsBuildAgentsNsg: bool

  @description('Required. Toggle to deploy NSG for Bastion host subnet (true) or not (false).')
  bastionNsg: bool
}

@export()
@description('Existing resource IDs to reuse; leave empty to create new resources.')
type resourceIdsType = {
  @description('Optional. Existing VNet resource ID to reuse; leave empty to create a new VNet.')
  virtualNetworkResourceId: string?

  @description('Optional. Existing Azure Bastion resource ID to reuse; leave empty to skip.')
  bastionHostResourceId: string?

  @description('Optional. Existing Application Insights resource ID to reuse.')
  appInsightsResourceId: string?

  @description('Optional. Existing Log Analytics Workspace resource ID to reuse.')
  logAnalyticsWorkspaceResourceId: string?

  @description('Optional. Existing App Configuration store resource ID to reuse.')
  appConfigResourceId: string?

  @description('Optional. Existing Key Vault resource ID to reuse.')
  keyVaultResourceId: string?

  @description('Optional. Existing Storage Account resource ID to reuse.')
  storageAccountResourceId: string?

  @description('Optional. Existing Cosmos DB account resource ID to reuse.')
  dbAccountResourceId: string?

  @description('Optional. Existing Azure AI Search service resource ID to reuse.')
  searchServiceResourceId: string?

  @description('Optional. Existing Grounding service resource ID to reuse.')
  groundingServiceResourceId: string?

  @description('Optional. Existing Container Apps Environment resource ID to reuse.')
  containerEnvResourceId: string?

  @description('Optional. Existing Azure Container Registry resource ID to reuse.')
  containerRegistryResourceId: string?

  @description('Optional. Existing API Management service resource ID to reuse.')
  apimServiceResourceId: string?

  @description('Optional. Existing Application Gateway resource ID to reuse.')
  applicationGatewayResourceId: string?

  @description('Optional. Existing Azure Firewall resource ID to reuse.')
  firewallResourceId: string?

  @description('Optional. Existing Azure Firewall Policy resource ID to reuse.')
  firewallPolicyResourceId: string?

  @description('Optional. Existing Public IP resource ID to reuse for the Application Gateway.')
  appGatewayPublicIpResourceId: string?

  @description('Optional. Existing Public IP resource ID to reuse for the Azure Firewall.')
  firewallPublicIpResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the agent (workload) subnet.')
  agentNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the private endpoints (PE) subnet.')
  peNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the Application Gateway subnet.')
  applicationGatewayNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the API Management subnet.')
  apiManagementNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the Azure Container Apps environment subnet.')
  acaEnvironmentNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the jumpbox (bastion-accessed) subnet.')
  jumpboxNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the DevOps build agents subnet.')
  devopsBuildAgentsNsgResourceId: string?

  @description('Optional. Existing NSG resource ID to reuse for the Bastion host subnet.')
  bastionNsgResourceId: string?
}

@export()
@description('Optional subnet names for the Virtual Network definition.')
type subnetNamesDefinitionType = {
  @description('Optional. Subnet name for private endpoints. Default: pe-subnet.')
  pe: string?

  @description('Optional. Subnet name for agent workloads. Default: agent-subnet.')
  agent: string?

  @description('Optional. Subnet name for Application Gateway. Default: app-gateway-subnet.')
  applicationGateway: string?

  @description('Optional. Subnet name for API Management. Default: api-management-subnet.')
  apiManagement: string?

  @description('Optional. Subnet name for Container Apps environment. Default: aca-environment-subnet.')
  acaEnvironment: string?

  @description('Optional. Subnet name for jumpbox VMs. Default: jumpbox-subnet.')
  jumpbox: string?

  @description('Optional. Subnet name for DevOps build agents. Default: devops-build-agents-subnet.')
  devopsBuildAgents: string?
}

@export()
@description('Configuration object for adding subnets to an existing Virtual Network.')
type existingVNetSubnetsDefinitionType = {
  @description('Required. Name or Resource ID of the existing Virtual Network. For cross-subscription/resource group scenarios, use the full Resource ID format: /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/virtualNetworks/{vnet-name}')
  existingVNetName: string

  @description('Optional. Use default AI Landing Zone subnets with 192.168.x.x addressing. Default: true.')
  useDefaultSubnets: bool?

  @description('Optional. Array of custom subnets to add to the existing VNet. If not provided and useDefaultSubnets is true, uses default AI Landing Zone subnets.')
  subnets: {
    @description('Required. Name of the subnet.')
    name: string

    @description('Conditional. Address prefix for the subnet. Required if addressPrefixes is empty.')
    addressPrefix: string?

    @description('Conditional. List of address prefixes for the subnet. Required if addressPrefix is empty.')
    addressPrefixes: array?

    @description('Optional. Application Gateway IP configurations for the subnet.')
    applicationGatewayIPConfigurations: array?

    @description('Optional. Disable default outbound connectivity for all VMs in subnet.')
    defaultOutboundAccess: bool?

    @description('Optional. Delegation to enable on the subnet.')
    delegation: string?

    @description('Optional. NAT Gateway resource ID for the subnet.')
    natGatewayResourceId: string?

    @description('Optional. NSG resource ID for the subnet.')
    networkSecurityGroupResourceId: string?

    @description('Optional. Policy for private endpoint network.')
    privateEndpointNetworkPolicies: 'Disabled' | 'Enabled' | 'NetworkSecurityGroupEnabled' | 'RouteTableEnabled'?

    @description('Optional. Policy for private link service network.')
    privateLinkServiceNetworkPolicies: 'Disabled' | 'Enabled'?

    @description('Optional. Route table resource ID for the subnet.')
    routeTableResourceId: string?

    @description('Optional. Service endpoint policies for the subnet.')
    serviceEndpointPolicies: array?

    @description('Optional. Service endpoints enabled on the subnet.')
    serviceEndpoints: string[]?

    @description('Optional. Sharing scope for the subnet.')
    sharingScope: 'DelegatedServices' | 'Tenant'?
  }[]?
}

@export()
@description('Configuration object for the Virtual Network (vNet) to be deployed.')
type vNetDefinitionType = {
  @description('Required. An array of one or more IP address prefixes OR the resource ID of the IPAM pool to be used for the Virtual Network. Required if using IPAM pool resource ID, you must also set ipamPoolNumberOfIpAddresses.')
  addressPrefixes: array

  @description('Required. The name of the Virtual Network (vNet).')
  name: string

  @description('Optional. Resource ID of the DDoS protection plan to assign the VNet to. If blank, DDoS protection is not configured.')
  ddosProtectionPlanResourceId: string?

  @description('Optional. The diagnostic settings of the Virtual Network.')
  diagnosticSettings: {
    @description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed.')
    eventHubName: string?

    @description('Optional. Destination type for export to Log Analytics. Allowed values: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Logs to be streamed. Set to [] to disable log collection.')
    logCategoriesAndGroups: {
      @description('Optional. Name of a diagnostic log category for the resource type.')
      category: string?

      @description('Optional. Name of a diagnostic log category group for the resource type.')
      categoryGroup: string?

      @description('Optional. Enable or disable the category explicitly. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace resource ID to which diagnostic logs should be sent.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metrics to be streamed. Set to [] to disable metric collection.')
    metricCategories: {
      @description('Required. Name of a diagnostic metric category for the resource type.')
      category: string

      @description('Optional. Enable or disable the metric category explicitly. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Name of the diagnostic setting.')
    name: string?

    @description('Optional. Resource ID of the diagnostic storage account.')
    storageAccountResourceId: string?

    @description('Optional. Resource ID of the diagnostic Log Analytics workspace.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. DNS servers associated with the Virtual Network.')
  dnsServers: array?

  @description('Optional. Enable or disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Indicates if VM protection is enabled for all subnets in the Virtual Network.')
  enableVmProtection: bool?

  @description('Optional. Flow timeout in minutes for intra-VM flows (range 4–30). Default 0 sets the property to null.')
  flowTimeoutInMinutes: int?

  @description('Optional. Number of IP addresses allocated from the IPAM pool. Required if addressPrefixes is defined with a resource ID of an IPAM pool.')
  ipamPoolNumberOfIpAddresses: string?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the Virtual Network.')
  lock: {
    @description('Optional. Type of lock. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Name of the lock.')
    name: string?

    @description('Optional. Notes for the lock.')
    notes: string?
  }?

  @description('Optional. Virtual Network peering configurations.')
  peerings: {
    @description('Required. Resource ID of the remote Virtual Network to peer with.')
    remoteVirtualNetworkResourceId: string

    @description('Optional. Allow forwarded traffic from VMs in local VNet. Default is true.')
    allowForwardedTraffic: bool?

    @description('Optional. Allow gateway transit from remote VNet. Default is false.')
    allowGatewayTransit: bool?

    @description('Optional. Allow VMs in local VNet to access VMs in remote VNet. Default is true.')
    allowVirtualNetworkAccess: bool?

    @description('Optional. Do not verify remote gateway provisioning state. Default is true.')
    doNotVerifyRemoteGateways: bool?

    @description('Optional. Name of the VNet peering resource. Default: peer-localVnetName-remoteVnetName.')
    name: string?

    @description('Optional. Allow forwarded traffic from remote peering. Default is true.')
    remotePeeringAllowForwardedTraffic: bool?

    @description('Optional. Allow gateway transit from remote peering. Default is false.')
    remotePeeringAllowGatewayTransit: bool?

    @description('Optional. Allow virtual network access from remote peering. Default is true.')
    remotePeeringAllowVirtualNetworkAccess: bool?

    @description('Optional. Do not verify provisioning state of remote peering gateway. Default is true.')
    remotePeeringDoNotVerifyRemoteGateways: bool?

    @description('Optional. Deploy outbound and inbound peering.')
    remotePeeringEnabled: bool?

    @description('Optional. Name of the remote peering resource. Default: peer-remoteVnetName-localVnetName.')
    remotePeeringName: string?

    @description('Optional. Use remote gateways for transit if allowed. Default is false.')
    remotePeeringUseRemoteGateways: bool?

    @description('Optional. Use remote gateways on this Virtual Network for transit. Default is false.')
    useRemoteGateways: bool?
  }[]?

  @description('Optional. Role assignments to create on the Virtual Network.')
  roleAssignments: {
    @description('Required. Principal ID of the user/group/identity to assign the role to.')
    principalId: string

    @description('Required. Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.')
    roleDefinitionIdOrName: string

    @description('Optional. Condition applied to the role assignment.')
    condition: string?

    @description('Optional. Condition version. Allowed value: 2.0.')
    conditionVersion: '2.0'?

    @description('Optional. Resource ID of delegated managed identity.')
    delegatedManagedIdentityResourceId: string?

    @description('Optional. Description of the role assignment.')
    description: string?

    @description('Optional. Name of the role assignment. If not provided, a GUID will be generated.')
    name: string?

    @description('Optional. Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
  }[]?

  @description('Optional. Array of subnets to deploy in the Virtual Network.')
  subnets: {
    @description('Required. Name of the subnet.')
    name: string

    @description('Conditional. Address prefix for the subnet. Required if addressPrefixes is empty.')
    addressPrefix: string?

    @description('Conditional. List of address prefixes for the subnet. Required if addressPrefix is empty.')
    addressPrefixes: array?

    @description('Conditional. Address space for subnet from IPAM Pool. Required if both addressPrefix and addressPrefixes are empty and VNet uses IPAM Pool.')
    ipamPoolPrefixAllocations: array?

    @description('Optional. Application Gateway IP configurations for the subnet.')
    applicationGatewayIPConfigurations: array?

    @description('Optional. Disable default outbound connectivity for all VMs in subnet. Only allowed at creation time.')
    defaultOutboundAccess: bool?

    @description('Optional. Delegation to enable on the subnet.')
    delegation: string?

    @description('Optional. NAT Gateway resource ID for the subnet.')
    natGatewayResourceId: string?

    @description('Optional. NSG resource ID for the subnet.')
    networkSecurityGroupResourceId: string?

    @description('Optional. Policy for private endpoint network. Allowed values: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled.')
    privateEndpointNetworkPolicies: 'Disabled' | 'Enabled' | 'NetworkSecurityGroupEnabled' | 'RouteTableEnabled'?

    @description('Optional. Policy for private link service network. Allowed values: Disabled, Enabled.')
    privateLinkServiceNetworkPolicies: 'Disabled' | 'Enabled'?

    @description('Optional. Role assignments to create on the subnet.')
    roleAssignments: {
      @description('Required. Principal ID of the user/group/identity to assign the role to.')
      principalId: string

      @description('Required. Role to assign. Accepts role name, role GUID, or fully qualified role definition ID.')
      roleDefinitionIdOrName: string

      @description('Optional. Condition applied to the role assignment.')
      condition: string?

      @description('Optional. Condition version. Allowed value: 2.0.')
      conditionVersion: '2.0'?

      @description('Optional. Resource ID of delegated managed identity.')
      delegatedManagedIdentityResourceId: string?

      @description('Optional. Description of the role assignment.')
      description: string?

      @description('Optional. Name of the role assignment. If not provided, a GUID will be generated.')
      name: string?

      @description('Optional. Principal type. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.')
      principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
    }[]?

    @description('Optional. Route table resource ID for the subnet.')
    routeTableResourceId: string?

    @description('Optional. Service endpoint policies for the subnet.')
    serviceEndpointPolicies: array?

    @description('Optional. Service endpoints enabled on the subnet.')
    serviceEndpoints: string[]?

    @description('Optional. Sharing scope for the subnet. Allowed values: DelegatedServices, Tenant.')
    sharingScope: 'DelegatedServices' | 'Tenant'?
  }[]?

  @description('Optional. Tags to apply to the Virtual Network.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. The BGP community associated with the Virtual Network.')
  virtualNetworkBgpCommunity: string?

  @description('Optional. Indicates if encryption is enabled for the Virtual Network. Requires the EnableVNetEncryption feature and a supported region.')
  vnetEncryption: bool?

  @description('Optional. Enforcement policy for unencrypted VMs in an encrypted VNet. Allowed values: AllowUnencrypted, DropUnencrypted.')
  vnetEncryptionEnforcement: 'AllowUnencrypted' | 'DropUnencrypted'?
}

@export()
@description('Optional. Per-subnet Network Security Group (NSG) definitions by role.')
type nsgPerSubnetDefinitionsType = {
  @description('Optional. NSG definition applied to the agent (workload) subnet.')
  agent: nsgDefinitionType?

  @description('Optional. NSG definition applied to the private endpoints (PE) subnet.')
  pe: nsgDefinitionType?

  @description('Optional. NSG definition applied to the Application Gateway subnet.')
  applicationGateway: nsgDefinitionType?

  @description('Optional. NSG definition applied to the API Management subnet.')
  apiManagement: nsgDefinitionType?

  @description('Optional. NSG definition applied to the Azure Container Apps environment (infrastructure) subnet.')
  acaEnvironment: nsgDefinitionType?

  @description('Optional. NSG definition applied to the jumpbox (bastion-accessed) subnet.')
  jumpbox: nsgDefinitionType?

  @description('Optional. NSG definition applied to the DevOps build agents subnet.')
  devopsBuildAgents: nsgDefinitionType?

  @description('Optional. NSG definition applied to the Bastion subnet.')
  bastion: nsgDefinitionType?  
}

@export()
@description('Configuration object for a Network Security Group (NSG).')
type nsgDefinitionType = {
  @description('Optional. Name of the Network Security Group.')
  name: string?

  @description('Optional. Diagnostic settings to send NSG logs/metrics to Log Analytics, Event Hub, or Storage.')
  diagnosticSettings: {
    @description('Optional. Name of the diagnostic settings resource.')
    name: string?
    @description('Optional. Destination Log Analytics workspace resource ID.')
    workspaceResourceId: string?
    @description('Optional. Destination Storage Account resource ID.')
    storageAccountResourceId: string?
    @description('Optional. Destination Event Hub authorization rule resource ID.')
    eventHubAuthorizationRuleResourceId: string?
    @description('Optional. Destination Event Hub name when sending to Event Hub.')
    eventHubName: string?
    @description('Optional. Destination type for Log Analytics (AzureDiagnostics or Dedicated).')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?
    @description('Optional. List of categories and/or category groups to enable.')
    logCategoriesAndGroups: {
      @description('Optional. Single diagnostic log category to enable.')
      category: string?
      @description('Optional. Category group (e.g., AllMetrics) to enable.')
      categoryGroup: string?
      @description('Optional. Whether this category/category group is enabled.')
      enabled: bool?
    }[]?
    @description('Optional. Marketplace partner destination resource ID (if applicable).')
    marketplacePartnerResourceId: string?
  }[]?

  @description('Optional. Enable or disable usage telemetry for this module. Default: true.')
  enableTelemetry: bool?

  @description('Optional. When true, flows created from NSG connections are re-evaluated when rules are updated. Default: false.')
  flushConnection: bool?

  @description('Optional. Azure region for the NSG. Defaults to the resource group location.')
  location: string?

  @description('Optional. Management lock configuration for the NSG.')
  lock: {
    @description('Optional. Lock type (None, CanNotDelete, or ReadOnly).')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Name of the management lock.')
    name: string?
    @description('Optional. Notes describing the reason for the lock.')
    notes: string?
  }?

  @description('Optional. Role assignments to apply on the NSG.')
  roleAssignments: {
    @description('Required. Principal (object) ID for the assignment.')
    principalId: string
    @description('Required. Role to assign (name, GUID, or fully qualified role definition ID).')
    roleDefinitionIdOrName: string
    @description('Optional. Advanced condition expression for the assignment.')
    condition: string?
    @description('Optional. Condition version. Use 2.0 when condition is provided.')
    conditionVersion: '2.0'?
    @description('Optional. Delegated managed identity resource ID (for cross-tenant scenarios).')
    delegatedManagedIdentityResourceId: string?
    @description('Optional. Description for the role assignment.')
    description: string?
    @description('Optional. Stable GUID name of the role assignment (omit to auto-generate).')
    name: string?
    @description('Optional. Principal type for the assignment.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
  }[]?

  @description('Optional. Security rules to apply to the NSG. If omitted, only default rules are present.')
  securityRules: {
    @description('Required. Name of the security rule.')
    name: string
    @description('Required. Properties that define the behavior of the security rule.')
    properties: {
      @description('Required. Whether matching traffic is allowed or denied.')
      access: 'Allow' | 'Deny'
      @description('Required. Direction of the rule (Inbound or Outbound).')
      direction: 'Inbound' | 'Outbound'
      @description('Required. Priority of the rule (100–4096). Must be unique per rule in the NSG.')
      priority: int
      @description('Required. Network protocol to match.')
      protocol: '*' | 'Ah' | 'Esp' | 'Icmp' | 'Tcp' | 'Udp'

      @description('Optional. Free-form description for the rule.')
      description: string?

      @description('Optional. Single destination address prefix (e.g., 10.0.0.0/24, VirtualNetwork).')
      destinationAddressPrefix: string?
      @description('Optional. Multiple destination address prefixes.')
      destinationAddressPrefixes: string[]?
      @description('Optional. Destination Application Security Group (ASG) resource IDs.')
      destinationApplicationSecurityGroupResourceIds: string[]?
      @description('Optional. Single destination port or port range (e.g., 443, 1000-2000).')
      destinationPortRange: string?
      @description('Optional. Multiple destination ports or port ranges.')
      destinationPortRanges: string[]?

      @description('Optional. Single source address prefix (e.g., Internet, 10.0.0.0/24).')
      sourceAddressPrefix: string?
      @description('Optional. Multiple source address prefixes.')
      sourceAddressPrefixes: string[]?
      @description('Optional. Source Application Security Group (ASG) resource IDs.')
      sourceApplicationSecurityGroupResourceIds: string[]?
      @description('Optional. Single source port or port range.')
      sourcePortRange: string?
      @description('Optional. Multiple source ports or port ranges.')
      sourcePortRanges: string[]?
    }
  }[]?

  @description('Optional. Tags to apply to the NSG.')
  tags: object?
}

@export()
@description('Configuration object for Private DNS Zones, VNet links, and existing zone resource IDs per service.')
type privateDnsZonesDefinitionType = {
  @description('Optional. Allow fallback to internet DNS resolution when Private DNS is unavailable.')
  allowInternetResolutionFallback: bool?

  @description('Optional. Create VNet link to associate Spoke with the zones (can be empty).')
  createNetworkLinks: bool?

  @description('Optional. Tags to apply to the Private DNS Zones.')
  tags: {
    @description('Optional. Arbitrary key for each tag.')
    *: string
  }?

  // --- Per-service existing zone IDs ---
  @description('Optional. Existing Private DNS Zone resource ID for Cognitive Services.')
  cognitiveservicesZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Azure API Management.')
  apimZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Azure OpenAI.')
  openaiZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for AI Services.')
  aiServicesZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Azure Cognitive Search.')
  searchZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Cosmos DB (SQL API).')
  cosmosSqlZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Blob Storage.')
  blobZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Key Vault.')
  keyVaultZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for App Configuration.')
  appConfigZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Container Apps.')
  containerAppsZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Azure Container Registry.')
  acrZoneId: string?

  @description('Optional. Existing Private DNS Zone resource ID for Application Insights.')
  appInsightsZoneId: string?
}

@export()
@description('Configuration object for a single Private DNS Zone to be deployed.')
type privateDnsZoneDefinitionType = {
  @description('Required. The name of the Private DNS Zone.')
  name: string

  @description('Optional. Location for the resource. Defaults to "global".')
  location: string?

  @description('Optional. Tags for the Private DNS Zone.')
  tags: object?

  @description('Optional. Enable/Disable usage telemetry for the module.')
  enableTelemetry: bool?

  @description('Optional. Virtual network links to create for the Private DNS Zone.')
  virtualNetworkLinks: {
    @description('Required. The name of the virtual network link.')
    name: string
    @description('Optional. Whether to enable auto-registration of virtual machine records in the zone.')
    registrationEnabled: bool?
    @description('Required. Resource ID of the virtual network to link.')
    virtualNetworkResourceId: string
    @description('Optional. Tags for the virtual network link.')
    tags: object?
  }[]?

  @description('Optional. A list of DNS zone records to create.')
  a: {
    @description('Required. Name of the A record.')
    name: string
    @description('Required. List of IPv4 addresses.')
    ipv4Addresses: string[]
    @description('Optional. Time-to-live for the record.')
    ttl: int?
    @description('Optional. Tags for the A record.')
    tags: object?
  }[]?

  @description('Optional. Lock configuration for the Private DNS Zone.')
  lock: {
    @description('Optional. Lock type.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Role assignments for the Private DNS Zone.')
  roleAssignments: {
    @description('Required. Principal ID to assign the role to.')
    principalId: string
    @description('Required. Role definition ID or name.')
    roleDefinitionIdOrName: string
    @description('Optional. Principal type.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
    @description('Optional. Description of the role assignment.')
    description: string?
    @description('Optional. Name for the role assignment.')
    name: string?
  }[]?
}

@export()
@description('Configuration object for the Web Application Firewall (WAF) Policy to be deployed.')
type wafPolicyDefinitionsType = {
  @description('Required. Name of the Application Gateway WAF policy.')
  name: string

  @description('Optional. Policy settings (state, mode, size limits).')
  policySettings: {
    @description('Required. WAF policy state.')
    state: 'Enabled' | 'Disabled'

    @description('Required. WAF mode (Prevention or Detection).')
    mode: 'Prevention' | 'Detection'

    @description('Required. Enable request body inspection.')
    requestBodyCheck: bool

    @description('Required. Maximum request body size (KB).')
    maxRequestBodySizeInKb: int

    @description('Required. File upload size limit (MB).')
    fileUploadLimitInMb: int
  }?

  @description('Required. Managed rules configuration (rule sets and exclusions).')
  managedRules: {
    @description('Optional. Exclusions for specific rules or variables.')
    exclusions: {
      @description('Required. Match variable to exclude (e.g., RequestHeaderNames).')
      matchVariable: string

      @description('Required. Selector value for the match variable.')
      selector: string

      @description('Required. Selector match operator (e.g., Equals, Contains).')
      selectorMatchOperator: string

      @description('Optional. Specific managed rule set exclusion details.')
      excludedRuleSet: {
        @description('Required. Rule set type (e.g., OWASP).')
        ruleSetType: string

        @description('Required. Rule set version (e.g., 3.2).')
        ruleSetVersion: string

        @description('Optional. Rule groups to exclude.')
        ruleGroup: string[]?
      }?
    }[]?

    @description('Required. Managed rule sets to apply.')
    managedRuleSets: {
      @description('Required. Rule set type (e.g., OWASP).')
      ruleSetType: string

      @description('Required. Rule set version.')
      ruleSetVersion: string

      @description('Optional. Overrides for specific rule groups.')
      ruleGroupOverrides: {
        @description('Required. Name of the rule group.')
        ruleGroupName: string

        @description('Required. Rule overrides within the group.')
        rule: {
          @description('Required. Rule ID.')
          id: string

          @description('Required. Action to take (e.g., Allow, Block, Log).')
          action: string

          @description('Required. Whether the rule is enabled.')
          enabled: bool
        }[]
      }[]?
    }[]
  }

  @description('Optional. Custom rules inside the policy.')
  customRules: array?

  @description('Optional. Enable or disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Resource tags.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
}

@export()
@description('Configuration object for a Public IP Address resource.')
type publicIpDefinitionType = {
  @description('Required. Name of the Public IP Address.')
  name: string

  @description('Optional. Availability zones for the Public IP Address allocation. Allowed values: 1, 2, 3.')
  zones: int[]?

  @description('Optional. DDoS protection settings for the Public IP Address.')
  ddosSettings: {
    @description('Required. DDoS protection mode. Allowed value: Enabled.')
    protectionMode: 'Enabled'

    @description('Optional. Associated DDoS protection plan.')
    ddosProtectionPlan: {
      @description('Required. Resource ID of the DDoS protection plan.')
      id: string
    }?
  }?

  @description('Optional. Diagnostic settings for the Public IP Address.')
  diagnosticSettings: {
    @description('Optional. Resource ID of the diagnostic Event Hub authorization rule.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Name of the diagnostic Event Hub.')
    eventHubName: string?

    @description('Optional. Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Log categories and groups to collect. Set to [] to disable log collection.')
    logCategoriesAndGroups: {
      @description('Optional. Name of a diagnostic log category.')
      category: string?

      @description('Optional. Name of a diagnostic log category group. Use allLogs to collect all logs.')
      categoryGroup: string?

      @description('Optional. Enable or disable the log category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace partner resource ID.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metric categories to collect. Set to [] to disable metric collection.')
    metricCategories: {
      @description('Required. Name of a diagnostic metric category. Use AllMetrics to collect all metrics.')
      category: string

      @description('Optional. Enable or disable the metric category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Name of the diagnostic setting.')
    name: string?

    @description('Optional. Resource ID of the diagnostic storage account.')
    storageAccountResourceId: string?

    @description('Optional. Resource ID of the diagnostic Log Analytics workspace.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. DNS settings for the Public IP Address.')
  dnsSettings: {
    @description('Required. Domain name label used to create an A DNS record in Azure DNS.')
    domainNameLabel: string

    @description('Optional. Domain name label scope. Allowed values: NoReuse, ResourceGroupReuse, SubscriptionReuse, TenantReuse.')
    domainNameLabelScope: 'NoReuse' | 'ResourceGroupReuse' | 'SubscriptionReuse' | 'TenantReuse'?

    @description('Optional. Fully qualified domain name (FQDN) associated with the Public IP.')
    fqdn: string?

    @description('Optional. Reverse FQDN used for PTR records.')
    reverseFqdn: string?
  }?

  @description('Optional. Enable or disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Idle timeout in minutes for the Public IP Address. Default is 4.')
  idleTimeoutInMinutes: int?

  @description('Optional. IP tags associated with the Public IP Address.')
  ipTags: {
    @description('Required. IP tag type.')
    ipTagType: string

    @description('Required. IP tag value.')
    tag: string
  }[]?

  @description('Optional. Location for the resource. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock configuration for the Public IP Address.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Lock name.')
    name: string?

    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. IP address version. Default is IPv4. Allowed values: IPv4, IPv6.')
  publicIPAddressVersion: 'IPv4' | 'IPv6'?

  @description('Optional. Public IP allocation method. Default is Static. Allowed values: Dynamic, Static.')
  publicIPAllocationMethod: 'Dynamic' | 'Static'?

  @description('Optional. Resource ID of the Public IP Prefix to allocate from.')
  publicIpPrefixResourceId: string?

  @description('Optional. Role assignments to apply to the Public IP Address.')
  roleAssignments: {
    @description('Required. Principal ID of the identity being assigned.')
    principalId: string

    @description('Required. Role to assign (display name, GUID, or full resource ID).')
    roleDefinitionIdOrName: string

    @description('Optional. Condition for the role assignment.')
    condition: string?

    @description('Optional. Condition version. Allowed value: 2.0.')
    conditionVersion: '2.0'?

    @description('Optional. Delegated managed identity resource ID.')
    delegatedManagedIdentityResourceId: string?

    @description('Optional. Description of the role assignment.')
    description: string?

    @description('Optional. Role assignment name (GUID). If omitted, a GUID is generated.')
    name: string?

    @description('Optional. Principal type of the assigned identity. Allowed values: Device, ForeignGroup, Group, ServicePrincipal, User.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
  }[]?

  @description('Optional. SKU name for the Public IP Address. Default is Standard. Allowed values: Basic, Standard.')
  skuName: 'Basic' | 'Standard'?

  @description('Optional. SKU tier for the Public IP Address. Default is Regional. Allowed values: Global, Regional.')
  skuTier: 'Global' | 'Regional'?

  @description('Optional. Tags to apply to the Public IP Address resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
}

@export()
@description('Configuration object for a Private Endpoint resource.')
type privateEndpointDefinitionType = {
  @description('Required. Name of the Private Endpoint.')
  name: string

  @description('Optional. Location for the resource. Default is resourceGroup().location.')
  location: string?

  @description('Required. Resource ID of the subnet in which the endpoint will be created.')
  subnetResourceId: string

  @description('Optional. A collection of private link service connections.')
  privateLinkServiceConnections: {
    @description('Required. The connection name.')
    name: string
    @description('Required. Properties of the private link service connection.')
    properties: {
      @description('Required. The resource id of the private link service.')
      privateLinkServiceId: string
      @description('Required. The ID(s) of the group(s) obtained from the remote resource that this private endpoint should connect to.')
      groupIds: string[]
      @description('Optional. A message passed to the owner of the remote resource with the private endpoint request.')
      requestMessage: string?
    }
  }[]?

  @description('Optional. A collection of manual private link service connections.')
  manualPrivateLinkServiceConnections: {
    @description('Required. The connection name.')
    name: string
    @description('Required. Properties of the manual private link service connection.')
    properties: {
      @description('Required. The resource id of the private link service.')
      privateLinkServiceId: string
      @description('Required. The ID(s) of the group(s) obtained from the remote resource that this private endpoint should connect to.')
      groupIds: string[]
      @description('Optional. A message passed to the owner of the remote resource with the private endpoint request.')
      requestMessage: string?
    }
  }[]?

  @description('Optional. The custom name of the network interface attached to the private endpoint.')
  customNetworkInterfaceName: string?

  @description('Optional. Private DNS zone group configuration.')
  privateDnsZoneGroup: {
    @description('Required. The name of the private DNS zone group.')
    name: string
    @description('Required. Array of private DNS zone group configurations.')
    privateDnsZoneGroupConfigs: {
      @description('Required. The name of the private DNS zone group config.')
      name: string
      @description('Required. The resource ID of the private DNS zone.')
      privateDnsZoneResourceId: string
    }[]
  }?

  @description('Optional. Tags to apply to the Private Endpoint resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. Lock configuration for the Private Endpoint.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Enable or disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Diagnostic settings for the Private Endpoint.')
  diagnosticSettings: {
    @description('Optional. Resource ID of the diagnostic Event Hub authorization rule.')
    eventHubAuthorizationRuleResourceId: string?
    @description('Optional. Name of the diagnostic Event Hub.')
    eventHubName: string?
    @description('Optional. Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?
    @description('Optional. Log categories and groups to collect.')
    logCategoriesAndGroups: {
      @description('Optional. Name of a diagnostic log category.')
      category: string?
      @description('Optional. Name of a diagnostic log category group.')
      categoryGroup: string?
      @description('Optional. Enable or disable the log category. Default is true.')
      enabled: bool?
    }[]?
    @description('Optional. Marketplace partner resource ID.')
    marketplacePartnerResourceId: string?
    @description('Optional. Metric categories to collect.')
    metricCategories: {
      @description('Required. Name of a diagnostic metric category.')
      category: string
      @description('Optional. Enable or disable the metric category. Default is true.')
      enabled: bool?
    }[]?
    @description('Optional. Name of the diagnostic setting.')
    name: string?
    @description('Optional. Resource ID of the diagnostic storage account.')
    storageAccountResourceId: string?
    @description('Optional. Resource ID of the diagnostic Log Analytics workspace.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. Role assignments to apply to the Private Endpoint.')
  roleAssignments: {
    @description('Required. Principal ID of the identity being assigned.')
    principalId: string
    @description('Required. Role to assign (display name, GUID, or full resource ID).')
    roleDefinitionIdOrName: string
    @description('Optional. Condition for the role assignment.')
    condition: string?
    @description('Optional. Condition version. Allowed value: 2.0.')
    conditionVersion: '2.0'?
    @description('Optional. Delegated managed identity resource ID.')
    delegatedManagedIdentityResourceId: string?
    @description('Optional. Description of the role assignment.')
    description: string?
    @description('Optional. Role assignment name (GUID). If omitted, a GUID is generated.')
    name: string?
    @description('Optional. Principal type of the assigned identity.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
  }[]?
}

@export()
@description('Configuration object for a Storage Account resource.')
type storageAccountDefinitionType = {
  @description('Required. Name of the Storage Account. Must be lower-case.')
  name: string

  @description('Conditional. The access tier for billing. Required if kind is set to BlobStorage. Allowed values: Cold, Cool, Hot, Premium.')
  accessTier: 'Cold' | 'Cool' | 'Hot' | 'Premium'?

  @description('Conditional. Enables Hierarchical Namespace for the storage account. Required if enableSftp or enableNfsV3 is true.')
  enableHierarchicalNamespace: bool?

  @description('Optional. Indicates whether public access is enabled for all blobs or containers. Recommended to be set to false.')
  allowBlobPublicAccess: bool?

  @description('Optional. Allow or disallow cross AAD tenant object replication.')
  allowCrossTenantReplication: bool?

  @description('Optional. Restrict copy scope. Allowed values: AAD, PrivateLink.')
  allowedCopyScope: 'AAD' | 'PrivateLink'?

  @description('Optional. Indicates whether Shared Key authorization is allowed. Default is true.')
  allowSharedKeyAccess: bool?

  @description('Optional. Provides the identity-based authentication settings for Azure Files.')
  azureFilesIdentityBasedAuthentication: object?

  @description('Optional. Blob service and containers configuration.')
  blobServices: object?

  @description('Optional. Sets the custom domain name (CNAME source) for the storage account.')
  customDomainName: string?

  @description('Optional. Indicates whether indirect CName validation is enabled (updates only).')
  customDomainUseSubDomainName: bool?

  @description('Optional. Customer managed key definition.')
  customerManagedKey: {
    @description('Required. The name of the customer managed key.')
    keyName: string
    @description('Required. The Key Vault resource ID where the key is stored.')
    keyVaultResourceId: string
    @description('Optional. Enable or disable key auto-rotation. Default is true.')
    autoRotationEnabled: bool?
    @description('Optional. The version of the customer managed key to reference.')
    keyVersion: string?
    @description('Optional. User-assigned identity resource ID to fetch the key (if no system-assigned identity is available).')
    userAssignedIdentityResourceId: string?
  }?

  @description('Optional. When true, OAuth is the default authentication method.')
  defaultToOAuthAuthentication: bool?

  @description('Optional. Diagnostic settings for the service.')
  diagnosticSettings: array?

  @description('Optional. Endpoint type. Allowed values: AzureDnsZone, Standard.')
  dnsEndpointType: 'AzureDnsZone' | 'Standard'?

  @description('Optional. Enables NFS 3.0 support. Requires hierarchical namespace enabled.')
  enableNfsV3: bool?

  @description('Optional. Enables Secure File Transfer Protocol (SFTP). Requires hierarchical namespace enabled.')
  enableSftp: bool?

  @description('Optional. Enable/disable telemetry for the module.')
  enableTelemetry: bool?

  @description('Optional. File service and share configuration.')
  fileServices: object?

  @description('Optional. Enables local users feature for SFTP authentication.')
  isLocalUserEnabled: bool?

  @description('Optional. Key type for Queue & Table services. Allowed values: Account, Service.')
  keyType: 'Account' | 'Service'?

  @description('Optional. Storage account type. Allowed values: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2.')
  kind: 'BlobStorage' | 'BlockBlobStorage' | 'FileStorage' | 'Storage' | 'StorageV2'?

  @description('Optional. Large file shares state. Allowed values: Disabled, Enabled.')
  largeFileSharesState: 'Disabled' | 'Enabled'?

  @description('Optional. Local users for SFTP authentication.')
  localUsers: array?

  @description('Optional. Resource location.')
  location: string?

  @description('Optional. Lock settings for the resource.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Managed identity configuration.')
  managedIdentities: {
    @description('Optional. Enables system-assigned identity.')
    systemAssigned: bool?
    @description('Optional. List of user-assigned identity resource IDs.')
    userAssignedResourceIds: array?
  }?

  @description('Optional. Storage account management policy rules.')
  managementPolicyRules: array?

  @description('Optional. Minimum TLS version for requests. Allowed value: TLS1_2.')
  minimumTlsVersion: 'TLS1_2'?

  @description('Optional. Network ACL rules and settings.')
  networkAcls: object?

  @description('Optional. Private endpoint configurations.')
  privateEndpoints: array?

  @description('Optional. Whether public network access is allowed. Allowed values: Disabled, Enabled.')
  publicNetworkAccess: 'Disabled' | 'Enabled'?

  @description('Optional. Queue service configuration.')
  queueServices: object?

  @description('Optional. Indicates whether infrastructure encryption with PMK is applied.')
  requireInfrastructureEncryption: bool?

  @description('Optional. Role assignments for the storage account.')
  roleAssignments: array?

  @description('Optional. SAS expiration action. Allowed values: Block, Log.')
  sasExpirationAction: 'Block' | 'Log'?

  @description('Optional. SAS expiration period in DD.HH:MM:SS format.')
  sasExpirationPeriod: string?

  @description('Optional. Configuration for exporting secrets to Key Vault.')
  secretsExportConfiguration: object?

  @description('Optional. SKU name for the storage account. Allowed values: Premium_LRS, Premium_ZRS, PremiumV2_LRS, PremiumV2_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS, StandardV2_GRS, StandardV2_GZRS, StandardV2_LRS, StandardV2_ZRS.')
  skuName:
    | 'Premium_LRS'
    | 'Premium_ZRS'
    | 'PremiumV2_LRS'
    | 'PremiumV2_ZRS'
    | 'Standard_GRS'
    | 'Standard_GZRS'
    | 'Standard_LRS'
    | 'Standard_RAGRS'
    | 'Standard_RAGZRS'
    | 'Standard_ZRS'
    | 'StandardV2_GRS'
    | 'StandardV2_GZRS'
    | 'StandardV2_LRS'
    | 'StandardV2_ZRS'?

  @description('Optional. When true, allows only HTTPS traffic to the storage service.')
  supportsHttpsTrafficOnly: bool?

  @description('Optional. Table service and tables configuration.')
  tableServices: object?

  @description('Optional. Tags for the resource.')
  tags: object?
}

@export()
@description('Configuration object for a VM Maintenance Configuration resource.')
type vmMaintenanceDefinitionType = {
  @description('Required. Name of the Maintenance Configuration.')
  name: string

  @description('Optional. Enable or disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Extension properties of the Maintenance Configuration.')
  extensionProperties: {
    @description('Optional. Arbitrary key for each extension property.')
    *: string
  }?

  @description('Optional. Configuration settings for VM guest patching with Azure Update Manager.')
  installPatches: {
    @description('Optional. Arbitrary key for each patch configuration property.')
    *: string
  }?

  @description('Optional. Resource location. Defaults to the resource group location.')
  location: string?

  @description('Optional. Lock configuration for the Maintenance Configuration.')
  lock: {
    @description('Optional. Lock type.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Lock name.')
    name: string?
    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Maintenance scope of the configuration. Default is Host.')
  maintenanceScope: 'Extension' | 'Host' | 'InGuestPatch' | 'OSImage' | 'SQLDB' | 'SQLManagedInstance'?

  @description('Optional. Definition of the Maintenance Window.')
  maintenanceWindow: {
    @description('Optional. Arbitrary key for each maintenance window property.')
    *: string
  }?

  @description('Optional. Namespace of the resource.')
  namespace: string?

  @description('Optional. Role assignments to apply to the Maintenance Configuration.')
  roleAssignments: {
    @description('Required. Principal ID of the identity being assigned.')
    principalId: string
    @description('Required. Role to assign (display name, GUID, or full resource ID).')
    roleDefinitionIdOrName: string
    @description('Optional. Condition for the role assignment.')
    condition: string?
    @description('Optional. Condition version.')
    conditionVersion: '2.0'?
    @description('Optional. Delegated managed identity resource ID.')
    delegatedManagedIdentityResourceId: string?
    @description('Optional. Description of the role assignment.')
    description: string?
    @description('Optional. Role assignment name (GUID). If omitted, a GUID is generated.')
    name: string?
    @description('Optional. Principal type of the assigned identity.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
  }[]?

  @description('Optional. Tags to apply to the Maintenance Configuration resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. Visibility of the configuration. Default is Custom.')
  visibility: '' | 'Custom' | 'Public'?
}

// ---------------------------------------------
// Firewall + Policy (open)
// ---------------------------------------------
@export()
@description('Configuration object for the Azure Firewall resource.')
type firewallDefinitionType = {
  @description('Required. Name of the Azure Firewall.')
  name: string

  @description('Conditional. IP addresses associated with Azure Firewall. Required if virtualHubId is supplied.')
  hubIPAddresses: {
    @description('Optional. Private IP Address associated with Azure Firewall.')
    privateIPAddress: string?

    @description('Optional. Public IPs associated with Azure Firewall.')
    publicIPs: {
      @description('Optional. List of public IP addresses or IPs to retain.')
      addresses: array?

      @description('Optional. Public IP address count.')
      count: int?
    }?
  }?

  @description('Conditional. The virtualHub resource ID to which the firewall belongs. Required if virtualNetworkId is empty.')
  virtualHubResourceId: string?

  @description('Conditional. Shared services Virtual Network resource ID containing AzureFirewallSubnet. Required if virtualHubId is empty.')
  virtualNetworkResourceId: string?

  @description('Optional. Additional Public IP configurations.')
  additionalPublicIpConfigurations: array?

  @description('Optional. Application rule collections used by Azure Firewall.')
  applicationRuleCollections: {
    @description('Required. Name of the application rule collection.')
    name: string

    @description('Required. Properties of the application rule collection.')
    properties: {
      @description('Required. Action of the rule collection.')
      action: {
        @description('Required. Action type. Allowed values: Allow, Deny.')
        type: 'Allow' | 'Deny'
      }

      @description('Required. Priority of the application rule collection (100-65000).')
      priority: int

      @description('Required. Application rules in the collection.')
      rules: {
        @description('Required. Name of the application rule.')
        name: string

        @description('Required. Protocols for the application rule.')
        protocols: {
          @description('Required. Protocol type. Allowed values: Http, Https, Mssql.')
          protocolType: 'Http' | 'Https' | 'Mssql'

          @description('Optional. Port number for the protocol (≤64000).')
          port: int?
        }[]

        @description('Optional. Description of the rule.')
        description: string?

        @description('Optional. List of FQDN tags for this rule.')
        fqdnTags: array?

        @description('Optional. List of source IP addresses for this rule.')
        sourceAddresses: array?

        @description('Optional. List of source IP groups for this rule.')
        sourceIpGroups: array?

        @description('Optional. List of target FQDNs for this rule.')
        targetFqdns: array?
      }[]
    }
  }[]?

  @description('Optional. Maximum number of capacity units for the firewall.')
  autoscaleMaxCapacity: int?

  @description('Optional. Minimum number of capacity units for the firewall.')
  autoscaleMinCapacity: int?

  @description('Optional. Availability Zones for zone-redundant deployment.')
  availabilityZones: int[]?

  @description('Optional. Tier of Azure Firewall. Allowed values: Basic, Premium, Standard.')
  azureSkuTier: 'Basic' | 'Premium' | 'Standard'?

  @description('Optional. Diagnostic settings for the firewall.')
  diagnosticSettings: {
    @description('Optional. Event Hub authorization rule resource ID.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Event Hub name for diagnostic logs.')
    eventHubName: string?

    @description('Optional. Log Analytics destination type. Allowed values: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Log categories and groups.')
    logCategoriesAndGroups: {
      @description('Optional. Name of a diagnostic log category.')
      category: string?

      @description('Optional. Name of a diagnostic log category group.')
      categoryGroup: string?

      @description('Optional. Enable/disable category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace partner resource ID for diagnostic logs.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metric categories for diagnostics.')
    metricCategories: {
      @description('Required. Name of a diagnostic metric category.')
      category: string

      @description('Optional. Enable/disable metric category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Diagnostic setting name.')
    name: string?

    @description('Optional. Diagnostic storage account resource ID.')
    storageAccountResourceId: string?

    @description('Optional. Log Analytics workspace resource ID.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. Enable or disable forced tunneling.')
  enableForcedTunneling: bool?

  @description('Optional. Enable or disable usage telemetry. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Resource ID of the Firewall Policy to attach.')
  firewallPolicyId: string?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the firewall.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Lock name.')
    name: string?

    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Properties of the Management Public IP to create and use.')
  managementIPAddressObject: object?

  @description('Optional. Management Public IP resource ID for AzureFirewallManagementSubnet.')
  managementIPResourceID: string?

  @description('Optional. NAT rule collections used by Azure Firewall.')
  natRuleCollections: {
    @description('Required. Name of the NAT rule collection.')
    name: string

    @description('Required. Properties of the NAT rule collection.')
    properties: {
      @description('Required. Action of the NAT rule collection.')
      action: {
        @description('Required. Action type. Allowed values: Dnat, Snat.')
        type: 'Dnat' | 'Snat'
      }

      @description('Required. Priority of the NAT rule collection (100–65000).')
      priority: int

      @description('Required. NAT rules in the collection.')
      rules: {
        @description('Required. Name of the NAT rule.')
        name: string

        @description('Required. Protocols for the NAT rule. Allowed values: Any, ICMP, TCP, UDP.')
        protocols: ('Any' | 'ICMP' | 'TCP' | 'UDP')[]

        @description('Optional. Description of the NAT rule.')
        description: string?

        @description('Optional. Destination addresses (IP ranges, prefixes, service tags).')
        destinationAddresses: array?

        @description('Optional. Destination ports.')
        destinationPorts: array?

        @description('Optional. Source addresses.')
        sourceAddresses: array?

        @description('Optional. Source IP groups.')
        sourceIpGroups: array?

        @description('Optional. Translated address for the NAT rule.')
        translatedAddress: string?

        @description('Optional. Translated FQDN for the NAT rule.')
        translatedFqdn: string?

        @description('Optional. Translated port for the NAT rule.')
        translatedPort: string?
      }[]
    }
  }[]?

  @description('Optional. Network rule collections used by Azure Firewall.')
  networkRuleCollections: {
    @description('Required. Name of the network rule collection.')
    name: string

    @description('Required. Properties of the network rule collection.')
    properties: {
      @description('Required. Action of the network rule collection.')
      action: {
        @description('Required. Action type. Allowed values: Allow, Deny.')
        type: 'Allow' | 'Deny'
      }

      @description('Required. Priority of the network rule collection (100–65000).')
      priority: int

      @description('Required. Network rules in the collection.')
      rules: {
        @description('Required. Name of the network rule.')
        name: string

        @description('Required. Protocols for the network rule. Allowed values: Any, ICMP, TCP, UDP.')
        protocols: ('Any' | 'ICMP' | 'TCP' | 'UDP')[]

        @description('Optional. Description of the network rule.')
        description: string?

        @description('Optional. Destination addresses.')
        destinationAddresses: array?

        @description('Optional. Destination FQDNs.')
        destinationFqdns: array?

        @description('Optional. Destination IP groups.')
        destinationIpGroups: array?

        @description('Optional. Destination ports.')
        destinationPorts: array?

        @description('Optional. Source addresses.')
        sourceAddresses: array?

        @description('Optional. Source IP groups.')
        sourceIpGroups: array?
      }[]
    }
  }[]?

  @description('Optional. Properties of the Public IP to create and use if no existing Public IP is provided.')
  publicIPAddressObject: object?

  @description('Optional. Public IP resource ID for the AzureFirewallSubnet.')
  publicIPResourceID: string?

  @description('Optional. Role assignments for the firewall.')
  roleAssignments: object[]?

  @description('Optional. Tags to apply to the Azure Firewall resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. Operation mode for Threat Intel. Allowed values: Alert, Deny, Off.')
  threatIntelMode: 'Alert' | 'Deny' | 'Off'?
}

@export()
@description('Configuration object for the Firewall Policy to be deployed.')
type firewallPolicyDefinitionType = {
  @description('Required. Name of the Firewall Policy.')
  name: string

  @description('Optional. A flag to indicate if SQL Redirect traffic filtering is enabled. Requires no rule using ports 11000–11999.')
  allowSqlRedirect: bool?

  @description('Optional. Resource ID of the base policy.')
  basePolicyResourceId: string?

  @description('Optional. Name of the CA certificate.')
  certificateName: string?

  @description('Optional. Default Log Analytics Resource ID for Firewall Policy Insights.')
  defaultWorkspaceResourceId: string?

  @description('Optional. Enable DNS Proxy on Firewalls attached to the Firewall Policy.')
  enableProxy: bool?

  @description('Optional. Enable or disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. List of FQDNs for the ThreatIntel Allowlist.')
  fqdns: array?

  @description('Optional. Flag to indicate if insights are enabled on the policy.')
  insightsIsEnabled: bool?

  @description('Optional. Intrusion detection configuration.')
  intrusionDetection: {
    @description('Optional. Intrusion detection configuration properties.')
    configuration: {
      @description('Optional. List of bypass traffic rules.')
      bypassTrafficSettings: {
        @description('Required. Name of the bypass traffic rule.')
        name: string

        @description('Optional. Description of the bypass traffic rule.')
        description: string?

        @description('Optional. Destination IP addresses or ranges.')
        destinationAddresses: array?

        @description('Optional. Destination IP groups.')
        destinationIpGroups: array?

        @description('Optional. Destination ports or ranges.')
        destinationPorts: array?

        @description('Optional. Protocol for the rule. Allowed values: ANY, ICMP, TCP, UDP.')
        protocol: 'ANY' | 'ICMP' | 'TCP' | 'UDP'?

        @description('Optional. Source IP addresses or ranges.')
        sourceAddresses: array?

        @description('Optional. Source IP groups.')
        sourceIpGroups: array?
      }[]?

      @description('Optional. List of private IP ranges to consider as internal.')
      privateRanges: array?

      @description('Optional. Signature override states.')
      signatureOverrides: {
        @description('Required. Signature ID.')
        id: string

        @description('Required. Signature state. Allowed values: Alert, Deny, Off.')
        mode: 'Alert' | 'Deny' | 'Off'
      }[]?
    }?

    @description('Optional. Intrusion detection mode. Allowed values: Alert, Deny, Off.')
    mode: 'Alert' | 'Deny' | 'Off'?

    @description('Optional. IDPS profile name. Allowed values: Advanced, Basic, Extended, Standard.')
    profile: 'Advanced' | 'Basic' | 'Extended' | 'Standard'?
  }?

  @description('Optional. List of IP addresses for the ThreatIntel Allowlist.')
  ipAddresses: array?

  @description('Optional. Key Vault secret ID (base-64 encoded unencrypted PFX or Certificate object).')
  keyVaultSecretId: string?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the Firewall Policy.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Lock name.')
    name: string?

    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Managed identity definition for this resource.')
  managedIdentities: {
    @description('Optional. User-assigned identity resource IDs. Required if using a user-assigned identity for encryption.')
    userAssignedResourceIds: array?
  }?

  @description('Optional. Number of days to retain Firewall Policy insights. Default is 365.')
  retentionDays: int?

  @description('Optional. Role assignments to create for the Firewall Policy.')
  roleAssignments: object[]?

  @description('Optional. Rule collection groups.')
  ruleCollectionGroups: array?

  @description('Optional. List of custom DNS servers.')
  servers: array?

  @description('Optional. SNAT private IP ranges configuration.')
  snat: {
    @description('Required. Mode for automatically learning private ranges. Allowed values: Disabled, Enabled.')
    autoLearnPrivateRanges: 'Disabled' | 'Enabled'

    @description('Optional. List of private IP ranges not to be SNATed.')
    privateRanges: array?
  }?

  @description('Optional. Tags to apply to the Firewall Policy.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. Threat Intelligence mode. Allowed values: Alert, Deny, Off.')
  threatIntelMode: 'Alert' | 'Deny' | 'Off'?

  @description('Optional. Tier of the Firewall Policy. Allowed values: Basic, Premium, Standard.')
  tier: 'Basic' | 'Premium' | 'Standard'?

  @description('Optional. List of workspaces for Firewall Policy Insights.')
  workspaces: array?
}

@export()
@description('Firewall Policy RCG input (open).')
type firewallPolicyRcgInputType = object

@export()
@description('Firewall Policy Rule Collection input (open).')
type firewallPolicyRuleCollectionInputType = object

@export()
@description('Firewall Policy Rule (open).')
type firewallPolicyRuleType = object

// ---------------------------------------------
// Cosmos DB (GenAI App flavor)
// ---------------------------------------------
@export()
@description('Configuration object for the GenAI App Cosmos DB account.')
type genAIAppCosmosDbDefinitionType = {
  @description('Required. The name of the account.')
  name: string

  @description('Optional. Enable automatic failover for regions. Defaults to true.')
  automaticFailover: bool?

  @description('Optional. Interval in minutes between two backups (periodic only). Defaults to 240. Range: 60–1440.')
  backupIntervalInMinutes: int?

  @description('Optional. Retention period for continuous mode backup. Default is Continuous30Days. Allowed values: Continuous30Days, Continuous7Days.')
  backupPolicyContinuousTier: 'Continuous30Days' | 'Continuous7Days'?

  @description('Optional. Backup mode. Periodic must be used if multiple write locations are enabled. Default is Continuous. Allowed values: Continuous, Periodic.')
  backupPolicyType: 'Continuous' | 'Periodic'?

  @description('Optional. Time (hours) each backup is retained (periodic only). Default is 8. Range: 2–720.')
  backupRetentionIntervalInHours: int?

  @description('Optional. Type of backup residency (periodic only). Default is Local. Allowed values: Geo, Local, Zone.')
  backupStorageRedundancy: 'Geo' | 'Local' | 'Zone'?

  @description('Optional. List of Cosmos DB specific capabilities to enable.')
  capabilitiesToAdd: (
    | 'DeleteAllItemsByPartitionKey'
    | 'DisableRateLimitingResponses'
    | 'EnableCassandra'
    | 'EnableGremlin'
    | 'EnableMaterializedViews'
    | 'EnableMongo'
    | 'EnableNoSQLFullTextSearch'
    | 'EnableNoSQLVectorSearch'
    | 'EnableServerless'
    | 'EnableTable')[]?

  @description('Optional. The offer type for the account. Default is Standard. Allowed value: Standard.')
  databaseAccountOfferType: 'Standard'?

  @description('Optional. Cosmos DB for NoSQL native role-based access control assignments.')
  dataPlaneRoleAssignments: {
    @description('Required. The Microsoft Entra principal ID granted access by this assignment.')
    principalId: string

    @description('Required. The unique identifier of the NoSQL native role definition.')
    roleDefinitionId: string

    @description('Optional. Unique name of the role assignment.')
    name: string?
  }[]?

  @description('Optional. Cosmos DB for NoSQL native role-based access control definitions.')
  dataPlaneRoleDefinitions: {
    @description('Required. A user-friendly unique name for the role definition.')
    roleName: string

    @description('Optional. Assignable scopes for the definition.')
    assignableScopes: string[]?

    @description('Optional. Assignments associated with this role definition.')
    assignments: {
      @description('Required. The Microsoft Entra principal ID granted access by this role assignment.')
      principalId: string

      @description('Optional. Unique identifier name for the role assignment.')
      name: string?
    }[]?

    @description('Optional. Array of allowed data actions.')
    dataActions: string[]?

    @description('Optional. Unique identifier for the role definition.')
    name: string?
  }[]?

  @description('Optional. Default consistency level. Default is Session. Allowed values: BoundedStaleness, ConsistentPrefix, Eventual, Session, Strong.')
  defaultConsistencyLevel: 'BoundedStaleness' | 'ConsistentPrefix' | 'Eventual' | 'Session' | 'Strong'?

  @description('Optional. Diagnostic settings for the Cosmos DB account.')
  diagnosticSettings: array?

  @description('Optional. Disable write operations on metadata resources via account keys. Default is true.')
  disableKeyBasedMetadataWriteAccess: bool?

  @description('Optional. Opt-out of local authentication, enforcing Microsoft Entra-only auth. Default is true.')
  disableLocalAuthentication: bool?

  @description('Optional. Enable analytical storage. Default is false.')
  enableAnalyticalStorage: bool?

  @description('Optional. Enable Free Tier. Default is false.')
  enableFreeTier: bool?

  @description('Optional. Enable multiple write locations. Requires periodic backup. Default is false.')
  enableMultipleWriteLocations: bool?

  @description('Optional. Enable/Disable usage telemetry. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Failover locations configuration.')
  failoverLocations: {
    @description('Required. Failover priority. 0 = write region.')
    failoverPriority: int

    @description('Required. Region name.')
    locationName: string

    @description('Optional. Zone redundancy flag for region. Default is true.')
    isZoneRedundant: bool?
  }[]?

  @description('Optional. Gremlin database configurations.')
  gremlinDatabases: array?

  @description('Optional. Location for the account. Defaults to resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the Cosmos DB account.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Lock name.')
    name: string?

    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Managed identity configuration.')
  managedIdentities: {
    @description('Optional. Enables system-assigned identity.')
    systemAssigned: bool?

    @description('Optional. User-assigned identity resource IDs.')
    userAssignedResourceIds: string[]?
  }?

  @description('Optional. Maximum lag time in seconds (BoundedStaleness). Defaults to 300.')
  maxIntervalInSeconds: int?

  @description('Optional. Maximum stale requests (BoundedStaleness). Defaults to 100000.')
  maxStalenessPrefix: int?

  @description('Optional. Minimum allowed TLS version. Default is Tls12.')
  minimumTlsVersion: 'Tls12'?

  @description('Optional. MongoDB database configurations.')
  mongodbDatabases: array?

  @description('Optional. Network restrictions for the Cosmos DB account.')
  networkRestrictions: object?

  @description('Optional. Private endpoint configurations for secure connectivity.')
  privateEndpoints: array?

  @description('Optional. Control plane Azure role assignments for Cosmos DB.')
  roleAssignments: object[]?

  @description('Optional. MongoDB server version (if using MongoDB API). Default is 4.2.')
  serverVersion: '3.2' | '3.6' | '4.0' | '4.2' | '5.0' | '6.0' | '7.0'?

  @description('Optional. SQL (NoSQL) database configurations.')
  sqlDatabases: array?

  @description('Optional. Table API database configurations.')
  tables: array?

  @description('Optional. Tags to apply to the Cosmos DB account.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?

  @description('Optional. Total throughput limit in RU/s. Default is unlimited (-1).')
  totalThroughputLimit: int?

  @description('Optional. Zone redundancy for single-region accounts. Default is true.')
  zoneRedundant: bool?
}

// ---------------------------------------------
// Hub‑and‑Spoke Peering
// ---------------------------------------------
@export()
@description('Hub VNet peering settings (open).')
type hubVnetPeeringDefinitionType = object



// ---------------------------------------------
// Azure Cognitive Search
// ---------------------------------------------
@export()
@description('Configuration object for the Azure Cognitive Search service.')
type kSAISearchDefinitionType = {
  @description('Required. The name of the Azure Cognitive Search service to create or update. Must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, must be between 2 and 60 characters in length, and must be globally unique. Immutable after creation.')
  name: string

  @description('Optional. Defines the options for how the data plane API of a Search service authenticates requests. Must remain {} if disableLocalAuth=true.')
  authOptions: {
    @description('Optional. Indicates that either API key or an access token from Microsoft Entra ID can be used for authentication.')
    aadOrApiKey: {
      @description('Optional. Response sent when authentication fails. Allowed values: http401WithBearerChallenge, http403.')
      aadAuthFailureMode: 'http401WithBearerChallenge' | 'http403'?
    }?

    @description('Optional. Indicates that only the API key can be used for authentication.')
    apiKeyOnly: object?
  }?

  @description('Optional. Policy that determines how resources within the search service are encrypted with Customer Managed Keys. Default is Unspecified. Allowed values: Disabled, Enabled, Unspecified.')
  cmkEnforcement: 'Disabled' | 'Enabled' | 'Unspecified'?

  @description('Optional. Diagnostic settings for the search service.')
  diagnosticSettings: {
    @description('Optional. Resource ID of the diagnostic Event Hub authorization rule.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Name of the diagnostic Event Hub. Without this, one Event Hub per category will be created.')
    eventHubName: string?

    @description('Optional. Destination type for Log Analytics. Allowed values: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Log categories and groups to collect. Use [] to disable.')
    logCategoriesAndGroups: {
      @description('Optional. Diagnostic log category.')
      category: string?

      @description('Optional. Diagnostic log category group. Use allLogs to collect all logs.')
      categoryGroup: string?

      @description('Optional. Enable or disable this log category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace partner resource ID to send logs to.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metric categories to collect.')
    metricCategories: {
      @description('Required. Diagnostic metric category. Example: AllMetrics.')
      category: string

      @description('Optional. Enable or disable this metric category. Default is true.')
      enabled: bool?
    }[]?

    @description('Optional. Name of the diagnostic setting.')
    name: string?

    @description('Optional. Storage account resource ID for diagnostic logs.')
    storageAccountResourceId: string?

    @description('Optional. Log Analytics workspace resource ID for diagnostic logs.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. Disable local authentication via API keys. Cannot be true if authOptions are defined. Default is true.')
  disableLocalAuth: bool?

  @description('Optional. Enable/disable usage telemetry for the module. Default is true.')
  enableTelemetry: bool?

  @description('Optional. Hosting mode, only for standard3 SKU. Allowed values: default, highDensity. Default is default.')
  hostingMode: 'default' | 'highDensity'?

  @description('Optional. Location for all resources. Default is resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings for the search service.')
  lock: {
    @description('Optional. Type of lock. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Name of the lock.')
    name: string?

    @description('Optional. Notes for the lock.')
    notes: string?
  }?

  @description('Optional. Managed identity definition for the search service.')
  managedIdentities: {
    @description('Optional. Enables system-assigned managed identity.')
    systemAssigned: bool?

    @description('Optional. User-assigned identity resource IDs. Required if user-assigned identity is used for encryption.')
    userAssignedResourceIds: string[]?
  }?

  @description('Optional. Network rules for the search service.')
  networkRuleSet: {
    @description('Optional. Bypass setting. Allowed values: AzurePortal, AzureServices, None.')
    bypass: 'AzurePortal' | 'AzureServices' | 'None'?

    @description('Optional. IP restriction rules applied when publicNetworkAccess=Enabled.')
    ipRules: {
      @description('Required. IPv4 address (e.g., 123.1.2.3) or range in CIDR format (e.g., 123.1.2.3/24) to allow.')
      value: string
    }[]?
  }?

  @description('Optional. Number of partitions in the search service. Valid values: 1,2,3,4,6,12 (or 1–3 for standard3 highDensity). Default is 1.')
  partitionCount: int?

  @description('Optional. Configuration details for private endpoints.')
  privateEndpoints: array?

  @description('Optional. Public network access. Default is Enabled. Allowed values: Enabled, Disabled.')
  publicNetworkAccess: 'Enabled' | 'Disabled'?

  @description('Optional. Number of replicas in the search service. Must be 1–12 for Standard SKUs or 1–3 for Basic. Default is 3.')
  replicaCount: int?

  @description('Optional. Role assignments for the search service.')
  roleAssignments: array?

  @description('Optional. Key Vault reference and secret settings for exporting admin keys.')
  secretsExportConfiguration: {
    @description('Required. Key Vault resource ID where the API Admin keys will be stored.')
    keyVaultResourceId: string

    @description('Optional. Secret name for the primary admin key.')
    primaryAdminKeyName: string?

    @description('Optional. Secret name for the secondary admin key.')
    secondaryAdminKeyName: string?
  }?

  @description('Optional. Semantic search configuration. Allowed values: disabled, free, standard.')
  semanticSearch: 'disabled' | 'free' | 'standard'?

  @description('Optional. Shared Private Link Resources to create. Default is [].')
  sharedPrivateLinkResources: array?

  @description('Optional. SKU of the search service. Determines price tier and limits. Default is standard. Allowed values: basic, free, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2.')
  sku: 'basic' | 'free' | 'standard' | 'standard2' | 'standard3' | 'storage_optimized_l1' | 'storage_optimized_l2'?

  @description('Optional. Tags for categorizing the search service.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
}

// ---------------------------------------------
// Bing Grounding
// ---------------------------------------------
@export()
@description('Configuration object for the Bing Grounding service to be deployed.')
type kSGroundingWithBingDefinitionType = {
  @description('Optional. Bing Grounding resource name.')
  name: string?
  @description('Required. Bing Grounding resource SKU.')
  sku: string
  @description('Required. Tags to apply to the Bing Grounding resource.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }
}

// ---------------------------------------------
// Key Vault
// ---------------------------------------------
@export()
@description('Configuration object for the Azure Key Vault to be deployed.')
type keyVaultDefinitionType = {
  @description('Required. Name of the Key Vault. Must be globally unique.')
  name: string

  @description('Optional. All access policies to create.')
  accessPolicies: {
    @description('Required. The object ID of a user, service principal or security group in the tenant for the vault.')
    objectId: string
    @description('Required. Permissions the identity has for keys, secrets and certificates.')
    permissions: {
      @description('Optional. Permissions to certificates.')
      certificates: (
        | 'all'
        | 'backup'
        | 'create'
        | 'delete'
        | 'deleteissuers'
        | 'get'
        | 'getissuers'
        | 'import'
        | 'list'
        | 'listissuers'
        | 'managecontacts'
        | 'manageissuers'
        | 'purge'
        | 'recover'
        | 'restore'
        | 'setissuers'
        | 'update')[]?
      @description('Optional. Permissions to keys.')
      keys: (
        | 'all'
        | 'backup'
        | 'create'
        | 'decrypt'
        | 'delete'
        | 'encrypt'
        | 'get'
        | 'getrotationpolicy'
        | 'import'
        | 'list'
        | 'purge'
        | 'recover'
        | 'release'
        | 'restore'
        | 'rotate'
        | 'setrotationpolicy'
        | 'sign'
        | 'unwrapKey'
        | 'update'
        | 'verify'
        | 'wrapKey')[]?
      @description('Optional. Permissions to secrets.')
      secrets: ('all' | 'backup' | 'delete' | 'get' | 'list' | 'purge' | 'recover' | 'restore' | 'set')[]?
      @description('Optional. Permissions to storage accounts.')
      storage: (
        | 'all'
        | 'backup'
        | 'delete'
        | 'deletesas'
        | 'get'
        | 'getsas'
        | 'list'
        | 'listsas'
        | 'purge'
        | 'recover'
        | 'regeneratekey'
        | 'restore'
        | 'set'
        | 'setsas'
        | 'update')[]?
    }
    @description('Optional. Application ID of the client making request on behalf of a principal.')
    applicationId: string?
    @description('Optional. The tenant ID that is used for authenticating requests to the key vault.')
    tenantId: string?
  }[]?

  @description('Optional. The vault\'s create mode to indicate whether the vault needs to be recovered or not.')
  createMode: 'default' | 'recover'?

  @description('Optional. The diagnostic settings of the service.')
  diagnosticSettings: object[]?

  @description('Optional. Provide true to enable Key Vault purge protection feature.')
  enablePurgeProtection: bool?

  @description('Optional. Controls how data actions are authorized. When true, RBAC is used for authorization.')
  enableRbacAuthorization: bool?

  @description('Optional. Switch to enable/disable Key Vault soft delete feature.')
  enableSoftDelete: bool?

  @description('Optional. Enable/Disable usage telemetry for module.')
  enableTelemetry: bool?

  @description('Optional. Specifies if the vault is enabled for deployment by script or compute.')
  enableVaultForDeployment: bool?

  @description('Optional. Specifies if the platform has access to the vault for disk encryption scenarios.')
  enableVaultForDiskEncryption: bool?

  @description('Optional. Specifies if the vault is enabled for a template deployment.')
  enableVaultForTemplateDeployment: bool?

  @description('Optional. All keys to create.')
  keys: object[]?

  @description('Optional. Location for all resources.')
  location: string?

  @description('Optional. The lock settings of the service.')
  lock: {
    @description('Optional. Specify the type of lock.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
    @description('Optional. Specify the name of the lock.')
    name: string?
    @description('Optional. Specify the notes of the lock.')
    notes: string?
  }?

  @description('Optional. Rules governing the accessibility of the resource from specific networks.')
  networkAcls: object?

  @description('Optional. Configuration details for private endpoints.')
  privateEndpoints: {
    @description('Required. Resource ID of the subnet where the endpoint needs to be created.')
    subnetResourceId: string
    @description('Optional. Application security groups in which the Private Endpoint IP configuration is included.')
    applicationSecurityGroupResourceIds: string[]?
    @description('Optional. Custom DNS configurations.')
    customDnsConfigs: {
      @description('Required. A list of private IP addresses of the private endpoint.')
      ipAddresses: string[]
      @description('Optional. FQDN that resolves to private endpoint IP address.')
      fqdn: string?
    }[]?
    @description('Optional. The custom name of the network interface attached to the Private Endpoint.')
    customNetworkInterfaceName: string?
    @description('Optional. Enable/Disable usage telemetry for module.')
    enableTelemetry: bool?
    @description('Optional. A list of IP configurations of the Private Endpoint.')
    ipConfigurations: {
      @description('Required. The name of the resource that is unique within a resource group.')
      name: string
      @description('Required. Properties of private endpoint IP configurations.')
      properties: {
        @description('Required. The ID of a group obtained from the remote resource to connect to.')
        groupId: string
        @description('Required. The member name of a group obtained from the remote resource.')
        memberName: string
        @description('Required. A private IP address obtained from the private endpoint\'s subnet.')
        privateIPAddress: string
      }
    }[]?
    @description('Optional. If Manual Private Link Connection is required.')
    isManualConnection: bool?
    @description('Optional. The location to deploy the Private Endpoint to.')
    location: string?
    @description('Optional. Lock settings for the Private Endpoint.')
    lock: {
      @description('Optional. Specify the type of lock.')
      kind: 'CanNotDelete' | 'None' | 'ReadOnly'?
      @description('Optional. Specify the name of the lock.')
      name: string?
      @description('Optional. Specify the notes of the lock.')
      notes: string?
    }?
    @description('Optional. A message passed with the manual connection request.')
    manualConnectionRequestMessage: string?
    @description('Optional. The name of the Private Endpoint.')
    name: string?
    @description('Optional. The private DNS zone group to configure for the Private Endpoint.')
    privateDnsZoneGroup: {
      @description('Required. The private DNS Zone Groups to associate the Private Endpoint.')
      privateDnsZoneGroupConfigs: {
        @description('Required. The resource ID of the private DNS zone.')
        privateDnsZoneResourceId: string
        @description('Optional. The name of the private DNS Zone Group config.')
        name: string?
      }[]
      @description('Optional. The name of the Private DNS Zone Group.')
      name: string?
    }?
    @description('Optional. The name of the private link connection to create.')
    privateLinkServiceConnectionName: string?
    @description('Optional. The resource ID of the Resource Group the Private Endpoint will be created in.')
    resourceGroupResourceId: string?
    @description('Optional. Array of role assignments to create for the Private Endpoint.')
    roleAssignments: object[]?
    @description('Optional. The subresource to deploy the Private Endpoint for (e.g., vault).')
    service: string?
    @description('Optional. Tags for the Private Endpoint.')
    tags: object?
  }[]?

  @description('Optional. Whether or not public network access is allowed for this resource.')
  publicNetworkAccess: '' | 'Disabled' | 'Enabled'?

  @description('Optional. Array of role assignments to create at the vault level.')
  roleAssignments: object[]?

  @description('Optional. All secrets to create.')
  secrets: {
    @description('Required. The name of the secret.')
    name: string
    @secure()
    @description('Required. The value of the secret.')
    value: string
    @description('Optional. Contains attributes of the secret.')
    attributes: {
      @description('Optional. Defines whether the secret is enabled or disabled.')
      enabled: bool?
      @description('Optional. Expiration time of the secret, in epoch seconds.')
      exp: int?
      @description('Optional. Not-before time of the secret, in epoch seconds.')
      nbf: int?
    }?
    @description('Optional. The content type of the secret.')
    contentType: string?
    @description('Optional. Array of role assignments to create for the secret.')
    roleAssignments: object[]?
    @description('Optional. Resource tags for the secret.')
    tags: object?
  }[]?

  @description('Optional. Specifies the SKU for the vault.')
  sku: 'premium' | 'standard'?

  @description('Optional. Soft delete retention days (between 7 and 90).')
  softDeleteRetentionInDays: int?

  @description('Optional. Resource tags for the vault.')
  tags: object?
}

// ---------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------
@export()
@description('Configuration object for the Log Analytics Workspace to be deployed.')
type logAnalyticsDefinitionType = {
  @description('Required. Name of the Log Analytics workspace.')
  name: string

  @description('Conditional. List of Storage Accounts to be linked. Required if forceCmkForQuery is true and savedSearches is not empty.')
  linkedStorageAccounts: {
    @description('Required. Name of the storage link.')
    name: string

    @description('Required. Linked storage accounts resource IDs.')
    storageAccountIds: array
  }[]?

  @description('Optional. Daily ingestion quota in GB. Default is -1.')
  dailyQuotaGb: int?

  @description('Optional. Data export instances for the workspace.')
  dataExports: {
    @description('Required. Name of the data export.')
    name: string

    @description('Required. Table names to export.')
    tableNames: array

    @description('Optional. Destination configuration for the export.')
    destination: {
      @description('Required. Destination resource ID.')
      resourceId: string

      @description('Optional. Destination metadata.')
      metaData: {
        @description('Optional. Event Hub name (not applicable when destination is Storage Account).')
        eventHubName: string?
      }?
    }?

    @description('Optional. Enable or disable the data export.')
    enable: bool?
  }[]?

  @description('Optional. Number of days data will be retained. Default 365 (0–730).')
  dataRetention: int?

  @description('Optional. Data sources for the workspace.')
  dataSources: {
    @description('Required. Kind of data source.')
    kind: string

    @description('Required. Name of the data source.')
    name: string

    @description('Optional. Counter name for WindowsPerformanceCounter.')
    counterName: string?

    @description('Optional. Event log name for WindowsEvent.')
    eventLogName: string?

    @description('Optional. Event types for WindowsEvent.')
    eventTypes: array?

    @description('Optional. Instance name for WindowsPerformanceCounter or LinuxPerformanceObject.')
    instanceName: string?

    @description('Optional. Interval in seconds for collection.')
    intervalSeconds: int?

    @description('Optional. Resource ID linked to the workspace.')
    linkedResourceId: string?

    @description('Optional. Object name for WindowsPerformanceCounter or LinuxPerformanceObject.')
    objectName: string?

    @description('Optional. Performance counters for LinuxPerformanceObject.')
    performanceCounters: array?

    @description('Optional. State (for IISLogs, LinuxSyslogCollection, or LinuxPerformanceCollection).')
    state: string?

    @description('Optional. System log name for LinuxSyslog.')
    syslogName: string?

    @description('Optional. Severities for LinuxSyslog.')
    syslogSeverities: array?

    @description('Optional. Tags for the data source.')
    tags: object?
  }[]?

  @description('Optional. Diagnostic settings for the workspace.')
  diagnosticSettings: {
    @description('Optional. Event Hub authorization rule resource ID.')
    eventHubAuthorizationRuleResourceId: string?

    @description('Optional. Diagnostic Event Hub name.')
    eventHubName: string?

    @description('Optional. Destination type for Log Analytics. Allowed: AzureDiagnostics, Dedicated.')
    logAnalyticsDestinationType: 'AzureDiagnostics' | 'Dedicated'?

    @description('Optional. Log categories and groups to stream.')
    logCategoriesAndGroups: {
      @description('Optional. Log category name.')
      category: string?

      @description('Optional. Log category group name.')
      categoryGroup: string?

      @description('Optional. Enable or disable the category. Default true.')
      enabled: bool?
    }[]?

    @description('Optional. Marketplace partner resource ID.')
    marketplacePartnerResourceId: string?

    @description('Optional. Metric categories to stream.')
    metricCategories: {
      @description('Required. Diagnostic metric category name.')
      category: string

      @description('Optional. Enable or disable the metric category. Default true.')
      enabled: bool?
    }[]?

    @description('Optional. Diagnostic setting name.')
    name: string?

    @description('Optional. Storage account resource ID for diagnostic logs.')
    storageAccountResourceId: string?

    @description('Optional. Use this workspace as diagnostic target (ignores workspaceResourceId).')
    useThisWorkspace: bool?

    @description('Optional. Log Analytics workspace resource ID for diagnostics.')
    workspaceResourceId: string?
  }[]?

  @description('Optional. Enable or disable telemetry. Default true.')
  enableTelemetry: bool?

  @description('Optional. Features for the workspace.')
  features: {
    @description('Optional. Disable non-EntraID auth. Default true.')
    disableLocalAuth: bool?

    @description('Optional. Enable data export.')
    enableDataExport: bool?

    @description('Optional. Enable log access using only resource permissions. Default false.')
    enableLogAccessUsingOnlyResourcePermissions: bool?

    @description('Optional. Remove data after 30 days.')
    immediatePurgeDataOn30Days: bool?
  }?

  @description('Optional. Enforce customer-managed storage for queries.')
  forceCmkForQuery: bool?

  @description('Optional. Gallery solutions for the workspace.')
  gallerySolutions: {
    @description('Required. Solution name. Must follow Microsoft or 3rd party naming convention.')
    name: string

    @description('Required. Plan for the gallery solution.')
    plan: {
      @description('Required. Product name (e.g., OMSGallery/AntiMalware).')
      product: string

      @description('Optional. Solution name (defaults to gallerySolutions.name).')
      name: string?

      @description('Optional. Publisher name (default: Microsoft for Microsoft solutions).')
      publisher: string?
    }
  }[]?

  @description('Optional. Linked services for the workspace.')
  linkedServices: {
    @description('Required. Name of the linked service.')
    name: string

    @description('Optional. Resource ID of the linked service (read access).')
    resourceId: string?

    @description('Optional. Resource ID for write access.')
    writeAccessResourceId: string?
  }[]?

  @description('Optional. Location of the workspace. Default: resourceGroup().location.')
  location: string?

  @description('Optional. Lock settings.')
  lock: {
    @description('Optional. Lock type. Allowed values: CanNotDelete, None, ReadOnly.')
    kind: 'CanNotDelete' | 'None' | 'ReadOnly'?

    @description('Optional. Lock name.')
    name: string?

    @description('Optional. Lock notes.')
    notes: string?
  }?

  @description('Optional. Managed identity definition (system-assigned or user-assigned).')
  managedIdentities: {
    @description('Optional. Enable system-assigned identity.')
    systemAssigned: bool?

    @description('Optional. User-assigned identity resource IDs.')
    userAssignedResourceIds: array?
  }?

  @description('Optional. Onboard workspace to Sentinel. Requires SecurityInsights solution.')
  onboardWorkspaceToSentinel: bool?

  @description('Optional. Network access for ingestion. Allowed: Disabled, Enabled.')
  publicNetworkAccessForIngestion: 'Disabled' | 'Enabled'?

  @description('Optional. Network access for query. Allowed: Disabled, Enabled.')
  publicNetworkAccessForQuery: 'Disabled' | 'Enabled'?

  @description('Optional. Replication settings.')
  replication: {
    @description('Conditional. Replication location. Required if replication is enabled.')
    location: string?

    @description('Optional. Enable replication.')
    enabled: bool?
  }?

  @description('Optional. Role assignments for the workspace.')
  roleAssignments: {
    @description('Required. Principal ID to assign.')
    principalId: string

    @description('Required. Role definition ID, name, or GUID.')
    roleDefinitionIdOrName: string

    @description('Optional. Condition for the role assignment.')
    condition: string?

    @description('Optional. Condition version. Allowed: 2.0.')
    conditionVersion: '2.0'?

    @description('Optional. Delegated managed identity resource ID.')
    delegatedManagedIdentityResourceId: string?

    @description('Optional. Role assignment description.')
    description: string?

    @description('Optional. Role assignment GUID name.')
    name: string?

    @description('Optional. Principal type. Allowed: Device, ForeignGroup, Group, ServicePrincipal, User.')
    principalType: 'Device' | 'ForeignGroup' | 'Group' | 'ServicePrincipal' | 'User'?
  }[]?

  @description('Optional. Saved KQL searches.')
  savedSearches: {
    @description('Required. Saved search category.')
    category: string

    @description('Required. Display name for the saved search.')
    displayName: string

    @description('Required. Name of the saved search.')
    name: string

    @description('Required. Query expression.')
    query: string

    @description('Optional. ETag for concurrency control.')
    etag: string?

    @description('Optional. Function alias if used as a function.')
    functionAlias: string?

    @description('Optional. Function parameters if query is used as a function.')
    functionParameters: string?

    @description('Optional. Tags for the saved search.')
    tags: array?

    @description('Optional. Version of the query language. Default is 2.')
    version: int?
  }[]?

  @description('Optional. Capacity reservation level in GB (100–5000 in increments of 100).')
  skuCapacityReservationLevel: int?

  @description('Optional. SKU name. Allowed: CapacityReservation, Free, LACluster, PerGB2018, PerNode, Premium, Standalone, Standard.')
  skuName:
    | 'CapacityReservation'
    | 'Free'
    | 'LACluster'
    | 'PerGB2018'
    | 'PerNode'
    | 'Premium'
    | 'Standalone'
    | 'Standard'?

  @description('Optional. Storage insights configs for linked storage accounts.')
  storageInsightsConfigs: {
    @description('Required. Storage account resource ID.')
    storageAccountResourceId: string

    @description('Optional. Blob container names to read.')
    containers: array?

    @description('Optional. Tables to read.')
    tables: array?
  }[]?

  @description('Optional. Custom LAW tables to be deployed.')
  tables: {
    @description('Required. Table name.')
    name: string

    @description('Optional. Table plan.')
    plan: string?

    @description('Optional. Restored logs configuration.')
    restoredLogs: {
      @description('Optional. Source table for restored logs.')
      sourceTable: string?

      @description('Optional. Start restore time (UTC).')
      startRestoreTime: string?

      @description('Optional. End restore time (UTC).')
      endRestoreTime: string?
    }?

    @description('Optional. Table retention in days.')
    retentionInDays: int?

    @description('Optional. Role assignments for the table.')
    roleAssignments: object[]?

    @description('Optional. Table schema.')
    schema: {
      @description('Required. Table name.')
      name: string

      @description('Required. List of table columns.')
      columns: {
        @description('Required. Column name.')
        name: string

        @description('Required. Column type. Allowed: boolean, dateTime, dynamic, guid, int, long, real, string.')
        type: 'boolean' | 'dateTime' | 'dynamic' | 'guid' | 'int' | 'long' | 'real' | 'string'

        @description('Optional. Logical data type hint. Allowed: armPath, guid, ip, uri.')
        dataTypeHint: 'armPath' | 'guid' | 'ip' | 'uri'?

        @description('Optional. Column description.')
        description: string?

        @description('Optional. Column display name.')
        displayName: string?
      }[]

      @description('Optional. Table description.')
      description: string?

      @description('Optional. Table display name.')
      displayName: string?
    }?

    @description('Optional. Search results for the table.')
    searchResults: {
      @description('Required. Query for the search job.')
      query: string

      @description('Optional. Description of the search job.')
      description: string?

      @description('Optional. Start time for the search (UTC).')
      startSearchTime: string?

      @description('Optional. End time for the search (UTC).')
      endSearchTime: string?

      @description('Optional. Row limit for the search job.')
      limit: int?
    }?

    @description('Optional. Total retention in days for the table.')
    totalRetentionInDays: int?
  }[]?

  @description('Optional. Tags for the workspace.')
  tags: {
    @description('Required. Arbitrary key for each tag.')
    *: string
  }?
}




