#!/bin/bash

# Hetzner Cloud Node Creation Script
# This script creates a new server on Hetzner Cloud using their API

set -e

# Configuration - Set these before running
HETZNER_API_TOKEN="${HETZNER_API_TOKEN:-}"
SERVER_NAME="${SERVER_NAME:-node-$(date +%s)}"
SERVER_TYPE="${SERVER_TYPE:-cx11}"  # smallest/cheapest instance
LOCATION="${LOCATION:-nbg1}"         # Nuremberg datacenter
IMAGE="${IMAGE:-ubuntu-22.04}"       # OS image
SSH_KEY_NAME="${SSH_KEY_NAME:-}"     # Optional: name of SSH key already in Hetzner

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if API token is set
if [ -z "$HETZNER_API_TOKEN" ]; then
    print_error "HETZNER_API_TOKEN is not set"
    echo "Please set your Hetzner Cloud API token:"
    echo "  export HETZNER_API_TOKEN='your-api-token-here'"
    echo ""
    echo "You can create an API token at: https://console.hetzner.cloud/"
    exit 1
fi

# Base URL for Hetzner Cloud API
API_BASE="https://api.hetzner.cloud/v1"

# Build the JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "name": "$SERVER_NAME",
  "server_type": "$SERVER_TYPE",
  "location": "$LOCATION",
  "image": "$IMAGE",
  "start_after_create": true
}
EOF
)

# Add SSH key if specified
if [ -n "$SSH_KEY_NAME" ]; then
    print_info "Looking up SSH key: $SSH_KEY_NAME"
    SSH_KEY_ID=$(curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
        "$API_BASE/ssh_keys" | \
        jq -r ".ssh_keys[] | select(.name==\"$SSH_KEY_NAME\") | .id")

    if [ -n "$SSH_KEY_ID" ]; then
        print_info "Found SSH key with ID: $SSH_KEY_ID"
        JSON_PAYLOAD=$(echo "$JSON_PAYLOAD" | jq ". + {ssh_keys: [$SSH_KEY_ID]}")
    else
        print_warning "SSH key '$SSH_KEY_NAME' not found, creating server without SSH key"
    fi
fi

print_info "Creating Hetzner Cloud server with the following configuration:"
echo "  Name:        $SERVER_NAME"
echo "  Type:        $SERVER_TYPE"
echo "  Location:    $LOCATION"
echo "  Image:       $IMAGE"
echo ""

# Create the server
RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $HETZNER_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$API_BASE/servers")

# Check if request was successful
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.error.message')
    print_error "Failed to create server: $ERROR_MESSAGE"
    exit 1
fi

# Extract server information
SERVER_ID=$(echo "$RESPONSE" | jq -r '.server.id')
SERVER_IPV4=$(echo "$RESPONSE" | jq -r '.server.public_net.ipv4.ip')
ROOT_PASSWORD=$(echo "$RESPONSE" | jq -r '.root_password')

print_info "Server created successfully!"
echo ""
echo "Server Details:"
echo "  ID:          $SERVER_ID"
echo "  Name:        $SERVER_NAME"
echo "  IPv4:        $SERVER_IPV4"
if [ "$ROOT_PASSWORD" != "null" ] && [ -n "$ROOT_PASSWORD" ]; then
    echo "  Root Pass:   $ROOT_PASSWORD"
fi
echo ""
print_info "Waiting for server to become available..."

# Wait for server to be running
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    STATUS=$(curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
        "$API_BASE/servers/$SERVER_ID" | jq -r '.server.status')

    if [ "$STATUS" = "running" ]; then
        print_info "Server is now running!"
        echo ""
        echo "You can connect to your server using:"
        echo "  ssh root@$SERVER_IPV4"
        exit 0
    fi

    echo -n "."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

print_warning "Server is taking longer than expected to start. Check status manually."
echo "Server ID: $SERVER_ID"
