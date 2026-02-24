# vault_events event source plugin

The `vault_events` plugin provides real-time monitoring of HashiCorp Vault events through WebSocket connections for agentless secret rotation workflows.

## Requirements

**Important**: This plugin requires **HashiCorp Vault Enterprise** or **HCP Vault Dedicated**. Event streaming is **not available** in Vault Community Edition.

- **Vault Enterprise**: Version 1.13+ (enabled by default in 1.16+)
- **HCP Vault Dedicated**: Event streaming supported
- **Vault OSS/Community**: **Not supported**

## Synopsis

- Connects to Vault's `/v1/sys/events/subscribe` endpoint with a WebSocket.
- Monitors KV operations and database events for agentless secret rotation.
- **IMPORTANT**: Vault's WebSocket API supports only one event pattern per connection.
- **Multiple event_paths will create separate WebSocket connections for each pattern**.
- **SUPPORTED EVENT TYPES**: Only `kv-v1/*`, `kv-v2/*`, and `database/*` are officially supported.
- Allows for agentless secret rotation triggered by real-time events.
- Provides automatic reconnection with exponential backoff.
- Supports secure SSL/TLS connections with configurable verification.
- Integrates with the ansible-rulebook environment variable system.

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `vault_addr` | string | yes | - | Vault server URL (e.g., "http://127.0.0.1:8200") |
| `vault_token` | string | yes | - | Vault authentication token |
| `event_paths` | list | no | `["kv-v2/data-*"]` | List of event paths to subscribe to (separate connection per pattern). |
| `verify_ssl` | boolean | no | `true` | Whether to verify SSL certificates. |
| `ping_interval` | integer | no | 20 | WebSocket ping interval in seconds |
| `backoff_initial` | float | no | 1.0 | Initial reconnection delay in seconds |
| `backoff_max` | float | no | 30.0 | Maximum reconnection delay in seconds |
| `namespace` | string | no | - | Vault namespace for multi-tenant setups |
| `headers` | dict | no | `{}` | Additional HTTP headers for the connection. |
| `filter_expression` | string | no | - | Boolean expression to filter events server-side using go-bexpr syntax. Reduces bandwidth and processing overhead by filtering at the Vault server. |

## Event paths

**IMPORTANT**: Only officially supported event types can be used with this plugin. For the complete and current list of supported event types, see the [HashiCorp Vault Event Notifications documentation](https://developer.hashicorp.com/vault/docs/concepts/events).

The plugin supports the following categories of events:

### KV v2 events
- `kv-v2/*` - All KV v2 events
- `kv-v2/data-*` - All KV v2 data operations

### KV v1 events
- `kv-v1/*` - All KV v1 events

### Database events
- `database/*` - All database events

### Performance note
For optimal performance, use single patterns with wildcards (e.g., `kv-v2/*`, `database/*`, `*`) rather than multiple specific patterns. Each pattern creates a separate WebSocket connection.

**For detailed event types and metadata**: See the [official event types table](https://developer.hashicorp.com/vault/docs/concepts/events#event-types) in the HashiCorp documentation.

## WebSocket connection behavior

**Critical Understanding**: Vault's WebSocket API has an important limitation:

- **One pattern per WebSocket connection**: Each event pattern in `event_paths` creates a separate WebSocket connection.
- **Multiple patterns = Multiple connections**: If you specify `["kv-v2/*", "database/*", "kv-v1/*"]`, three separate WebSocket connections will be established.
- **Resource implications**: Each connection consumes server resources and client connections.
- **Best practice**: Use broader patterns with wildcards when possible (e.g., `*` for all events, `kv-v2/*` for all KV v2 events).

## Environment variables

When using with `ansible-rulebook --env-vars`, the following environment variables are supported:

- `VAULT_ADDR` - Vault server URL
- `VAULT_TOKEN` - Vault authentication token

## Server-side event filtering

The `filter_expression` parameter allows you to filter events server-side using go-bexpr boolean expressions. This reduces bandwidth and processing overhead by filtering events at the Vault server before they are sent to the client.

More information can be found in [the official Vault documentation](https://developer.hashicorp.com/vault/docs/commands/events).

### Primary filtering field

Based on testing, the most reliable field for server-side filtering is:

- `event_type` - The event type (e.g., "kv-v2/data-write", "kv-v2/data-delete", "database/creds-create")

### Common event types for filtering

- `kv-v2/data-write` - KV v2 secret creation and updates
- `kv-v2/data-delete` - KV v2 secret deletion
- `kv-v2/data-patch` - KV v2 secret partial updates
- `kv-v2/metadata-write` - KV v2 metadata updates
- `database/creds-create` - Database credential creation
- `database/config-write` - Database configuration changes

### Filter expression examples

#### Basic equality filtering
```yaml
# Monitor only write operations
filter_expression: 'event_type == "kv-v2/data-write"'

# Monitor only delete operations
filter_expression: 'event_type == "kv-v2/data-delete"'
```

#### Contains filtering
```yaml
# Monitor all operations containing "write"
filter_expression: 'event_type contains "write"'

# Monitor all KV v2 operations
filter_expression: 'event_type contains "kv-v2"'
```

#### Complex OR expressions
```yaml
# Monitor write and delete operations
filter_expression: 'event_type == "kv-v2/data-write" or event_type == "kv-v2/data-delete"'

# Monitor write and patch operations
filter_expression: 'event_type == "kv-v2/data-write" or event_type == "kv-v2/data-patch"'
```

### Important notes

- Server-side filtering uses the `event_type` field, which is different from the nested paths in the event data structure
- Complex nested field filtering may not work reliably for server-side filtering
- Event data access in rulebook conditions uses nested paths like `event.data.event.metadata.data_path`
- Filters are URL-encoded and applied at the Vault server level

## Event data structure

When events are received in your rulebook, they follow this structure:
```

#### Boolean logic combinations
```yaml
filter_expression: 'data.event.metadata.data_path == "secret/data/prod" and data.event.metadata.operation == "data-write"'
filter_expression: 'data.event.metadata.operation == "data-write" or data.event.metadata.operation == "data-patch"'
filter_expression: 'data.event.metadata.data_path == "secret/data/prod/database" and data.event.metadata.operation != "data-read"'
```

#### Pattern matching with regex
```yaml
filter_expression: 'data.event.metadata.data_path matches "^secret/data/prod/.*"'
filter_expression: 'event_type contains "kv-v2"'
filter_expression: 'data.plugin_info.mount_path matches "^secret/"'
```

#### Complex combinations
```yaml
filter_expression: '(data.event.metadata.data_path matches "^secret/data/prod/.*" and data.event.metadata.operation != "data-read") or data.plugin_info.mount_path == "database/"'
```

## Examples

### Basic usage

```yaml
---
- name: Monitor Vault Events
  hosts: localhost
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "http://127.0.0.1:8200"
        vault_token: "myroot"
        event_paths:
          - "kv-v2/data-*"
  
  rules:
    - name: Log KV Events
      condition: event.data.event_type == "kv-v2/data-write"
      action:
        debug:
          msg: "Secret written to {{ event.data.event.metadata.data_path }}"
```

### Environment variable configuration

```yaml
---
- name: Monitor Vault with Environment Variables
  hosts: localhost
  sources:
    - gitrgoliveira.vault_eda.vault_events:
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

### Production configuration

```yaml
---
- name: Production Vault Monitoring
  hosts: localhost
  sources:
    - gitrgoliveira.vault_eda.vault_events:
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
      condition: event.data.event_type in ["kv-v2/data-delete", "database/config-write"]
      action:
        uri:
          url: "https://alerts.company.com/webhook"
          method: POST
          body_format: json
          body:
            alert: "Critical Vault event detected"
            event_type: "{{ event.data.event_type }}"
            timestamp: "{{ ansible_date_time.iso8601 }}"
```

### SSL/TLS configuration

```yaml
---
- name: Secure Vault Connection
  hosts: localhost
  sources:
    - gitrgoliveira.vault_eda.vault_events:
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
          msg: "Received event from secure Vault: {{ event.data.event_type }}"
```

### Development with self-signed certificates

```yaml
---
- name: Development Vault Monitoring
  hosts: localhost
  sources:
    - gitrgoliveira.vault_eda.vault_events:
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

## Event structure

Events received from Vault follow the [CloudEvents specification](https://cloudevents.io/) and have a structured format. For complete details on the event structure and metadata fields, see the [HashiCorp Vault Event Notifications Format documentation](https://developer.hashicorp.com/vault/docs/concepts/events#event-notifications-format).

### Complete event structure

Events received by the plugin have the following structure when accessed in rulebook conditions. This matches the [CloudEvents format documented by Vault](https://developer.hashicorp.com/vault/docs/concepts/events#event-notifications-format):

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "source": "vault://mycluster",
  "specversion": "1.0",
  "type": "*",
  "datacontentype": "application/cloudevents",
  "time": "2025-09-15T12:34:56.789Z",
  "data": {
    "event": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "metadata": {
        "current_version": "1",
        "data_path": "secret/data/myapp/config",
        "modified": "true",
        "oldest_version": "0",
        "operation": "data-write",
        "path": "secret/data/myapp/config"
      }
    },
    "event_type": "kv-v2/data-write",
    "plugin_info": {
      "mount_class": "secret",
      "mount_accessor": "kv_5dc4d18e",
      "mount_path": "secret/",
      "plugin": "kv"
    }
  }
}
```

### Event type examples

#### KV v2 Write Event
```json
{
  "data": {
    "event": {
      "id": "a3be9fb1-b514-519f-5b25-b6f144a8c1ce",
      "metadata": {
        "current_version": "3",
        "data_path": "secret/data/myapp/config",
        "modified": "true",
        "oldest_version": "0",
        "operation": "data-write",
        "path": "secret/data/myapp/config"
      }
    },
    "event_type": "kv-v2/data-write",
    "plugin_info": {
      "mount_class": "secret",
      "mount_accessor": "kv_5dc4d18e",
      "mount_path": "secret/",
      "plugin": "kv"
    }
  }
}
```

#### KV v2 Delete Event

**Note**: Delete events do not include the `data_path` metadata field.

```json
{
  "data": {
    "event": {
      "id": "b4cf9fb2-c625-629f-6c36-c7f255b9d2df",
      "metadata": {
        "modified": "true",
        "operation": "data-delete",
        "path": "secret/data/myapp/config"
      }
    },
    "event_type": "kv-v2/data-delete",
    "plugin_info": {
      "mount_class": "secret",
      "mount_accessor": "kv_5dc4d18e",
      "mount_path": "secret/",
      "plugin": "kv"
    }
  }
}
```

#### Database Credentials Event
```json
{
  "data": {
    "event": {
      "id": "c5dg0gc3-d736-730g-7d47-d8g366c0e3eg",
      "metadata": {
        "modified": "true",
        "name": "readonly",
        "operation": "creds-create",
        "path": "database/creds/readonly"
      }
    },
    "event_type": "database/creds-create",
    "plugin_info": {
      "mount_class": "secret",
      "mount_accessor": "database_a1b2c3d4",
      "mount_path": "database/",
      "plugin": "database"
    }
  }
}
```

### Accessing event data in rules

In your rulebook conditions and actions, access event data using these paths:

```yaml
rules:
  - name: Handle KV Write Events
    condition: event.data.event_type == "kv-v2/data-write"
    action:
      debug:
        msg: |
          Event Type: {{ event.data.event_type }}
          Path: {{ event.data.event.metadata.path }}
          Data Path: {{ event.data.event.metadata.data_path }}
          Operation: {{ event.data.event.metadata.operation }}
          Version: {{ event.data.event.metadata.current_version }}
          Plugin: {{ event.data.plugin_info.plugin }}
          Mount Path: {{ event.data.plugin_info.mount_path }}

  - name: Handle Database Events
    condition: event.data.event_type.startswith("database/")
    action:
      debug:
        msg: |
          Database Event: {{ event.data.event_type }}
          Path: {{ event.data.event.metadata.path }}
          Name: {{ event.data.event.metadata.name | default('N/A') }}
          Plugin Mount: {{ event.data.plugin_info.mount_path }}
```

### Common event metadata fields

These fields are inside `event.data.event.metadata` in rulebook access paths. For the authoritative list per event type, see the [official event types table](https://developer.hashicorp.com/vault/docs/concepts/events#event-types).

- **path**: The API path that was invoked to generate the event (always present)
- **data_path**: The API path that can be used to fetch the underlying data. Only present on certain event types (writes, patches, undelete, config-write, metadata-write). Not present on delete, destroy, or metadata-delete events.
- **operation**: Operation performed (e.g., "data-write", "data-delete", "creds-create")
- **modified**: Whether the event resulted in data modification ("true" or "false")
- **current_version**: Current secret version as a string (KV v2 write/patch events)
- **oldest_version**: Oldest available secret version as a string (KV v2 write/patch events)
- **name**: Resource name (database events)
- **vault_index**: Vault's storage index, usable with [consistency control headers](https://developer.hashicorp.com/vault/docs/enterprise/consistency#conditional-forwarding-performance-standbys-only) to avoid stale reads

These fields are inside `event.data.plugin_info`:

- **plugin**: Plugin type generating the event (e.g., "kv", "database")
- **mount_path**: Mount path of the plugin (e.g., "secret/", "database/")
- **mount_class**: Plugin class (e.g., "secret", "auth")
- **mount_accessor**: Unique ID of the mounted plugin

The top-level `event.data.event_type` field contains the event type (e.g., "kv-v2/data-write", "database/creds-create").

**For complete event structure details**: See the [official event notifications format](https://developer.hashicorp.com/vault/docs/concepts/events#event-notifications-format) in the HashiCorp documentation.

## Troubleshooting

### Connection issues

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

   For more details on the API endpoint, see the [Event Streaming Command documentation](https://developer.hashicorp.com/vault/docs/commands/events).

### SSL certificate issues

For self-signed certificates or development environments:

```yaml
verify_ssl: false
```

### Authentication errors

Ensure your Vault token has the necessary permissions:

```bash
# Check token capabilities
vault token capabilities sys/events/subscribe/kv-v2/data-*
```

### Network connectivity

Check if WebSocket connections are blocked by firewalls or proxies. The plugin uses:
- HTTP/HTTPS protocols for initial connection
- WebSocket upgrade for streaming

### Debug logging

Enable debug logging in your rulebook to see detailed connection information:

```yaml
rules:
  - name: Debug All Events
    condition: true
    action:
      debug:
        var: event
```

### HCP Vault Dedicated specific troubleshooting

When using HCP Vault Dedicated, additional considerations apply:

1. **Subscribe capability requirement**: HCP requires explicit `subscribe` capability in ACL policies. 403 errors typically indicate missing this capability.

   ```bash
   # Check token policies include subscribe capability
   vault token lookup -format=json | jq -r '.data.policies[]' | \
   xargs -I {} vault policy read {}
   
   # Should include subscribe capabilities and event types
   ```

2. **Namespace requirement**: Always use `VAULT_NAMESPACE=admin` for HCP Vault Dedicated:

   ```yaml
   sources:
     - gitrgoliveira.vault_eda.vault_events:
         vault_addr: "https://your-cluster.z1.hashicorp.cloud:8200"
         vault_token: "{{ vault_token }}"
         namespace: "admin"  # Required for HCP
   ```

3. **Connection timing**: Wait 15-20 seconds after establishing WebSocket connection before generating test events for reliable testing.

   ```bash
   # Direct WebSocket testing with HCP
   wscat -c "wss://your-cluster.z1.hashicorp.cloud:8200/v1/sys/events/subscribe/kv-v2/*?json=true" \
         -H "X-Vault-Token: $VAULT_TOKEN" \
         -H "X-Vault-Namespace: admin"
   ```

## Notes

- The plugin automatically handles WebSocket reconnection with exponential backoff.
- SSL/TLS verification can be disabled for development environments.
- **Multiple event paths create separate WebSocket connections - use patterns with wildcards for better performance**.
- Environment variables provide flexible configuration for different deployment environments.
- The plugin is designed for high availability with error handling.
- Only `kv-v1/*`, `kv-v2/*`, and `database/*` event types are officially supported by Vault Enterprise.

## See also

- [HashiCorp Vault Event Notifications Documentation](https://developer.hashicorp.com/vault/docs/concepts/events) - Official documentation for event types and format
- [HashiCorp Vault Event Streaming Command](https://developer.hashicorp.com/vault/docs/commands/events) - Command documentation for event subscription
- [Ansible Event-Driven Automation](https://ansible.readthedocs.io/projects/rulebook/) - Official Ansible EDA documentation
- [WebSocket Protocol Specification](https://tools.ietf.org/html/rfc6455) - WebSocket protocol reference