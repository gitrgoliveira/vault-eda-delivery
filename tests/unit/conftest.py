# pyright: reportMissingImports=false

import importlib.util
from pathlib import Path
from types import ModuleType

import pytest


@pytest.fixture(scope="session")
def vault_events_module() -> ModuleType:
    """Load vault_events plugin module directly from repository path for unit testing."""
    repo_root = Path(__file__).resolve().parents[2]
    plugin_path = (
        repo_root
        / "collections"
        / "ansible_collections"
        / "gitrgoliveira"
        / "vault_eda"
        / "plugins"
        / "event_source"
        / "vault_events.py"
    )

    spec = importlib.util.spec_from_file_location("vault_events_under_test", plugin_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module specification from {plugin_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
