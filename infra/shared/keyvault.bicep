param name string
param location string = resourceGroup().location
param tags object = {}

@description('Service principal that should be granted read access to the KeyVault. If unset, no service principal is granted access by default')
param principalId string = ''

// Set up access policies
var defaultAccessPolicies = !empty(principalId) ? [
  {
    objectId: principalId
    permissions: { 
      secrets: [ 'get', 'list' ]
      keys: [ 'get', 'list' ]
      certificates: [ 'get', 'list' ]
    }
    tenantId: subscription().tenantId
  }
] : []

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
    softDeleteRetentionInDays: 90
    accessPolicies: defaultAccessPolicies
    enableSoftDelete: true
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
