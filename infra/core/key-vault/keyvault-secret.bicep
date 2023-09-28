targetScope = 'resourceGroup'

param kvName string
param contentType string = 'text/plain'

param secretName string
@secure()
param secretValue string

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kvName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: secretName
  parent: kv
  properties: {
    value: secretValue
    contentType: contentType
  }
}

output kvReferenceLatest string = '@Microsoft.KeyVault(VaultName=${kvName};SecretName=${secretName})'
