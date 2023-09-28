param webApiWebAppName string
param location string
param appServicePlanId string
param webApiClientId string
param webApiTenantId string
param openAIBaseUrl string
param apimAdminProductSecretName string
param publicNetworkAccess string
param vaultName string
@secure()
param cosmosDbConnectionStringSecretReference string
param cosmosDbConnectionStringSecretName string
param vnetIntegrationSubnetId string
@secure()
param appInsightsConnectionString string
param clientHostName string
param openAiDeploymentModelName string

resource chat_web_api 'Microsoft.Web/sites@2022-09-01' = {
  name: webApiWebAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    keyVaultReferenceIdentity: 'SystemAssigned'
    serverFarmId: appServicePlanId
    vnetRouteAllEnabled: true
    publicNetworkAccess: publicNetworkAccess
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    clientAffinityEnabled: false
    clientCertEnabled: false
    enabled: true
    httpsOnly: true
    reserved: false
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'
      alwaysOn: true
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/healthz'
      ftpsState: 'Disabled'
      scmMinTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AzureAd__ClientId'
          value: webApiClientId
        }
        {
          name: 'AzureAd__TenantId'
          value: webApiTenantId
        }
        {
          name: 'CosmosDb__ConnectionString'
          value: cosmosDbConnectionStringSecretReference
        }
        {
          name: 'FrontendOrigin'
          value: 'https://${clientHostName}'
        }
        {
          name: 'OpenAi__BaseUrl'
          value: openAIBaseUrl
        }
        {
          name: 'OpenAI__AdminApiKey'
          value: '@Microsoft.KeyVault(VaultName=${vaultName};SecretName=${apimAdminProductSecretName})'
        }
        {
          name: 'OpenAi__DeploymentName'
          value: openAiDeploymentModelName
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

var vaultSecretUserRoleName = 'Key Vault Secrets User'

module chat_web_api_is_cosmosdb_connection_string_kv_secret_user '../role-assignment/role-assignment-kv-secret.bicep' = {
  name: 'chat-web-api-cosmos-cstring-kv-secret-user-role-assignment'

  params: {
    keyVaultName: vaultName
    secretName: cosmosDbConnectionStringSecretName
    principalIds: [ chat_web_api.identity.principalId ]
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: vaultSecretUserRoleName
  }
}

module chat_web_api_is_apim_admin_product_secret_user '../role-assignment/role-assignment-kv-secret.bicep' = {
  name: 'chat-web-api-apim-admin-product-secret-user-role-assignment'

  params: {
    keyVaultName: vaultName
    secretName: apimAdminProductSecretName
    principalIds: [ chat_web_api.identity.principalId ]
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: vaultSecretUserRoleName
  }
}
