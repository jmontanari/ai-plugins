"""
Tests for transcript_eval.config — load_config precedence + SF-6 guard.

Test Data (from plan Phase 1):
  TS-config-precedence:
    - CLI --store=/a + env SPEC_FLOW_INSIGHTS_STORE=/b → resolves /a (CLI wins)
    - env only → /b
    - neither → default (/Volumes/joeData/spec-flow-insights/)
"""
import pytest
from pathlib import Path
from types import SimpleNamespace

from transcript_eval.config import (
    Config,
    Thresholds,
    DEFAULT_STORE,
    _REPO_ROOT,
    load_config,
)


# ---------------------------------------------------------------------------
# TS-config-precedence
# ---------------------------------------------------------------------------
def test_config_cli_wins_over_env(tmp_path):
    """CLI --store=/a wins over SPEC_FLOW_INSIGHTS_STORE=/b."""
    cli_args = SimpleNamespace(store=str(tmp_path / "a"), project_dir=None)
    env = {"SPEC_FLOW_INSIGHTS_STORE": str(tmp_path / "b")}
    config = load_config(cli_args, env)
    assert config.store_path == Path(tmp_path / "a")


def test_config_env_wins_over_default(tmp_path):
    """SPEC_FLOW_INSIGHTS_STORE env var wins over default when no CLI flag."""
    cli_args = SimpleNamespace(store=None, project_dir=None)
    env = {"SPEC_FLOW_INSIGHTS_STORE": str(tmp_path / "b")}
    config = load_config(cli_args, env)
    assert config.store_path == Path(tmp_path / "b")


def test_config_default_when_neither(tmp_path):
    """Neither CLI nor env → default store path used."""
    cli_args = SimpleNamespace(store=None, project_dir=None)
    env = {}
    config = load_config(cli_args, env)
    assert config.store_path == DEFAULT_STORE


def test_config_project_dir_from_cli(tmp_path):
    """--project-dir from CLI is used."""
    d1 = tmp_path / "proj1"
    d2 = tmp_path / "proj2"
    cli_args = SimpleNamespace(store=str(tmp_path / "store"), project_dir=[str(d1), str(d2)])
    config = load_config(cli_args, {})
    assert Path(d1) in config.project_dirs
    assert Path(d2) in config.project_dirs


def test_config_project_dir_from_env(tmp_path):
    """SPEC_FLOW_PROJECT_DIRS env var (colon-separated) is used when no CLI flag."""
    d1 = tmp_path / "proj1"
    d2 = tmp_path / "proj2"
    cli_args = SimpleNamespace(store=str(tmp_path / "store"), project_dir=None)
    env = {"SPEC_FLOW_PROJECT_DIRS": f"{d1}:{d2}"}
    config = load_config(cli_args, env)
    assert Path(d1) in config.project_dirs
    assert Path(d2) in config.project_dirs


# ---------------------------------------------------------------------------
# SF-6 guard: in-repo store_path rejected at construction
# ---------------------------------------------------------------------------
def test_config_rejects_in_repo_store_path():
    """store_path under repo root is rejected at Config construction (SF-6)."""
    in_repo = _REPO_ROOT / "tools" / "transcript-eval" / ".bad-store"
    with pytest.raises(ValueError, match="SF-6"):
        Config(project_dirs=[], store_path=in_repo)


def test_config_accepts_external_store_path(tmp_path):
    """store_path outside repo root is accepted."""
    # tmp_path is under /tmp — definitely outside repo root.
    config = Config(project_dirs=[], store_path=tmp_path / "store")
    assert config.store_path == tmp_path / "store"


# ---------------------------------------------------------------------------
# Thresholds defaults
# ---------------------------------------------------------------------------
def test_thresholds_defaults():
    """Default thresholds match spec: coverage=0.95, agreement=0.80."""
    t = Thresholds()
    assert t.coverage == 0.95
    assert t.agreement == 0.80
