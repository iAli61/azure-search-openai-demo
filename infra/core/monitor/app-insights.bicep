param appInsightsName string
param location string
param workspaceResourceId string

resource ai 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    RetentionInDays: 90
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output appInsightsKey string = ai.properties.InstrumentationKey
output appInsightsConnectionString string = ai.properties.ConnectionString
output appInsightsAppId string = ai.properties.AppId
