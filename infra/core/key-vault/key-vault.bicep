param kvName string
param location string
param tenantId string
param skuName string
param publicNetworkAccess string

resource kv_resource 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: toLower(publicNetworkAccess) != 'enabled' ? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    } : null
  }

}

output keyVaultUri string = kv_resource.properties.vaultUri
output kvName string = kv_resource.name

