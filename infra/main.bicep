targetScope = 'subscription'

// Parameters
@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

// Resource name parameters with defaults
param containerRegistryName string = ''
param logAnalyticsWorkspaceName string = ''
param applicationInsightsName string = ''
param containerAppsEnvironmentName string = ''
param containerAppName string = ''

// Azure OpenAI parameters
@description('Azure OpenAI API key')
@secure()
param azureOpenAIApiKey string

@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string

@description('Azure OpenAI Deployment Name')
param azureOpenAIDeploymentName string

@description('Azure OpenAI API Version')
param azureOpenAIApiVersion string = '2024-08-01-preview'

@description('Optionally create a managed identity for the container app')
param managedIdentity bool = false

// Variables
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: union(tags, { createdBy: 'azd', uniqueId: resourceToken })
}

// Container Registry Module
module registry './core/registry/container-registry.bicep' = {
  name: 'container-registry'
  scope: resourceGroup
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    sku: 'Basic'
    adminUserEnabled: true
  }
}

// Log Analytics Workspace Module
module logAnalyticsWorkspace './core/monitoring/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: resourceGroup
  params: {
    name: !empty(logAnalyticsWorkspaceName)
      ? logAnalyticsWorkspaceName
      : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    sku: 'PerGB2018'
    retentionInDays: 30
  }
}

// Application Insights Module
module appInsights './core/monitoring/app-insights.bicep' = {
  name: 'application-insights'
  scope: resourceGroup
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

// Container App Environment Module
module containerAppsEnvironment './core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: resourceGroup
  params: {
    name: !empty(containerAppsEnvironmentName)
      ? containerAppsEnvironmentName
      : '${abbrs.appContainerAppsEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    logAnalyticsWorkspaceSharedKey: logAnalyticsWorkspace.outputs.sharedKey
  }
}

// Container App User Assigned Identity (Optional)
module containerAppIdentity './core/security/managed-identity.bicep' = if (managedIdentity) {
  name: 'container-app-identity'
  scope: resourceGroup
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}
