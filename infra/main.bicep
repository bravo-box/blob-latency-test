// Main Bicep template for blob latency test infrastructure
// Deploys two storage accounts in different regions and a test VM

targetScope = 'resourceGroup'

@description('Base name for resources')
param baseName string = 'bloblatencytest'

@description('Primary region for storage account')
@allowed([
  'eastus'
  'eastus2'
  'westus'
  'westus2'
  'centralus'
  'northcentralus'
  'southcentralus'
  'westcentralus'
])
param primaryRegion string = 'eastus'

@description('Secondary region for storage account')
@allowed([
  'eastus'
  'eastus2'
  'westus'
  'westus2'
  'centralus'
  'northcentralus'
  'southcentralus'
  'westcentralus'
])
param secondaryRegion string = 'westus2'

@description('Region for VM deployment')
@allowed([
  'eastus'
  'eastus2'
  'westus'
  'westus2'
  'centralus'
  'northcentralus'
  'southcentralus'
  'westcentralus'
])
param vmRegion string = 'centralus'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@description('SSH public key for VM authentication')
@secure()
param sshPublicKey string

@description('VM size')
param vmSize string = 'Standard_B2s'

@description('Tags to apply to all resources')
param tags object = {
  environment: 'test'
  purpose: 'blob-latency-testing'
}

// Generate unique suffix for storage accounts
var uniqueSuffix = uniqueString(resourceGroup().id)

// Deploy primary storage account
module primaryStorage 'modules/storage-account.bicep' = {
  name: 'primaryStorage'
  params: {
    storageAccountName: '${baseName}1${uniqueSuffix}'
    location: primaryRegion
    tags: union(tags, {
      region: 'primary'
      regionName: primaryRegion
    })
  }
}

// Deploy secondary storage account
module secondaryStorage 'modules/storage-account.bicep' = {
  name: 'secondaryStorage'
  params: {
    storageAccountName: '${baseName}2${uniqueSuffix}'
    location: secondaryRegion
    tags: union(tags, {
      region: 'secondary'
      regionName: secondaryRegion
    })
  }
}

// Deploy test VM
module testVM 'modules/virtual-machine.bicep' = {
  name: 'testVM'
  params: {
    vmName: '${baseName}-vm'
    location: vmRegion
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    tags: union(tags, {
      purpose: 'test-runner'
    })
  }
}

// Outputs
output primaryStorageAccountName string = primaryStorage.outputs.storageAccountName
output primaryStorageAccountRegion string = primaryRegion
output secondaryStorageAccountName string = secondaryStorage.outputs.storageAccountName
output secondaryStorageAccountRegion string = secondaryRegion
output vmName string = testVM.outputs.vmName
output vmPublicIP string = testVM.outputs.publicIPAddress
output vmResourceId string = testVM.outputs.vmResourceId
