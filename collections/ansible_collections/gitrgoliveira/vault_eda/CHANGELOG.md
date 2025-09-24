# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Changelog

All notable changes to this collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-09-24

### Added

- **Test automation script** (`scripts/test-examples.sh`) for systematically verifying all vault_eda examples by running them as background processes and generating appropriate test events.
- **Server-side event filtering** using go-bexpr boolean expressions.
- New `filter_expression` parameter for the `vault_events` plugin.
- Support for filtering events by metadata fields:
  - `data_path` - Path where data operation occurred
  - `operation` - Operation type (read, write, patch, delete)
  - `path` - Full Vault path
  - `modified` - Timestamp of modification
  - `vault_index` - Vault's internal index value
  - `plugin_info.plugin` - Plugin type (kv, database, etc.)
  - `plugin_info.mount_path` - Plugin mount path
- Filter expression syntax examples:
  - Basic equality: `data_path == "secret/prod/database"`
  - Boolean logic: `data_path == "secret/prod" and operation != "read"`
  - Pattern matching: `data_path matches "^secret/prod/.*"`
  - Complex combinations: `(data_path matches "^secret/prod/.*" and operation != "read") or plugin_info.plugin == "database"`
- New example files demonstrating enhanced filtering capabilities:
  - `enhanced-filtering.yml` with advanced filtering techniques
  - `filter-monitoring.yml` with practical filter expression examples
- HCP Vault specific rulebook (`hcp-vault-rulebook.yaml`) for cloud-specific event monitoring scenarios.

### Changed

- **Breaking**: Filter expressions are applied server-side, reducing client bandwidth.
- URL construction now includes filter query parameter when `filter_expression` is provided.
- All WebSocket connections use the same filter expression when multiple event paths are specified.
- Enhanced plugin code structure for improved clarity and consistency.
- Updated build system with new Makefile targets including `compile-deps`.
- Improved dependency management with ansible-lint integration.

### Documentation

- Added comprehensive filter expression section to `docs/vault_events.md`.
- Enhanced README files with server-side filtering examples and usage patterns.
- Updated plugin documentation with filter parameter details and examples.
- Added practical production monitoring examples using filters.
- Improved documentation consistency and wording across all files.

## [0.0.1] - 2025-09-19

### Added

- Initial release of the Vault Event-Driven Automation collection for agentless secret rotation.
- `vault_events` event source plugin for real-time Vault event monitoring.
- WebSocket connection to Vault's `/v1/sys/events/subscribe` endpoint.
- Support for officially supported event types (see [HashiCorp Vault Event Types](https://developer.hashicorp.com/vault/docs/concepts/events#event-types)):
  - KV v2 operations (`kv-v2/*`).
  - KV v1 operations (`kv-v1/*`).
  - Database credential events (`database/*`).
- Configuration options:
  - Environment variable support.
  - SSL/TLS configuration with verification options.
  - Custom HTTP headers support.
  - Vault namespace support.
  - Configurable reconnection with exponential backoff.
  - Adjustable WebSocket ping intervals.
- Auto-reconnection logic with exponential backoff for resilient connections.
- Detailed logging and debugging capabilities.
- Complete documentation with usage examples and ACL requirements.
- Mozilla Public License 2.0 (MPL-2.0) licensing.

### Requirements

- **HashiCorp Vault Enterprise 1.13+** or **HCP Vault Dedicated** (Community Edition not supported).
- Vault ACL policies for event subscription and secret access.
- Python 3.7+ with websockets >= 10.0.
- ansible-core >= 2.14 and ansible-rulebook >= 1.0.0.

### Documentation

- Enterprise requirements and limitations documented.
- Vault ACL policy examples for event subscription and secret rotation.
- Plugin parameter documentation with examples.
- Troubleshooting guide for Enterprise-specific issues.
- Environment variable configuration guide.
- Event type reference for all supported Vault Enterprise events.

### Security Notes

- ACL policies required for both event subscription (`sys/events/subscribe/*`) and secret access.
- Support for secure token-based authentication with namespace isolation.