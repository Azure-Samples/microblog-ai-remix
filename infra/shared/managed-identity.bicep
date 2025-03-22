@description('Name of the user assigned managed identity')
param name string

@description('Location for the user assigned managed identity')
param location string = resourceGroup().location

@description('Tags for the user assigned managed identity')
param tags object = {}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output id string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
output name string = managedIdentity.name
