@description('Name of the Log Analytics Workspace')
param name string

@description('Location of the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Tags for the Log Analytics Workspace')
param tags object = {}

@description('Pricing tier: PerGB2018 or Free or Standalone or PerNode or Standard or Premium')
@allowed([
  'Free'
  'Standard'
  'Premium'
  'PerNode'
  'PerGB2018'
  'Standalone'
])
param sku string = 'PerGB2018'

@description('Number of days to retain logs')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Outputs
output id string = logAnalyticsWorkspace.id
output name string = logAnalyticsWorkspace.name
output customerId string = logAnalyticsWorkspace.properties.customerId
@secure()
output sharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
