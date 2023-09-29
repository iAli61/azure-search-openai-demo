param botWebappName string
param botDisplayName string
param companyName string
param appServicePlanId string
param appType string
param tenantId string
param location string
param applicationInsightsConnectionString string
param applicationInsightsKey string
param directLineSecretName string
param openAiDeployment string
param microsoftAppPasswordSecretName string
param microsoftAppId string
param keyVaultName string

resource webapp 'Microsoft.Web/sites@2022-09-01' = {
  name: botWebappName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    reserved: true
    vnetRouteAllEnabled: true
    publicNetworkAccess: 'Enabled' // Disabled if using a private runner to deploy
    clientAffinityEnabled: false
    keyVaultReferenceIdentity: 'SystemAssigned'
    siteConfig: {
      numberOfWorkers: 1
      ipSecurityRestrictionsDefaultAction: 'Allow'
      linuxFxVersion: 'NODE:18-lts'
      webSocketsEnabled: true
      alwaysOn: true
      http20Enabled: true
      healthCheckPath: '/healthz'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'DirectLineSecret'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${directLineSecretName})'
        }
        {
          name: '_BotName'
          value: botDisplayName
        }
        {
          name: '_CompanyName'
          value: companyName
        }
        {
          name: '_DeploymentName'
          value: openAiDeployment
        }
        {
          name: 'MicrosoftAppType'
          value: appType
        }
        {
          name: 'MicrosoftAppTenantId'
          value: toLower(appType) == 'multitenant' ? 'common' : tenantId
        }
        {
          name: 'MicrosoftAppId'
          value: microsoftAppId
        }
        {
          name: 'MicrosoftAppPassword'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${microsoftAppPasswordSecretName})'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
      ]
    }
  }
}

output botAppServiceHost string = webapp.properties.defaultHostName
output managedIdentityPrincipalId string = webapp.identity.principalId
output botMessagesEndpoint string = 'https://${webapp.properties.defaultHostName}/api/messages'

// cors: {
//   allowedOrigins: [
//     'https://botservice.hosting.portal.azure.net/'
//     'https://hosting.onecloud.azure-test.net/'
//   ]
// }
