# Ansible Collection - gitrgoliveira.vault_eda

This collection provides event source plugins for HashiCorp Vault integration with Ansible Event-Driven Automation (EDA) for agentless rotation of Vault secrets through real-time event monitoring.

## Requirements

### Vault Enterprise or HCP Vault Dedicated only

**Important**: This collection requires **HashiCorp Vault Enterprise** or **HCP Vault Dedicated**. Event streaming is **not available** in Vault Community Edition.

- **Vault Enterprise**: Version 1.13+ (enabled by default in 1.16+)
- **HCP Vault Dedicated**: Event streaming supported
- **Vault OSS/Community**: Not supported

## Description

The `gitrgoliveira.vault_eda` collection allows for agentless secret rotation and real-time monitoring of HashiCorp Vault events through WebSocket connections. It provides an event source plugin that connects to Vault's `/v1/sys/events/subscribe` endpoint and processes events in real-time for use with ansible-rulebook to trigger automated secret rotation workflows.

## Features

- **Agentless Secret Rotation**: Automated secret rotation triggered by Vault events.
- **Real-time Event Streaming**: WebSocket connection to Vault's event subscription endpoint.
- **Server-side Event Filtering**: Filter events at the Vault server using go-bexpr boolean expressions.
- **Enterprise Ready**: Built for Vault Enterprise and HCP Vault Dedicated.
- **Flexible Configuration**: Support for environment variables and dynamic configuration.
- **Supported Event Types**: Monitor KV v1, KV v2, and database events.
- **Secure Authentication**: Support for Vault tokens with ACL policies.
- **Auto-Reconnection**: Built-in reconnection logic with exponential backoff.
- **Comprehensive Logging**: Detailed logging for debugging and monitoring.

## Requirements

- **Vault Enterprise 1.13+** or **HCP Vault Dedicated** (event streaming not available in Community Edition)
- Python 3.7+
- ansible-core >= 2.14
- ansible-rulebook >= 1.0.0
- websockets >= 10.0

### Required Vault ACL policies

#### Event subscription policy

```hcl
# Allow subscription to event notifications
path "sys/events/subscribe/*" {
    capabilities = ["read"]
}
```

#### Secret access policy (for rotation workflows)

```hcl
# Allow monitoring and rotation of secrets
path "secret/data/*" {
    capabilities = ["list", "subscribe", "read", "update"]
    subscribe_event_types = ["kv-v2/*"]
}

# For database credential rotation
path "database/creds/*" {
    capabilities = ["list", "subscribe", "read"]
    subscribe_event_types = ["database/*"]
}
```

Apply policies:

```bash
vault policy write eda-automation policy.hcl
vault token create -policy=eda-automation
```

## Installation

```bash
ansible-galaxy collection install gitrgoliveira.vault_eda
```

## Plugins

### Event source plugins

#### vault_events

Monitor HashiCorp Vault events in real-time via WebSocket connection.

**Parameters:**

- `vault_addr` (string, required): Vault server URL (e.g., "http://127.0.0.1:8200")
- `vault_token` (string, required): Vault authentication token
- `event_paths` (list, optional): List of event paths to subscribe to (default: `["kv-v2/data-*"]`). 
  - **IMPORTANT**: Each pattern creates a separate WebSocket connection.
  - **Supported types**: Only `kv-v1/*`, `kv-v2/*`, and `database/*` are officially supported.
  - **Performance tip**: Use broader patterns with wildcards for better performance.
- `verify_ssl` (boolean, optional): Whether to verify SSL certificates (default: `true`).
- `ping_interval` (integer, optional): WebSocket ping interval in seconds (default: 20).
- `backoff_initial` (float, optional): Initial reconnection delay in seconds (default: 1.0).
- `backoff_max` (float, optional): Maximum reconnection delay in seconds (default: 30.0).
- `namespace` (string, optional): Vault namespace for multi-tenant setups
- `headers` (dict, optional): Additional HTTP headers for the connection

**Example usage:**

```yaml
---
- name: Monitor Vault KV Events
  hosts: localhost
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ ansible_env.VAULT_ADDR | default('http://127.0.0.1:8200') }}"
        vault_token: "{{ ansible_env.VAULT_TOKEN }}"
        event_paths:
          - "kv-v2/data-*"
          - "database/*"
        verify_ssl: false
        ping_interval: 30
  
  rules:
    - name: Handle KV Write Events
      condition: event.event_type == "kv-v2/data-write"
      action:
        debug:
          msg: "Secret written to {{ event.data.path }} by {{ event.data.metadata.created_by }}"
    
    - name: Handle Database Events
      condition: event.event_type.startswith("database/")
      action:
        debug:
          msg: "Database event: {{ event.event_type }} - {{ event.data.path | default('N/A') }}"
```

## Environment variables

The plugin supports dynamic configuration through environment variables when used with ansible-rulebook's `--env-vars` flag:

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="your-vault-token"

ansible-rulebook --env-vars VAULT_ADDR,VAULT_TOKEN -i inventory.yml --rulebook vault-monitoring.yml
```

## Event types

The plugin supports officially supported Vault Enterprise event types. For the complete and current list of supported event types, see the [HashiCorp Vault Event Notifications documentation](https://developer.hashicorp.com/vault/docs/concepts/events#event-types).

**Supported categories:**
- **KV v2 Events**: `kv-v2/*` (all KV v2 operations)
- **KV v1 Events**: `kv-v1/*` (all KV v1 operations)  
- **Database Events**: `database/*` (all database operations)

**For detailed event types and metadata**: See the [official event types table](https://developer.hashicorp.com/vault/docs/concepts/events#event-types) in the HashiCorp documentation.

## Troubleshooting

### Connection issues

1. **Verify Vault Enterprise is running and accessible**:
   ```bash
   curl -s $VAULT_ADDR/v1/sys/health
   vault version
   ```

2. **Check token permissions for event subscription**:
   ```bash
   vault token capabilities sys/events/subscribe/kv-v2/data-*
   ```

3. **Check secret access permissions**:
   ```bash
   vault token capabilities secret/data/myapp
   ```

4. **Verify event streaming is available (Enterprise only)**:
   ```bash
   vault events subscribe kv-v2/data-test
   ```

5. **Test event subscription directly**:
   ```bash
   curl -H "X-Vault-Token: $VAULT_TOKEN" \
        $VAULT_ADDR/v1/sys/events/subscribe/kv-v2/data-test
   ```

### Authentication errors

Ensure your Vault token has the necessary permissions:

```bash
# Check token capabilities for event subscription
vault token capabilities sys/events/subscribe/kv-v2/data-*

# Check token capabilities for secret access
vault token capabilities secret/data/*
```

### SSL/TLS issues

For development environments with self-signed certificates:

```yaml
sources:
  - gitrgoliveira.vault_eda.vault_events:
      vault_addr: "https://vault.example.com:8200"
      vault_token: "{{ vault_token }}"
      verify_ssl: false  # Disable SSL verification
```

### Debugging

Enable debug logging in your rulebook:

```yaml
---
- name: Debug Vault Events
  hosts: localhost
  gather_facts: false
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ ansible_env.VAULT_ADDR }}"
        vault_token: "{{ ansible_env.VAULT_TOKEN }}"
  
  rules:
    - name: Log All Events
      condition: true
      action:
        debug:
          var: event
```

## License

Mozilla Public License 2.0 (MPL-2.0)

## Author information

Created by Ricardo Oliveira for HashiCorp Vault Event-Driven Automation integration.

## Support

For issues and feature requests, please use the GitHub repository issue tracker.