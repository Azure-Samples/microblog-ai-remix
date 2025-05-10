@description('Name of the virtual network')
param name string

@description('Azure region where the resource will be deployed')
param location string

@description('Resource tags')
param tags object = {}

@description('Address prefix for the virtual network')
param addressPrefix string = '10.0.0.0/16'

@description('Array of subnet objects with name and addressPrefix')
param subnets array = [
  {
    name: 'default'
    addressPrefix: '10.0.0.0/24'
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: subnet.?delegations ?? []
        privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies ?? 'Enabled'
        privateLinkServiceNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies ?? 'Enabled'
        serviceEndpoints: subnet.?serviceEndpoints ?? []
      }
    }]
  }
}

output id string = vnet.id
output name string = vnet.name
