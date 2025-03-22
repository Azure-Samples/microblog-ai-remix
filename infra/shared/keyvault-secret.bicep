param keyVaultName string
param secretName string
@secure()
param secretValue string
param contentType string = ''
param expirationUnixTime int = -1

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: secretValue
    contentType: !empty(contentType) ? contentType : null
    attributes: {
      exp: expirationUnixTime > 0 ? expirationUnixTime : null
    }
  }
}

output secretUri string = secret.properties.secretUri
output secretUriWithVersion string = secret.properties.secretUriWithVersion
