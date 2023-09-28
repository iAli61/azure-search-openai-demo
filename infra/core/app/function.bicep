param functionName string
param location string
param storageAccountName string
@secure()
param appInsightsKey string
param appInsightsConnectionString string
param apiManagementServiceName string
param kvName string
param cosmosConnectionStringSecretName string
param resourceGroupName string
param subscriptionId string
param tenantId string
param kind string
param appServicePlanId string
param appSubnetResourceId string
param logAnalyticsWorkspaceId string

resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2021-01-01' existing = {
  name: storageAccountName
  scope: resourceGroup()
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${functionStorageAccount.listKeys().keys[0].value}'

resource func_resource 'Microsoft.Web/sites@2022-09-01' = {
  name: functionName
  location: location
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    publicNetworkAccess: 'Enabled' // Disabled if using a private runner to deploy
    vnetRouteAllEnabled: true
    virtualNetworkSubnetId: appSubnetResourceId // to communicate with private cosmos
    clientAffinityEnabled: false
    siteConfig: {
      numberOfWorkers: 1
      ipSecurityRestrictionsDefaultAction: 'Allow'
      linuxFxVersion: 'DOTNET|6.0'
      alwaysOn: true
      http20Enabled: true
      healthCheckPath: '/healthz'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'ApiManagementServiceName'
          value: apiManagementServiceName
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'CosmosConnectionString'
          value: '@Microsoft.KeyVault(VaultName=${kvName};SecretName=${cosmosConnectionStringSecretName})'
        }
        {
          name: 'BlobConnectionString'
          value: '@Microsoft.KeyVault(VaultName=${kvName};SecretName=blobConnectionString)'
        }
        {
          name: 'DatabaseName'
          value: 'backend'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'QuotaContainerName'
          value: 'quotas'
        }
        {
          name: 'ResourceGroupName' // APIM RG
          value: resourceGroupName
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'AzureWebJobsDashboard'
          value: storageConnectionString
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
        {
          name: 'StorageProvider'
          value: 'cosmos'
        }
        {
          name: 'SubscriptionId'
          value: subscriptionId
        }
        {
          name: 'TenantId'
          value: tenantId
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${functionName}${uniqueString(resourceGroup().id)}'
        }
        {
          name: 'Reporting__Reports__avg_token_usage__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__avg_token_usage_latest__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__sum_token_usage_per_user__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__sum_token_usage_per_user_latest__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__avg_reponse_time_per_token_bucket__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__avg_reponse_time_per_token_bucket_latest__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__count_errorcode__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
        {
          name: 'Reporting__Reports__count_errorcode_latest__Arguments__WorkspaceId'
          value: logAnalyticsWorkspaceId
        }
      ]
    }
  }
}

var logAnalyticsContributorRoleId = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
resource functionIsLogAnalyticsContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, func_resource.id, logAnalyticsContributorRoleId)
  scope: resourceGroup()

  properties: {
    principalId: func_resource.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsContributorRoleId)
    principalType: 'ServicePrincipal'
    description: 'Allows the function app to read secrets from the key vault'
  }
}

output functionName string = func_resource.name
output resourceId string = func_resource.id
output managedIdentityPrincipalId string = func_resource.identity.principalId
output functionHost string = func_resource.properties.defaultHostName
output functionEndpoint string = 'https://${func_resource.properties.defaultHostName}'
