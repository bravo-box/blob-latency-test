#!/bin/bash

# Quick Start Script
# Helps users quickly set up and run blob latency tests

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Check if Azure CLI is installed
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed."
        echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI is installed"
}

# Check if logged in
check_azure_login() {
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure."
        echo "Please run: az login"
        exit 1
    fi
    local account_name=$(az account show --query name -o tsv)
    print_success "Logged in to Azure (Subscription: $account_name)"
}

# Main menu
show_menu() {
    print_header "Blob Latency Test - Quick Start"
    echo "What would you like to do?"
    echo ""
    echo "1) Run test with existing storage accounts"
    echo "2) Deploy new infrastructure (storage accounts + VM)"
    echo "3) Check prerequisites"
    echo "4) View examples"
    echo "5) Exit"
    echo ""
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1) run_test ;;
        2) deploy_infrastructure ;;
        3) check_prerequisites ;;
        4) view_examples ;;
        5) exit 0 ;;
        *) 
            print_error "Invalid choice"
            show_menu
            ;;
    esac
}

# Run test
run_test() {
    print_header "Run Blob Upload Test"
    
    echo "Enter the first storage account details:"
    read -p "Storage Account 1 Name: " storage1
    read -p "Storage Account 1 Region (e.g., eastus): " region1
    
    echo ""
    echo "Enter the second storage account details:"
    read -p "Storage Account 2 Name: " storage2
    read -p "Storage Account 2 Region (e.g., westus2): " region2
    
    echo ""
    read -p "File size in MB [default: 100]: " filesize
    filesize=${filesize:-100}
    
    echo ""
    print_info "Running test with:"
    echo "  Storage 1: $storage1 in $region1"
    echo "  Storage 2: $storage2 in $region2"
    echo "  File size: ${filesize}MB"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    ./scripts/blob-upload-test.sh -a "$storage1" -r "$region1" -b "$storage2" -s "$region2" -f "$filesize"
    
    echo ""
    read -p "Press Enter to return to menu..."
    show_menu
}

# Deploy infrastructure
deploy_infrastructure() {
    print_header "Deploy Infrastructure"
    
    print_info "This will deploy:"
    echo "  - Two storage accounts in different regions"
    echo "  - One VM for running tests"
    echo ""
    
    read -p "Resource Group Name: " rg_name
    read -p "Resource Group Location (e.g., centralus): " rg_location
    
    echo ""
    print_info "Checking for SSH key..."
    
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        print_error "No SSH key found at ~/.ssh/id_rsa.pub"
        read -p "Would you like to generate one now? [y/N]: " generate_key
        if [[ $generate_key =~ ^[Yy]$ ]]; then
            ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
            print_success "SSH key generated"
        else
            print_error "Cannot proceed without SSH key"
            read -p "Press Enter to return to menu..."
            show_menu
            return
        fi
    fi
    
    # Create parameters file
    local ssh_key=$(cat ~/.ssh/id_rsa.pub)
    local params_file="infra/main.parameters.local.json"
    
    print_info "Creating parameters file..."
    cat > "$params_file" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "baseName": {
      "value": "bloblatencytest"
    },
    "primaryRegion": {
      "value": "eastus"
    },
    "secondaryRegion": {
      "value": "westus2"
    },
    "vmRegion": {
      "value": "centralus"
    },
    "adminUsername": {
      "value": "azureuser"
    },
    "sshPublicKey": {
      "value": "$ssh_key"
    },
    "vmSize": {
      "value": "Standard_B2s"
    },
    "tags": {
      "value": {
        "environment": "test",
        "purpose": "blob-latency-testing"
      }
    }
  }
}
EOF
    
    print_success "Parameters file created: $params_file"
    
    echo ""
    print_info "Starting deployment..."
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    cd infra
    ./deploy.sh -g "$rg_name" -l "$rg_location" -p "$(basename $params_file)"
    cd ..
    
    echo ""
    print_success "Deployment complete!"
    print_info "Note the output values above for running tests"
    
    echo ""
    read -p "Press Enter to return to menu..."
    show_menu
}

# Check prerequisites
check_prerequisites() {
    print_header "Prerequisites Check"
    
    check_azure_cli
    check_azure_login
    
    # Check for bc
    if command -v bc &> /dev/null; then
        print_success "bc calculator is installed"
    else
        print_error "bc calculator is not installed"
        echo "Install it with: sudo apt-get install bc (Ubuntu/Debian) or brew install bc (macOS)"
    fi
    
    # Check for jq
    if command -v jq &> /dev/null; then
        print_success "jq is installed"
    else
        print_error "jq is not installed (needed for deployment)"
        echo "Install it with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
    fi
    
    echo ""
    print_info "Current Azure subscription:"
    az account show --query "{Name:name, ID:id, TenantID:tenantId}" -o table
    
    echo ""
    read -p "Press Enter to return to menu..."
    show_menu
}

# View examples
view_examples() {
    print_header "Examples"
    
    if [ -f EXAMPLES.md ]; then
        less EXAMPLES.md || cat EXAMPLES.md
    else
        print_error "EXAMPLES.md not found"
    fi
    
    echo ""
    read -p "Press Enter to return to menu..."
    show_menu
}

# Main
main() {
    clear
    check_azure_cli
    check_azure_login
    show_menu
}

main
