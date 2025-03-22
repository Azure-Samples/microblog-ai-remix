param name string
param location string = resourceGroup().location
param tags object = {}

param adminUserEnabled bool = true
param anonymousPullEnabled bool = false
param dataEndpointEnabled bool = false
param encryption object = {
  status: 'disabled'
}
param networkRuleBypassOptions string = 'AzureServices'
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'Basic'
}
param zoneRedundancy string = 'Disabled'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: sku
  properties: {
    adminUserEnabled: adminUserEnabled
    anonymousPullEnabled: anonymousPullEnabled
    dataEndpointEnabled: dataEndpointEnabled
    encryption: encryption
    networkRuleBypassOptions: networkRuleBypassOptions
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: zoneRedundancy
    policies: {
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
  }
}

output loginServer string = containerRegistry.properties.loginServer
output name string = containerRegistry.name
output id string = containerRegistry.id
