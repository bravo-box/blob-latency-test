#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SERVICE_SUFFIX=${SERVICE_SUFFIX:-"blob.core.usgovcloudapi.net"}
MTR_CYCLES=${MTR_CYCLES:-5}

RESOLVE_DNS=true
LOG_ENABLED=true
OUTPUT_FILE=""
TRACE_TOOL=""

STORAGE_ACCOUNTS=()
HOST_TARGETS=()
TARGETS=()

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

  -s <storage-account>   Add a storage account (expands to <name>.${SERVICE_SUFFIX})
  -H <hostname-or-ip>    Add a fully qualified hostname or IP
  -d <dns-suffix>        Override the DNS suffix for storage accounts
  -c <cycles>            Probe cycles per target when using mtr (default: ${MTR_CYCLES})
  -o <path>              Write hop report to this file (default: ./network-hops-<timestamp>.log)
  -L                     Disable log file output (console only)
  -n                     Skip DNS lookups (--no-dns / -n)
  -h                     Show this help

Environment:
  SERVICE_SUFFIX   Default storage endpoint suffix
  MTR_CYCLES       Default cycle count for mtr

At least one -s or -H value is required.
EOF
    exit 1
}

trim() {
    local val="$1"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    printf '%s' "$val"
}

ensure_positive_integer() {
    if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -eq 0 ]; then
        print_error "$2 must be a positive integer"
        exit 1
    fi
}

detect_trace_tool() {
    if command -v mtr >/dev/null 2>&1; then
        TRACE_TOOL="mtr"
    elif command -v traceroute >/dev/null 2>&1; then
        TRACE_TOOL="traceroute"
    else
        print_error "Install 'mtr' (preferred) or 'traceroute' to capture hops."
        exit 1
    fi
}

prepare_targets() {
    for raw in "${STORAGE_ACCOUNTS[@]}"; do
        local acct
        acct=$(trim "$raw")
        [ -z "$acct" ] && continue
        TARGETS+=("${acct}.${SERVICE_SUFFIX}")
    done
    for raw in "${HOST_TARGETS[@]}"; do
        local host
        host=$(trim "$raw")
        [ -z "$host" ] && continue
        TARGETS+=("$host")
    done
}

setup_logging() {
    [ "$LOG_ENABLED" = true ] || return
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="network-hops-$(date +%Y%m%d-%H%M%S).log"
    fi
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    {
        echo "Blob Latency Test - Network Hop Report ($(date -u))"
        echo "Targets: ${TARGETS[*]}"
        echo ""
    } > "$OUTPUT_FILE"
    print_info "Logging hop output to $OUTPUT_FILE"
}

run_trace() {
    local target="$1"
    if [ "$TRACE_TOOL" = "mtr" ]; then
        local mtr_flags=(--report --report-cycles "$MTR_CYCLES")
        [ "$RESOLVE_DNS" = false ] && mtr_flags+=(--no-dns)
        mtr "${mtr_flags[@]}" "$target"
    else
        local traceroute_flags=()
        [ "$RESOLVE_DNS" = false ] && traceroute_flags+=(-n)
        traceroute "${traceroute_flags[@]}" "$target"
    fi
}

log_block() {
    if [ "$LOG_ENABLED" = true ]; then
        tee -a "$OUTPUT_FILE"
    else
        cat
    fi
}

main() {
    while getopts "s:H:c:d:o:nLh" opt; do
        case $opt in
            s) STORAGE_ACCOUNTS+=("$OPTARG") ;;
            H) HOST_TARGETS+=("$OPTARG") ;;
            c) ensure_positive_integer "$OPTARG" "Probe cycles"; MTR_CYCLES="$OPTARG" ;;
            d) SERVICE_SUFFIX="$OPTARG" ;;
            o) OUTPUT_FILE="$OPTARG" ;;
            n) RESOLVE_DNS=false ;;
            L) LOG_ENABLED=false ;;
            h) usage ;;
            *) usage ;;
        esac
    done

    prepare_targets
    if [ "${#TARGETS[@]}" -eq 0 ]; then
        print_error "Provide at least one storage account (-s) or hostname (-H)."
        usage
    fi

    detect_trace_tool
    setup_logging
    [ "$LOG_ENABLED" = false ] && print_warning "Log file disabled; output shown only on console."

    print_info "Using ${TRACE_TOOL} to trace ${#TARGETS[@]} target(s)"
    local total=${#TARGETS[@]}
    local idx=1
    for target in "${TARGETS[@]}"; do
        if [ "$LOG_ENABLED" = true ]; then
            {
                echo ""
                echo "===== [$idx/$total] $target ====="
                if ! run_trace "$target"; then
                    print_warning "Hop capture failed for $target (see console for details)"
                fi
            } | log_block
        else
            echo ""
            echo "===== [$idx/$total] $target ====="
            if ! run_trace "$target"; then
                print_warning "Hop capture failed for $target"
            fi
        fi
        idx=$((idx + 1))
    done

    if [ "$LOG_ENABLED" = true ]; then
        echo "" | log_block
        print_success "Network hop report saved to $OUTPUT_FILE"
    else
        print_success "Network hop capture completed"
    fi
}

main "$@"