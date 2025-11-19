# Example Usage

This document provides examples of how to use the blob-latency-test scripts.

## Example 1: Local Testing with Existing Storage Accounts

If you already have two storage accounts deployed in different regions:

```bash
./scripts/blob-upload-test.sh \
  -a mystorageeastus \
  -r eastus \
  -b mystoragewestus \
  -s westus2 \
  -f 100
```

## Example 2: Testing with Different File Sizes

Test with a smaller 50MB file:

```bash
./scripts/blob-upload-test.sh \
  -a mystorageeastus \
  -r eastus \
  -b mystoragewestus \
  -s westus2 \
  -f 50
```

Test with a larger 500MB file:

```bash
./scripts/blob-upload-test.sh \
  -a mystorageeastus \
  -r eastus \
  -b mystoragewestus \
  -s westus2 \
  -f 500
```

## Example 3: Using Environment Variables

```bash
export FILE_SIZE_MB=200
export CONTAINER_NAME=my-test-container

./scripts/blob-upload-test.sh \
  -a mystorageeastus \
  -r eastus \
  -b mystoragewestus \
  -s westus2
```

## Example 4: Complete Infrastructure Deployment

### Step 1: Prepare SSH Key

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_vm_key

# Copy your public key
cat ~/.ssh/azure_vm_key.pub
```

### Step 2: Prepare Parameters File

```bash
cd infra
cp main.parameters.json main.parameters.local.json

# Edit main.parameters.local.json and update:
# - sshPublicKey: paste your SSH public key
# - Update regions if desired
# - Update tags with your information
```

### Step 3: Deploy Infrastructure

```bash
./deploy.sh -g blob-latency-rg -l centralus -p main.parameters.local.json
```

### Step 4: Note the Outputs

The deployment will output:
- primaryStorageAccountName
- primaryStorageAccountRegion
- secondaryStorageAccountName
- secondaryStorageAccountRegion
- vmPublicIP

### Step 5: Run Test on VM

```bash
# SSH to the VM
ssh -i ~/.ssh/azure_vm_key azureuser@<vmPublicIP>

# Clone the repo or copy the script
git clone https://github.com/bravo-box/blob-latency-test.git
cd blob-latency-test

# Login to Azure on the VM
az login

# Assign Storage Blob Data Contributor role to VM's managed identity
# (Run this from your local machine, not the VM)
VM_PRINCIPAL_ID=$(az vm show -g blob-latency-rg -n bloblatencytest-vm --query identity.principalId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $VM_PRINCIPAL_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/blob-latency-rg

# Run the test on the VM
./scripts/blob-upload-test.sh \
  -a <primaryStorageAccountName> \
  -r <primaryStorageAccountRegion> \
  -b <secondaryStorageAccountName> \
  -s <secondaryStorageAccountRegion> \
  -f 100
```

## Example 5: Testing from Different Geographic Locations

To test how network proximity affects upload speeds, run the test from different locations:

1. **From your local machine** (e.g., from US East Coast)
2. **From the deployed VM** (e.g., in Central US)
3. **From another region's VM** (deploy another VM in a different region)

Compare the results to see how geographic proximity affects upload performance.

## Expected Output Example

```
[INFO] Starting Blob Upload Latency Test
Configuration:
  Region 1: eastus (mystorageeastus)
  Region 2: westus2 (mystoragewestus)
  Test File Size: 100MB

[INFO] Checking prerequisites...
[SUCCESS] Prerequisites check passed
[INFO] Generating test file of 100MB...
[SUCCESS] Test file generated: test-file-100mb.bin (100M)

==================================================
Starting Upload Tests
==================================================

[INFO] Testing upload to eastus (Storage Account: mystorageeastus)...

[SUCCESS] Upload completed to eastus
  Region: eastus
  Storage Account: mystorageeastus
  File Size: 100.00 MB
  Duration: 8.45 seconds
  Speed: 11.83 MB/s (94.67 Mbps)

[INFO] Testing upload to westus2 (Storage Account: mystoragewestus)...

[SUCCESS] Upload completed to westus2
  Region: westus2
  Storage Account: mystoragewestus
  File Size: 100.00 MB
  Duration: 12.32 seconds
  Speed: 8.12 MB/s (64.93 Mbps)

==================================================
[SUCCESS] All tests completed!
==================================================
[INFO] Cleaning up test file...
[SUCCESS] Test file removed
```

## Tips for Testing

1. **Network Considerations**: Test during off-peak hours for more consistent results
2. **File Size**: Larger files (100MB+) provide more accurate speed measurements
3. **Multiple Runs**: Run tests multiple times and average the results
4. **VM Size**: Use larger VM sizes for higher network throughput (e.g., Standard_D4s_v3)
5. **Storage SKU**: Consider Premium storage for higher performance testing

## Cleanup

After testing, clean up resources:

```bash
# Delete all test blobs (if needed)
az storage blob delete-batch \
  --account-name mystorageeastus \
  --source latency-test \
  --auth-mode login

# Delete resource group (removes all resources)
az group delete --name blob-latency-rg --yes --no-wait
```
