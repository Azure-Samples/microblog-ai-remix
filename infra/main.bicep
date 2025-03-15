targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

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
param azureOpenAIApiVersion string = '2024-05-01-preview'

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
var resourceGroupName = 'rg-${environmentName}'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, { createdBy: 'azd', uniqueId: resourceToken })
}

// Log Analytics Workspace Module
module logAnalytics './core/monitoring/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsWorkspaceName)
      ? logAnalyticsWorkspaceName
      : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

// Application Insights Module
module appInsights './core/monitoring/app-insights.bicep' = {
  name: 'application-insights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Container Registry Module
module registry './core/registry/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    adminUserEnabled: true
  }
}

// Container Apps Environment Module
module containerAppsEnvironment './core/host/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: !empty(containerAppsEnvironmentName)
      ? containerAppsEnvironmentName
      : '${abbrs.appContainerAppsEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Azure OpenAI Module (Optional)
module openAI './core/ai/openai.bicep' = if (createNewOpenAIResource) {
  name: 'openai'
  scope: rg
  params: {
    name: !empty(openAIResourceName) ? openAIResourceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    deploymentName: azureOpenAIDeploymentName
    modelName: 'gpt-4o'
    createNewOpenAIResource: createNewOpenAIResource
  }
}

// Identity Module
module containerAppIdentity './core/security/managed-identity.bicep' = if (managedIdentity) {
  name: 'container-app-identity'
  scope: rg
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container App Module
module containerApp './app/containerapp.bicep' = {
  name: 'container-app'
  scope: rg
  params: {
    name: !empty(containerAppName) ? containerAppName : '${abbrs.appContainerApps}${resourceToken}'
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    containerRegistryName: registry.outputs.name
    applicationInsightsConnectionString: appInsights.outputs.connectionString
    azureOpenAIApiKey: azureOpenAIApiKey
    azureOpenAIEndpoint: createNewOpenAIResource ? openAI.outputs.endpoint : azureOpenAIEndpoint
    azureOpenAIDeploymentName: createNewOpenAIResource ? openAI.outputs.deploymentName : azureOpenAIDeploymentName
    azureOpenAIApiVersion: azureOpenAIApiVersion
    userAssignedIdentityId: managedIdentity ? containerAppIdentity.outputs.id : ''
    managedIdentity: managedIdentity
  }
}

module keyvault 'core/security/keyvault.bicep' = {
  name: 'keyvault-module'
  scope: rg
  params: {
    keyVaultName: 'microblog-ai-kv'
    location: location
    openAiAccountName: openAIResourceName
    createNewOpenAIResource: createNewOpenAIResource
    azureOpenAIApiKey: azureOpenAIApiKey
    azureOpenAIEndpoint: azureOpenAIEndpoint
    azureOpenAIDeploymentName: azureOpenAIDeploymentName
    objectId: managedIdentity ? containerAppIdentity.outputs.principalId : subscription().subscriptionId
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
output AZURE_RESOURCE_GROUP string = resourceGroupName
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_OPENAI_ENDPOINT string = createNewOpenAIResource ? openAI.outputs.endpoint : azureOpenAIEndpoint
output keyVaultName string = keyvault.outputs.keyVaultName
output openAiKeySecretUri string = keyvault.outputs.openAiKeySecretUri
output openAiEndpointSecretUri string = keyvault.outputs.openAiEndpointSecretUri
