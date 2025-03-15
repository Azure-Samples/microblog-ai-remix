param keyVaultName string
param location string
param openAiAccountName string
param createNewOpenAIResource bool
param azureOpenAIApiKey string
param azureOpenAIEndpoint string
param azureOpenAIDeploymentName string
param tenantId string = subscription().tenantId
param objectId string  // <-- This should be the object ID of the principal deploying resources

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId
        permissions: {
          secrets: [ 'get', 'list', 'set', 'delete', 'recover', 'backup', 'restore' ]
          keys: [ 'get', 'list', 'create', 'import', 'delete', 'recover' ]
          certificates: [ 'get', 'list', 'create', 'delete' ]
        }
      }
    ]
  }
}

// Store OpenAI API Key in Key Vault
resource openAiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE_OPENAI_API_KEY'
  properties: {
    value: createNewOpenAIResource ? listKeys(resourceId('Microsoft.CognitiveServices/accounts', openAiAccountName), '2023-05-01').key1 : azureOpenAIApiKey
  }
}

// Store OpenAI Endpoint in Key Vault
resource openAiEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE_OPENAI_ENDPOINT'
  properties: {
    value: azureOpenAIEndpoint
  }
}

// Store OpenAI Deployment Name in Key Vault
resource openAiDeploymentSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
  properties: {
    value: azureOpenAIDeploymentName
  }
}

// Outputs
output keyVaultName string = keyVault.name
output openAiKeySecretUri string = openAiKeySecret.properties.secretUri
output openAiEndpointSecretUri string = openAiEndpointSecret.properties.secretUri
output openAiDeploymentSecretUri string = openAiDeploymentSecret.properties.secretUri
