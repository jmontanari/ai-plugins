"""
Secret scrubbing for transcript-eval.

Applied to every extracted record's text fields before writing to the store.
Non-secret text is never modified.

AC-5: secret-shaped tokens are replaced with redaction markers before any
      extracted record leaves this module.
"""
from __future__ import annotations

import re

# ---------------------------------------------------------------------------
# Redaction patterns (ordered from most- to least-specific so broader
# patterns don't shadow narrower ones)
# ---------------------------------------------------------------------------

# PEM private-key blocks (multi-line) — must come before single-line patterns
_PEM_PRIVATE_KEY_RE = re.compile(
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----",
    re.DOTALL,
)

# Bearer tokens in Authorization headers
_BEARER_RE = re.compile(
    r"Bearer [A-Za-z0-9\-._~+/]+=*"
)

# API/secret keys matching the common sk-... pattern (≥16 alphanum chars after the prefix)
_SECRET_KEY_RE = re.compile(
    r"sk-[A-Za-z0-9]{16,}"
)


def scrub(text: str) -> str:
    """
    Replace secret-shaped tokens in text with redaction markers.

    Patterns:
      - PEM private key blocks       → <redacted-private-key>
      - Bearer <token>               → <redacted-bearer>
      - sk-<16+ alphanum chars>      → <redacted-key>

    Non-secret text is returned unchanged.
    """
    text = _PEM_PRIVATE_KEY_RE.sub("<redacted-private-key>", text)
    text = _BEARER_RE.sub("<redacted-bearer>", text)
    text = _SECRET_KEY_RE.sub("<redacted-key>", text)
    return text
