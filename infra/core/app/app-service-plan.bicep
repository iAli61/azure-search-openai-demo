param appServicePlanName string
param location string
param skuCode string
param capacity int
param kind string
param zoneRedundant bool = false

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    capacity: capacity
    name: skuCode
  }
  kind: toLower(kind)
  properties: {
    zoneRedundant: zoneRedundant
    reserved: toLower(kind) == 'linux' ? true : false
  }
}

output appServicePlanResourceId string = appServicePlan.id
