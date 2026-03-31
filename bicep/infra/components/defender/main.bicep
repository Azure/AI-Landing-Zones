targetScope = 'subscription'

@description('Optional. Enable Microsoft Defender for AI.')
param enableDefenderForAI bool = true

@description('Optional. Enable Defender for Key Vault.')
param enableDefenderForKeyVault bool = true

// Deploy Microsoft Defender for AI at subscription level
resource defenderForAI 'Microsoft.Security/pricings@2024-01-01' = if (enableDefenderForAI) {
  name: 'AI'
  properties: {
    pricingTier: 'Standard'
  }
}

// Enable Defender for Storage (recommended for AI workloads)
resource defenderForStorage 'Microsoft.Security/pricings@2024-01-01' = if (enableDefenderForAI) {
  name: 'StorageAccounts'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'DefenderForStorageV2'
    extensions: [
      {
        name: 'OnUploadMalwareScanning'
        isEnabled: 'True'
        additionalExtensionProperties: {
          CapGBPerMonthPerStorageAccount: '5000'
        }
      }
      {
        name: 'SensitiveDataDiscovery'
        isEnabled: 'True'
      }
    ]
  }
}

// Enable Defender for Key Vault
resource defenderForKeyVault 'Microsoft.Security/pricings@2024-01-01' = if (enableDefenderForAI && enableDefenderForKeyVault) {
  name: 'KeyVaults'
  properties: {
    pricingTier: 'Standard'
  }
}

@description('Defender for AI enabled.')
output defenderForAIEnabled bool = enableDefenderForAI

@description('Defender for Storage enabled.')
output defenderForStorageEnabled bool = enableDefenderForAI

@description('Defender for Key Vault enabled.')
output defenderForKeyVaultEnabled bool = enableDefenderForAI && enableDefenderForKeyVault
