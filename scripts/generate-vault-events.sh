
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#!/bin/bash

# Vault Event Generator Script
# This script generates various KV events to test the rulebook

set -e

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"myroot"}
SECRET_PATH="secret/data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_action() {
    echo -e "${BLUE}[ACTION]${NC} $1"
}

# Check if Vault is running and accessible
check_vault() {
    print_status "Checking Vault connectivity..."
    if ! vault status > /dev/null 2>&1; then
        print_error "Cannot connect to Vault at $VAULT_ADDR"
        print_error "Make sure Vault is running: make start-vault"
        exit 1
    fi
    print_status "Vault is accessible!"
}

# Wait function with countdown
wait_with_countdown() {
    local seconds=$1
    local message=$2
    echo -n "$message "
    for ((i=seconds; i>0; i--)); do
        echo -n "$i "
        sleep 1
    done
    echo ""
}

# Generate write events
generate_write_events() {
    print_action "Generating KV write events..."
    
    # Event 1: Write user credentials
    print_status "Writing secret: $SECRET_PATH/users/john"
    vault kv put secret/users/john username=john password=secret123 email=john@example.com
    wait_with_countdown 2 "Waiting for event processing..."
    
    # Event 2: Write database config
    print_status "Writing secret: $SECRET_PATH/db/config"
    vault kv put secret/db/config host=localhost port=5432 database=myapp username=dbuser password=dbpass123
    wait_with_countdown 2 "Waiting for event processing..."
    
    # Event 3: Write API keys
    print_status "Writing secret: $SECRET_PATH/api/keys"
    vault kv put secret/api/keys stripe_key=sk_test_123 github_token=ghp_456 aws_access_key=AKIA789
    wait_with_countdown 2 "Waiting for event processing..."
    
    # Event 4: Update existing secret
    print_status "Updating secret: $SECRET_PATH/users/john"
    vault kv put secret/users/john username=john password=newpass456 email=john.doe@example.com department=engineering
    wait_with_countdown 2 "Waiting for event processing..."
}

# Generate patch events (if supported)
generate_patch_events() {
    print_action "Generating KV patch events..."
    
    # Patch operation (KV v2 feature)
    print_status "Patching secret: $SECRET_PATH/users/john"
    vault kv patch secret/users/john last_login="$(date)" status=active
    wait_with_countdown 2 "Waiting for event processing..."
}

# Generate delete events
generate_delete_events() {
    print_action "Generating KV delete events..."
    
    # Create a secret to delete
    print_status "Creating temporary secret for deletion test..."
    vault kv put secret/temp/delete-me data=temporary
    wait_with_countdown 1 "Secret created, now deleting..."
    
    # Delete the secret
    print_status "Deleting secret: $SECRET_PATH/temp/delete-me"
    vault kv delete secret/temp/delete-me
    wait_with_countdown 2 "Waiting for event processing..."
    
    # Delete another existing secret
    print_status "Deleting secret: $SECRET_PATH/api/keys"
    vault kv delete secret/api/keys
    wait_with_countdown 2 "Waiting for event processing..."
}

# Generate metadata events
generate_metadata_events() {
    print_action "Generating KV metadata events..."
    
    # Update metadata
    print_status "Updating metadata for secret: $SECRET_PATH/users/john"
    vault kv metadata put secret/users/john max-versions=10 delete-version-after=720h
    wait_with_countdown 2 "Waiting for event processing..."
}

# Generate undelete events
generate_undelete_events() {
    print_action "Generating KV undelete events..."
    
    # Undelete a previously deleted secret
    print_status "Undeleting secret: $SECRET_PATH/temp/delete-me"
    vault kv undelete -versions=1 secret/temp/delete-me
    wait_with_countdown 2 "Waiting for event processing..."
}

# Generate destroy events (permanent deletion)
generate_destroy_events() {
    print_action "Generating KV destroy events..."
    
    # Permanently destroy secret versions
    print_status "Destroying secret versions: $SECRET_PATH/temp/delete-me"
    vault kv destroy -versions=1 secret/temp/delete-me
    wait_with_countdown 2 "Waiting for event processing..."
}

# Main execution
main() {
    echo "=========================================="
    echo "     Vault Event Generator"
    echo "=========================================="
    echo
    
    # Set environment
    export VAULT_ADDR
    export VAULT_TOKEN
    
    # Check prerequisites
    check_vault
    
    echo
    print_status "Starting event generation sequence..."
    print_warning "Make sure your rulebook is running in another terminal!"
    print_warning "Run: make run-rulebook"
    echo
    
    # Give user time to start rulebook
    read -p "Press Enter when your rulebook is running and ready to receive events..."
    
    # Generate different types of events
    generate_write_events
    echo
    
    generate_patch_events
    echo
    
    generate_metadata_events
    echo
    
    generate_delete_events
    echo
    
    generate_undelete_events
    echo
    
    generate_destroy_events
    echo
    
    print_status "Event generation complete!"
    print_status "Check your rulebook output to see the captured events."
    
    echo
    echo "=========================================="
    echo "     Event Generation Summary"
    echo "=========================================="
    echo "✓ Write events: 4 secrets created/updated"
    echo "✓ Patch events: 1 secret patched"
    echo "✓ Metadata events: 1 metadata update"
    echo "✓ Delete events: 2 secrets deleted"
    echo "✓ Undelete events: 1 secret restored"
    echo "✓ Destroy events: 1 secret permanently destroyed"
    echo
    print_status "To generate more events, run this script again!"
}

# Run main function
main "$@"
