param kvName string
param functionName string

resource functionResource 'Microsoft.Web/sites@2022-09-01' existing = {
  name: functionName
}

module keyvaultSecretFunction '../key-vault/keyvault-secret.bicep' = {
  name: 'kv-secret-function-deployment'
  params: {
    kvName: kvName
    secretName: 'functionApiKey'
    secretValue: listkeys('${functionResource.id}/host/default/', '2021-02-01').functionKeys.default
  }
}
