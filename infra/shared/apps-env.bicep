param name string
param location string = resourceGroup().location
param tags object = {}

param logAnalyticsWorkspaceName string
param applicationInsightsName string = ''

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: !empty(applicationInsightsName) ? applicationInsights.properties.ConnectionString : null
    zoneRedundant: false
  }
}

output name string = containerAppsEnvironment.name
output domain string = containerAppsEnvironment.properties.defaultDomain
output id string = containerAppsEnvironment.id
