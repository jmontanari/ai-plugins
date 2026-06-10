#!/usr/bin/env python3
# manifest-query.py — python fast path for manifest-query (awk-output-identical)
#
# Usage: manifest-query.py <subcommand> [args] --file <path>
#
# Subcommands:
#   open                       — print slugs where status != merged, in manifest order
#   deps <slug>                — print that slug's dependencies, one per line
#   deps <slug> --reverse      — print slugs whose deps include <slug>
#   ready                      — print slugs where status==open AND every dep is merged
#   table                      — aligned columns: slug | status | deps | prd_sections
#   set-status <slug> <new>    — rewrite that piece's status: line in-place
#
# --file is required; error with usage (exit 64) when absent.

import sys
import os
import re
import tempfile

# ---------------------------------------------------------------------------
# Status vocabulary (must match the awk tool exactly)
# ---------------------------------------------------------------------------
STATUS_VOCAB = {"open", "specced", "planned", "in-progress", "merged", "done",
                "superseded", "blocked"}
STATUS_VOCAB_STR = "open, specced, planned, in-progress, merged, done, superseded, blocked"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
USAGE = """\
Usage: manifest-query <subcommand> [args] --file <path>

Subcommands:
  open                       List slugs where status != merged (manifest order)
  deps <slug>                List dependencies of <slug>
  deps <slug> --reverse      List slugs that depend on <slug>
  ready                      List slugs: status==open AND all deps are merged
  table                      Aligned table: slug | status | deps | prd_sections
  set-status <slug> <new>    Update <slug>'s status field in-place

Status vocabulary: open, specced, planned, in-progress, merged, done, superseded, blocked

--file <path>  Required. Path to manifest.yaml.
"""

def usage():
    sys.stderr.write(USAGE)
    sys.exit(64)


# ---------------------------------------------------------------------------
# Manifest parser
#
# Replicates the AWK parser logic exactly.
# Each piece is a tuple: (slug, status, deps_str, prd_str)
# where deps_str and prd_str are comma-separated strings (matching awk output).
# ---------------------------------------------------------------------------
def parse_manifest(filepath):
    """Parse manifest.yaml and return list of (slug, status, deps, prd) tuples."""
    pieces = []

    # Parser state
    in_piece = False
    in_desc = False
    in_deps = False
    in_prd = False

    slug = ""
    init_name = ""
    status = ""
    deps = ""
    prd = ""

    def save_piece():
        effective = slug if slug else init_name
        pieces.append((effective, status, deps, prd))

    # Regex patterns matching the AWK parser
    re_top_level = re.compile(r'^[a-z_]+:')
    # M6: recognize ANY "  - <key>:" opener so status-first pieces work
    re_new_item = re.compile(r'^  - [a-z_]+')
    re_desc_block = re.compile(r'^    description:\s*[|>]\s*$')
    re_block_dep_item = re.compile(r'^      - ')
    re_block_prd_item = re.compile(r'^      - ')
    re_field_level = re.compile(r'^    [^ ]')
    re_slug_field = re.compile(r'^    slug:')
    re_name_field = re.compile(r'^    name:')
    re_status_field = re.compile(r'^    status:')
    re_deps_field = re.compile(r'^    (dependencies|depends_on):')
    re_prd_field = re.compile(r'^    prd_sections:')

    with open(filepath, 'r', encoding='utf-8') as f:
        for raw_line in f:
            # Strip trailing newline only (preserve leading whitespace)
            line = raw_line.rstrip('\n').rstrip('\r')

            # Top-level key ends piece parsing (matches /^coverage:/ || /^[a-z_]+:/)
            # but not pieces: (which is just consumed)
            if re_top_level.match(line):
                if line.startswith('pieces:'):
                    pass  # AWK: next — just skip, no save
                else:
                    if in_piece:
                        save_piece()
                    in_piece = False
                    in_desc = False
                    in_deps = False
                    in_prd = False
                continue

            # New list item — beginning of a piece (M6: ANY "  - <key>:" opener)
            if re_new_item.match(line) and ':' in line:
                if in_piece:
                    save_piece()
                in_piece = True
                in_desc = False
                in_deps = False
                in_prd = False
                slug = ""
                init_name = ""
                status = ""
                deps = ""
                prd = ""
                # Extract value from the opener line
                val = re.sub(r'^  - [a-z_]+:\s*', '', line).strip()
                if line.startswith('  - slug:'):
                    slug = val
                elif line.startswith('  - name:'):
                    init_name = val
                elif line.startswith('  - status:'):
                    # M5: strip inline comment
                    val = re.sub(r'\s+#.*$', '', val).strip()
                    status = val
                elif re.match(r'^  - (dependencies|depends_on):', line):
                    # M5: strip inline comment before bracket stripping
                    val = re.sub(r'\s+#.*$', '', val).strip()
                    if val == "" or val == "[]":
                        if val == "[]":
                            deps = ""
                        else:
                            in_deps = True
                    else:
                        val = re.sub(r'^\[', '', val)
                        val = re.sub(r'\]$', '', val)
                        val = val.strip()
                        deps = val
                elif line.startswith('  - prd_sections:'):
                    # M5: strip inline comment before bracket stripping
                    val = re.sub(r'\s+#.*$', '', val).strip()
                    if val == "" or val == "[]":
                        if val == "[]":
                            prd = ""
                        else:
                            in_prd = True
                    else:
                        val = re.sub(r'^\[', '', val)
                        val = re.sub(r'\]$', '', val)
                        val = val.strip()
                        prd = val
                continue

            # Skip non-piece lines
            if not in_piece:
                continue

            # Detect start of description literal block
            if re_desc_block.match(line):
                in_desc = True
                in_deps = False
                in_prd = False
                continue

            # While inside description block: skip content, exit at field level
            if in_desc:
                # Count leading spaces
                spaces = len(line) - len(line.lstrip(' '))
                if spaces <= 4 and len(line) > 0:
                    # Back at field level — exit description block and fall through
                    in_desc = False
                    # Fall through to process this field line
                else:
                    continue

            # Block-style list items under deps (6-space "      - item")
            if in_deps and re_block_dep_item.match(line):
                val = re.sub(r'^      -\s*', '', line).strip()
                # Strip inline comments (e.g. "# comment")
                val = re.sub(r'\s+#.*$', '', val).strip()
                if val:
                    if deps == "":
                        deps = val
                    else:
                        deps = deps + ", " + val
                continue

            # Block-style list items under prd_sections (6-space "      - item")
            if in_prd and re_block_prd_item.match(line):
                val = re.sub(r'^      -\s*', '', line).strip()
                # Strip inline comments (e.g. "# comment")
                val = re.sub(r'\s+#.*$', '', val).strip()
                if val:
                    if prd == "":
                        prd = val
                    else:
                        prd = prd + ", " + val
                continue

            # Exit block-style deps/prd collection when we return to field level (4-space)
            if (in_deps or in_prd) and re_field_level.match(line):
                in_deps = False
                in_prd = False
                # fall through to process this field line

            # Field captures (4-space indented)
            if re_slug_field.match(line):
                in_deps = False
                in_prd = False
                val = re.sub(r'^    slug:\s*', '', line).strip()
                slug = val
                continue

            if re_name_field.match(line):
                in_deps = False
                in_prd = False
                val = re.sub(r'^    name:\s*', '', line).strip()
                if not init_name:
                    init_name = val
                continue

            if re_status_field.match(line):
                in_deps = False
                in_prd = False
                val = re.sub(r'^    status:\s*', '', line).strip()
                # M5: strip inline trailing comment
                val = re.sub(r'\s+#.*$', '', val).strip()
                status = val
                continue

            # dependencies: or depends_on: — inline form [ ] or block form
            if re_deps_field.match(line):
                in_prd = False
                val = re.sub(r'^    (dependencies|depends_on):\s*', '', line).strip()
                # M5: strip inline trailing comment BEFORE bracket/whitespace stripping
                val = re.sub(r'\s+#.*$', '', val).strip()
                if val == "" or val == "[]":
                    if val == "[]":
                        deps = ""
                    else:
                        # block-style: enter collection mode
                        in_deps = True
                else:
                    # inline: [item, item] or bare items
                    in_deps = False
                    val = re.sub(r'^\[', '', val)
                    val = re.sub(r'\]$', '', val)
                    val = val.strip()
                    deps = val
                continue

            if re_prd_field.match(line):
                in_deps = False
                val = re.sub(r'^    prd_sections:\s*', '', line).strip()
                # M5: strip inline trailing comment BEFORE bracket/whitespace stripping
                val = re.sub(r'\s+#.*$', '', val).strip()
                if val == "" or val == "[]":
                    if val == "[]":
                        prd = ""
                    else:
                        in_prd = True
                else:
                    in_prd = False
                    val = re.sub(r'^\[', '', val)
                    val = re.sub(r'\]$', '', val)
                    val = val.strip()
                    prd = val
                continue

    # End of file: save the last piece if any
    if in_piece:
        save_piece()

    return pieces


# ---------------------------------------------------------------------------
# Subcommand: open
# ---------------------------------------------------------------------------
def cmd_open(pieces):
    for (s, status, deps, prd) in pieces:
        if status != "merged" and status != "":
            print(s)
        elif status == "" and s != "":
            print(s)


# ---------------------------------------------------------------------------
# Subcommand: deps
# ---------------------------------------------------------------------------
def split_deps(deps_str):
    """Split a comma-separated deps string into a list, matching awk tr/sed logic."""
    if not deps_str:
        return []
    items = []
    for item in deps_str.split(','):
        item = item.strip()
        if item:
            items.append(item)
    return items


def cmd_deps(pieces, target, reverse):
    if not reverse:
        # Forward: find the slug and print its deps
        found = False
        for (s, status, deps, prd) in pieces:
            if s == target:
                found = True
                dep_list = split_deps(deps)
                for d in dep_list:
                    print(d)
                break
        if not found:
            sys.stderr.write("Error: unknown slug: {}\n".format(target))
            sys.exit(2)
    else:
        # Reverse: check target exists, then print slugs that depend on target
        target_exists = any(s == target for (s, _, _, _) in pieces)
        if not target_exists:
            sys.stderr.write("Error: unknown slug: {}\n".format(target))
            sys.exit(2)
        for (s, status, deps, prd) in pieces:
            if not deps:
                continue
            dep_list = split_deps(deps)
            for d in dep_list:
                if d == target:
                    print(s)
                    break


# ---------------------------------------------------------------------------
# Subcommand: ready
# ---------------------------------------------------------------------------
def cmd_ready(pieces):
    # Build slug -> status lookup
    status_of = {}
    for (s, status, deps, prd) in pieces:
        status_of[s] = status

    for (s, status, deps, prd) in pieces:
        if status != "open":
            continue
        dep_list = split_deps(deps)
        ready = True
        for d in dep_list:
            if not d:
                continue
            ds = status_of.get(d, "")
            if ds != "merged" and ds != "done":
                ready = False
                break
        if ready:
            print(s)


# ---------------------------------------------------------------------------
# Subcommand: table
# ---------------------------------------------------------------------------
def _blen(s):
    """Return the byte length of a string (UTF-8), matching awk's length() semantics."""
    return len(s.encode('utf-8'))


def _pad(s, width):
    """Left-justify s to byte-width `width`, matching awk's %-Ws printf behaviour.

    awk printf "%-Ws" pads based on byte length (length() counts bytes in UTF-8
    locales).  Python's str.format "{:<W}" pads based on code-point count.  For
    ASCII-only strings they are identical; for strings containing multi-byte
    characters (e.g. em-dash U+2014 = 3 UTF-8 bytes) awk needs fewer pad spaces
    to reach `width` bytes than Python would.  We replicate the awk behaviour by
    computing the required padding in bytes.
    """
    byte_len = _blen(s)
    pad = width - byte_len
    if pad <= 0:
        return s
    return s + ' ' * pad


def cmd_table(pieces):
    # Compute column widths using BYTE lengths (awk length() counts bytes, not chars)
    # Initial values match the awk BEGIN block
    w_slug = 4
    w_status = 6
    w_deps = 4
    w_prd = 12

    for (s, status, deps, prd) in pieces:
        b = _blen(s)
        if b > w_slug:
            w_slug = b
        b = _blen(status)
        if b > w_status:
            w_status = b
        b = _blen(deps)
        if b > w_deps:
            w_deps = b
        b = _blen(prd)
        if b > w_prd:
            w_prd = b

    # Format matching awk: "%-w_slug s  %-w_status s  %-w_deps s  %s\n"
    # The last column (prd_sections) has no fixed width — awk uses plain %s.
    def fmt_row(s, status, deps, prd):
        return "{}  {}  {}  {}".format(
            _pad(s, w_slug),
            _pad(status, w_status),
            _pad(deps, w_deps),
            prd
        )

    # Header
    print(fmt_row("slug", "status", "deps", "prd_sections"))
    # Separator
    print(fmt_row("-" * w_slug, "-" * w_status, "-" * w_deps, "-" * w_prd))
    # Data rows
    for (s, status, deps, prd) in pieces:
        print(fmt_row(s, status, deps, prd))


# ---------------------------------------------------------------------------
# Subcommand: set-status
# ---------------------------------------------------------------------------
def cmd_set_status(filepath, pieces, target, new_status):
    # Validate status value
    if new_status not in STATUS_VOCAB:
        sys.stderr.write("Error: unknown status: '{}'. Valid: {}\n".format(
            new_status, "open specced planned in-progress merged done superseded blocked"))
        sys.exit(2)

    # Verify slug exists
    found = any(s == target for (s, _, _, _) in pieces)
    if not found:
        sys.stderr.write("Error: unknown slug: {}\n".format(target))
        sys.exit(2)

    # S4: Resolve symlinks so we write through to the real file, not create
    # a detached copy when filepath is a symlink.
    real_filepath = os.path.realpath(os.path.abspath(filepath))

    # M1: Create temp file in the SAME directory as the target manifest to
    # avoid cross-device rename (os.replace raises OSError errno 18 when
    # $TMPDIR is on a different filesystem than the manifest).
    manifest_dir = os.path.dirname(real_filepath)

    # Rewrite the status: line in-place using the same awk logic.
    # Tracks which piece we are in and rewrites only the first status: line
    # of the matched piece, leaving all other bytes unchanged.
    #
    # M6: Buffer lines when the piece opener is NOT a slug/name field (e.g.
    # "  - status: open") so we can rewrite the status line retrospectively
    # once the effective identifier (slug/name) is known.
    in_piece = False
    in_desc = False
    slug_val = ""
    init_name = ""
    matched_done = False
    # Buffer: list of (raw_line, is_status_candidate) tuples
    buf = []           # list of raw_line strings
    buf_status_idx = -1  # index in buf of the opener status line, or -1
    id_known = False

    re_top_level_setstatus = re.compile(r'^[a-z_]+:')
    # M6: recognize ANY "  - <key>:" opener
    re_new_item_ss = re.compile(r'^  - [a-z_]+:')
    re_desc_block_ss = re.compile(r'^    description:\s*\|\s*$')

    tmpfd, tmppath = tempfile.mkstemp(dir=manifest_dir)
    try:
        # S3: Preserve original file mode
        orig_mode = os.stat(real_filepath).st_mode
        os.chmod(tmppath, orig_mode)

        # Open with newline='' to preserve raw line endings (CRLF/LF/no-newline)
        # exactly as awk sees them — without Python's universal-newline translation.
        with open(real_filepath, 'r', encoding='utf-8', newline='') as f:
            lines = f.readlines()

        out_lines = []

        def flush_buf():
            nonlocal buf, buf_status_idx, id_known
            out_lines.extend(buf)
            buf = []
            buf_status_idx = -1
            id_known = False

        def resolve_id():
            """Flush buffer, potentially rewriting the buffered status line."""
            nonlocal buf, buf_status_idx, id_known, matched_done
            effective = slug_val if slug_val else init_name
            if buf_status_idx >= 0 and effective == target and not matched_done:
                raw = buf[buf_status_idx]
                stripped = raw.rstrip('\n').rstrip('\r')
                new_stripped = re.sub(r'status:\s*.*$', 'status: ' + new_status,
                                      stripped)
                buf[buf_status_idx] = new_stripped + '\n'
                matched_done = True
            id_known = True
            flush_buf()

        def emit(raw_line):
            if not id_known:
                buf.append(raw_line)
            else:
                out_lines.append(raw_line)

        for raw_line in lines:
            line_stripped = raw_line.rstrip('\n').rstrip('\r')

            # Stop piece tracking at coverage block or other top-level keys
            if re_top_level_setstatus.match(line_stripped):
                flush_buf()
                if not line_stripped.startswith('pieces:'):
                    in_piece = False
                    in_desc = False
                out_lines.append(raw_line)
                continue

            # New list item (M6: any opener)
            if re_new_item_ss.match(line_stripped):
                flush_buf()
                in_piece = True
                in_desc = False
                slug_val = ""
                init_name = ""
                buf_status_idx = -1
                id_known = False
                val = re.sub(r'^  - [a-z_]+:\s*', '', line_stripped).strip()
                if line_stripped.startswith('  - slug:'):
                    slug_val = val
                    id_known = True
                    out_lines.append(raw_line)
                elif line_stripped.startswith('  - name:'):
                    init_name = val
                    id_known = True
                    out_lines.append(raw_line)
                elif line_stripped.startswith('  - status:'):
                    # Status-first: buffer this as a candidate for rewriting
                    buf.append(raw_line)
                    buf_status_idx = len(buf) - 1
                else:
                    buf.append(raw_line)
                continue

            if not in_piece:
                flush_buf()
                out_lines.append(raw_line)
                continue

            # Description block detection
            if re_desc_block_ss.match(line_stripped):
                in_desc = True
                emit(raw_line)
                continue

            if in_desc:
                spaces = len(line_stripped) - len(line_stripped.lstrip(' '))
                if spaces <= 4 and len(line_stripped) > 0:
                    in_desc = False
                    # fall through
                else:
                    emit(raw_line)
                    continue

            # slug field
            if line_stripped.startswith('    slug:'):
                val = re.sub(r'^    slug:\s*', '', line_stripped).strip()
                slug_val = val
                if not id_known:
                    resolve_id()
                out_lines.append(raw_line)
                continue

            # name field
            if line_stripped.startswith('    name:'):
                val = re.sub(r'^    name:\s*', '', line_stripped).strip()
                if not init_name:
                    init_name = val
                if not id_known:
                    resolve_id()
                out_lines.append(raw_line)
                continue

            # status field — potentially rewrite
            if line_stripped.startswith('    status:'):
                effective = slug_val if slug_val else init_name
                if effective == target and not matched_done:
                    # Preserve indentation, rewrite value.
                    # Always terminate with bare \n — this matches awk's behaviour:
                    # awk's sub() consumes any trailing \r (part of .*$) and print
                    # always appends \n, so the rewritten line is always bare-LF.
                    new_line = re.sub(r'status:\s*.*$', 'status: ' + new_status,
                                      line_stripped)
                    out_lines.append(new_line + '\n')
                    matched_done = True
                else:
                    out_lines.append(raw_line)
                continue

            emit(raw_line)

        # Flush any remaining buffer (e.g. piece at end of file)
        flush_buf()

        # F1 (no-trailing-newline parity): awk's `print` always emits \n as the
        # record terminator, so a file whose final line lacks a newline gains one
        # byte in awk's output.  Replicate that here.
        if out_lines and not out_lines[-1].endswith('\n'):
            out_lines[-1] = out_lines[-1] + '\n'

        # Write to temp file then rename (atomic replace).
        # Use newline='' so that \r\n sequences in out_lines are written verbatim
        # rather than being translated by the platform's text-mode newline handling.
        with os.fdopen(tmpfd, 'w', encoding='utf-8', newline='') as f:
            f.writelines(out_lines)
        tmpfd = None  # fd now owned by the with block

        # S2: Wrap atomic replace in try/except for a clean error message
        try:
            os.replace(tmppath, real_filepath)
        except OSError as e:
            sys.stderr.write("Error: failed to write {}: {}\n".format(filepath, e))
            sys.exit(2)
        tmppath = None

    finally:
        if tmpfd is not None:
            try:
                os.close(tmpfd)
            except OSError:
                pass
        if tmppath is not None:
            try:
                os.unlink(tmppath)
            except OSError:
                pass


# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
def parse_args(argv):
    manifest_file = ""
    reverse = False
    positionals = []

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == '--file':
            i += 1
            if i < len(argv):
                manifest_file = argv[i]
        elif arg == '--reverse':
            reverse = True
        else:
            positionals.append(arg)
        i += 1

    subcmd = positionals[0] if len(positionals) >= 1 else ""
    arg1 = positionals[1] if len(positionals) >= 2 else ""
    arg2 = positionals[2] if len(positionals) >= 3 else ""

    return subcmd, manifest_file, arg1, arg2, reverse


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    argv = sys.argv[1:]
    subcmd, manifest_file, arg1, arg2, reverse = parse_args(argv)

    # Validate --file
    if not manifest_file:
        sys.stderr.write("Error: --file is required\n")
        usage()

    if not os.path.isfile(manifest_file):
        sys.stderr.write("Error: file not found: {}\n".format(manifest_file))
        sys.exit(2)

    if not subcmd:
        usage()

    # Dispatch
    if subcmd == 'open':
        pieces = parse_manifest(manifest_file)
        cmd_open(pieces)

    elif subcmd == 'deps':
        if not arg1:
            sys.stderr.write("Error: deps requires a slug argument\n")
            usage()
        pieces = parse_manifest(manifest_file)
        cmd_deps(pieces, arg1, reverse)

    elif subcmd == 'ready':
        pieces = parse_manifest(manifest_file)
        cmd_ready(pieces)

    elif subcmd == 'table':
        pieces = parse_manifest(manifest_file)
        cmd_table(pieces)

    elif subcmd == 'set-status':
        if not arg1 or not arg2:
            sys.stderr.write("Error: set-status requires <slug> and <new-status> arguments\n")
            usage()
        pieces = parse_manifest(manifest_file)
        cmd_set_status(manifest_file, pieces, arg1, arg2)

    else:
        sys.stderr.write("Error: unknown subcommand: '{}'\n".format(subcmd))
        usage()


if __name__ == '__main__':
    main()
