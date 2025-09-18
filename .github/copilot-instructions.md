# Copilot Instructions for Vault Event-Driven Automation

## Project Overview

This project provides **agentless rotation of HashiCorp Vault secrets** using Ansible Event-Driven Automation (EDA). It consists of a custom WebSocket plugin that connects to Vault Enterprise's `/v1/sys/events/subscribe` endpoint for real-time secret rotation workflows.

## Key Architecture Patterns

### 1. Ansible Collection Structure
- **Plugin Location**: `collections/ansible_collections/gitrgoliveira/vault/plugins/event_source/vault_events.py`
- **Collection Manifest**: `collections/ansible_collections/gitrgoliveira/vault/galaxy.yml`
- **Entry Point**: The `main()` function is called by ansible-rulebook with `(queue, args)` parameters
- **Multiple WebSocket Connections**: Each event pattern in `event_paths` creates a separate WebSocket connection (Vault API limitation)

### 2. Environment Variable Integration
- Uses `ansible-rulebook --env-vars VAULT_ADDR,VAULT_TOKEN` pattern for dynamic configuration
- Rulebook references: `{{ VAULT_ADDR | default('http://127.0.0.1:8200') }}`
- **Critical**: Only use officially supported event types: `kv-v1/*`, `kv-v2/*`, `database/*`

### 3. WebSocket Event Processing
```python
# Pattern: Separate connections per event pattern
await _stream_multiple_patterns(queue, vault_addr, event_paths, ...)

# Pattern: Event structure follows CloudEvents specification
event = {
    "data": {
        "event_type": "kv-v2/data-write",
        "event": {"metadata": {"path": "...", "operation": "..."}},
        "plugin_info": {"plugin": "...", "mount_path": "..."}
    }
}
```

## Development Workflow Commands

### Essential Makefile Targets
```bash
# Complete development setup
make setup-env && make start-vault && make run-rulebook-bg && make test-events

# Background process management (with PID tracking)
make run-rulebook-bg    # Starts with PID in rulebook.pid
make stop-rulebook      # Kills using stored PID
tail -f rulebook.log    # View live logs

# Vault Enterprise management
make start-vault        # Dev mode with token 'myroot'
make status-vault       # Check if running + health check
```

### Java/JNI Requirements
ansible-rulebook requires specific Java environment setup:
```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export DYLD_LIBRARY_PATH="$JAVA_HOME/lib/server:$DYLD_LIBRARY_PATH"
```

## Project-Specific Conventions

### 1. Enterprise-Only Focus
- **Vault Enterprise/HCP Vault Dedicated only** - Community Edition lacks event streaming
- All documentation emphasizes Enterprise requirements
- Event types limited to officially supported ones only

### 2. Event Structure Patterns
```yaml
# Rulebook condition patterns
condition: event.data.event_type == "kv-v2/data-write"
condition: event.data.event_type is match("database/.*")

# Message access patterns  
Path: {{ event.data.event.metadata.path }}
Operation: {{ event.data.event.metadata.operation }}
Plugin: {{ event.data.plugin_info.plugin | default('N/A') }}
```

### 3. Collection Release Process
- Version in `galaxy.yml` must match git tag and workflow input
- GitHub Actions workflow: Manual dispatch or tag-based triggers
- Requires `GALAXY_API_KEY` secret for Ansible Galaxy publishing

## Critical Integration Points

### WebSocket API Constraints
- **One pattern per connection**: Multiple `event_paths` = multiple WebSocket connections
- **Supported events only**: `kv-v1/*`, `kv-v2/*`, `database/*` (auth/policy events removed)
- **Enterprise requirement**: `/v1/sys/events/subscribe` endpoint availability

### ACL Policy Requirements
```hcl
# Event subscription capability
path "sys/events/subscribe/*" { capabilities = ["read"] }

# Secret access for rotation
path "secret/data/*" { 
    capabilities = ["list", "subscribe", "read", "update"]
    subscribe_event_types = ["kv-v2/*"] 
}
```

### Error Handling Patterns
- Exponential backoff for WebSocket reconnection
- JSON parsing with graceful fallback to raw message
- PID-based process management for background services

## Testing and Debugging

### Event Generation Script
`scripts/generate-vault-events.sh` creates comprehensive test events:
- KV operations: write, patch, delete, metadata, undelete, destroy
- Interactive prompts with countdown timers
- Colored output for clear status indication

### Debug Patterns
- All rules include debug actions with structured messages
- Log analysis: Events logged with timestamps and structured format
- WebSocket connection status logged with pattern identification

## Dependencies and Versions
- **ansible-core**: >=2.14 (specified in `meta/runtime.yml`)
- **websockets**: >=10.0 (WebSocket library requirement)
- **Python**: 3.7+ with asyncio support
- **Java**: Required for ansible-rulebook (JNI bridge)

When working on this codebase, always verify Vault Enterprise availability and test with multiple event patterns to ensure proper WebSocket connection handling.