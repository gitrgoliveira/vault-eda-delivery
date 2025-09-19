# Vault Event-Driven Automation Delivery

This repository provides tools for agentless rotation of HashiCorp Vault secrets using Ansible Event-Driven Automation (EDA). It includes a custom WebSocket plugin that connects to Vault's event streaming endpoint and processes events in real-time for automated secret rotation workflows.

## Features

- **Agentless Secret Rotation**: Automate secret rotation triggered by Vault events without requiring agents.
- **Real-time Event Streaming**: Connect directly to Vault's `/v1/sys/events/subscribe` endpoint using WebSocket for immediate event processing.
- **Dynamic Configuration**: Use environment variables for `VAULT_ADDR` and `VAULT_TOKEN` to easily switch between different Vault environments.
- **Broad Event Support**: Support events from KV v1, KV v2, and Database secrets engines.
- **Automated Development Workflow**: Use the provided Makefile to quickly set up, run, and test the entire environment.
- **Reliable Connectivity**: The WebSocket plugin automatically reconnects with exponential backoff during connection failures.

## Prerequisites

Before you begin, ensure you have the following components installed and configured:

1. **Vault Enterprise or HCP Vault Dedicated**: This project requires Vault v1.13+ or HCP Vault Dedicated. Event streaming is not available in the Community Edition.
2. **Python**: You need Python 3.7+ with `venv` support.
3. **Java**: `ansible-rulebook` requires a Java Runtime Environment (JRE) or Java Development Kit (JDK).
4. **Vault ACL Policy**: You must have a Vault token with a policy granting permissions to subscribe to events and manage secrets.

## Quick Start

This section guides you through the fastest way to get the project running. The `make` commands automate the setup and execution.

1. **Set Environment Variables**:
   Export the address of your Vault server and an authentication token.

   ```bash
   export VAULT_ADDR=http://127.0.0.1:8200
   export VAULT_TOKEN=myroot
   ```

2. **Set Up and Start the Environment**:
   This command initializes the Python environment, installs dependencies, and starts a Vault Enterprise server in development mode.

   ```bash
   make setup-env
   make start-vault
   ```

3. **Run the Rulebook in the Background**:
   This starts the `ansible-rulebook` process to listen for Vault events. The process ID is stored in `rulebook.pid`.

   ```bash
   make run-rulebook-bg
   ```

4. **Generate Test Events**:
   Run the included script to create, update, and delete secrets in Vault, which generates events for the rulebook to process.

   ```bash
   make test-events
   ```

5. **Monitor the Logs**:
   You can view the live output and captured events in the log file.

   ```bash
   tail -f rulebook.log
   ```

## Configuration

To customize the behavior of the automation, you can adjust the following settings.

### Environment Variables

The Ansible rulebook uses environment variables to connect to Vault. You can configure them by using the `--env-vars` parameter or exporting them in your shell.

- `VAULT_ADDR`: The URL of your Vault server (default: `http://127.0.0.1:8200`).
- `VAULT_TOKEN`: A Vault authentication token with the required permissions (default: `myroot`).


### Vault ACL Policies

Your Vault token needs policies that allow it to subscribe to events and manage secrets. The following examples show the required permissions.

#### Event Subscription Policy

This policy is mandatory for the plugin to connect to the event stream.

```hcl
# Allow subscription to event notifications
path "sys/events/subscribe/*" {
    capabilities = ["read"]
}
```

#### Secret Access Policy

This policy allows the automation to monitor and rotate secrets in specific paths.

```hcl
# Allow monitoring and rotation of secrets in KV v2
path "secret/data/*" {
    capabilities = ["list", "subscribe", "read", "update", "create", "delete"]
    subscribe_event_types = ["kv-v2/*"]
}

# Allow monitoring of database credentials
path "database/creds/*" {
    capabilities = ["list", "subscribe", "read"]
    subscribe_event_types = ["database/*"]
}
```

#### Complete Example Policy

The following policy combines all required permissions for the automation.

```hcl
# Complete policy for Vault EDA automation
path "sys/events/subscribe/*" {
    capabilities = ["read"]
}

path "secret/data/*" {
    capabilities = ["list", "subscribe", "read", "update", "create", "delete"]
    subscribe_event_types = ["kv-v2/*"]
}

path "database/creds/*" {
    capabilities = ["list", "subscribe", "read"]
    subscribe_event_types = ["database/*"]
}

path "auth/token/lookup-self" {
    capabilities = ["read"]
}
```

To apply the policy and create a token, you can run the following commands:

```bash
# Save the policy to a file (e.g., eda-policy.hcl)
vault policy write eda-automation eda-policy.hcl

# Create a token with the policy, or attach it to a role for EDA to use.
vault token create -policy=eda-automation -ttl=24h
```

### Event Subscription Paths

You can configure which Vault events to monitor by editing the `event_paths` in `vault-eda-rulebook.yaml`. For a complete and up-to-date list of event types, refer to the [official Vault documentation on Event Notifications](https://developer.hashicorp.com/vault/docs/concepts/events).

Example configuration showing supported event types:

```yaml
event_paths:
  # KV Secrets Engine Events
  - "kv-v2/data-*"          # KV v2 data operations (write, delete, patch)
  - "kv-v2/metadata-*"      # KV v2 metadata operations
  - "kv-v1/*"               # KV v1 operations
  
  # Database Secrets Engine Events  
  - "database/creds-*"      # Database credential creation
  - "database/config-*"     # Database configuration changes
  - "database/rotate*"      # Database credential rotation
  - "database/role-*"       # Database role management
```

## Development Setup

This section provides detailed instructions for setting up the environment manually.

### Vault Enterprise Requirements

**Important**: This setup requires **HashiCorp Vault Enterprise** or **HCP Vault Dedicated**. Event streaming is **not available** in Vault Community Edition.

- **Vault Enterprise**: Version 1.13+ (enabled by default in 1.16+)
- **HCP Vault Dedicated**: Event streaming supported
- **Vault OSS/Community**: Not supported

For Vault Enterprise versions 1.13-1.15, event notifications may need to be enabled with the `events.alpha1` experiment flag:

```bash
# Enable events in older Enterprise versions
vault server -experiment events.alpha1
```

### Python Virtual Environment

The project uses a Python virtual environment to manage dependencies.

1. **Activate the Virtual Environment**:
   Change to the project directory and source the activation script.

   ```bash
   cd /path/to/vault-eda-delivery
   source .venv/bin/activate
   ```

2. **Verify Installation**:
   Check that the required Ansible tools are installed and available in your path.

   ```bash
   ansible --version
   ansible-runner --version
   ansible-rulebook --version
   ```

3. **Deactivate the Environment**:
   When you are finished, you can deactivate the virtual environment.

   ```bash
   deactivate
   ```

### Java Requirement for Ansible Rulebook

`ansible-rulebook` requires a Java environment to run. If you are on macOS and use Homebrew, you can install it and configure the required environment variables.

1. **Install OpenJDK**:

   ```bash
   brew install openjdk
   ```

2. **Set Environment Variables**:
   Add the following exports to your shell profile (e.g., `~/.zshrc` or `~/.bash_profile`) to ensure Java is found.

   ```bash
   export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
   export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
   export DYLD_LIBRARY_PATH="$JAVA_HOME/lib/server:$DYLD_LIBRARY_PATH"
   ```

   **Note**: The `DYLD_LIBRARY_PATH` is required for the JNI (Java Native Interface) bridge to work correctly.

## Makefile Targets

The project includes a Makefile to automate common development and operational tasks.

```bash
# Environment setup
make setup-env          # Set up Python virtual environment and dependencies
make help               # Show all available targets

# Vault management
make start-vault        # Start Vault Enterprise in dev mode
make stop-vault         # Stop Vault server
make status-vault       # Check Vault server status

# Rulebook execution
make run-rulebook       # Run rulebook in foreground
make run-rulebook-bg    # Run rulebook in background with PID tracking
make stop-rulebook      # Stop background rulebook process

# Testing and development
make test-events        # Generate test events using generate-vault-events.sh
make clean              # Stop all processes and clean up log files
```

## Architecture

This section describes the components and data flow of the project.

### Component Overview

The repository is structured as an Ansible Collection to package the custom event source plugin.

```
vault-eda-delivery/
├── collections/
│   └── ansible_collections/
│       └── gitrgoliveira/
│           └── vault/
│               └── plugins/
│                   └── event_source/
│                       └── vault_events.py          # Custom WebSocket plugin
├── vault-eda-rulebook.yaml                          # Main rulebook configuration
├── scripts/generate-vault-events.sh                 # Event generation script
├── Makefile                                         # Automation workflow
├── inventory.yml                                    # Ansible inventory
├── requirements.txt                                 # Python dependencies
└── README.md                                        # Documentation
```

- **vault-eda-rulebook.yaml**: Main rulebook configuration with environment variable integration.
- **collections/ansible_collections/gitrgoliveira/vault/plugins/event_source/vault_events.py**: Custom WebSocket event source plugin.
- **scripts/generate-vault-events.sh**: Event generation script for testing.
- **Makefile**: Automation for development workflow.

### Event Flow

The event-driven process follows these steps:

1. **Event Generation**: An operation in Vault (like a KV secret write) generates an event.
2. **WebSocket Stream**: Vault streams the event in real-time over the `/v1/sys/events/subscribe` endpoint.
3. **Custom Plugin**: The `vault_events.py` plugin receives the event from the WebSocket and formats it as a structured fact for the rulebook.
4. **Rule Engine**: `ansible-rulebook` matches the event against conditions defined in the rulebook.
5. **Action Execution**: If a condition matches, the rulebook triggers the corresponding action, such as logging the event or running an Ansible playbook.

## Troubleshooting

If you encounter issues, refer to the following common problems and solutions.

### Common Issues

1. **Event Streaming Not Available**: Verify you are using Vault Enterprise or HCP Vault Dedicated, as the Community Edition does not support event streaming.

   ```bash
   # Check Vault version and edition
   vault version
   
   # For Enterprise, verify events are enabled
   vault events subscribe kv-v2/data-test
   ```

2. **ACL Permission Denied**: Ensure your Vault token has a policy with `read` capabilities on `sys/events/subscribe/*` and `subscribe` capabilities on the secret paths you wish to monitor.

   ```bash
   # Check token capabilities
   vault token capabilities sys/events/subscribe/kv-v2/data-*
   vault token capabilities secret/data/myapp
   
   # Should return: ["read"] for events, ["list", "subscribe"] for secrets
   ```

3. **Java/JNI Error on macOS**: Check that the `DYLD_LIBRARY_PATH` environment variable is set correctly and points to your JDK's server library.

   ```bash
   export DYLD_LIBRARY_PATH="$JAVA_HOME/lib/server:$DYLD_LIBRARY_PATH"
   ```

4. **WebSocket Connection Failed**: Confirm that the Vault server is running and accessible from where you are running `ansible-rulebook`. Use `make status-vault` to check.

   ```bash
   make status-vault
   curl -s http://127.0.0.1:8200/v1/sys/health
   ```

5. **Rulebook Not Starting**: Check the `rulebook.log` for errors and ensure no other process is using the same ports.

   ```bash
   ps aux | grep ansible-rulebook
   tail -f rulebook.log
   ```

### Debugging

Use the following commands to troubleshoot issues:

- **View Logs**: `tail -f rulebook.log`
- **Check Vault Logs**: `tail -f vault.log`
- **Process Status**: `make status-vault` and check rulebook PID
- **Manual Testing**: Create secrets manually to test event generation

Events are captured and logged with structured debug output:

```
** 2025-09-15 23:03:18.028740 [debug] ******************************************
KV Write Event - Path: secret/data/test, Data Path: secret/data/test, Operation: data-write, Version: 1
********************************************************************************
```