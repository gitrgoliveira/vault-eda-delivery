# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# vault_events Event Source Plugin

The `vault_events` plugin provides real-time monitoring of HashiCorp Vault events through WebSocket connections for agentless secret rotation workflows.

## Requirements

**Important**: This plugin requires **HashiCorp Vault Enterprise** or **HCP Vault Dedicated**. Event streaming is **not available** in Vault Community Edition.

- **Vault Enterprise**: Version 1.13+ (enabled by default in 1.16+)
- **HCP Vault Dedicated**: Event streaming supported
- **Vault OSS/Community**: ❌ **Not supported**

## Synopsis

- Connects to Vault's `/v1/sys/events/subscribe` endpoint via WebSocket
- Monitors various event types including KV operations, database events, authentication, and policy changes
- Enables agentless secret rotation triggered by real-time events
- Provides automatic reconnection with exponential backoff
- Supports secure SSL/TLS connections with configurable verification
- Integrates with ansible-rulebook environment variable system

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `vault_addr` | string | yes | - | Vault server URL (e.g., "http://127.0.0.1:8200") |
| `vault_token` | string | yes | - | Vault authentication token |
| `event_paths` | list | no | ["kv-v2/data-*"] | List of event paths to subscribe to |
| `verify_ssl` | boolean | no | true | Whether to verify SSL certificates |
| `ping_interval` | integer | no | 20 | WebSocket ping interval in seconds |
| `backoff_initial` | float | no | 1.0 | Initial reconnection delay in seconds |
| `backoff_max` | float | no | 30.0 | Maximum reconnection delay in seconds |
| `namespace` | string | no | - | Vault namespace for multi-tenant setups |
| `headers` | dict | no | {} | Additional HTTP headers for the connection |

## Event Paths

The plugin supports various event path patterns:

### KV v2 Events
- `kv-v2/data-*` - All KV v2 data operations
- `kv-v2/data-write` - KV v2 write operations
- `kv-v2/data-delete` - KV v2 delete operations
- `kv-v2/data-patch` - KV v2 patch operations
- `kv-v2/metadata-*` - KV v2 metadata operations

### KV v1 Events
- `kv-v1/write` - KV v1 write operations
- `kv-v1/delete` - KV v1 delete operations

### Database Events
- `database/creds-create` - Database credential creation
- `database/rotate` - Database credential rotation
- `database/config-*` - Database configuration changes
- `database/role-*` - Database role operations

## Environment Variables

When using with `ansible-rulebook --env-vars`, the following environment variables are supported:

- `VAULT_ADDR` - Vault server URL
- `VAULT_TOKEN` - Vault authentication token

## Examples

### Basic Usage

```yaml
---
- name: Monitor Vault Events
  hosts: localhost
  sources:
    - gitrgoliveira.vault.vault_events:
        vault_addr: "http://127.0.0.1:8200"
        vault_token: "myroot"
        event_paths:
          - "kv-v2/data-*"
  
  rules:
    - name: Log KV Events
      condition: event.event_type == "kv-v2/data-write"
      action:
        debug:
          msg: "Secret written to {{ event.data.path }}"
```

### Environment Variable Configuration

```yaml
---
- name: Monitor Vault with Environment Variables
  hosts: localhost
  sources:
    - gitrgoliveira.vault.vault_events:
        vault_addr: "{{ ansible_env.VAULT_ADDR }}"
        vault_token: "{{ ansible_env.VAULT_TOKEN }}"
        event_paths:
          - "kv-v2/data-*"
          - "database/*"
  
  rules:
    - name: Handle All Events
      condition: true
      action:
        debug:
          var: event
```

### Production Configuration

```yaml
---
- name: Production Vault Monitoring
  hosts: localhost
  sources:
    - gitrgoliveira.vault.vault_events:
        vault_addr: "https://vault.company.com:8200"
        vault_token: "{{ vault_token }}"
        namespace: "production"
        event_paths:
          - "kv-v2/data-*"
          - "kv-v1/*"
          - "database/*"
        verify_ssl: true
        ping_interval: 30
        backoff_initial: 2.0
        backoff_max: 60.0
        headers:
          X-Custom-Header: "monitoring-system"
  
  rules:
    - name: Critical Events Alert
      condition: event.event_type in ["kv-v2/data-delete", "database/config-write"]
      action:
        uri:
          url: "https://alerts.company.com/webhook"
          method: POST
          body_format: json
          body:
            alert: "Critical Vault event detected"
            event_type: "{{ event.event_type }}"
            timestamp: "{{ ansible_date_time.iso8601 }}"
```

### SSL/TLS Configuration

```yaml
---
- name: Secure Vault Connection
  hosts: localhost
  sources:
    - gitrgoliveira.vault.vault_events:
        vault_addr: "https://vault.example.com:8200"
        vault_token: "{{ vault_token }}"
        verify_ssl: true  # Enable SSL verification
        event_paths:
          - "kv-v2/data-*"
  
  rules:
    - name: Process Secure Events
      condition: true
      action:
        debug:
          msg: "Received event from secure Vault: {{ event.event_type }}"
```

### Development with Self-Signed Certificates

```yaml
---
- name: Development Vault Monitoring
  hosts: localhost
  sources:
    - gitrgoliveira.vault.vault_events:
        vault_addr: "https://localhost:8200"
        vault_token: "dev-token"
        verify_ssl: false  # Disable SSL verification for development
        event_paths:
          - "kv-v2/data-*"
  
  rules:
    - name: Debug All Events
      condition: true
      action:
        debug:
          var: event
```

## Event Structure

Events received from Vault have the following general structure:

```json
{
  "event_type": "kv-v2/data-write",
  "timestamp": "2025-09-15T12:34:56.789Z",
  "data": {
    "path": "secret/data/myapp/config",
    "metadata": {
      "created_time": "2025-09-15T12:34:56.789Z",
      "version": 1,
      "destroyed": false
    }
  }
}
```

## Troubleshooting

### Connection Issues

1. **Verify Vault server is accessible**:
   ```bash
   curl -s $VAULT_ADDR/v1/sys/health
   ```

2. **Check token permissions**:
   ```bash
   vault token lookup
   ```

3. **Test event subscription directly**:
   ```bash
   curl -H "X-Vault-Token: $VAULT_TOKEN" \
        $VAULT_ADDR/v1/sys/events/subscribe/kv-v2/data-test
   ```

### SSL Certificate Issues

For self-signed certificates or development environments:

```yaml
verify_ssl: false
```

### Authentication Errors

Ensure your Vault token has the necessary permissions:

```bash
# Check token capabilities
vault token capabilities sys/events/subscribe/kv-v2/data-*
```

### Network Connectivity

Check if WebSocket connections are blocked by firewalls or proxies. The plugin uses:
- HTTP/HTTPS protocols for initial connection
- WebSocket upgrade for streaming

### Debug Logging

Enable debug logging in your rulebook to see detailed connection information:

```yaml
rules:
  - name: Debug All Events
    condition: true
    action:
      debug:
        var: event
```

## Notes

- The plugin automatically handles WebSocket reconnection with exponential backoff
- SSL/TLS verification can be disabled for development environments
- Multiple event paths can be specified to monitor different types of events
- Environment variables provide flexible configuration for different deployment environments
- The plugin is designed for high availability with robust error handling

## See Also

- [HashiCorp Vault Event Streaming Documentation](https://developer.hashicorp.com/vault/api-docs/system/events)
- [Ansible Event-Driven Automation](https://ansible.readthedocs.io/projects/rulebook/)
- [WebSocket Protocol Specification](https://tools.ietf.org/html/rfc6455)