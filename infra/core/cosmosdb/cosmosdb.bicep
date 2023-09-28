param cosmosdbName string
param location string
param kvName string
param publicNetworkAccess string

resource cosmosdb_resource 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosdbName
  location: location
  tags: {
    defaultExperience: 'Core (SQL)'
    'hidden-cosmos-mmspecial': ''
  }
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: false
    enableAnalyticalStorage: false
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false
    enablePartitionMerge: false
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    cors: []
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    ipRules: []
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
    networkAclBypassResourceIds: []
  }
}

// .Backend

resource cosmosdbName_backend 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosdb_resource
  name: 'backend'
  properties: {
    resource: {
      id: 'backend'
    }
  }
}

resource cosmosdbName_backend_quotas 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: cosmosdbName_backend
  name: 'quotas'
  properties: {
    resource: {
      id: 'quotas'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: []
        excludedPaths: [
          {
            path: '/*'
          }
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
        version: 2
      }
      defaultTtl: 31536000
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

// .Web

resource cosmosdbName_web 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosdb_resource
  name: 'web'
  properties: {
    resource: {
      id: 'web'
    }
  }
}

resource cosmosdbName_web_conversations 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: cosmosdbName_web
  name: 'Conversations'
  properties: {
    resource: {
      id: 'Conversations'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: []
        excludedPaths: [
          {
            path: '/*'
          }
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/userName'
        ]
        kind: 'Hash'
        version: 2
      }
      defaultTtl: 60 * 60 * 24 * 365
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

var cosmosDbConnectionStringSecretName = 'CosmosConnectionString'

module keyvaultSecretCosmos '../key-vault/keyvault-secret.bicep' = {
  name: 'kv-secret-cosmos-deployment'
  params: {
    kvName: kvName
    secretName: cosmosDbConnectionStringSecretName
    secretValue: cosmosdb_resource.listConnectionStrings().connectionStrings[0].connectionString
  }
}

output cosmosdbName string = cosmosdb_resource.name
output cosmosdbConnectionStringSecretReference string = keyvaultSecretCosmos.outputs.kvReferenceLatest
output cosmosdbConnectionStringSecretName string = cosmosDbConnectionStringSecretName
