#!/bin/bash

# Deploy Conduit Cluster
# Creates 5 nodes and installs Conduit on all of them

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Number of nodes to create
NUM_NODES=5

print_header "CONDUIT CLUSTER DEPLOYMENT"

echo "This script will:"
echo "  • Create $NUM_NODES new servers in Hetzner Cloud"
echo "  • Install Conduit on each server"
echo "  • Configure them with default settings"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

print_header "Step 1/2: Creating $NUM_NODES Servers"

SERVER_IDS=()

for i in $(seq 1 $NUM_NODES); do
    print_info "Creating server $i/$NUM_NODES..."

    # Create server and capture output
    OUTPUT=$(./hetzner create 2>&1)

    # Extract server ID from output (look for "ID: <number>")
    SERVER_ID=$(echo "$OUTPUT" | grep -oE "ID:\s+[0-9]+" | grep -oE "[0-9]+" | head -n 1)

    if [ -n "$SERVER_ID" ]; then
        SERVER_IDS+=("$SERVER_ID")
        print_success "Server $i created with ID: $SERVER_ID"
    else
        echo "$OUTPUT"
        echo -e "${RED}Failed to create server $i${NC}"
        exit 1
    fi

    # Small delay to avoid API rate limits
    sleep 2
done

echo ""
print_success "All $NUM_NODES servers created successfully!"
echo ""
echo "Server IDs: ${SERVER_IDS[@]}"

print_header "Step 2/2: Installing Conduit on All Servers"

for i in "${!SERVER_IDS[@]}"; do
    SERVER_ID="${SERVER_IDS[$i]}"
    NUM=$((i + 1))

    print_info "Installing Conduit on server $NUM/$NUM_NODES (ID: $SERVER_ID)..."

    ./hetzner run "$SERVER_ID" > /dev/null 2>&1 &
    INSTALL_PID=$!

    # Wait for installation with a spinner
    SPIN='-\|/'
    j=0
    while kill -0 $INSTALL_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${SPIN:$i:1} Installing Conduit on server $NUM/$NUM_NODES..."
        sleep 0.5
    done

    wait $INSTALL_PID
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        printf "\r"
        print_success "Conduit installed on server $NUM/$NUM_NODES (ID: $SERVER_ID)"
    else
        printf "\r"
        echo -e "${RED}Failed to install Conduit on server $NUM${NC}"
    fi

    sleep 2
done

print_header "DEPLOYMENT COMPLETE!"

echo "Cluster Summary:"
echo "  Total Servers: $NUM_NODES"
echo "  Server IDs: ${SERVER_IDS[@]}"
echo ""
echo "Next steps:"
echo "  • View all servers:  ./hetzner list"
echo "  • Check stats:       ./hetzner report"
echo "  • View individual:   ./hetzner stats <id>"
echo ""
print_success "Conduit cluster is ready!"
