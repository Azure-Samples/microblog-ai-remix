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
@description('Azure OpenAI API Key')
@secure()
param azureOpenAIApiKey string

@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string

@description('Azure OpenAI Deployment Name')
param azureOpenAIDeploymentName string

@description('Azure OpenAI API Version')
param azureOpenAIApiVersion string = '2024-08-01-preview'

@description('Flag to indicate whether to create a new Azure OpenAI resource or use an existing one')
param createNewOpenAIResource bool = false

@description('Name for the Azure OpenAI resource if creating a new one')
param openAIResourceName string = ''

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

// Azure OpenAI Module (Optional)
module openAI './core/ai/openai.bicep' = if (createNewOpenAIResource) {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: !empty(openAIResourceName) ? openAIResourceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    deploymentName: azureOpenAIDeploymentName
    modelName: 'gpt-4o'
    createNewOpenAIResource: createNewOpenAIResource
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

// Container App Module
module containerApp './app/containerapp.bicep' = {
  name: 'container-app'
  scope: resourceGroup
  params: {
    name: !empty(containerAppName) ? containerAppName : '${abbrs.appContainerApps}${resourceToken}'
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    containerRegistryLoginServer: registry.outputs.loginServer
    containerRegistryUsername: registry.outputs.username
    containerRegistryPassword: registry.outputs.password
    applicationInsightsConnectionString: appInsights.outputs.connectionString
    azureOpenAIApiKey: azureOpenAIApiKey
    azureOpenAIEndpoint: createNewOpenAIResource ? openAI.outputs.endpoint : azureOpenAIEndpoint
    azureOpenAIDeploymentName: createNewOpenAIResource ? openAI.outputs.deploymentName : azureOpenAIDeploymentName
    azureOpenAIApiVersion: azureOpenAIApiVersion
    userAssignedIdentityId: managedIdentity ? containerAppIdentity.outputs.id : ''
    managedIdentity: managedIdentity
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerAppsEnvironment.outputs.name
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
output AZURE_CONTAINER_APP_NAME string = containerApp.outputs.name
output AZURE_CONTAINER_APP_URI string = containerApp.outputs.uri
output AZURE_RESOURCE_GROUP string = resourceGroup.name
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_OPENAI_ENDPOINT string = createNewOpenAIResource ? openAI.outputs.endpoint : azureOpenAIEndpoint
