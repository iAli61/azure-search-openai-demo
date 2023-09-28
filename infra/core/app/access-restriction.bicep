param appServiceName string
param ipRestrictionAddresses array

resource appService 'Microsoft.Web/sites@2022-09-01' existing = {
  name: appServiceName
}

var additionalIpSecurityRestrictions = [for (ip, i) in ipRestrictionAddresses: {
  ipAddress: '${ip}/32'
  action: 'Allow'
  tag: 'Default'
  priority: 900 + i
  name: 'APIM_${i}'
  description: 'Allow request from APIM ${i}'
}]

resource sitesConfig 'Microsoft.Web/sites/config@2021-02-01' = {
  name: 'web'
  parent: appService
  properties: {
    ipSecurityRestrictions: additionalIpSecurityRestrictions
  }
}
