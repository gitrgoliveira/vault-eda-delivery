#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
HashiCorp Vault WebSocket Event Source Plugin for Ansible Event-Driven Automation.

This module provides a custom WebSocket plugin that connects to Vault Enterprise's
event streaming endpoint for real-time secret rotation workflows.
"""

DOCUMENTATION = """
---
name: vault_events
description: HashiCorp Vault WebSocket event source for agentless secret rotation
version: "0.1.1"
description:
  - This plugin connects to Vault's WebSocket event streaming endpoint and forwards
    events to ansible-rulebook for processing agentless secret rotation workflows.
  - Supports real-time monitoring of Vault operations including KV secrets,
    database credentials, authentication, and policy changes.
  - Provides automatic reconnection with exponential backoff for reliable monitoring.
  - "IMPORTANT: Requires Vault Enterprise or HCP Vault Dedicated. Event streaming 
    is not available in Vault Community Edition."

options:
  vault_addr:
    description:
      - Vault server URL including protocol and port.
      - Can be provided via VAULT_ADDR environment variable when using --env-vars.
    type: str
    required: true
    example: "http://127.0.0.1:8200"
  
  vault_token:
    description:
      - Vault authentication token with appropriate permissions.
      - Can be provided via VAULT_TOKEN environment variable when using --env-vars.
    type: str
    required: true
    no_log: true
  
  event_paths:
    description:
      - List of event paths to subscribe to (each creates a separate WebSocket connection).
      - "Supported types: 'kv-v1/*', 'kv-v2/*', 'database/*'"
      - "Use wildcards for better performance (e.g., 'kv-v2/*', 'database/*', '*')"
    type: list
    elements: str
    default: ["kv-v2/data-*"]
    example: ["kv-v2/*", "database/*", "kv-v1/*"]
  
  verify_ssl:
    description:
      - Whether to verify SSL certificates for HTTPS connections.
      - Set to false for development environments with self-signed certificates.
    type: bool
    default: true
  
  ping_interval:
    description:
      - WebSocket ping interval in seconds to maintain connection.
    type: int
    default: 20
  
  backoff_initial:
    description:
      - Initial delay in seconds before reconnection attempts.
    type: float
    default: 1.0
  
  backoff_max:
    description:
      - Maximum delay in seconds between reconnection attempts.
    type: float
    default: 30.0
  
  namespace:
    description:
      - Vault namespace for multi-tenant Vault deployments.
    type: str
    required: false
  
  headers:
    description:
      - Additional HTTP headers to include in the WebSocket connection.
    type: dict
    default: {}
  
  filter_expression:
    description:
      - Boolean expression to filter events server-side using go-bexpr syntax. https://developer.hashicorp.com/vault/docs/commands/events#event_type
      - Filters are applied at the Vault server before events are sent to the client.
      - "Primary filtering field: 'event_type' (most reliable for server-side filtering)"
      - "Available event_type values: 'kv-v2/data-write', 'kv-v2/data-delete', 'kv-v2/data-patch', 'kv-v2/metadata-write', 'database/creds-create', etc."
      - "Equality: 'event_type == \"kv-v2/data-write\"'"
      - "Contains matching: 'event_type contains \"write\"'"
      - "Complex expressions: 'event_type == \"kv-v2/data-write\" or event_type == \"kv-v2/data-delete\"'"
    type: str
    required: false
    example: 'event_type == "kv-v2/data-write"'

requirements:
  - python >= 3.7
  - websockets >= 10.0
  - asyncio
  - HashiCorp Vault Enterprise 1.13+ or HCP Vault Dedicated with event streaming enabled
  - Proper Vault ACL policies for event subscription and secret access

author:
  - Ricardo Oliveira

notes:
  - Requires Vault Enterprise 1.13+ or HCP Vault Dedicated (not available in Community Edition).
  - Automatic WebSocket reconnection with exponential backoff.
  - Each event pattern creates a separate WebSocket connection.
  - Environment variables supported with ansible-rulebook --env-vars flag.
  - Requires proper ACL policies for event subscription and secret access.
  - Event notifications follow CloudEvents specification format.

seealso:
  - name: HashiCorp Vault Event Streaming
    description: Official Vault documentation for event streaming
    link: https://developer.hashicorp.com/vault/api-docs/system/events
  - name: Ansible Event-Driven Automation
    description: Official EDA documentation
    link: https://ansible.readthedocs.io/projects/rulebook/
"""

EXAMPLES = """
# Basic KV monitoring
- name: Monitor Vault KV events
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "http://127.0.0.1:8200"
        vault_token: "myroot"
        event_paths:
          - "kv-v2/*"

# Database credentials monitoring
- name: Monitor database events
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ VAULT_ADDR | default('http://127.0.0.1:8200') }}"
        vault_token: "{{ VAULT_TOKEN }}"
        event_paths:
          - "database/*"


# Multiple patterns (creates separate connections)
- name: Monitor multiple event types
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ VAULT_ADDR | default('http://127.0.0.1:8200') }}"
        vault_token: "{{ VAULT_TOKEN }}"
        event_paths:
          - "kv-v2/*"
          - "database/*"

# Development with self-signed certs
- name: Development monitoring
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "https://localhost:8200"
        vault_token: "dev-token"
        verify_ssl: false
        event_paths:
          - "kv-v2/*"

# Filter specific event types
- name: Monitor write operations only
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ VAULT_ADDR | default('http://127.0.0.1:8200') }}"
        vault_token: "{{ VAULT_TOKEN }}"
        event_paths:
          - "kv-v2/*"
        filter_expression: 'event_type == "kv-v2/data-write"'

# Filter using contains operator
- name: Monitor all write operations
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ VAULT_ADDR | default('http://127.0.0.1:8200') }}"
        vault_token: "{{ VAULT_TOKEN }}"
        event_paths:
          - "kv-v2/*"
          - "database/*"
        filter_expression: 'event_type contains "write"'

# Complex OR expressions
- name: Monitor write and delete operations
  sources:
    - gitrgoliveira.vault_eda.vault_events:
        vault_addr: "{{ VAULT_ADDR | default('http://127.0.0.1:8200') }}"
        vault_token: "{{ VAULT_TOKEN }}"
        event_paths:
          - "kv-v2/*"
        filter_expression: 'event_type == "kv-v2/data-write" or event_type == "kv-v2/data-delete"'
"""

"""
HashiCorp Vault WebSocket Event Source Plugin for Ansible Event-Driven Automation

This plugin connects to Vault's WebSocket event streaming endpoint and forwards
events to ansible-rulebook for processing. It supports real-time monitoring of
Vault operations including KV secrets, authentication, and policy changes.

Author: Ricardo Oliveira
License: Mozilla Public License 2.0 (MPL-2.0)
Dependencies: websockets, asyncio
"""

import asyncio
import json
import logging
import ssl
from typing import Any, Dict, List, Optional
from urllib.parse import quote

from websockets import connect
from websockets.exceptions import ConnectionClosed, WebSocketException

# Configure logging for the plugin
log = logging.getLogger("vault_events")


async def _stream_single_pattern(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    queue,
    vault_addr: str,
    event_pattern: str,
    headers: Dict[str, str],
    ping_interval: int,
    verify_ssl: bool,
    backoff_initial: float,
    backoff_max: float,
    filter_expression: Optional[str] = None,
):
    """
    Establish and maintain WebSocket connection to Vault events endpoint for a single pattern.

    Args:
        queue: asyncio queue for sending events to ansible-rulebook
        vault_addr: Base Vault server URL
        event_pattern: Single event pattern to subscribe to
        headers: HTTP headers including authentication
        ping_interval: Seconds between WebSocket ping frames
        verify_ssl: Whether to verify SSL certificates
        backoff_initial: Initial reconnection delay in seconds
        backoff_max: Maximum reconnection delay in seconds
        filter_expression: Optional go-bexpr boolean expression to filter events
    """
    # Build the WebSocket URL for this specific pattern
    url = _build_event_url(vault_addr, event_pattern, filter_expression)

    # Configure SSL context for secure connections
    ssl_ctx = None
    if url.startswith("wss://"):
        ssl_ctx = ssl.create_default_context()
        if not verify_ssl:
            # Disable SSL verification for development environments
            ssl_ctx.check_hostname = False
            ssl_ctx.verify_mode = ssl.CERT_NONE

    # Exponential backoff for reconnection attempts
    backoff = backoff_initial

    while True:
        try:
            # Establish WebSocket connection with proper headers
            async with connect(
                url,
                additional_headers=headers,
                ping_interval=ping_interval,
                ssl=ssl_ctx,
            ) as ws:
                log.info(
                    "Connected to Vault WebSocket for pattern '%s': %s",
                    event_pattern,
                    url,
                )
                backoff = backoff_initial  # Reset backoff on successful connection

                # Process incoming messages from Vault
                async for msg in ws:
                    try:
                        # Parse JSON event data from Vault
                        event = json.loads(msg)
                        log.debug(
                            "Received Vault event from pattern '%s': %s",
                            event_pattern,
                            event.get("event_type", "unknown"),
                        )
                    except json.JSONDecodeError as e:
                        # Handle malformed JSON gracefully
                        log.warning(
                            "Failed to parse JSON message from pattern '%s': %s",
                            event_pattern,
                            e,
                        )
                        event = {
                            "raw": msg,
                            "error": "json_decode_failed",
                            "pattern": event_pattern,
                        }
                    except (UnicodeDecodeError, ValueError, TypeError) as e:
                        # Handle any other parsing errors
                        log.error(
                            "Unexpected error parsing message from pattern '%s': %s",
                            event_pattern,
                            e,
                        )
                        event = {"raw": msg, "error": str(e), "pattern": event_pattern}

                    # Forward event to ansible-rulebook queue
                    await queue.put(event)

        except asyncio.CancelledError:
            # Handle graceful shutdown
            log.info(
                "WebSocket connection for pattern '%s' cancelled, shutting down",
                event_pattern,
            )
            raise
        except (ConnectionClosed, WebSocketException, OSError, ssl.SSLError) as e:
            # Handle connection errors with exponential backoff
            log.warning(
                "WebSocket for pattern '%s' disconnected: %s; reconnecting in %.1fs",
                event_pattern,
                e,
                backoff,
            )
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, backoff_max)  # Exponential backoff with cap


async def _stream_multiple_patterns(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    queue,
    vault_addr: str,
    event_paths: List[str],
    headers: Dict[str, str],
    ping_interval: int,
    verify_ssl: bool,
    backoff_initial: float,
    backoff_max: float,
    filter_expression: Optional[str] = None,
):
    """
    Manage multiple WebSocket connections for different event patterns.

    Args:
        queue: asyncio queue for sending events to ansible-rulebook
        vault_addr: Base Vault server URL
        event_paths: List of event patterns to subscribe to
        headers: HTTP headers including authentication
        ping_interval: Seconds between WebSocket ping frames
        verify_ssl: Whether to verify SSL certificates
        backoff_initial: Initial reconnection delay in seconds
        backoff_max: Maximum reconnection delay in seconds
        filter_expression: Optional go-bexpr boolean expression to filter events
    """
    # Create tasks for each event pattern
    tasks = []
    for pattern in event_paths:
        log.info("Creating WebSocket connection for event pattern: %s", pattern)
        task = asyncio.create_task(
            _stream_single_pattern(
                queue,
                vault_addr,
                pattern,
                headers,
                ping_interval,
                verify_ssl,
                backoff_initial,
                backoff_max,
                filter_expression,
            )
        )
        tasks.append(task)

    try:
        # Wait for all tasks to complete (they run indefinitely)
        await asyncio.gather(*tasks)
    except asyncio.CancelledError:
        # Cancel all tasks when shutting down
        log.info("Cancelling all WebSocket connections")
        for task in tasks:
            task.cancel()
        # Wait for all tasks to finish cancellation
        await asyncio.gather(*tasks, return_exceptions=True)
        raise


def _build_event_url(vault_addr: str, event_pattern: str, filter_expression: Optional[str] = None) -> str:
    """
    Construct the WebSocket URL for Vault event subscription.

    Args:
        vault_addr: Base Vault server URL (http/https)
        event_pattern: Single event pattern to subscribe to
        filter_expression: Optional go-bexpr boolean expression to filter events

    Returns:
        Complete WebSocket URL for event subscription
    """
    # Convert HTTP(S) to WebSocket scheme
    if vault_addr.startswith("https://"):
        ws_url = vault_addr.replace("https://", "wss://")
    else:
        ws_url = vault_addr.replace("http://", "ws://")

    # Build base event subscription URL
    event_url = f"{ws_url}/v1/sys/events/subscribe/{event_pattern}?json=true"
    
    # Add filter expression if provided
    if filter_expression:
        encoded_filter = quote(filter_expression)
        event_url += f"&filter={encoded_filter}"
        log.info("Applied filter expression: %s", filter_expression)
    
    log.info("Built event URL: %s", event_url)

    return event_url


async def main(queue: Any, args: Dict[str, Any]):
    """
    Main entry point for the Vault events plugin.

    This function is called by ansible-rulebook to start the event source.
    It processes configuration parameters and initiates WebSocket connections.

    Args:
        queue: asyncio queue for sending events to ansible-rulebook
        args: Configuration dictionary from the rulebook YAML

    Expected args:
        vault_addr: Vault server URL (e.g., "http://127.0.0.1:8200")
        vault_token: Vault authentication token
        event_paths: List of event patterns to subscribe to (separate connection per pattern)
        verify_ssl: Whether to verify SSL certificates (default: True)
        ping_interval: WebSocket ping interval in seconds (default: 20)
        backoff_initial: Initial reconnection delay (default: 1.0)
        backoff_max: Maximum reconnection delay (default: 30.0)
        namespace: Optional Vault namespace
        headers: Optional additional HTTP headers
        filter_expression: Optional go-bexpr boolean expression to filter events

    Note:
        Each event pattern in event_paths will get its own WebSocket connection.
        For best performance, use patterns with wildcards (e.g., "kv-v2/*").
    """
    log.info("Starting Vault WebSocket event source plugin")

    # Extract and validate required parameters
    vault_addr = args.get("vault_addr")
    if not vault_addr:
        raise ValueError("vault_addr parameter is required")

    vault_token = args.get("vault_token")
    if not vault_token:
        raise ValueError("vault_token parameter is required")

    event_paths = args.get("event_paths", ["kv-v2/data-*"])
    if isinstance(event_paths, str):
        event_paths = [event_paths]  # Convert single string to list

    log.info("Vault Address: %s", vault_addr)
    log.info("Event Paths: %s", event_paths)

    # Inform about multiple connections
    if len(event_paths) > 1:
        log.info(
            "Multiple event paths provided. Creating %d separate WebSocket connections.",
            len(event_paths),
        )
        log.info(
            "For optimal performance, consider using single patterns with wildcards (e.g., 'kv-v2/*', 'database/*', '*')."
        )

    # Prepare HTTP headers for authentication
    headers: Dict[str, str] = {}
    headers["X-Vault-Token"] = vault_token

    # Add optional Vault namespace header
    if args.get("namespace"):
        headers["X-Vault-Namespace"] = args["namespace"]
        log.info("Using Vault namespace: %s", args["namespace"])

    # Add any additional custom headers
    custom_headers = args.get("headers", {})
    if custom_headers:
        headers.update(custom_headers)
        log.info("Added custom headers: %s", list(custom_headers.keys()))

    # Extract connection parameters with defaults
    verify_ssl = bool(args.get("verify_ssl", True))
    ping_interval = int(args.get("ping_interval", 20))
    backoff_initial = float(args.get("backoff_initial", 1.0))
    backoff_max = float(args.get("backoff_max", 30.0))
    filter_expression = args.get("filter_expression")

    log.info(
        "Connection settings - SSL verify: %s, Ping interval: %ds",
        verify_ssl,
        ping_interval,
    )
    
    if filter_expression:
        log.info("Using filter expression: %s", filter_expression)

    # Start the WebSocket streams - create separate connections for multiple patterns
    await _stream_multiple_patterns(
        queue=queue,
        vault_addr=vault_addr,
        event_paths=event_paths,
        headers=headers,
        ping_interval=ping_interval,
        verify_ssl=verify_ssl,
        backoff_initial=backoff_initial,
        backoff_max=backoff_max,
        filter_expression=filter_expression,
    )
