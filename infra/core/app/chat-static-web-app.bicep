param chatSWAName string
param location string
param publicNetworkAccess string
param chatSWASkuName string
param chatSWASkuSize string

resource chat_spa 'Microsoft.Web/staticSites@2022-03-01' = {
  name: chatSWAName
  location: location
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
  sku: {
    name: chatSWASkuName
    size: chatSWASkuSize
  }
}

output defaultHostName string = chat_spa.properties.defaultHostname
