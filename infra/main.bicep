targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Whether the deployment is running on GitHub Actions')
param runningOnGh string = ''

param microblogAppExists bool = false
@secure()
param microblogAppDefinition object

@description('Id of the user ir app to assign application roles')
param principalId string = ''

// Azure OpenAI parameters
@description('Azure OpenAI API Key (leave empty if using Managed Identity)')
@secure()
param azureOpenAIApiKey string

@description('Azure OpenAI Endpoint URL')
param azureOpenAIEndpoint string = ''

@description('Azure OpenAI Deployment Name for GPT model')
param azureOpenAIDeploymentName string = 'gpt-4o'

@description('Azure OpenAI API Version')
param azureOpenAIApiVersion string = '2024-05-01-preview'

@description('Flag to create a new Azure OpenAI resource. Set to true only if you want to create a new instance')
param createNewOpenAIResource bool = false

@description('Location for Azure OpenAI resource')
param openAiLocation string = 'eastus'

var tags = {
  'azd-env-name': environmentName
}

// Abbreviations for resource naming
var abbrs = loadJsonContent('./abbreviations.json')

// Resource token for unique naming
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Resource Group Name
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Monitoring resources
module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
  }
  scope: rg
}

// Dashboard for monitoring
module dashboard './shared/dashboard-web.bicep' = {
  name: 'dashboard'
  params: {
    name: '${abbrs.portalDashboards}${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    location: location
    tags: tags
  }
  scope: rg
}

// Container registry
module registry './shared/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: rg
}

// Key Vault for secrets
module keyVault './shared/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    tags: tags
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    principalId: principalId
  }
  scope: rg
}

// Virtual Network resource
module vnet './shared/vnet.bicep' = {
  name: 'vnet'
  params: {
    name: '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
    addressPrefix: '10.0.0.0/16'
    subnets: [
      {
        name: 'infrastructure-subnet'
        addressPrefix: '10.0.0.0/23'
      }
    ]
  }
  scope: rg
}

// Container Apps Environment 
module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    vnetName: vnet.outputs.name
    infraSubnetName: 'infrastructure-subnet'
  }
  scope: rg
}

// Azure OpenAI Service (conditionally created)
module openAi './shared/cognitiveservices.bicep' = if (createNewOpenAIResource) {
  name: 'openai'
  scope: rg
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiLocation
    tags: tags
    sku: {
      name: 'S0'
    }
    disableLocalAuth: true
    deployments: [
      {
        name: azureOpenAIDeploymentName
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: '1106'
        }
        sku: {
          name: 'Standard'
          capacity: 10
        }
      }
    ]
  }
}

// Managed Identity for the app
module appIdentity './shared/managed-identity.bicep' = {
  name: 'app-identity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
  scope: rg
}

// Container App
module microblogApp './app/microblog-app.bicep' = {
  name: 'microblog-app'
  params: {
    // Base resource parameters
    name: '${abbrs.appContainerApps}${resourceToken}'
    location: location
    tags: tags
    identityName: appIdentity.outputs.name
    containerRegistryName: registry.outputs.name
    containerAppsEnvironmentName: appsEnv.outputs.name
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    keyVaultName: keyVault.outputs.name
    azureOpenAIApiKey: azureOpenAIApiKey
    azureOpenAIEndpoint: createNewOpenAIResource ? openAi.outputs.endpoint : azureOpenAIEndpoint
    
    // Deployment control parameters
    exists: microblogAppExists
    
    // Application configuration
    appDefinition: union(microblogAppDefinition, {
      settings: [
        // Application configuration parameters
        {
          name: 'AZURE_KEY_VAULT_NAME' 
          value: keyVault.outputs.name
        }
        {
          name: 'AZURE_KEY_VAULT_ENDPOINT' 
          value: keyVault.outputs.endpoint
        }
        // OpenAI configuration parameters
        // Note: These are now referenced via Key Vault in the container
        // but we maintain them in appDefinition for orchestration purposes
        {
          name: 'AZURE_OPENAI_DEPLOYMENT_NAME' 
          value: azureOpenAIDeploymentName
        }
        {
          name: 'AZURE_OPENAI_API_VERSION' 
          value: azureOpenAIApiVersion
        }
        {
          name: 'NODE_ENV'
          value: 'production'
        }
      ]
    })
  }
  scope: rg
  dependsOn: [openAiKeySecret, openAiEndpointSecret]
}

// Add OpenAI RBAC Roles
module openAiRoleBackend './shared/role.bicep' = if (createNewOpenAIResource) {
  name: 'openai-role-backend-${resourceToken}'
  params: {
    principalId: microblogApp.outputs.principalId
    // Cognitive Services OpenAI User role
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
  scope: rg
}

// Add OpenAI User RBAC Role for the user if needed
module openAiRoleUser './shared/role.bicep' = if (createNewOpenAIResource && !empty(principalId) && empty(runningOnGh)) {
  name: 'openai-role-user-${resourceToken}'
  params: {
    principalId: principalId
    // Cognitive Services OpenAI User
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'User'
  }
  scope: rg
}

// Store OpenAI details in KeyVault
module openAiKeySecret 'shared/keyvault-secret.bicep' = {
  name: 'openai-key-secret'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'AZURE-OPENAI-API-KEY'
    secretValue: createNewOpenAIResource ? openAi.outputs.apiKey : azureOpenAIApiKey
  }
  scope: rg
}

module openAiEndpointSecret 'shared/keyvault-secret.bicep' = {
  name: 'openai-endpoint-secret'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'AZURE-OPENAI-ENDPOINT'
    secretValue: createNewOpenAIResource ? openAi.outputs.endpoint : azureOpenAIEndpoint
  }
  scope: rg
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = rg.name

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output AZURE_CONTAINER_ENVIRONMENT_NAME string = appsEnv.outputs.name
output AZURE_CONTAINER_APP_NAME string = microblogApp.outputs.name
output AZURE_CONTAINER_APP_URI string = microblogApp.outputs.uri

output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint

output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString

// OpenAI outputs
output AZURE_OPENAI_API_KEY string = '@Microsoft.KeyVault(SecretUri=${keyVault.outputs.endpoint}/secrets/AZURE-OPENAI-API-KEY)'
output AZURE_OPENAI_ENDPOINT string = createNewOpenAIResource ? openAi.outputs.endpoint : azureOpenAIEndpoint
output AZURE_OPENAI_DEPLOYMENT_NAME string = azureOpenAIDeploymentName
output AZURE_OPENAI_API_VERSION string = azureOpenAIApiVersion
