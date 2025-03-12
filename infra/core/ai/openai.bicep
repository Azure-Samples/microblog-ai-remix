@description('Name of the Azure OpenAI resource')
param name string

@description('Location for the Azure OpenAI resource')
param location string = resourceGroup().location

@description('Tags for the Azure OpenAI resource')
param tags object = {}

@description('SKU name for the Azure OpenAI resource')
param skuName string = 'Standard'

@description('SKU capacity for the Azure OpenAI resource')
param skuCapacity int = 1

@description('Deployment name for the model')
param deploymentName string

@description('Model name to deploy')
param modelName string = 'gpt-4o'

@description('Indicates whether to create a new Azure OpenAI resource or use an existing one')
param createNewOpenAIResource bool = false

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = if (createNewOpenAIResource) {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
  }
}

resource openAIDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = if (createNewOpenAIResource) {
  parent: openAIAccount
  name: deploymentName
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
    }
  }
}

// These outputs will be empty strings if createNewOpenAIResource is false
output id string = createNewOpenAIResource ? openAIAccount.id : ''
output endpoint string = createNewOpenAIResource ? openAIAccount.properties.endpoint : ''
output deploymentName string = createNewOpenAIResource ? openAIDeployment.name : deploymentName
