#!/bin/bash

# Blob Upload Latency Test Script
# Tests blob upload performance to two different Azure regions

set -e

# Default values
FILE_SIZE_MB=${FILE_SIZE_MB:-100}
TEST_FILE="test-file-${FILE_SIZE_MB}mb.bin"
CONTAINER_NAME=${CONTAINER_NAME:-"latency-test"}

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
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

# Function to generate test file
generate_test_file() {
    if [ -f "$TEST_FILE" ]; then
        print_warning "Test file already exists: $TEST_FILE"
        return
    fi
    
    print_info "Generating test file of ${FILE_SIZE_MB}MB..."
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count=$FILE_SIZE_MB status=progress 2>&1 | tail -1
    print_success "Test file generated: $TEST_FILE ($(du -h "$TEST_FILE" | cut -f1))"
}

# Function to upload blob and measure performance
upload_and_measure() {
    local storage_account=$1
    local region=$2
    local blob_name="test-blob-$(date +%s).bin"
    
    print_info "Testing upload to $region (Storage Account: $storage_account)..."
    
    # Create container if it doesn't exist
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$storage_account" \
        --auth-mode login \
        --only-show-errors > /dev/null 2>&1 || true
    
    # Measure upload time
    local start_time=$(date +%s.%N)
    
    az storage blob upload \
        --container-name "$CONTAINER_NAME" \
        --file "$TEST_FILE" \
        --name "$blob_name" \
        --account-name "$storage_account" \
        --auth-mode login \
        --only-show-errors \
        --overwrite
    
    local end_time=$(date +%s.%N)
    
    # Calculate duration and speed
    local duration=$(echo "$end_time - $start_time" | bc)
    local file_size_bytes=$(stat -f%z "$TEST_FILE" 2>/dev/null || stat -c%s "$TEST_FILE")
    local file_size_mb=$(echo "scale=2; $file_size_bytes / 1024 / 1024" | bc)
    local speed_mbps=$(echo "scale=2; ($file_size_mb * 8) / $duration" | bc)
    local speed_MBps=$(echo "scale=2; $file_size_mb / $duration" | bc)
    
    echo ""
    print_success "Upload completed to $region"
    echo "  Region: $region"
    echo "  Storage Account: $storage_account"
    echo "  File Size: ${file_size_mb} MB"
    echo "  Duration: ${duration} seconds"
    echo "  Speed: ${speed_MBps} MB/s (${speed_mbps} Mbps)"
    echo ""
    
    # Clean up uploaded blob
    print_info "Cleaning up uploaded blob..."
    az storage blob delete \
        --container-name "$CONTAINER_NAME" \
        --name "$blob_name" \
        --account-name "$storage_account" \
        --auth-mode login \
        --only-show-errors > /dev/null
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -a <storage_account_1> -r <region_1> -b <storage_account_2> -s <region_2> [-f <file_size_mb>]

Options:
    -a    First storage account name
    -r    First region name (e.g., eastus)
    -b    Second storage account name
    -s    Second region name (e.g., westus)
    -f    File size in MB (default: 100)
    -h    Display this help message

Environment Variables:
    FILE_SIZE_MB        Size of test file in MB (default: 100)
    CONTAINER_NAME      Container name for uploads (default: latency-test)

Example:
    $0 -a storage1eastus -r eastus -b storage1westus -s westus -f 50

EOF
    exit 1
}

# Main script
main() {
    local storage_account_1=""
    local region_1=""
    local storage_account_2=""
    local region_2=""
    
    # Parse command line arguments
    while getopts "a:r:b:s:f:h" opt; do
        case $opt in
            a) storage_account_1="$OPTARG" ;;
            r) region_1="$OPTARG" ;;
            b) storage_account_2="$OPTARG" ;;
            s) region_2="$OPTARG" ;;
            f) FILE_SIZE_MB="$OPTARG" ;;
            h) usage ;;
            *) usage ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$storage_account_1" ] || [ -z "$region_1" ] || [ -z "$storage_account_2" ] || [ -z "$region_2" ]; then
        print_error "Missing required arguments"
        usage
    fi
    
    # Update test file name with size
    TEST_FILE="test-file-${FILE_SIZE_MB}mb.bin"
    
    print_info "Starting Blob Upload Latency Test"
    echo "Configuration:"
    echo "  Region 1: $region_1 ($storage_account_1)"
    echo "  Region 2: $region_2 ($storage_account_2)"
    echo "  Test File Size: ${FILE_SIZE_MB}MB"
    echo ""
    
    check_prerequisites
    generate_test_file
    
    echo "=================================================="
    echo "Starting Upload Tests"
    echo "=================================================="
    echo ""
    
    # Test upload to first region
    upload_and_measure "$storage_account_1" "$region_1"
    
    # Test upload to second region
    upload_and_measure "$storage_account_2" "$region_2"
    
    echo "=================================================="
    print_success "All tests completed!"
    echo "=================================================="
    
    # Clean up test file
    print_info "Cleaning up test file..."
    rm -f "$TEST_FILE"
    print_success "Test file removed"
}

main "$@"
