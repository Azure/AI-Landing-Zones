// AVM Container App wrapper (pass-through)
targetScope = 'resourceGroup'

import { containerAppDefinitionType } from '../common/types.bicep'

@description('Container App configuration.')
param containerApp containerAppDefinitionType

module inner 'br/public:avm/res/app/container-app:0.18.1' = {
  name: 'ca-avm-${containerApp.name}'
  params: {
    // Required parameters
    name: containerApp.name
    environmentResourceId: containerApp.environmentResourceId!
    
    // Provide default container configuration
    containers: [
      {
        name: 'default'
        image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        resources: {
          cpu: '0.5'
          memory: '1.0Gi'
        }
      }
    ]
    
    // Optional parameters that pass through safely
    location: containerApp.?location ?? resourceGroup().location
    tags: containerApp.?tags
    workloadProfileName: containerApp.?workloadProfileName
    activeRevisionsMode: containerApp.?activeRevisionsMode

    // Ingress + IP allowlist
    disableIngress: containerApp.?disableIngress
    ingressExternal: containerApp.?ingressExternal
    ingressTransport: containerApp.?ingressTransport
    ingressAllowInsecure: containerApp.?ingressAllowInsecure
    ingressTargetPort: containerApp.?ingressTargetPort
    exposedPort: containerApp.?exposedPort
    ipSecurityRestrictions: containerApp.?ipSecurityRestrictions

    clientCertificateMode: containerApp.?clientCertificateMode
    lock: containerApp.?lock
    managedIdentities: containerApp.?managedIdentities
    revisionSuffix: containerApp.?revisionSuffix
    roleAssignments: containerApp.?roleAssignments
    stickySessionsAffinity: containerApp.?stickySessionsAffinity
    trafficLabel: containerApp.?trafficLabel
    trafficLatestRevision: containerApp.?trafficLatestRevision
    trafficRevisionName: containerApp.?trafficRevisionName
    trafficWeight: containerApp.?trafficWeight
  }
}

output resourceId string = inner.outputs.resourceId
output name string = inner.outputs.name
output location string = inner.outputs.location
output resourceGroupName string = inner.outputs.resourceGroupName
output fqdn string = inner.outputs.fqdn
output systemAssignedMIPrincipalId string? = inner.outputs.?systemAssignedMIPrincipalId
