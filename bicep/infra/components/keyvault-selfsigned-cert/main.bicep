targetScope = 'resourceGroup'

@description('Key Vault name where the certificate will be created.')
param keyVaultName string

@description('Certificate name in Key Vault (also becomes the secret name).')
param certificateName string = 'agw-tls'

@description('DNS name to put in CN + SAN (e.g., pip-agw-<baseName>.<region>.cloudapp.azure.com).')
param dnsName string

@description('Validity in months.')
param validityInMonths int = 12

@description('RSA key size.')
param keySize int = 2048

#disable-next-line BCP081
resource selfSignedCert 'Microsoft.KeyVault/vaults/certificates@2023-07-01' = {
  name: '${keyVaultName}/${certificateName}'
  properties: {
    attributes: {
      enabled: true
    }
    certificatePolicy: {
      issuerParameters: {
        name: 'Self'
      }
      keyProperties: {
        exportable: true
        keyType: 'RSA'
        keySize: keySize
        reuseKey: true
      }
      secretProperties: {
        contentType: 'application/x-pkcs12'
      }
      x509CertificateProperties: {
        subject: 'CN=${dnsName}'
        subjectAlternativeNames: {
          dnsNames: [
            dnsName
          ]
        }
        validityInMonths: validityInMonths
      }
    }
  }
}

@description('Key Vault secret ID with version (use this as Application Gateway sslCertificate.properties.keyVaultSecretId).')
#disable-next-line use-resource-symbol-reference
output keyVaultSecretId string = string(reference(selfSignedCert.id, '2023-07-01').sid)
