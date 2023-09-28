param botServicesName string
param tenantId string
param appType string
@secure()
param developerAppInsightKey string
param developerAppInsightsApplicationId string = ''
param developerAppInsightsApiKey string = ''
param endpoint string
param iconUrl string = ''
param displayName string
param clientId string
// @secure()
// param clientSecret string
// param tokenExchangeUrl string
param keyVaultName string

resource botServices_mvpbot_resource 'Microsoft.BotService/botServices@2022-09-15' = {
  name: botServicesName
  location: 'global'
  sku: {
    name: 'S1'
  }
  kind: 'azurebot'
  properties: {
    displayName: displayName //
    iconUrl: iconUrl
    endpoint: endpoint //
    msaAppId: clientId //
    msaAppType: appType
    developerAppInsightKey: developerAppInsightKey
    developerAppInsightsApplicationId: developerAppInsightsApplicationId
    developerAppInsightsApiKey: developerAppInsightsApiKey
    schemaTransformationVersion: '1.3'
    tenantId: tenantId
    msaAppTenantId: toLower(appType) == 'multitenant' ? '' : tenantId
    isCmekEnabled: false
    disableLocalAuth: false // true ?
  }
}

resource botServices_mvpbot_name_MsTeamsChannel 'Microsoft.BotService/botServices/channels@2022-09-15' = {
  parent: botServices_mvpbot_resource
  name: 'MsTeamsChannel'
  location: 'global'
  properties: {
    properties: {
      enableCalling: false
      incomingCallRoute: 'graphPma'
      isEnabled: true
      deploymentEnvironment: 'CommercialDeployment'
      acceptedTerms: true
    }
    channelName: 'MsTeamsChannel'
    location: 'global'
  }
}


// resource OAuthBotSettings 'Microsoft.BotService/botServices/connections@2022-09-15' = {
//   parent: botServices_mvpbot_resource
//   name: 'OAuthBotSettings'
//   location: 'global'
//   sku: {
//     name: 'S1'
//   }
//   kind: 'azurebot'
//   properties: {
//     clientId: clientId
//     clientSecret: clientSecret
//     scopes: 'openid profile User.Read User.ReadBasic.All'
//     parameters: [
//       {
//         key: 'clientId'
//         value: clientId
//       }
//       {
//         key: 'clientSecret'
//         value: clientSecret
//       }
//       {
//         key: 'tokenExchangeUrl'
//         value: tokenExchangeUrl
//       }
//       {
//         key: 'tenantId'
//         value: toLower(appType) == 'multitenant' ? 'common' : tenantId
//       }
//       {
//         key: 'scopes'
//         value: 'openid profile User.Read User.ReadBasic.All'
//       }
//     ]
//     serviceProviderId: '30dd229c-58e3-4a48-bdfd-91ec48eb906c'
//   }
// }

module directChannelSecret '../key-vault/keyvault-secret.bicep' = {
  name: 'kv-secret-direct-channel-deployment'
  params: {
    kvName: keyVaultName
    secretName: 'directChannelKey'
    secretValue: listChannelWithKeys('${botServices_mvpbot_resource.id}/channels/DirectLineChannel', '2018-07-12').properties.properties.sites[0].key
  }
}
