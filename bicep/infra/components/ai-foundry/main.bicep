/*
Standard Setup Network Secured Steps for main.bicep
-----------------------------------
*/
@description('Location for all resources.')
@allowed([
  'westus'
  'eastus'
  'eastus2'
  'japaneast'
  'francecentral'
  'spaincentral'
  'uaenorth'
  'southcentralus'
  'italynorth'
  'germanywestcentral'
  'brazilsouth'
  'southafricanorth'
  'australiaeast'
  'swedencentral'
  'canadaeast'
  'westeurope'
  'westus3'
  'uksouth'
  'southindia'

  //only class B and C
  'koreacentral'
  'polandcentral'
  'switzerlandnorth'
  'norwayeast'
])
param location string = 'eastus2'

@description('Name for your AI Services resource.')
param aiServices string = 'aiservices'

// Model deployment parameters (default values)
@description('The name of the model you want to deploy')
param modelName string = 'gpt-5-mini'
@description('The provider of your model')
param modelFormat string = 'OpenAI'
@description('The version of your model')
param modelVersion string = '2025-08-07'
@description('The sku of your model deployment')
param modelSkuName string = 'GlobalStandard'
@description('The tokens per minute (TPM) of your model deployment')
param modelCapacity int = 10

@description('Optional. List of model deployments to create. If provided and non-empty, it takes precedence over the single-model parameters.')
param modelDeployments array = []

// Deterministic suffix for resource names (update/no-op on rerun)
var uniqueSuffix = substring(uniqueString(resourceGroup().id, aiServices), 0, 4)

// Suffix for module/deployment names. Does not affect resource names.
var deploymentSuffix = substring(uniqueString(deployment().name), 0, 4)
var accountName = toLower('${aiServices}${uniqueSuffix}')

@description('Name for your project resource.')
param firstProjectName string = 'project'

@description('This project will be a sub-resource of your account')
param projectDescription string = 'A project for the AI Foundry account with network secured deployed Agent'

@description('The display name of the project')
param displayName string = 'network secured agent project'

// Existing Virtual Network parameters
@description('Virtual Network name for the Agent to create new or existing virtual network')
param vnetName string = 'agent-vnet-test'

@description('The name of Agents Subnet to create new or existing subnet for agents')
param agentSubnetName string = 'agent-subnet'

@description('The name of Private Endpoint subnet to create new or existing subnet for private endpoints')
param peSubnetName string = 'pe-subnet'

//Existing standard Agent required resources
@description('Existing Virtual Network name Resource ID')
param existingVnetResourceId string = ''

@description('Address space for the VNet (only used for new VNet)')
param vnetAddressPrefix string = ''

@description('Address prefix for the agent subnet. The default value is 192.168.0.0/24 but you can choose any size /26 or any class like 10.0.0.0 or 172.168.0.0')
param agentSubnetPrefix string = ''

@description('Address prefix for the private endpoint subnet')
param peSubnetPrefix string = ''

@description('The AI Search Service full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param aiSearchResourceId string = ''
@description('The AI Storage Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param azureStorageAccountResourceId string = ''
@description('The Cosmos DB Account full ARM Resource ID. This is an optional field, and if not provided, the resource will be created.')
param azureCosmosDBAccountResourceId string = ''

@description('The Key Vault full ARM Resource ID. This is an optional field, and if not provided, the resource will be created (when includeAssociatedResources=true).')
param keyVaultResourceId string = ''

@description('Optional. When false, the module will not deploy or update the VNet/subnets. Use this when the VNet/subnets are managed by a landing zone template.')
param deployVnetAndSubnets bool = true

//New Param for resource group of Private DNS zones
//@description('Optional: Resource group containing existing private DNS zones. If specified, DNS zones will not be created.')
//param existingDnsZonesResourceGroup string = ''

@description('Object mapping DNS zone names to their resource group, or empty string to indicate creation')
param existingDnsZones object = {
  'privatelink.services.ai.azure.com': ''
  'privatelink.openai.azure.com': ''
  'privatelink.cognitiveservices.azure.com': ''               
  'privatelink.search.windows.net': ''           
  'privatelink.blob.${environment().suffixes.storage}': ''                            
  'privatelink.documents.azure.com': ''                       
  'privatelink.vaultcore.azure.net': ''
}

@description('Zone Names for Validation of existing Private Dns Zones')
param dnsZoneNames array = [
  'privatelink.services.ai.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.search.windows.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.documents.azure.com'
  'privatelink.vaultcore.azure.net'
]


var projectName = toLower('${firstProjectName}${uniqueSuffix}')
// --------------------
// Dependency resource naming (landing zone style)
// --------------------
// Derive from the effective AI account name so the dependency names are clearly associated:
// - Cosmos DB:  cosmos-<aiAccountName>
// - Search:     search-<aiAccountName>
// - Storage:    st<aiAccountName>
// Notes:
// - Cosmos/Search can contain hyphens, but must not contain underscores.
// - Storage must be 3-24 chars, lowercase alphanumeric only (no '-' or '_'), and must be globally unique.

var aiServicesForDeps = toLower(replace(aiServices, '_', ''))

// Cosmos DB account name (max 44). Ensure the unique suffix remains present even if truncated.
var cosmosBodyMax = 38 // 44 - len('cosmos-')
var cosmosBodyPrefix = take(aiServicesForDeps, cosmosBodyMax - length(uniqueSuffix))
var cosmosDBName = 'cosmos-${cosmosBodyPrefix}${uniqueSuffix}'

// Search service name (max 60). Ensure the unique suffix remains present even if truncated.
var searchBodyMax = 53 // 60 - len('search-')
var searchBodyPrefix = take(aiServicesForDeps, searchBodyMax - length(uniqueSuffix))
var aiSearchName = 'search-${searchBodyPrefix}${uniqueSuffix}'

// Storage account name constraints: 3-24 chars, numbers and lowercase letters only.
var aiServicesForStorage = toLower(replace(replace(aiServices, '-', ''), '_', ''))
var storageBodyMax = 22 // 24 - len('st')
var storageBodyPrefix = take(aiServicesForStorage, storageBodyMax - length(uniqueSuffix))
var azureStorageName = 'st${storageBodyPrefix}${uniqueSuffix}'

// Check if existing resources have been passed in
var storagePassedIn = azureStorageAccountResourceId != ''
var searchPassedIn = aiSearchResourceId != ''
var cosmosPassedIn = azureCosmosDBAccountResourceId != ''
var keyVaultPassedIn = keyVaultResourceId != ''
var existingVnetPassedIn = existingVnetResourceId != ''

// When no VNet is available (neither created nor provided), the component must run in "public mode":
// - No network injection (agent subnet not required)
// - No private endpoints / private DNS
// - Public network access enabled for created dependencies
var varHasVnet = deployVnetAndSubnets || existingVnetPassedIn
var effectiveDeployPrivateEndpointsAndDns = deployPrivateEndpointsAndDns && varHasVnet
var effectiveConfigurePrivateDns = configurePrivateDns && varHasVnet

var effectiveAiSearchPublicNetworkAccess = varHasVnet ? aiSearchPublicNetworkAccess : 'Enabled'
var effectiveCosmosDbPublicNetworkAccess = varHasVnet ? cosmosDbPublicNetworkAccess : 'Enabled'
var effectiveStorageAccountPublicNetworkAccess = varHasVnet ? storageAccountPublicNetworkAccess : 'Enabled'
var effectiveKeyVaultPublicNetworkAccess = varHasVnet ? keyVaultPublicNetworkAccess : 'Enabled'


var acsParts = split(aiSearchResourceId, '/')
var aiSearchServiceSubscriptionId = searchPassedIn ? acsParts[2] : subscription().subscriptionId
var aiSearchServiceResourceGroupName = searchPassedIn ? acsParts[4] : resourceGroup().name

var cosmosParts = split(azureCosmosDBAccountResourceId, '/')
var cosmosDBSubscriptionId = cosmosPassedIn ? cosmosParts[2] : subscription().subscriptionId
var cosmosDBResourceGroupName = cosmosPassedIn ? cosmosParts[4] : resourceGroup().name

var storageParts = split(azureStorageAccountResourceId, '/')
var azureStorageSubscriptionId = storagePassedIn ? storageParts[2] : subscription().subscriptionId
var azureStorageResourceGroupName = storagePassedIn ? storageParts[4] : resourceGroup().name

var vnetParts = split(existingVnetResourceId, '/')
var vnetSubscriptionId = existingVnetPassedIn ? vnetParts[2] : subscription().subscriptionId
var vnetResourceGroupName = existingVnetPassedIn ? vnetParts[4] : resourceGroup().name
var existingVnetName = existingVnetPassedIn ? last(vnetParts) : vnetName
var trimVnetName = trim(existingVnetName)

@description('The name of the project capability host to be created')
param projectCapHost string = 'caphostproj'

@description('Optional. Account capability host name to create (standard/public mode). When empty, the module assumes the service auto-created accountName@aml_aiagentservice.')
param accountCapHost string = ''

@description('If false, skips creation of private endpoints and private DNS configuration (useful for Platform Landing Zone scenarios).')
param deployPrivateEndpointsAndDns bool = true

@description('When false, the component will still create Private Endpoints but will skip Private DNS Zones, DNS VNet links, and Private DNS Zone Groups. Use this for Platform Landing Zone (Model B) scenarios where the workload deployer has no permissions on platform-owned DNS resources.')
param configurePrivateDns bool = true

@description('Optional. When false, the module will NOT deploy associated resources (AI Search, Storage, Cosmos) or their private endpoints/DNS.')
param includeAssociatedResources bool = false

@description('Optional. AI Search public network access. Default: Disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param aiSearchPublicNetworkAccess string = 'Disabled'

@description('Optional. AI Search network rules (used when aiSearchPublicNetworkAccess=Enabled). Example: { bypass: "None", ipRules: [ { value: "1.2.3.4" } ] }.')
param aiSearchNetworkRuleSet object = {}

@description('Optional. Cosmos DB public network access. Default: Disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param cosmosDbPublicNetworkAccess string = 'Disabled'

@description('Optional. Cosmos DB IP allowlist (used when cosmosDbPublicNetworkAccess=Enabled). Example: ["1.2.3.4","5.6.7.0/24"]. Note: RFC1918 ranges (10/8, 172.16/12, 192.168/16, 100.64/10) are not enforceable by Cosmos IP firewall rules; use Private Endpoints and/or VNet rules instead.')
param cosmosDbIpRules string[] = []

@description('Optional. Storage Account public network access. Default: Disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param storageAccountPublicNetworkAccess string = 'Disabled'

@description('Optional. Storage Account network ACLs (used when storageAccountPublicNetworkAccess=Enabled). Example: { bypass: "AzureServices", defaultAction: "Deny", ipRules: [ { value: "1.2.3.4" } ] }.')
param storageAccountNetworkAcls object = {}

@description('Optional. Key Vault public network access. Default: Disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param keyVaultPublicNetworkAccess string = 'Disabled'

@description('Optional. Key Vault network ACLs (used when keyVaultPublicNetworkAccess=Enabled). Example: { bypass: "AzureServices", defaultAction: "Deny", ipRules: [ { value: "1.2.3.4" } ] }.')
param keyVaultNetworkAcls object = {}

@description('Optional. When false, the module will NOT create Capability Hosts (Foundry Agent Service) or perform its dependent role assignments.')
param createCapabilityHosts bool = false

@description('Optional. When false, skips the best-effort deployment script delay used before creating the project capability host (useful when deploymentScripts are blocked by policy).')
param enableCapabilityHostDelayScript bool = true

@description('Optional. How long to wait (in seconds) before creating the project capability host, to give the service time to finish provisioning the account-level capability host. Default: 600 (10 minutes).')
param capabilityHostWaitSeconds int = 600

var effectiveCreateCapabilityHosts = createCapabilityHosts && includeAssociatedResources
var aiSearchPublicNetworkAccessLower = effectiveAiSearchPublicNetworkAccess == 'Enabled' ? 'enabled' : 'disabled'

// In public/no-vnet mode, the service may not auto-provision the account-level capability host.
// Default to creating one explicitly, unless the caller provided a specific name.
var effectiveAccountCapHost = (!varHasVnet && empty(accountCapHost)) ? 'caphostacc' : accountCapHost

// Create Virtual Network and Subnets
module vnet 'modules-network-secured/network-agent-vnet.bicep' = if (deployVnetAndSubnets) {
  name: 'vnet-${trimVnetName}-${deploymentSuffix}-deployment'
  params: {
    location: location
    vnetName: trimVnetName
    useExistingVnet: existingVnetPassedIn
    existingVnetResourceGroupName: vnetResourceGroupName
    agentSubnetName: agentSubnetName
    peSubnetName: peSubnetName
    vnetAddressPrefix: vnetAddressPrefix
    agentSubnetPrefix: agentSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
    existingVnetSubscriptionId: vnetSubscriptionId
  }
}

var resolvedVnetName = (deployVnetAndSubnets ? vnet.?outputs.virtualNetworkName : trimVnetName) ?? trimVnetName
var resolvedVnetResourceGroupName = (deployVnetAndSubnets ? vnet.?outputs.virtualNetworkResourceGroup : vnetResourceGroupName) ?? vnetResourceGroupName
var resolvedVnetSubscriptionId = (deployVnetAndSubnets ? vnet.?outputs.virtualNetworkSubscriptionId : vnetSubscriptionId) ?? vnetSubscriptionId

var resolvedAgentSubnetId = (deployVnetAndSubnets ? vnet.?outputs.agentSubnetId : null) ?? (!empty(existingVnetResourceId) ? '${existingVnetResourceId}/subnets/${agentSubnetName}' : '')

var resolvedPeSubnetName = (deployVnetAndSubnets ? vnet.?outputs.peSubnetName : peSubnetName) ?? peSubnetName

/*
  Create the AI Services account and gpt-4o model deployment
*/
module aiAccount 'modules-network-secured/ai-account-identity.bicep' = {
  name: '${accountName}-${deploymentSuffix}-deployment'
  params: {
    // workspace organization
    accountName: accountName
    location: location
    modelName: modelName
    modelFormat: modelFormat
    modelVersion: modelVersion
    modelSkuName: modelSkuName
    modelCapacity: modelCapacity
    modelDeployments: modelDeployments
    agentSubnetId: varHasVnet ? resolvedAgentSubnetId : ''
    networkInjection: varHasVnet ? 'true' : 'false'
  }
}

module validateExistingResources 'modules-network-secured/validate-existing-resources.bicep' = if (includeAssociatedResources) {
  name: 'validate-existing-resources-${deploymentSuffix}-deployment'
  params: {
    aiSearchResourceId: aiSearchResourceId
    azureStorageAccountResourceId: azureStorageAccountResourceId
    azureCosmosDBAccountResourceId: azureCosmosDBAccountResourceId
    keyVaultResourceId: keyVaultResourceId
    existingDnsZones: existingDnsZones
    dnsZoneNames: dnsZoneNames
  }
}

// Key Vault name constraints: 3-24 chars, alphanumerics and hyphens.
// Requirement: name derived from the effective AI account name -> kv-<aiAccountName> (truncated if needed).
var kvNameBase = toLower('kv-${accountName}')
var kvNameTruncated = take(kvNameBase, 24)
var keyVaultName = endsWith(kvNameTruncated, '-') ? '${take(kvNameTruncated, 23)}0' : kvNameTruncated

var keyVaultParts = split(keyVaultResourceId, '/')
var resolvedKeyVaultSubscriptionId = keyVaultPassedIn ? keyVaultParts[2] : subscription().subscriptionId
var resolvedKeyVaultResourceGroupName = keyVaultPassedIn ? keyVaultParts[4] : resourceGroup().name
var resolvedKeyVaultName = keyVaultPassedIn ? last(keyVaultParts) : keyVaultName

module keyVault '../../wrappers/avm.res.key-vault.vault.bicep' = if (includeAssociatedResources && !keyVaultPassedIn) {
  name: 'ai-foundry-kv-${deploymentSuffix}'
  params: {
    keyVault: {
      name: keyVaultName
      location: location
      enableRbacAuthorization: true
      publicNetworkAccess: effectiveKeyVaultPublicNetworkAccess
      networkAcls: empty(keyVaultNetworkAcls) ? null : keyVaultNetworkAcls
    }
  }
}

// This module will create new agent dependent resources
// A Cosmos DB account, an AI Search Service, and a Storage Account are created if they do not already exist
module aiDependencies 'modules-network-secured/standard-dependent-resources.bicep' = if (includeAssociatedResources) {
  name: 'dependencies-${deploymentSuffix}-deployment'
  params: {
    location: location
    azureStorageName: azureStorageName
    aiSearchName: aiSearchName
    cosmosDBName: cosmosDBName

    // Network ACLs / Public Access
    aiSearchPublicNetworkAccess: aiSearchPublicNetworkAccessLower
    aiSearchNetworkRuleSet: aiSearchNetworkRuleSet
    cosmosDbPublicNetworkAccess: effectiveCosmosDbPublicNetworkAccess
    cosmosDbIpRules: cosmosDbIpRules
    storageAccountPublicNetworkAccess: effectiveStorageAccountPublicNetworkAccess
    storageAccountNetworkAcls: storageAccountNetworkAcls

    // AI Search Service parameters
    aiSearchResourceId: aiSearchResourceId
    aiSearchExists: validateExistingResources!.outputs.aiSearchExists

    // Storage Account
    azureStorageAccountResourceId: azureStorageAccountResourceId
    azureStorageExists: validateExistingResources!.outputs.azureStorageExists

    // Cosmos DB Account
    cosmosDBResourceId: azureCosmosDBAccountResourceId
    cosmosDBExists: validateExistingResources!.outputs.cosmosDBExists
    }
}

resource keyVaultExisting 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (includeAssociatedResources) {
  name: resolvedKeyVaultName
  scope: resourceGroup(resolvedKeyVaultSubscriptionId, resolvedKeyVaultResourceGroupName)
}

// Private Endpoint and DNS Configuration
// This module sets up private network access for all Azure services:
// 1. Creates private endpoints in the specified subnet
// 2. Sets up private DNS zones for each service
// 3. Links private DNS zones to the VNet for name resolution
// 4. Configures network policies to restrict access to private endpoints only
module privateEndpointAndDNS 'modules-network-secured/private-endpoint-and-dns.bicep' = if (effectiveDeployPrivateEndpointsAndDns) {
  name: '${deploymentSuffix}-private-endpoint'
  params: {
    aiAccountName: aiAccount.outputs.accountName // AI Services to secure
    aiSearchName: includeAssociatedResources ? aiDependencies!.outputs.aiSearchName : '' // AI Search to secure
    storageName: includeAssociatedResources ? aiDependencies!.outputs.azureStorageName : '' // Storage to secure
    cosmosDBName: includeAssociatedResources ? aiDependencies!.outputs.cosmosDBName : ''
    keyVaultName: includeAssociatedResources ? keyVaultExisting.name : ''
    vnetName: resolvedVnetName // VNet containing subnets
    peSubnetName: resolvedPeSubnetName // Subnet for private endpoints
    vnetResourceGroupName: resolvedVnetResourceGroupName
    vnetSubscriptionId: resolvedVnetSubscriptionId
    cosmosDBSubscriptionId: cosmosDBSubscriptionId
    cosmosDBResourceGroupName: cosmosDBResourceGroupName
    aiSearchSubscriptionId: aiSearchServiceSubscriptionId
    aiSearchResourceGroupName: aiSearchServiceResourceGroupName
    storageAccountResourceGroupName: azureStorageResourceGroupName
    storageAccountSubscriptionId: azureStorageSubscriptionId
    keyVaultSubscriptionId: includeAssociatedResources
      ? resolvedKeyVaultSubscriptionId
      : subscription().subscriptionId
    keyVaultResourceGroupName: includeAssociatedResources
      ? resolvedKeyVaultResourceGroupName
      : resourceGroup().name
    existingDnsZones: existingDnsZones
    configurePrivateDns: effectiveConfigurePrivateDns
  }
  dependsOn: [
    #disable-next-line BCP321
    includeAssociatedResources ? aiDependencies : null
    #disable-next-line BCP321
    (includeAssociatedResources && !keyVaultPassedIn) ? keyVault : null
  ]
}

/*
  Creates a new project (sub-resource of the AI Services account)
*/
module aiProjectWithConnections 'modules-network-secured/ai-project-identity.bicep' = if (includeAssociatedResources) {
  name: '${projectName}-${deploymentSuffix}-deployment'
  params: {
    // workspace organization
    projectName: projectName
    projectDescription: projectDescription
    displayName: displayName
    location: location

    aiSearchName: aiDependencies!.outputs.aiSearchName
    aiSearchServiceResourceGroupName: aiDependencies!.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: aiDependencies!.outputs.aiSearchServiceSubscriptionId

    cosmosDBName: aiDependencies!.outputs.cosmosDBName
    cosmosDBSubscriptionId: aiDependencies!.outputs.cosmosDBSubscriptionId
    cosmosDBResourceGroupName: aiDependencies!.outputs.cosmosDBResourceGroupName

    azureStorageName: aiDependencies!.outputs.azureStorageName
    azureStorageSubscriptionId: aiDependencies!.outputs.azureStorageSubscriptionId
    azureStorageResourceGroupName: aiDependencies!.outputs.azureStorageResourceGroupName
    // dependent resources
    accountName: aiAccount.outputs.accountName
  }
  dependsOn: [
      #disable-next-line BCP321
      (includeAssociatedResources && !keyVaultPassedIn) ? keyVault : null
      #disable-next-line BCP321
      effectiveDeployPrivateEndpointsAndDns ? privateEndpointAndDNS : null
  ]
}

module aiProjectMinimal 'modules-network-secured/ai-project-minimal.bicep' = if (!includeAssociatedResources) {
  name: '${projectName}-${deploymentSuffix}-deployment'
  params: {
    projectName: projectName
    projectDescription: projectDescription
    displayName: displayName
    location: location
    accountName: aiAccount.outputs.accountName
  }
}

var varAiProjectWorkspaceId = includeAssociatedResources
  ? aiProjectWithConnections!.outputs.projectWorkspaceId
  : aiProjectMinimal!.outputs.projectWorkspaceId

module formatProjectWorkspaceId 'modules-network-secured/format-project-workspace-id.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'format-project-workspace-id-${deploymentSuffix}-deployment'
  params: {
    projectWorkspaceId: varAiProjectWorkspaceId
  }
}

/*
  Assigns the project SMI the storage blob data contributor role on the storage account
*/
module storageAccountRoleAssignment 'modules-network-secured/azure-storage-account-role-assignment.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'storage-${azureStorageName}-${deploymentSuffix}-deployment'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    azureStorageName: aiDependencies!.outputs.azureStorageName
    projectPrincipalId: aiProjectWithConnections!.outputs.projectPrincipalId
  }
  dependsOn: [
   #disable-next-line BCP321
   effectiveDeployPrivateEndpointsAndDns ? privateEndpointAndDNS : null
  ]
}

// The Comos DB Operator role must be assigned before the caphost is created
module cosmosAccountRoleAssignments 'modules-network-secured/cosmosdb-account-role-assignment.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'cosmos-account-ra-${deploymentSuffix}-deployment'
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
  params: {
    cosmosDBName: aiDependencies!.outputs.cosmosDBName
    projectPrincipalId: aiProjectWithConnections!.outputs.projectPrincipalId
  }
  dependsOn: [
    #disable-next-line BCP321
    effectiveDeployPrivateEndpointsAndDns ? privateEndpointAndDNS : null
  ]
}

// This role can be assigned before or after the caphost is created
module aiSearchRoleAssignments 'modules-network-secured/ai-search-role-assignments.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'ai-search-ra-${deploymentSuffix}-deployment'
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
  params: {
    aiSearchName: aiDependencies!.outputs.aiSearchName
    projectPrincipalId: aiProjectWithConnections!.outputs.projectPrincipalId
  }
  dependsOn: [
    #disable-next-line BCP321
    effectiveDeployPrivateEndpointsAndDns ? privateEndpointAndDNS : null
  ]
}

// This module creates the capability host for the project and account
module addProjectCapabilityHost 'modules-network-secured/add-project-capability-host.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'capabilityHost-configuration-${deploymentSuffix}-deployment'
  params: {
    accountName: aiAccount.outputs.accountName
    projectName: aiProjectWithConnections!.outputs.projectName
    cosmosDBConnection: aiProjectWithConnections!.outputs.cosmosDBConnection
    azureStorageConnection: aiProjectWithConnections!.outputs.azureStorageConnection
    aiSearchConnection: aiProjectWithConnections!.outputs.aiSearchConnection
    projectCapHost: projectCapHost
    accountCapHost: effectiveAccountCapHost
    enableCapabilityHostDelayScript: enableCapabilityHostDelayScript
    capabilityHostWaitSeconds: capabilityHostWaitSeconds
  }
  dependsOn: [
      #disable-next-line BCP321
      effectiveDeployPrivateEndpointsAndDns ? privateEndpointAndDNS : null
     cosmosAccountRoleAssignments
     storageAccountRoleAssignment
     aiSearchRoleAssignments
  ]
}

// The Storage Blob Data Owner role must be assigned after the caphost is created
module storageContainersRoleAssignment 'modules-network-secured/blob-storage-container-role-assignments.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'storage-containers-ra-${deploymentSuffix}-deployment'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    aiProjectPrincipalId: aiProjectWithConnections!.outputs.projectPrincipalId
    storageName: aiDependencies!.outputs.azureStorageName
    workspaceId: formatProjectWorkspaceId!.outputs.projectWorkspaceIdGuid
  }
  dependsOn: [
    addProjectCapabilityHost
  ]
}

// The Cosmos Built-In Data Contributor role must be assigned after the caphost is created
module cosmosContainerRoleAssignments 'modules-network-secured/cosmos-container-role-assignments.bicep' = if (effectiveCreateCapabilityHosts) {
  name: 'cosmos-containers-ra-${deploymentSuffix}-deployment'
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
  params: {
    cosmosAccountName: aiDependencies!.outputs.cosmosDBName
    projectWorkspaceId: formatProjectWorkspaceId!.outputs.projectWorkspaceIdGuid
    projectPrincipalId: aiProjectWithConnections!.outputs.projectPrincipalId

  }
dependsOn: [
  addProjectCapabilityHost
  storageContainersRoleAssignment
  ]
}

@description('AI Foundry resource group name.')
output resourceGroupName string = resourceGroup().name

@description('AI Services account name.')
output aiServicesName string = aiAccount.outputs.accountName

@description('Map of model deployment name to deployment resource ID.')
output modelDeploymentsResourceIdsByName object = aiAccount.outputs.modelDeploymentResourceIdsByName

@description('AI Foundry project name.')
output aiProjectName string = includeAssociatedResources
  ? aiProjectWithConnections!.outputs.projectName
  : aiProjectMinimal!.outputs.projectName

@description('AI Search name used by the project.')
output aiSearchName string = includeAssociatedResources ? aiDependencies!.outputs.aiSearchName : ''

@description('Cosmos DB account name used by the project.')
output cosmosAccountName string = includeAssociatedResources ? aiDependencies!.outputs.cosmosDBName : ''

@description('Storage account name used by the project.')
output storageAccountName string = includeAssociatedResources ? aiDependencies!.outputs.azureStorageName : ''

@description('Key Vault name used by the project.')
output keyVaultName string = includeAssociatedResources ? keyVaultExisting.name : ''
