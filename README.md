# Vault Event-Driven Automation Delivery

This repository provides a comprehensive solution for **agentless rotation of HashiCorp Vault secrets** using Ansible Event-Driven Automation (EDA). It includes a custom WebSocket plugin that connects to Vault's event streaming endpoint and processes events in real-time to enable automated secret rotation workflows.

## 🚨 Requirements

### Vault Enterprise or HCP Vault Dedicated

**Important**: This solution requires **HashiCorp Vault Enterprise** or **HCP Vault Dedicated**. Event streaming is **not available** in Vault Community Edition.

- **Vault Enterprise**: Version 1.13+ (enabled by default in 1.16+)
- **HCP Vault Dedicated**: Event streaming supported
- **Vault OSS/Community**: ❌ **Not supported**

For Vault Enterprise versions 1.13-1.15, event notifications may need to be enabled with the `events.alpha1` experiment flag:

```bash
# Enable events in older Enterprise versions
vault server -experiment events.alpha1
```

### Required Vault ACL Policies

The following Vault policies are required for event subscription and secret rotation:

#### 1. Event Subscription Policy

```hcl
# Allow subscription to event notifications
path "sys/events/subscribe/*" {
    capabilities = ["read"]
}
```

#### 2. Secret Access Policy (for rotation workflows)

```hcl
# Allow monitoring and rotation of secrets in specific paths
path "secret/data/*" {
    capabilities = ["list", "subscribe", "read", "update"]
    subscribe_event_types = ["*"]
}

# For database credential rotation
path "database/creds/*" {
    capabilities = ["list", "subscribe", "read"]
    subscribe_event_types = ["database/*"]
}

# For dynamic secrets monitoring
path "aws/creds/*" {
    capabilities = ["list", "subscribe", "read"]
    subscribe_event_types = ["*"]
}
```

#### 3. Complete Example Policy

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

**Apply the policy:**

```bash
# Save policy to file
vault policy write eda-automation eda-policy.hcl

# Create token with policy
vault token create -policy=eda-automation -ttl=24h
```

## Features

- 🔄 **Agentless Secret Rotation**: Automated secret rotation triggered by Vault events
- 🌐 **Real-time Event Streaming**: WebSocket connection to Vault's `/v1/sys/events/subscribe` endpoint
- 🏢 **Enterprise Ready**: Built for Vault Enterprise and HCP Vault Dedicated
- 🔧 **Environment Variable Configuration**: Dynamic configuration using `VAULT_ADDR` and `VAULT_TOKEN` via `--env-vars`
- 📊 **Multiple Event Types**: Support for KV v2, database, auth, and system events
- 🔧 **Background Processing**: Run rulebooks in background with proper process management and PID tracking
- 🛠️ **Development Automation**: Complete Makefile-based workflow for setup and testing
- 📝 **Comprehensive Logging**: Detailed logging for debugging and monitoring with structured output
- 🏗️ **Collection Architecture**: Proper Ansible collection structure for the custom plugin
- 🔄 **Auto-Reconnection**: WebSocket reconnection with exponential backoff for reliability
- 🔐 **Secure Authentication**: Token-based authentication with proper ACL support

## Quick Start

### Prerequisites

1. **Vault Enterprise or HCP Vault Dedicated** (version 1.13+)
2. **Vault ACL Policy** configured for event subscription
3. **Python 3.7+** with virtual environment support

### Setup

```bash
# Set environment variables
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=myroot

# Set up environment and start Vault Enterprise
make setup-env
make start-vault

# Verify event streaming is available
vault events subscribe kv-v2/data-* &

# Start event monitoring in background
make run-rulebook-bg

# Generate test events
make test-events

# View live logs
tail -f rulebook.log
```

## Configuration

### Environment Variables

The system uses environment variables for dynamic configuration via ansible-rulebook's `--env-vars` parameter:

- `VAULT_ADDR`: Vault server URL (default: `http://127.0.0.1:8200`)
- `VAULT_TOKEN`: Vault authentication token (default: `myroot`)

Example usage with different environments:

```bash
# Development environment (default)
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=myroot

# Production environment
export VAULT_ADDR=https://vault.company.com:8200
export VAULT_TOKEN=hvs.production.token.here

# Staging environment  
export VAULT_ADDR=https://vault-staging.company.com:8443
export VAULT_TOKEN=hvs.staging.token.here
```

### Event Subscription

Configure which Vault events to monitor in `vault-eda-rulebook.yaml`. The following event types are available in Vault Enterprise:

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

## Makefile Targets

The project includes a comprehensive Makefile for automation:

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

### Component Overview

### Component Overview

```
vault-ansible-delivery/
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

- **vault-eda-rulebook.yaml**: Main rulebook configuration with environment variable integration
- **collections/ansible_collections/gitrgoliveira/vault/plugins/event_source/vault_events.py**: Custom WebSocket event source plugin
- **scripts/generate-vault-events.sh**: Event generation script for testing
- **Makefile**: Comprehensive automation for development workflow

### Event Flow

1. **Vault Events**: Generated by KV v2 operations (create, update, delete, patch)
2. **WebSocket Stream**: Real-time event streaming via `/v1/sys/events/subscribe`
3. **Custom Plugin**: Processes WebSocket messages and forwards to ansible-rulebook
4. **Rule Engine**: Matches events against conditions and triggers actions
5. **Debug Output**: Structured logging of captured events

## Python Environment Setup

A Python virtual environment is configured with the required Ansible packages.

### Activate the Virtual Environment

```bash
cd /Users/ricardo/repos/sse/vault-ansible-delivery
source .venv/bin/activate
```

### Verify Installation

Check that all packages are installed and working:

```bash
# Check Ansible core
ansible --version

# Check Ansible Runner
ansible-runner --version

# Check Ansible Rulebook (requires Java/JVM)
ansible-rulebook --version
```

### Installed Packages

- `ansible` (v12.0.0) - Ansible automation platform
- `ansible-core` (v2.19.2) - Core Ansible engine
- `ansible-rulebook` (v1.1.7) - Event-driven automation
- `ansible-runner` (v2.4.1) - Ansible execution interface

### Java Requirement

`ansible-rulebook` requires a Java Runtime Environment (JRE) or Java Development Kit (JDK). On macOS with Homebrew:

```bash
# Install OpenJDK
brew install openjdk

# Set PATH and JAVA_HOME (add to ~/.zshrc or ~/.bash_profile)
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export DYLD_LIBRARY_PATH="$JAVA_HOME/lib/server:$DYLD_LIBRARY_PATH"
```

**Note**: The `DYLD_LIBRARY_PATH` is required for the JNI (Java Native Interface) bridge to work properly with ansible-rulebook.

### Deactivate Environment

```bash
deactivate
```

## Troubleshooting

### Common Issues

1. **Event Streaming Not Available**: Verify you're using Vault Enterprise or HCP Vault Dedicated
   ```bash
   # Check Vault version and edition
   vault version
   
   # For Enterprise, verify events are enabled
   vault events subscribe kv-v2/data-test
   ```

2. **ACL Permission Denied**: Ensure your token has the required policies
   ```bash
   # Check token capabilities
   vault token capabilities sys/events/subscribe/kv-v2/data-*
   vault token capabilities secret/data/myapp
   
   # Should return: ["read"] for events, ["list", "subscribe"] for secrets
   ```

3. **Java/JNI Error**: Ensure `DYLD_LIBRARY_PATH` is set correctly
   ```bash
   export DYLD_LIBRARY_PATH="$JAVA_HOME/lib/server:$DYLD_LIBRARY_PATH"
   ```

4. **WebSocket Connection Failed**: Check Vault is running and accessible
   ```bash
   make status-vault
   curl -s http://127.0.0.1:8200/v1/sys/health
   ```

5. **Environment Variables Not Working**: Verify variables are exported
   ```bash
   echo $VAULT_ADDR
   echo $VAULT_TOKEN
   ```

6. **Rulebook Not Starting**: Check background process status
   ```bash
   ps aux | grep ansible-rulebook
   tail -f rulebook.log
   ```

### Debugging

- **View Logs**: `tail -f rulebook.log`
- **Check Vault Logs**: `tail -f vault.log`
- **Process Status**: `make status-vault` and check rulebook PID
- **Manual Testing**: Create secrets manually to test event generation

### Log Analysis

Events are captured and logged with structured debug output:
```
** 2025-09-15 23:03:18.028740 [debug] ******************************************
KV Write Event - Path: secret/data/test, Data Path: secret/data/test, Operation: data-write, Version: 1
********************************************************************************
```

## Collection Release Process

The project features a comprehensive, automated release workflow with multi-environment testing and enhanced security measures. For detailed release procedures, see **[RELEASE.md](RELEASE.md)**.

### Quick Release Guide

#### Local Development Release

```bash
# Build and test the collection locally
make build-collection

# Publish to Ansible Galaxy (requires GALAXY_API_KEY)
export GALAXY_API_KEY="your_api_key_here"
make publish-collection

# Or do both in one step
make release-collection
```

#### Automated GitHub Release (Recommended)

The repository includes **enhanced GitHub Actions** with comprehensive validation:

1. **Manual Release Workflow**: 
   - Go to Actions → "Release Ansible Collection" → "Run workflow"
   - Enter the version number (e.g., "1.0.1")
   - **Matrix testing** across 4 Python versions × 4 Ansible Core versions
   - **Comprehensive validation** including security checks and dependency verification

2. **Automated Tag Release**:
   - Create and push a git tag: `git tag v1.0.1 && git push origin v1.0.1`
   - Same comprehensive validation and testing pipeline

#### Enhanced Workflow Features

✅ **Multi-Matrix Validation**: Python 3.9-3.12 × Ansible Core 2.14-2.17  
✅ **Security Hardening**: Minimal permissions, environment protection  
✅ **Comprehensive Testing**: Structure, imports, dependencies, size validation  
✅ **Automated Publishing**: Galaxy + GitHub releases with rich release notes  
✅ **Artifact Management**: Collection packages with 90-day retention  
✅ **Rollback Support**: Comprehensive troubleshooting and recovery procedures  

#### Prerequisites for Automated Release

1. **Set up GALAXY_API_KEY secret**:
   - Get your API key from [Ansible Galaxy](https://galaxy.ansible.com/me/preferences)
   - Add it as a repository secret: Settings → Secrets and variables → Actions
   - Secret name: `GALAXY_API_KEY`

2. **Update version in galaxy.yml**:
   ```yaml
   version: 1.0.1  # Follow semantic versioning
   ```

3. **Update CHANGELOG.md** with detailed release notes

#### Supported Environments

- **Python**: 3.9, 3.10, 3.11, 3.12
- **Ansible Core**: 2.14 (LTS), 2.15, 2.16, 2.17
- **Automatic compatibility validation** and exclusion of incompatible combinations

For complete release documentation, troubleshooting guides, and best practices, see **[RELEASE.md](RELEASE.md)**.