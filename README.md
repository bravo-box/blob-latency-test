# blob-latency-test

A repository with scripts to test blob upload latency and speed between two Azure regions. This tool helps you measure and compare blob upload performance across different Azure regions.

## Features

- Upload test files to Azure Blob Storage in two different regions
- Measure upload time and speed (MB/s and Mbps)
- Support for local execution and VM-based testing
- Infrastructure as Code using Bicep templates
- Automated deployment of storage accounts and test VM

## Prerequisites

### For Local Testing
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- Active Azure subscription
- Bash shell (Linux, macOS, or WSL on Windows)
- `bc` command-line calculator (usually pre-installed)

### For Infrastructure Deployment
- All local testing prerequisites
- `jq` for JSON parsing (used in deployment script)
- SSH key pair for VM access

## Quick Start

### Option A: Interactive Quick Start (Recommended for Beginners)

Use the interactive quickstart script that guides you through the process:

```bash
./quickstart.sh
```

This interactive script will help you:
- Check prerequisites
- Run tests with existing storage accounts
- Deploy new infrastructure
- View examples

### Option B: Manual Command Line

#### 1. Local Testing

Run the blob upload test locally against two existing storage accounts:

```bash
# Login to Azure
az login

# Run the test
./scripts/blob-upload-test.sh \
  -a <storage-account-1> \
  -r eastus \
  -b <storage-account-2> \
  -s westus2 \
  -f 100
```

**Parameters:**
- `-a`: First storage account name
- `-r`: First region name
- `-b`: Second storage account name
- `-s`: Second region name
- `-f`: File size in MB (optional, default: 100)

**Example:**
```bash
./scripts/blob-upload-test.sh \
  -a mystorageeastus \
  -r eastus \
  -b mystoragewestus \
  -s westus2 \
  -f 50
```

#### 2. Deploy Infrastructure

Deploy the complete infrastructure (storage accounts + VM) using Bicep:

```bash
cd infra

# Edit parameters file with your values
cp main.parameters.json main.parameters.local.json
# Edit main.parameters.local.json:
# - Set your SSH public key
# - Customize regions if needed
# - Set tags

# Deploy
./deploy.sh -g blob-latency-rg -l centralus -p main.parameters.local.json
```

The deployment script will:
1. Create a resource group
2. Deploy two storage accounts in different regions
3. Deploy a test VM with Azure CLI pre-installed
4. Output the storage account names and VM IP address

#### 3. Run Tests on the VM

After deployment, SSH to the VM and run tests:

```bash
# SSH to the VM
ssh azureuser@<vm-public-ip>

# Copy the test script to the VM
# (or clone the repo on the VM)

# Run the test
./blob-upload-test.sh \
  -a <storage-account-1> \
  -r <region-1> \
  -b <storage-account-2> \
  -s <region-2>
```

## Project Structure

```
.
├── scripts/
│   └── blob-upload-test.sh     # Main test script
├── infra/
│   ├── main.bicep              # Main Bicep template
│   ├── main.parameters.json    # Parameters template
│   ├── deploy.sh               # Deployment script
│   └── modules/
│       ├── storage-account.bicep   # Storage account module
│       └── virtual-machine.bicep   # VM module
├── quickstart.sh               # Interactive quick start script
├── EXAMPLES.md                 # Detailed usage examples
└── README.md
```

## Infrastructure Details

### Storage Accounts
- **Type:** StorageV2 (General Purpose v2)
- **SKU:** Standard_LRS
- **Features:**
  - HTTPS only
  - TLS 1.2 minimum
  - Private blob access
  - 7-day blob retention policy

### Virtual Machine
- **OS:** Ubuntu 22.04 LTS
- **Default Size:** Standard_B2s
- **Authentication:** SSH key only
- **Pre-installed Software:**
  - Azure CLI
  - bc (calculator)
- **Network:** Public IP with SSH access (port 22)

## Test Output Example

```
Starting Blob Upload Latency Test
Configuration:
  Region 1: eastus (mystorageeastus)
  Region 2: westus2 (mystoragewestus)
  Test File Size: 100MB

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
```

## Configuration

### Environment Variables

You can customize the test using environment variables:

```bash
# Set file size (in MB)
export FILE_SIZE_MB=200

# Set container name
export CONTAINER_NAME=my-test-container

# Run test
./scripts/blob-upload-test.sh -a storage1 -r eastus -b storage2 -s westus
```

### Bicep Parameters

Key parameters in `main.parameters.json`:
- `baseName`: Base name for all resources
- `primaryRegion`: First storage account region
- `secondaryRegion`: Second storage account region
- `vmRegion`: VM deployment region
- `adminUsername`: VM admin username
- `sshPublicKey`: SSH public key for VM access
- `vmSize`: VM size (default: Standard_B2s)

## Security Considerations

- Storage accounts use HTTPS only with TLS 1.2 minimum
- VM uses SSH key authentication (no password)
- Network Security Group allows SSH from any IP (customize for production)
- VM has system-assigned managed identity for Azure resource access
- Test script uses Azure CLI with `--auth-mode login` for RBAC-based access

## Cleanup

To remove all deployed resources:

```bash
# Delete the resource group and all resources
az group delete --name blob-latency-rg --yes
```

## Troubleshooting

### Azure CLI Not Authenticated
```bash
az login
```

### Permission Denied on Scripts
```bash
chmod +x scripts/blob-upload-test.sh
chmod +x infra/deploy.sh
```

### Storage Account Access Issues
Ensure you have the appropriate RBAC role:
```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <your-user-id> \
  --scope /subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<storage-account>
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

See the [LICENSE](LICENSE) file for details.
