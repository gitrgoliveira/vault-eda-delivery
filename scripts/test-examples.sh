#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Test Examples Script
# This script systematically tests all vault_eda examples by running them as background processes
# and generating appropriate test events to verify they work correctly.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXAMPLES_DIR="$PROJECT_ROOT/collections/ansible_collections/gitrgoliveira/vault_eda/examples"
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"myroot"}
TEST_TIMEOUT=${TEST_TIMEOUT:-15}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Arrays to track background processes
declare -a RULEBOOK_PIDS=()
declare -a RULEBOOK_LOGS=()

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

print_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# Cleanup function
cleanup() {
    print_warning "Cleaning up background processes..."
    for pid in "${RULEBOOK_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            print_status "Stopping rulebook process $pid"
            kill "$pid" 2>/dev/null || true
        fi
    done
    
    # Clean up any remaining ansible-rulebook processes
    pkill -f ansible-rulebook 2>/dev/null || true
    
    print_status "Cleanup complete"
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if we're in the project root
    if [[ ! -f "$PROJECT_ROOT/ansible.cfg" ]]; then
        print_error "Must be run from project root or script must be in scripts/ directory"
        exit 1
    fi
    
    # Check if Vault is running
    if ! vault status > /dev/null 2>&1; then
        print_error "Vault is not running. Start with: make start-vault"
        exit 1
    fi
    
    # Check if virtual environment exists and activate it
    if [[ ! -d "$PROJECT_ROOT/.venv" ]]; then
        print_error "Virtual environment not found. Run: make setup-env"
        exit 1
    fi
    
    # Check Java environment for ansible-rulebook
    if [[ -z "$JAVA_HOME" ]]; then
        print_warning "JAVA_HOME not set. Setting up Java environment..."
        export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
        export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
        export DYLD_LIBRARY_PATH="$JAVA_HOME/lib/server:$DYLD_LIBRARY_PATH"
    fi
    
    print_status "Prerequisites check complete"
}

# Function to start a rulebook in background
start_rulebook() {
    local example_name="$1"
    local rulebook_file="$EXAMPLES_DIR/$example_name"
    local inventory_file="$EXAMPLES_DIR/inventory.yml"
    local log_file="$PROJECT_ROOT/${example_name%.yml}.log"
    
    print_action "Starting rulebook: $example_name"
    
    # Activate virtual environment and start rulebook
    cd "$PROJECT_ROOT"
    source .venv/bin/activate
    
    # Start ansible-rulebook in background
    ansible-rulebook \
        -i "$inventory_file" \
        -r "$rulebook_file" \
        --env-vars VAULT_ADDR,VAULT_TOKEN \
        --verbose > "$log_file" 2>&1 &
    
    local pid=$!
    RULEBOOK_PIDS+=("$pid")
    RULEBOOK_LOGS+=("$log_file")
    
    print_status "Started $example_name with PID $pid, logging to $log_file"
    
    # Give it time to start up
    sleep 5
    
    # Check if it's still running
    if ! kill -0 "$pid" 2>/dev/null; then
        print_error "Rulebook $example_name failed to start. Check $log_file"
        tail -20 "$log_file"
        return 1
    fi
    
    # Check if it connected successfully
    if grep -q "Connected to Vault WebSocket" "$log_file"; then
        print_status "✓ $example_name connected to Vault successfully"
        return 0
    elif grep -q "ERROR" "$log_file"; then
        print_error "✗ $example_name has errors. Check $log_file"
        tail -20 "$log_file"
        return 1
    else
        print_warning "? $example_name status unclear, continuing..."
        return 0
    fi
}

# Function to generate test events
generate_test_events() {
    print_test "Generating comprehensive test events..."
    
    # Set environment
    export VAULT_ADDR
    export VAULT_TOKEN
    
    # Event 1: Write event for basic monitoring
    print_test "1. Creating KV write event"
    vault kv put secret/test/basic-write username=testuser password=secret123
    sleep 2
    
    # Event 2: High-value secret (for production monitoring)
    print_test "2. Creating high-value secret event"
    vault kv put secret/prod/database host=prod-db.company.com username=dbadmin password=prodpass123
    sleep 2
    
    # Event 3: API key secret (for production monitoring)
    print_test "3. Creating API key secret event"
    vault kv put secret/api-keys/stripe key=sk_live_123456789 webhook_secret=whsec_abcdefgh
    sleep 2
    
    # Event 4: Patch operation
    print_test "4. Creating patch event"
    vault kv patch secret/test/basic-write department=engineering last_login="$(date)"
    sleep 2
    
    # Event 5: Delete operation
    print_test "5. Creating delete event"
    vault kv put secret/temp/delete-test data=temporary
    sleep 1
    vault kv delete secret/temp/delete-test
    sleep 2
    
    # Event 6: Metadata operation
    print_test "6. Creating metadata event"
    vault kv metadata put -max-versions=10 secret/test/basic-write
    sleep 2
    
    # Event 7: Standard operation (non-sensitive path)
    print_test "7. Creating standard operation event"
    vault kv put secret/dev/config debug=true log_level=info
    sleep 2
    
    print_test "Test event generation complete"
}

# Function to check for critical errors in logs
check_for_critical_errors() {
    local example_name="$1"
    local log_file="$2"
    
    # Define critical error patterns (excluding acceptable warnings)
    local critical_patterns=(
        "Traceback"
        "FATAL"
        "CRITICAL"
        "Connection refused"
        "Authentication failed"
        "Permission denied"
        "Failed to connect"
        "WebSocket.*closed unexpectedly"
        "Unable to.*subscribe"
        "Plugin.*failed to initialize"
        "Unhandled exception"
        "Process.*died"
    )
    
    # Define acceptable warning patterns that should not cause failure
    local acceptable_patterns=(
        "ConstraintEvaluationException"
        "Warning.*deprecated"
        "UserWarning"
    )
    
    print_test "Checking for critical errors in $example_name..."
    
    # Check for critical errors
    local critical_errors=0
    for pattern in "${critical_patterns[@]}"; do
        if grep -q -i "$pattern" "$log_file" 2>/dev/null; then
            print_error "Critical error detected in $example_name: $pattern"
            grep -i "$pattern" "$log_file" | head -3 | while read -r line; do
                echo "  WARNING: $line"
            done
            critical_errors=$((critical_errors + 1))
        fi
    done
    
    # Check for generic ERROR messages, but filter out acceptable ones
    local error_lines
    error_lines=$(grep -i "ERROR" "$log_file" 2>/dev/null || echo "")
    
    if [[ -n "$error_lines" ]]; then
        local filtered_errors=""
        while IFS= read -r line; do
            local is_acceptable=false
            for acceptable in "${acceptable_patterns[@]}"; do
                if echo "$line" | grep -q -i "$acceptable"; then
                    is_acceptable=true
                    break
                fi
            done
            
            if [[ "$is_acceptable" == false ]]; then
                filtered_errors="$filtered_errors$line\n"
                critical_errors=$((critical_errors + 1))
            fi
        done <<< "$error_lines"
        
        if [[ -n "$filtered_errors" && "$filtered_errors" != "\n" ]]; then
            print_error "Unfiltered errors detected in $example_name:"
            echo -e "$filtered_errors" | head -5 | while read -r line; do
                [[ -n "$line" ]] && echo "  ERROR: $line"
            done
        fi
    fi
    
    if [[ "$critical_errors" -gt 0 ]]; then
        print_error "✗ $example_name has $critical_errors critical errors"
        return 1
    else
        print_status "✓ No critical errors detected in $example_name"
        return 0
    fi
}

# Function to check rulebook logs for expected events
check_rulebook_results() {
    local example_name="$1"
    local log_file="$2"
    
    print_test "Checking results for $example_name..."
    
    # First check for critical errors
    if ! check_for_critical_errors "$example_name" "$log_file"; then
        return 1
    fi
    
    # Count events captured
    local event_count
    event_count=$(grep -c "KV Write Event\|SECRET DELETED\|HIGH-VALUE SECRET\|Standard operation\|WRITE OPERATION\|New secret created\|Secret updated\|Secret WRITTEN\|Secret DELETED\|Secret PATCHED\|Plugin activity\|Patch operation" "$log_file" 2>/dev/null || echo "0")
    
    if [[ "$event_count" -gt 0 ]]; then
        print_status "✓ $example_name captured $event_count events"
        
        # Show some sample events
        print_status "Sample events from $example_name:"
        grep -E "KV Write Event|SECRET DELETED|HIGH-VALUE SECRET|Standard operation|WRITE OPERATION|New secret created|Secret updated|Secret WRITTEN|Secret DELETED|Secret PATCHED|Plugin activity|Patch operation" "$log_file" | head -3 | while read -r line; do
            echo "  → $line"
        done
        
        return 0
    else
        print_warning "? $example_name captured no recognizable events"
        
        # Show recent log entries to help debug
        print_warning "Recent log entries:"
        tail -10 "$log_file" | while read -r line; do
            echo "  $line"
        done
        
        return 1
    fi
}

# Function to test a specific example
test_example() {
    local example_name="$1"
    local description="$2"
    
    echo
    echo "=========================================="
    echo "Testing: $example_name"
    echo "Description: $description"
    echo "=========================================="
    
    # Start the rulebook
    if ! start_rulebook "$example_name"; then
        print_error "Failed to start $example_name"
        return 1
    fi
    
    # Generate test events
    generate_test_events
    
    # Wait a bit for events to be processed
    sleep 3
    
    # Check results
    local log_file="${example_name%.yml}.log"
    local test_result=0
    if ! check_rulebook_results "$example_name" "$PROJECT_ROOT/$log_file"; then
        print_error "✗ $example_name failed result check"
        test_result=1
    fi
    
    # Stop this rulebook
    local pid_count=${#RULEBOOK_PIDS[@]}
    if [[ $pid_count -gt 0 ]]; then
        local pid="${RULEBOOK_PIDS[$((pid_count-1))]}"
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_status "Stopped $example_name"
        fi
        
        # Remove from tracking arrays
        unset 'RULEBOOK_PIDS[$((pid_count-1))]'
        unset 'RULEBOOK_LOGS[$((pid_count-1))]'
    fi
    
    # Return the test result
    return $test_result
}

# Main test execution
main() {
    echo "=========================================="
    echo "     Vault EDA Examples Test Suite"
    echo "=========================================="
    echo
    
    # Set environment
    export VAULT_ADDR
    export VAULT_TOKEN
    
    check_prerequisites
    
    # Define examples to test (using indexed arrays instead)
    local examples_names=("basic-monitoring.yml" "enhanced-filtering.yml" "filter-monitoring.yml" "production-monitoring.yml")
    local examples_descriptions=(
        "Basic monitoring of KV operations"
        "Enhanced filtering with metadata" 
        "Server-side filtering demonstration"
        "Production-ready monitoring with comprehensive rules"
    )
    
    local total_tests=0
    local passed_tests=0
    
    # Test each example
    for i in "${!examples_names[@]}"; do
        local example_name="${examples_names[$i]}"
        local description="${examples_descriptions[$i]}"
        
        if [[ -f "$EXAMPLES_DIR/$example_name" ]]; then
            total_tests=$((total_tests + 1))
            
            if test_example "$example_name" "$description"; then
                passed_tests=$((passed_tests + 1))
            fi
        else
            print_warning "Example file not found: $example_name"
        fi
    done
    
    # Summary
    echo
    echo "=========================================="
    echo "           Test Results Summary"
    echo "=========================================="
    echo "Total tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $((total_tests - passed_tests))"
    
    if [[ "$passed_tests" -eq "$total_tests" ]]; then
        print_status "All examples are working correctly!"
        echo
        print_status "Log files created:"
        for log in basic-monitoring.log enhanced-filtering.log filter-monitoring.log production-monitoring.log; do
            if [[ -f "$PROJECT_ROOT/$log" ]]; then
                echo "  - $log"
                # Check for acceptable warnings
                local warning_count
                warning_count=$(grep -c -i "ConstraintEvaluationException" "$PROJECT_ROOT/$log" 2>/dev/null || echo "0")
                if [[ "$warning_count" -gt 0 ]]; then
                    echo "    (Contains $warning_count acceptable warnings)"
                fi
            fi
        done
        
        return 0
    else
        print_error "Some examples failed. Check the log files for details."
        echo
        print_error "Failed examples analysis:"
        for log in basic-monitoring.log enhanced-filtering.log filter-monitoring.log production-monitoring.log; do
            if [[ -f "$PROJECT_ROOT/$log" ]]; then
                local critical_errors
                critical_errors=$(grep -i -E "Traceback|FATAL|CRITICAL|Connection refused|Authentication failed" "$PROJECT_ROOT/$log" 2>/dev/null | wc -l)
                if [[ "$critical_errors" -gt 0 ]]; then
                    echo "  - $log: $critical_errors critical errors detected"
                fi
            fi
        done
        
        return 1
    fi
}

# Run main function
main "$@"