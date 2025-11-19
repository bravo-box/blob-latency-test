#!/bin/bash

# Infrastructure Deployment Script
# Deploys the blob latency test infrastructure to Azure

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -g <resource_group> -l <location> [-p <parameters_file>]

Options:
    -g    Resource group name
    -l    Resource group location (e.g., centralus)
    -p    Parameters file path (default: main.parameters.json)
    -h    Display this help message

Example:
    $0 -g blob-latency-rg -l centralus

EOF
    exit 1
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Main script
main() {
    local resource_group=""
    local location=""
    local parameters_file="main.parameters.json"
    
    # Parse command line arguments
    while getopts "g:l:p:h" opt; do
        case $opt in
            g) resource_group="$OPTARG" ;;
            l) location="$OPTARG" ;;
            p) parameters_file="$OPTARG" ;;
            h) usage ;;
            *) usage ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$resource_group" ] || [ -z "$location" ]; then
        print_error "Missing required arguments"
        usage
    fi
    
    check_prerequisites
    
    print_info "Starting infrastructure deployment..."
    echo "Configuration:"
    echo "  Resource Group: $resource_group"
    echo "  Location: $location"
    echo "  Parameters File: $parameters_file"
    echo ""
    
    # Create resource group if it doesn't exist
    print_info "Creating resource group..."
    az group create \
        --name "$resource_group" \
        --location "$location" \
        --output table
    
    print_success "Resource group created/verified"
    
    # Deploy infrastructure
    print_info "Deploying infrastructure (this may take several minutes)..."
    
    deployment_output=$(az deployment group create \
        --resource-group "$resource_group" \
        --template-file main.bicep \
        --parameters "@${parameters_file}" \
        --output json)
    
    print_success "Infrastructure deployment completed!"
    echo ""
    
    # Extract and display outputs
    print_info "Deployment outputs:"
    echo "$deployment_output" | jq -r '.properties.outputs | to_entries[] | "  \(.key): \(.value.value)"'
    
    echo ""
    print_success "Deployment complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Note the storage account names and regions from the outputs above"
    echo "  2. SSH to the VM using: ssh azureuser@<vmPublicIP>"
    echo "  3. Run the blob upload test script on the VM or locally"
}

main "$@"
