# pyright: reportMissingImports=false

import asyncio
import json
from urllib.parse import parse_qs, urlparse

import pytest
from unittest.mock import AsyncMock


class _FakeWebSocket:
    def __init__(self, messages):
        self._messages = list(messages)

    def __aiter__(self):
        return self._iter_messages()

    async def _iter_messages(self):
        for message in self._messages:
            yield message
        raise asyncio.CancelledError()


class _ConnectContextManager:
    def __init__(self, websocket):
        self._websocket = websocket

    async def __aenter__(self):
        return self._websocket

    async def __aexit__(self, exc_type, exc, tb):
        return False


class _FailingConnectContextManager:
    async def __aenter__(self):
        raise OSError("connection dropped")

    async def __aexit__(self, exc_type, exc, tb):
        return False


def test_build_event_url_without_filter(vault_events_module):
    url = vault_events_module._build_event_url(
        "http://127.0.0.1:8200",
        "kv-v2/*",
    )

    assert url == "ws://127.0.0.1:8200/v1/sys/events/subscribe/kv-v2/*?json=true"


def test_build_event_url_with_filter(vault_events_module):
    url = vault_events_module._build_event_url(
        "https://vault.example.com:8200",
        "kv-v2/*",
        'event_type == "kv-v2/data-write"',
    )

    parsed = urlparse(url)
    query = parse_qs(parsed.query)

    assert parsed.scheme == "wss"
    assert parsed.netloc == "vault.example.com:8200"
    assert parsed.path == "/v1/sys/events/subscribe/kv-v2/*"
    assert query["json"] == ["true"]
    assert query["filter"] == ['event_type == "kv-v2/data-write"']


@pytest.mark.asyncio
async def test_main_requires_vault_addr(vault_events_module):
    with pytest.raises(ValueError, match="vault_addr parameter is required"):
        await vault_events_module.main(asyncio.Queue(), {"vault_token": "token"})


@pytest.mark.asyncio
async def test_main_requires_vault_token(vault_events_module):
    with pytest.raises(ValueError, match="vault_token parameter is required"):
        await vault_events_module.main(asyncio.Queue(), {"vault_addr": "http://127.0.0.1:8200"})


@pytest.mark.asyncio
async def test_main_normalizes_event_paths_and_headers(monkeypatch, vault_events_module):
    stream_mock = AsyncMock()
    monkeypatch.setattr(vault_events_module, "_stream_multiple_patterns", stream_mock)

    queue = asyncio.Queue()
    args = {
        "vault_addr": "http://127.0.0.1:8200",
        "vault_token": "my-token",
        "event_paths": "kv-v2/*",
        "namespace": "admin",
        "headers": {"X-Custom": "value"},
        "verify_ssl": False,
        "ping_interval": 30,
        "backoff_initial": 0.5,
        "backoff_max": 5.0,
        "filter_expression": 'event_type contains "write"',
    }

    await vault_events_module.main(queue, args)

    stream_mock.assert_awaited_once()
    await_args = stream_mock.await_args
    assert await_args is not None
    call = await_args.kwargs

    assert call["queue"] is queue
    assert call["vault_addr"] == "http://127.0.0.1:8200"
    assert call["event_paths"] == ["kv-v2/*"]
    assert call["headers"]["X-Vault-Token"] == "my-token"
    assert call["headers"]["X-Vault-Namespace"] == "admin"
    assert call["headers"]["X-Custom"] == "value"
    assert call["verify_ssl"] is False
    assert call["ping_interval"] == 30
    assert call["backoff_initial"] == 0.5
    assert call["backoff_max"] == 5.0
    assert call["filter_expression"] == 'event_type contains "write"'


@pytest.mark.asyncio
async def test_stream_single_pattern_queues_valid_json_event(monkeypatch, vault_events_module):
    queue = asyncio.Queue()
    websocket = _FakeWebSocket([json.dumps({"event_type": "kv-v2/data-write", "event": {}})])

    monkeypatch.setattr(
        vault_events_module,
        "connect",
        lambda *args, **kwargs: _ConnectContextManager(websocket),
    )

    with pytest.raises(asyncio.CancelledError):
        await vault_events_module._stream_single_pattern(
            queue=queue,
            vault_addr="http://127.0.0.1:8200",
            event_pattern="kv-v2/*",
            headers={"X-Vault-Token": "token"},
            ping_interval=20,
            verify_ssl=True,
            backoff_initial=1.0,
            backoff_max=30.0,
        )

    event = await asyncio.wait_for(queue.get(), timeout=1.0)
    assert event["event_type"] == "kv-v2/data-write"


@pytest.mark.asyncio
async def test_stream_single_pattern_handles_malformed_json(monkeypatch, vault_events_module):
    queue = asyncio.Queue()
    websocket = _FakeWebSocket(["not-json"])

    monkeypatch.setattr(
        vault_events_module,
        "connect",
        lambda *args, **kwargs: _ConnectContextManager(websocket),
    )

    with pytest.raises(asyncio.CancelledError):
        await vault_events_module._stream_single_pattern(
            queue=queue,
            vault_addr="http://127.0.0.1:8200",
            event_pattern="kv-v2/*",
            headers={"X-Vault-Token": "token"},
            ping_interval=20,
            verify_ssl=True,
            backoff_initial=1.0,
            backoff_max=30.0,
        )

    event = await asyncio.wait_for(queue.get(), timeout=1.0)
    assert event["raw"] == "not-json"
    assert event["error"] == "json_decode_failed"
    assert event["pattern"] == "kv-v2/*"


@pytest.mark.asyncio
async def test_stream_single_pattern_retries_with_exponential_backoff(monkeypatch, vault_events_module):
    sleep_durations = []

    async def fake_sleep(duration):
        sleep_durations.append(duration)
        if len(sleep_durations) >= 2:
            raise asyncio.CancelledError()

    monkeypatch.setattr(
        vault_events_module,
        "connect",
        lambda *args, **kwargs: _FailingConnectContextManager(),
    )
    monkeypatch.setattr(vault_events_module.asyncio, "sleep", fake_sleep)

    with pytest.raises(asyncio.CancelledError):
        await vault_events_module._stream_single_pattern(
            queue=asyncio.Queue(),
            vault_addr="http://127.0.0.1:8200",
            event_pattern="kv-v2/*",
            headers={"X-Vault-Token": "token"},
            ping_interval=20,
            verify_ssl=True,
            backoff_initial=1.0,
            backoff_max=30.0,
        )

    assert sleep_durations == [1.0, 2.0]
