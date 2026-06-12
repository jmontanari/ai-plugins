"""
Config loader for transcript-eval.

Precedence: CLI flag > env var > default (no in-repo write target is ever a valid store_path).
SF-6 guard: store_path under the repo root is rejected at construction.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

DEFAULT_STORE = Path("/Volumes/joeData/spec-flow-insights/")
DEFAULT_PROJECT_GLOB = "~/.claude/projects/*/"

# Repo root — used to guard against in-repo store paths (SF-6).
# Resolve from this file's location: tools/transcript-eval/transcript_eval/config.py
# → ../../../../ = repo root
_REPO_ROOT = Path(__file__).resolve().parents[3]


@dataclass
class Thresholds:
    coverage: float = 0.95
    agreement: float = 0.80


@dataclass
class Config:
    project_dirs: list[Path]
    store_path: Path
    thresholds: Thresholds = field(default_factory=Thresholds)

    def __post_init__(self) -> None:
        # SF-6 guard: reject any store_path that resolves under the repo root.
        try:
            self.store_path.resolve().relative_to(_REPO_ROOT)
        except ValueError:
            # relative_to raises ValueError when the path is NOT under _REPO_ROOT — that's the
            # safe / expected case; swallow it and proceed.
            return
        raise ValueError(
            f"store_path {self.store_path!r} resolves under the repo root "
            f"({_REPO_ROOT}) — in-repo store paths are forbidden (SF-6)."
        )


def _default_project_dirs() -> list[Path]:
    """Return all ~/.claude/projects/*/ directories (glob-expanded)."""
    base = Path("~/.claude/projects/").expanduser()
    if base.exists():
        dirs = sorted(p for p in base.iterdir() if p.is_dir())
        return dirs if dirs else [base]
    return [base]


def load_config(cli_args: Any, env: dict[str, str] | None = None) -> Config:
    """
    Build a Config from CLI args + environment.

    cli_args: a namespace from argparse (or any object with .store / .project_dir attrs).
    env: a dict-like of env vars (defaults to os.environ if None).
    """
    if env is None:
        env = dict(os.environ)

    # --- store_path ---
    store_raw = None
    if getattr(cli_args, "store", None):
        store_raw = cli_args.store
    elif env.get("SPEC_FLOW_INSIGHTS_STORE"):
        store_raw = env["SPEC_FLOW_INSIGHTS_STORE"]

    store_path = Path(store_raw) if store_raw else DEFAULT_STORE

    # --- project_dirs ---
    project_dirs: list[Path] = []
    cli_dirs = getattr(cli_args, "project_dir", None) or []
    if cli_dirs:
        project_dirs = [Path(d) for d in cli_dirs]
    elif env.get("SPEC_FLOW_PROJECT_DIRS"):
        project_dirs = [Path(d) for d in env["SPEC_FLOW_PROJECT_DIRS"].split(":") if d]
    else:
        project_dirs = _default_project_dirs()

    return Config(
        project_dirs=project_dirs,
        store_path=store_path,
    )
