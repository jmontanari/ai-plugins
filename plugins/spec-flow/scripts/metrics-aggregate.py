#!/usr/bin/env python3
# metrics-aggregate.py — python fast path (awk-output-identical).
# See plugins/spec-flow/reference/metrics-artifact.md for schema and SC contract.
import sys
import os
import re


# ---------------------------------------------------------------------------
# YAML loader
# ---------------------------------------------------------------------------

def _load_yaml_stdlib(path):
    """Load a YAML file using PyYAML if available, otherwise use manual parser."""
    try:
        import yaml
        with open(path) as f:
            return yaml.safe_load(f)
    except ImportError:
        pass
    # Fallback: manual block-style parser
    return _parse_metrics_manual(path)


def _parse_metrics_manual(path):
    """
    Minimal block-style YAML parser for the metrics.yaml schema.
    Handles the exact indentation structure defined in metrics-artifact.md.
    No inline flow maps (ADR-1 guarantees this).
    Returns a dict matching PyYAML's safe_load output, or None on hard error.
    """
    try:
        with open(path) as f:
            lines = f.readlines()
    except OSError:
        return None

    result = {}
    section = None      # top-level key: spec | plan | execute | final_review | etc.
    subsection = None   # 2-space key under execute: phases | discoveries | spikes | amendments | resume
    in_resume_item = False
    current_resume_item = None

    def set_nested(d, keys, value):
        for k in keys[:-1]:
            d = d.setdefault(k, {})
        d[keys[-1]] = value

    def parse_value(v):
        v = v.strip()
        # Strip inline YAML comments — match awk which strips from any '#'
        # Prefer ' #' (space before hash) first; fall back to bare '#'
        idx = v.find(' #')
        if idx == -1:
            idx = v.find('#')
        if idx != -1:
            v = v[:idx].rstrip()
        if v in ('true', 'True'):
            return True
        if v in ('false', 'False'):
            return False
        if v == 'null' or v == '~' or v == '':
            return None
        try:
            return int(v)
        except ValueError:
            pass
        try:
            return float(v)
        except ValueError:
            pass
        return v

    for line in lines:
        # Strip trailing newline
        raw = line.rstrip('\n').rstrip('\r')
        stripped = raw.strip()
        if not stripped or stripped.startswith('#'):
            continue

        # Count leading spaces
        indent = len(raw) - len(raw.lstrip(' '))

        # Top-level key (indent == 0)
        if indent == 0 and ':' in raw:
            m = re.match(r'^([a-z_]+):\s*(.*)', raw)
            if m:
                section = m.group(1)
                subsection = None
                in_resume_item = False
                current_resume_item = None
                val = m.group(2).strip()
                if val and val != '|' and val != '>':
                    result[section] = parse_value(val)
                elif section not in result:
                    result[section] = {}
            continue

        # 2-space key under a section (indent == 2)
        if indent == 2 and section:
            m = re.match(r'^  ([a-z_]+):\s*(.*)', raw)
            if m:
                key = m.group(1)
                val = m.group(2).strip()
                # Track execute subsections
                if section == 'execute' and not val:
                    subsection = key
                    in_resume_item = False
                    current_resume_item = None
                    if not isinstance(result.get(section), dict):
                        result[section] = {}
                    result[section].setdefault(key, {} if key != 'resume' else [])
                elif section == 'execute' and key == 'resume' and not val:
                    subsection = 'resume'
                    in_resume_item = False
                    current_resume_item = None
                    if not isinstance(result.get(section), dict):
                        result[section] = {}
                    result[section].setdefault('resume', [])
                else:
                    if not isinstance(result.get(section), dict):
                        result[section] = {}
                    if section == 'execute':
                        subsection = None
                        in_resume_item = False
                    if val and val not in ('|', '>'):
                        result[section][key] = parse_value(val)
                    elif not val:
                        result[section][key] = {}
            elif indent == 2 and raw.strip().startswith('- ') and section == 'execute' and subsection == 'resume':
                # New resume list item: "  - at: ..."
                if current_resume_item is not None:
                    result['execute']['resume'].append(current_resume_item)
                current_resume_item = {}
                in_resume_item = True
                m2 = re.match(r'^\s+-\s+at:\s*(.*)', raw)
                if m2:
                    current_resume_item['at'] = m2.group(1).strip()
            continue

        # 4-space key under execute subsection (indent == 4)
        if indent == 4 and section == 'execute' and subsection in ('phases', 'discoveries', 'spikes', 'amendments'):
            m = re.match(r'^    ([a-z_]+):\s*(.*)', raw)
            if m:
                key = m.group(1)
                val = m.group(2).strip()
                if not isinstance(result.get('execute'), dict):
                    result['execute'] = {}
                sub_dict = result['execute'].setdefault(subsection, {})
                if isinstance(sub_dict, dict) and val:
                    sub_dict[key] = parse_value(val)
            continue

        # 4-space resume list item "    - at: ..."
        if indent == 4 and section == 'execute' and subsection == 'resume':
            if raw.strip().startswith('- at:'):
                if current_resume_item is not None:
                    result['execute']['resume'].append(current_resume_item)
                current_resume_item = {}
                in_resume_item = True
                m2 = re.match(r'^\s+-\s+at:\s*(.*)', raw)
                if m2:
                    current_resume_item['at'] = m2.group(1).strip()
            continue

        # 6-space key under a resume item: "      outcome: ..."
        if indent == 6 and section == 'execute' and subsection == 'resume' and in_resume_item and current_resume_item is not None:
            m = re.match(r'^      ([a-z_]+):\s*(.*)', raw)
            if m:
                key = m.group(1)
                val = m.group(2).strip()
                current_resume_item[key] = parse_value(val)
            continue

    # Flush last resume item
    if current_resume_item is not None and section == 'execute' and subsection == 'resume':
        if isinstance(result.get('execute'), dict):
            result['execute'].setdefault('resume', []).append(current_resume_item)

    return result


# ---------------------------------------------------------------------------
# Piece order from manifest.yaml
# ---------------------------------------------------------------------------

def _safe_slug(slug: str) -> bool:
    """Return True if slug is safe for path construction (CWE-22)."""
    return '/' not in slug and '\\' not in slug and not slug.startswith('.')


def read_piece_order(path):
    """Read manifest.yaml and return piece slugs in manifest order."""
    slugs = []
    if not os.path.exists(path):
        print(f"metrics-aggregate: manifest not found: {path}", file=sys.stderr)
        return slugs
    try:
        with open(path) as f:
            in_pieces = False
            for line in f:
                if line.strip() == 'pieces:':
                    in_pieces = True
                    continue
                if in_pieces:
                    if line.startswith('  - ') or line.startswith('    '):
                        m = re.match(r'\s+slug:\s+(\S+)', line)
                        if m:
                            slug = m.group(1)
                            if not _safe_slug(slug):
                                print(f"metrics-aggregate: rejected unsafe slug: {slug!r}", file=sys.stderr)
                                continue
                            slugs.append(slug)
    except Exception:
        pass
    return slugs


# ---------------------------------------------------------------------------
# Metrics loader
# ---------------------------------------------------------------------------

def load_metrics(path):
    """Load and parse a metrics.yaml file. Returns None if missing or parse fails."""
    if not os.path.exists(path):
        return None
    try:
        data = _load_yaml_stdlib(path)
        if data is None:
            print(f"metrics-aggregate: parsed None from {path}", file=sys.stderr)
            return None
        if not isinstance(data, dict):
            print(f"metrics-aggregate: unexpected type from {path}: {type(data)}", file=sys.stderr)
            return None
        # schema_version presence check: a valid metrics.yaml must have schema_version
        if 'schema_version' not in data:
            print(f"metrics-aggregate: no schema_version in {path} — treating as malformed", file=sys.stderr)
            return None
        return data
    except Exception as e:
        print(f"metrics-aggregate: failed to parse {path}: {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# SC computation helpers
# ---------------------------------------------------------------------------

def emit_sc001(instrumented):
    """SC-001: population = research_artifact == True; pass if qa_rounds <= 3."""
    pop = [(s, d) for s, d in instrumented if d.get('spec', {}).get('research_artifact') is True]
    passed = sum(1 for s, d in pop if d.get('spec', {}).get('qa_rounds', 0) <= 3)
    total = len(pop)
    print(f"SC-001 pass={passed} total={total} population=research-artifact")


def emit_sc002(instrumented):
    """SC-002: population = concreteness_floor == passed; rate = clean/total >= 0.80."""
    pop = [(s, d) for s, d in instrumented if d.get('plan', {}).get('concreteness_floor') == 'passed']
    clean = sum(d.get('execute', {}).get('phases', {}).get('clean_sonnet', 0) for s, d in pop)
    total = sum(d.get('execute', {}).get('phases', {}).get('total', 0) for s, d in pop)
    if total == 0:
        rate = 0.0
        passes = False
    else:
        rate = clean / total
        passes = rate >= 0.80
    print(f"SC-002 rate={rate:.2f} threshold=0.80 pass={str(passes).lower()} population=concreteness-floor")


def split_halves(items):
    """Return (first_half, second_half) per the trend-split rule."""
    N = len(items)
    if N < 2:
        return None, None
    half = N // 2
    first = items[:half]
    second = items[N - half:]
    return first, second


def emit_sc003(instrumented, N):
    """SC-003: trend of execute.discoveries.unmarked, first vs second half."""
    if N < 2:
        print("SC-003 trend=insufficient-data")
        return
    first, second = split_halves(instrumented)
    f_sum = sum(d.get('execute', {}).get('discoveries', {}).get('unmarked', 0) for s, d in first)
    s_sum = sum(d.get('execute', {}).get('discoveries', {}).get('unmarked', 0) for s, d in second)
    trend = 'down' if s_sum < f_sum else ('up' if s_sum > f_sum else 'flat')
    print(f"SC-003 first={f_sum} second={s_sum} trend={trend}")


def emit_sc004(instrumented):
    """SC-004: resume_rate == 1.0 AND all sonnet_default == true."""
    if not instrumented:
        print("SC-004 trend=insufficient-data")
        return
    all_resume = []
    for s, d in instrumented:
        resume = d.get('execute', {}).get('resume', [])
        if isinstance(resume, list):
            all_resume.extend(resume)
    resume_total = len(all_resume)
    if resume_total == 0:
        resume_rate = 1.0
        resume_clean = 0
    else:
        resume_clean = sum(1 for r in all_resume if isinstance(r, dict) and r.get('outcome') == 'clean')
        resume_rate = resume_clean / resume_total
    sonnet_all = all(
        d.get('execute', {}).get('sonnet_default') is True
        for s, d in instrumented
    )
    # Use integer equality to avoid float precision issues (Fix 5)
    resume_ok = (resume_total == 0 or resume_clean == resume_total)
    passes = resume_ok and sonnet_all
    print(f"SC-004 resume_rate={resume_rate:.2f} sonnet_default_all={str(sonnet_all).lower()} pass={str(passes).lower()}")


def emit_sc005(instrumented, N):
    """SC-005: trend of spikes (planned + scope), first vs second half."""
    if N < 2:
        print("SC-005 trend=insufficient-data")
        return
    first, second = split_halves(instrumented)
    f_sum = sum(
        d.get('execute', {}).get('spikes', {}).get('planned', 0) +
        d.get('execute', {}).get('spikes', {}).get('scope', 0)
        for s, d in first
    )
    s_sum = sum(
        d.get('execute', {}).get('spikes', {}).get('planned', 0) +
        d.get('execute', {}).get('spikes', {}).get('scope', 0)
        for s, d in second
    )
    trend = 'down' if s_sum < f_sum else ('up' if s_sum > f_sum else 'flat')
    print(f"SC-005 first={f_sum} second={s_sum} trend={trend}")


def emit_sc006(instrumented):
    """SC-006: sum of repeat_scope == 0."""
    total_rs = sum(d.get('execute', {}).get('amendments', {}).get('repeat_scope', 0) for s, d in instrumented)
    passes = total_rs == 0
    print(f"SC-006 repeat_scope_sum={total_rs} pass={str(passes).lower()}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _emit_empty_sc_lines():
    """Emit zero-value SC lines (degraded output when input is invalid)."""
    print("SC-001 pass=0 total=0 population=research-artifact")
    print("SC-002 rate=0.00 threshold=0.80 pass=false population=concreteness-floor")
    print("SC-003 trend=insufficient-data")
    print("SC-004 resume_rate=1.00 sonnet_default_all=true pass=false")
    print("SC-005 trend=insufficient-data")
    print("SC-006 repeat_scope_sum=0 pass=false")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("usage: metrics-aggregate <prd-slug>", file=sys.stderr)
        sys.exit(0)

    prd = sys.argv[1]

    # Reject prd slug with path separators or leading dot (CWE-22)
    if not _safe_slug(prd):
        print(f"metrics-aggregate: rejected unsafe prd-slug: {prd!r}", file=sys.stderr)
        _emit_empty_sc_lines()
        sys.exit(0)
    docs = os.environ.get("DOCS_ROOT", "docs")
    manifest_path = os.path.join(docs, "prds", prd, "manifest.yaml")

    # Read piece order from manifest
    pieces = read_piece_order(manifest_path)

    # Load each piece's metrics.yaml
    metrics_list = []   # list of (slug, data_or_None)
    absent_list = []

    for slug in pieces:
        m_path = os.path.join(docs, "prds", prd, "specs", slug, "metrics.yaml")
        data = load_metrics(m_path)
        if data is None:
            absent_list.append(f"ABSENT {prd}/{slug}")
            metrics_list.append((slug, None))
        else:
            metrics_list.append((slug, data))

    instrumented = [(slug, d) for slug, d in metrics_list if d is not None]
    N = len(instrumented)

    # Compute and emit SC-001..SC-006
    emit_sc001(instrumented)
    emit_sc002(instrumented)
    emit_sc003(instrumented, N)
    emit_sc004(instrumented)
    emit_sc005(instrumented, N)
    emit_sc006(instrumented)

    # Emit ABSENT lines
    for line in absent_list:
        print(line)

    sys.exit(0)


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"metrics-aggregate: unexpected error: {e}", file=sys.stderr)
        sys.exit(0)
