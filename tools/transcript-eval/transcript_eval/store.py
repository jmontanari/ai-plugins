"""
External insight store writer for transcript-eval.

Writes ONLY to the configured store_path (outside the repo).
An unwritable store parent raises StoreUnwritableError — no in-repo fallback (SF-NFR-4).
Every write target is asserted to be under store_path (SF-6).
"""
from __future__ import annotations

import json
import os
from pathlib import Path

from .config import Config, _REPO_ROOT


class StoreUnwritableError(RuntimeError):
    """Raised when the insight store path or its parent is not writable."""


class InsightStore:
    """Manages all writes to the external insight store."""

    def __init__(self, config: Config) -> None:
        self.store_path = config.store_path.resolve()

        # SF-6: store must not be under the repo root.
        try:
            self.store_path.relative_to(_REPO_ROOT)
            raise StoreUnwritableError(
                f"insight store {self.store_path!r} is under the repo root "
                f"({_REPO_ROOT}) — in-repo stores are forbidden (SF-6)."
            )
        except ValueError:
            pass  # Normal: path is NOT relative to repo root — this is what we want.

        # Writability check: create store_path if parent is writable; fail loudly otherwise.
        if self.store_path.exists():
            if not os.access(self.store_path, os.W_OK):
                raise StoreUnwritableError(
                    f"insight store unwritable: {self.store_path} — refusing in-repo fallback"
                )
        else:
            parent = self.store_path.parent
            if not os.access(parent, os.W_OK):
                raise StoreUnwritableError(
                    f"insight store unwritable: {self.store_path} — "
                    f"parent directory {parent} is not writable — refusing in-repo fallback"
                )
            self.store_path.mkdir(parents=True, exist_ok=True)

    def _assert_under_store(self, path: Path) -> None:
        """Assert that path is under store_path and not under the repo root."""
        resolved = path.resolve()
        try:
            resolved.relative_to(self.store_path)
        except ValueError as exc:
            raise StoreUnwritableError(
                f"write target {resolved!r} is outside the store root "
                f"{self.store_path!r} — SF-6 violation."
            ) from exc
        # Also guard against repo root writes.
        try:
            resolved.relative_to(_REPO_ROOT)
            raise StoreUnwritableError(
                f"write target {resolved!r} is under the repo root ({_REPO_ROOT}) — SF-6 violation."
            )
        except ValueError:
            pass  # Good: not under repo root.

    def append_run(self, record: dict) -> None:
        """Append one JSON line to <store>/run-index.jsonl with a 'kind' field."""
        target = self.store_path / "run-index.jsonl"
        self._assert_under_store(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")

    def write_aggregates(self, data: dict) -> None:
        """Write aggregates to <store>/aggregates.json (overwrites)."""
        target = self.store_path / "aggregates.json"
        self._assert_under_store(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def write_story(self, run_id: str, content: str) -> None:
        """
        Write story to <store>/story-latest.md and archive to <store>/stories/<run_id>.md.
        """
        # story-latest.md
        latest = self.store_path / "story-latest.md"
        self._assert_under_store(latest)
        latest.parent.mkdir(parents=True, exist_ok=True)
        latest.write_text(content, encoding="utf-8")

        # stories/<run_id>.md archive
        archive = self.store_path / "stories" / f"{run_id}.md"
        self._assert_under_store(archive)
        archive.parent.mkdir(parents=True, exist_ok=True)
        archive.write_text(content, encoding="utf-8")
