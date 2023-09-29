param name string
param location string = resourceGroup().location
param tags object = {}

param customSubDomainName string = name
param kind string = 'TextAnalytics'
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S'
}

resource lang 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
}
