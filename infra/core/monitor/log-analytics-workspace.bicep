@description('Naming convention Process')
param name string

@description('Set resources tags')
param tags object = {}

@description('Specify the pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])

param sku string = 'PerGB2018'

@description('Specify the number of days to retain data.')
param retentionInDays int = 30

@description('Location for all resources.')
param location string = resourceGroup().location

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: retentionInDays
  }
}

output resourceId string = workspace.id
output workspaceName string = workspace.name
output workspaceId string = workspace.properties.customerId
