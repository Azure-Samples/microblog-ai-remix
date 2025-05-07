param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param containerRegistryName string
param containerAppsEnvironmentName string
param applicationInsightsName string
param exists bool = false

// Key Vault parameters (maintained for future use)
param keyVaultName string
param openAiApiKeySecretName string = 'AZURE-OPENAI-API-KEY'
param openAiEndpointSecretName string = 'AZURE-OPENAI-ENDPOINT'

// Direct credential parameters
@secure()
param azureOpenAIApiKey string = ''
@secure()
param azureOpenAIEndpoint string = ''

@description('Whether the deployment is running on GitHub Actions')
param runningOnGh string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

@secure()
param appDefinition object

// Process application settings and secrets
var appSettingsArray = filter(array(appDefinition.settings), i => i.name != '')
var secrets = map(filter(appSettingsArray, i => i.?secret == true), i => {
  name: i.name
  value: i.value
  secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
})
var env = map(filter(appSettingsArray, i => i.?secret != true), i => {
  name: i.name
  value: i.value
})

// Generate a unique string for resource naming
var resourceToken = uniqueString(resourceGroup().id, name)

// Managed identity for the container app
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

// Reference to existing resources
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: containerAppsEnvironmentName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

// Key Vault reference
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// RBAC for Container Registry
module acrPullRole '../shared/role.bicep' = {
  name: 'acr-pull-role-${resourceToken}'
  params: {
    principalId: identity.properties.principalId
    // AcrPull role definition ID
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' 
    principalType: 'ServicePrincipal'
  }
}

// RBAC for Key Vault Secrets (maintained for future use)
module kvRoleAssignment '../shared/role.bicep' = {
  name: 'kv-secretuser-role-${resourceToken}'
  params: {
    principalId: identity.properties.principalId
    // Key Vault Secrets User role definition ID
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
    principalType: 'ServicePrincipal'
  }
}

// Get existing container app image details if it exists
module fetchLatestImage '../modules/fetch-container-image.bicep' = {
  name: '${name}-fetch-image'
  params: {
    exists: exists
    name: name
  }
}

// Container App resource
resource app 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: name
  location: location
  tags: union(tags, {'azd-service-name': 'microblog-ai-remix'})
  dependsOn: [acrPullRole, kvRoleAssignment]
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {'${identity.id}': {}}
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistryName}.azurecr.io'
          identity: identity.id
        }
      ]
      secrets: union([
        // Direct value secrets
        {
          name: 'azure-openai-api-key'
          value: !empty(azureOpenAIApiKey) ? azureOpenAIApiKey : 'placeholder-value'
        }
        {
          name: 'azure-openai-endpoint'
          value: !empty(azureOpenAIEndpoint) ? azureOpenAIEndpoint : 'https://placeholder-endpoint.openai.azure.com'
        }
      ], map(secrets, secret => {
        name: secret.secretRef
        value: secret.value
      }))
    }
    template: {
      containers: [
        {
          image: fetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/hello-world:latest'
          name: 'main'
          env: union([
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
            {
              name: 'PORT'
              value: '80'
            }
            // Environment variables referencing secrets
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              secretRef: 'azure-openai-endpoint'
            }
          ],
          env,
          map(secrets, secret => {
            name: secret.name
            secretRef: secret.secretRef
          }))
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          probes: [
            {
              type: 'liveness'
              httpGet: {
                path: '/health'
                port: 80
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'readiness'
              httpGet: {
                path: '/health'
                port: 80
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling-rule'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

// Base resource outputs
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output name string = app.name
output uri string = 'https://${app.properties.configuration.ingress.fqdn}'
output id string = app.id
output principalId string = app.identity.principalId

// Key Vault reference outputs
output keyVaultUri string = keyVault.properties.vaultUri

// Secret configuration outputs with direct resource references
output openAiKeySecretPath string = '${keyVault.properties.vaultUri}secrets/${openAiApiKeySecretName}'
output openAiEndpointSecretPath string = '${keyVault.properties.vaultUri}secrets/${openAiEndpointSecretName}'
