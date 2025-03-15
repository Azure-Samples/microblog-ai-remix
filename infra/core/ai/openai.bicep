metadata description = 'Creates an Azure Cognitive Services instance.'
param name string
param location string = resourceGroup().location
param tags object = {}

@description('The custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name
param kind string = 'OpenAI'

@description('The deployment name for the model')
param deploymentName string

@description('Model name to deploy')
param modelName string = 'gpt-4o'

@description('Indicates whether to create a new Azure OpenAI resource or use an existing one')
param createNewOpenAIResource bool = false

@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}

param disableLocalAuth bool = false

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = if (createNewOpenAIResource) {
  name: name
  location: location
  tags: tags
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
  }
  sku: sku
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = if (createNewOpenAIResource) {
  parent: account
  name: deploymentName
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
    }
  }
  sku: {
    name: 'Standard'
    capacity: 20
  }
}

output endpoint string = createNewOpenAIResource ? account.properties.endpoint : ''
output id string = createNewOpenAIResource ? account.id : ''
output name string = createNewOpenAIResource ? account.name : ''
output deploymentName string = deploymentName
