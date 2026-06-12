"""
Extraction logic for transcript-eval.

Parses Claude Code .jsonl session transcripts and extracts:
- Gate/board-seat Agent dispatches (measured seats only)
- Correlated tool_result responses
- Individual findings from result text
- Accept/reject inference per finding (ADR-6 heuristic)

SF-NFR-2: best-effort field-probing; emits None on miss, reports misses.
SF-NFR-3: never raises on malformed .jsonl lines — null + increment miss counter.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator


# ---------------------------------------------------------------------------
# Measured seat set — subagent_type values tracked by the eval harness
# ---------------------------------------------------------------------------

MEASURED_SEATS: frozenset[str] = frozenset(
    [
        "spec-flow:qa-spec",
        "spec-flow:qa-plan",
        "spec-flow:qa-phase",
        "spec-flow:qa-phase-lite",
        "spec-flow:qa-tdd-red",
        "spec-flow:review-board-architecture",
        "spec-flow:review-board-blind",
        "spec-flow:review-board-edge-case",
        "spec-flow:review-board-ground-truth",
        "spec-flow:review-board-integration",
        "spec-flow:review-board-prd-alignment",
        "spec-flow:review-board-security",
        "spec-flow:review-board-spec-compliance",
        "spec-flow:verify",
    ]
)


def is_measured_seat(subagent_type: str) -> bool:
    """Return True if subagent_type is in the measured seat set."""
    return subagent_type in MEASURED_SEATS


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class Finding:
    text: str
    accept_reject: str | None = None  # "accepted" | "rejected" | None (ambiguous)


@dataclass
class Dispatch:
    tool_use_id: str
    seat: str          # subagent_type value
    result_text: str | None = None
    findings: list[Finding] = field(default_factory=list)


@dataclass
class CoverageReport:
    sessions_parsed: int = 0
    lines_missed: int = 0     # lines that failed json.JSONDecodeError
    fields_missed: int = 0    # fields that were None/missing in otherwise-valid records
    inference_ambiguous: int = 0  # findings where accept/reject could not be determined


# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------

def _text_of(content: object) -> str | None:
    """
    Extract text from tool_result content, which may be:
    - a plain string
    - a list of blocks: [{"type": "text", "text": "..."}]
    - None / unexpected type → return None
    """
    if content is None:
        return None
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text", ""))
        return "\n".join(parts) if parts else None
    return None


# ---------------------------------------------------------------------------
# Core extraction functions
# ---------------------------------------------------------------------------

def iter_records(jsonl_path: Path) -> Iterator[dict | None]:
    """
    Yield one dict per line in jsonl_path.

    SF-NFR-3: on json.JSONDecodeError yields None (caller must count misses).
    NEVER raises — all exceptions on individual lines are swallowed.
    The returned None signals a parse miss to the caller.
    """
    try:
        lines = jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            yield None


def extract_dispatches(records: list[dict | None]) -> list[Dispatch]:
    """
    Scan records for assistant messages containing Agent/Task tool_use blocks
    whose subagent_type is in MEASURED_SEATS.

    Returns a list of Dispatch objects (result_text populated by correlate_results).
    """
    dispatches: list[Dispatch] = []
    for record in records:
        if record is None:
            continue
        if record.get("type") != "assistant":
            continue
        message = record.get("message") or {}
        content = message.get("content") or []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") != "tool_use":
                continue
            if block.get("name") not in ("Agent", "Task"):
                continue
            input_data = block.get("input") or {}
            seat = input_data.get("subagent_type", "")
            if not is_measured_seat(seat):
                continue
            tool_use_id = block.get("id")
            if tool_use_id is None:
                continue
            dispatches.append(Dispatch(tool_use_id=tool_use_id, seat=seat))
    return dispatches


def correlate_results(
    records: list[dict | None],
    dispatches: list[Dispatch],
) -> None:
    """
    Mutate each Dispatch's result_text by scanning for tool_result records
    whose tool_use_id matches the dispatch's tool_use_id.

    Real schema pattern (Cluster A — confirmed 58/58 correlation):
      user-type messages with content[].type == "tool_result"
    """
    # Build a fast lookup: tool_use_id → Dispatch
    id_to_dispatch: dict[str, Dispatch] = {d.tool_use_id: d for d in dispatches}

    for record in records:
        if record is None:
            continue
        message = record.get("message") or {}
        content = message.get("content") or []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") != "tool_result":
                continue
            tuid = block.get("tool_use_id")
            if tuid not in id_to_dispatch:
                continue
            dispatch = id_to_dispatch[tuid]
            dispatch.result_text = _text_of(block.get("content"))


# ---------------------------------------------------------------------------
# Finding extraction
# ---------------------------------------------------------------------------

# Split on FINDING: markers (linear-time; avoids DOTALL + lookahead backtracking on large inputs)
_FINDING_SPLIT_RE = re.compile(
    r"(?im)^[^\S\n]*(?:[-*•][^\S\n]*)?FINDING:",
)


def extract_findings(result_text: str | None) -> list[Finding]:
    """
    Extract Finding objects from a gate result text string.

    Looks for lines beginning with "FINDING:" (case-insensitive).
    If no FINDING: pattern is found and result_text is non-empty, treats
    the entire text as a single finding (best-effort).

    Returns an empty list if result_text is None or whitespace-only.
    """
    if not result_text or not result_text.strip():
        return []

    parts = _FINDING_SPLIT_RE.split(result_text)
    if len(parts) > 1:
        # parts[0] is content before the first FINDING: — discard it
        return [Finding(text=p.strip()) for p in parts[1:] if p.strip()]

    # Fallback: no FINDING: prefix found — treat full text as one finding
    return [Finding(text=result_text.strip())]


# ---------------------------------------------------------------------------
# Accept/reject inference (ADR-6 heuristic)
# ---------------------------------------------------------------------------

# Downstream agent types that indicate a finding was acted upon (accepted)
_DOWNSTREAM_FIX_SEATS = frozenset(
    [
        "spec-flow:fix-doc",
        "spec-flow:fix-code",
        "spec-flow:implementer",
    ]
)

# Edit tool names (inline file edits also indicate acceptance)
_EDIT_TOOLS = frozenset(["Edit", "Write", "NotebookEdit"])


def infer_accept_reject(
    finding: Finding,
    downstream_records: list[dict | None],
) -> str:
    """
    ADR-6 heuristic: return "accepted" if any downstream fix-dispatch or Edit
    follows the finding; otherwise return "rejected".

    KNOWN DEVIATION from the full ADR-6 spec: the plan specifies "referencing
    the finding" — i.e. the downstream dispatch's prompt should mention this
    finding specifically. This implementation uses PRESENCE ONLY (any downstream
    fix in the session window ⇒ accepted), not text-proximity.

    Consequence in multi-finding sessions: an unrelated fix dispatch that
    follows a rejected finding can mislabel it as "accepted" (false-positive
    acceptance). This over-counts precision. The SF-7 spike's ≥80% agreement
    gate is the designed catch point — a low agreement score here means
    "heuristic too broad", not "extraction broken" (ADR-6: "revisit the
    inference design" on HALT).
    """
    for record in downstream_records:
        if record is None:
            continue
        if record.get("type") != "assistant":
            continue
        message = record.get("message") or {}
        content = message.get("content") or []
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            # Fix-agent dispatch
            if btype == "tool_use" and block.get("name") in ("Agent", "Task"):
                input_data = block.get("input") or {}
                seat = input_data.get("subagent_type", "")
                if seat in _DOWNSTREAM_FIX_SEATS:
                    return "accepted"
            # Inline edit tool
            if btype == "tool_use" and block.get("name") in _EDIT_TOOLS:
                return "accepted"

    return "rejected"


# ---------------------------------------------------------------------------
# High-level session extraction
# ---------------------------------------------------------------------------

def extract_session(
    jsonl_path: Path,
    coverage: CoverageReport,
) -> list[Dispatch]:
    """
    Full extraction pipeline for one session file.

    1. iter_records (counting parse misses)
    2. extract_dispatches
    3. correlate_results
    4. extract_findings per dispatch
    5. infer_accept_reject for each finding

    Mutates coverage in place. Returns list of Dispatch objects.
    """
    coverage.sessions_parsed += 1

    records: list[dict | None] = []
    for rec in iter_records(jsonl_path):
        records.append(rec)
        if rec is None:
            coverage.lines_missed += 1

    dispatches = extract_dispatches(records)
    correlate_results(records, dispatches)

    for dispatch in dispatches:
        if dispatch.result_text is None:
            coverage.fields_missed += 1
            continue
        dispatch.findings = extract_findings(dispatch.result_text)

        # Find the index of this dispatch in records to get downstream records
        dispatch_idx = _find_dispatch_index(records, dispatch.tool_use_id)
        downstream = records[dispatch_idx + 1:] if dispatch_idx >= 0 else []

        for finding in dispatch.findings:
            finding.accept_reject = infer_accept_reject(finding, downstream)
            if finding.accept_reject is None:
                coverage.inference_ambiguous += 1

    return dispatches


def _find_dispatch_index(records: list[dict | None], tool_use_id: str) -> int:
    """Return the index in records of the assistant message containing tool_use_id."""
    for i, record in enumerate(records):
        if record is None:
            continue
        if record.get("type") != "assistant":
            continue
        message = record.get("message") or {}
        content = message.get("content") or []
        for block in content:
            if (
                isinstance(block, dict)
                and block.get("type") == "tool_use"
                and block.get("id") == tool_use_id
            ):
                return i
    return -1
