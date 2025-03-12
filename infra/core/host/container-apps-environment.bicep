@description('Name of the Container Apps Environment')
param name string

@description('Location of the Container Apps Environment')
param location string = resourceGroup().location

@description('Tags for the Container Apps Environment')
param tags object = {}

@description('Resource ID of the Log Analytics workspace to which this Container Apps Environment should send logs')
param logAnalyticsWorkspaceId string

@description('Shared key for the Log Analytics workspace')
@secure()
param logAnalyticsWorkspaceSharedKey string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
        sharedKey: logAnalyticsWorkspaceSharedKey
      }
    }
    zoneRedundant: false
  }
}

// Outputs
output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
