# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Changelog

All notable changes to this collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-09-15

### Added

- Initial release of the Vault Event-Driven Automation collection for **agentless secret rotation**
- `vault_events` event source plugin for real-time Vault event monitoring
- WebSocket connection to Vault's `/v1/sys/events/subscribe` endpoint
- **Enterprise Ready**: Built specifically for Vault Enterprise and HCP Vault Dedicated
- Support for multiple event types:
  - KV v2 operations (write, delete, patch, metadata)
  - KV v1 operations (write, delete)
  - Database credential events (creation, rotation, configuration)
  - Authentication events (token, userpass)
  - Policy changes and system events
  - Mount/unmount operations
- Comprehensive configuration options:
  - Environment variable support
  - SSL/TLS configuration with verification options
  - Custom HTTP headers support
  - Vault namespace support
  - Configurable reconnection with exponential backoff
  - Adjustable WebSocket ping intervals
- Auto-reconnection logic with exponential backoff for resilient connections
- Detailed logging and debugging capabilities
- Complete documentation with usage examples and ACL requirements
- Mozilla Public License 2.0 (MPL-2.0) licensing

### Requirements

- **HashiCorp Vault Enterprise 1.13+** or **HCP Vault Dedicated** (Community Edition not supported)
- Proper Vault ACL policies for event subscription and secret access
- Python 3.7+ with websockets >= 10.0
- ansible-core >= 2.14 and ansible-rulebook >= 1.0.0

### Documentation

- Enterprise requirements and limitations clearly documented
- Vault ACL policy examples for event subscription and secret rotation
- Complete plugin parameter documentation with examples
- Troubleshooting guide for Enterprise-specific issues
- Environment variable configuration guide
- Event type reference for all supported Vault Enterprise events

### Security Notes

- ACL policies required for both event subscription (`sys/events/subscribe/*`) and secret access
- Support for secure token-based authentication with namespace isolation