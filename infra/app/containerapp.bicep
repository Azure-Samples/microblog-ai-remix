@description('Name of the Container App')
param name string

@description('Location of the Container App')
param location string = resourceGroup().location

@description('Tags for the Container App')
param tags object = {}

@description('Resource ID of the Container Apps Environment in which this app should be deployed')
param containerAppsEnvironmentId string

@description('Name of the Container Registry')
param containerRegistryName string

@description('Connection string for Application Insights')
@secure()
param applicationInsightsConnectionString string

@description('Azure OpenAI API Key')
@secure()
param azureOpenAIApiKey string

@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string

@description('Azure OpenAI Deployment Name')
param azureOpenAIDeploymentName string

@description('Azure OpenAI API Version')
param azureOpenAIApiVersion string = '2024-05-01-preview'

@description('Container image name')
param imageName string = 'microblog-ai-remix'

@description('Container image tag')
param imageTag string = 'latest'

@description('Minimum number of replicas')
param minReplicas int = 0

@description('Maximum number of replicas')
param maxReplicas int = 10

@description('Number of CPU cores allocated to a single container instance')
param containerCpuCoreCount string = '0.5'

@description('Memory allocated to a single container instance')
param containerMemory string = '1.0Gi'

@description('Flag that determines if the container app should use managed identity')
param managedIdentity bool = false

@description('Resource ID of the user assigned managed identity')
param userAssignedIdentityId string = ''

// Referência ao recurso existente
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

// Definir tipo de identidade
var identityType = managedIdentity ? (!empty(userAssignedIdentityId) ? 'UserAssigned' : 'SystemAssigned') : 'None'
var identityProperties = !empty(userAssignedIdentityId)
  ? {
      type: identityType
      userAssignedIdentities: {
        '${userAssignedIdentityId}': {}
      }
    }
  : {
      type: identityType
    }

// Obter as credenciais do registry
var registryCredentials = registry.listCredentials()
var registryUsername = registryCredentials.username
var registryPassword = registryCredentials.passwords[0].value

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: identityProperties
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        transport: 'auto'
      }
      registries: [
        {
          server: registry.properties.loginServer
          username: registryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        {
          name: 'container-registry-password'
          value: registryPassword
        }
        {
          name: 'azure-openai-api-key'
          value: azureOpenAIApiKey
        }
        {
          name: 'application-insights-connection-string'
          value: applicationInsightsConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'main'
          image: '${registry.properties.loginServer}/${imageName}:${imageTag}'
          env: [
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAIEndpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
              value: azureOpenAIDeploymentName
            }
            {
              name: 'AZURE_OPENAI_API_VERSION'
              value: azureOpenAIApiVersion
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'application-insights-connection-string'
            }
            {
              name: 'PORT'
              value: '80'
            }
            {
              name: 'NODE_ENV'
              value: 'production'
            }
          ]
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
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
        minReplicas: minReplicas
        maxReplicas: maxReplicas
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

// Outputs
output id string = containerApp.id
output name string = containerApp.name
output uri string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output identityPrincipalId string = managedIdentity && identityType == 'SystemAssigned'
  ? containerApp.identity.principalId
  : ''
