"""
Tests for transcript_eval.scrub — Phase 2.

TS-scrub-key:  secret key sk-ABCD1234EFGHabcd5678IJ → <redacted-key>; original absent.
TS-scrub-noop: benign text → unchanged.
"""
from __future__ import annotations

from transcript_eval.scrub import scrub


# ---------------------------------------------------------------------------
# TS-scrub-key
# ---------------------------------------------------------------------------

class TestScrubKey:
    """TS-scrub-key: API key pattern scrubbed."""

    SECRET_TOKEN = "sk-ABCD1234EFGHabcd5678IJ"

    def test_secret_key_replaced(self) -> None:
        """TS-scrub-key: secret key replaced with <redacted-key>."""
        text = f"Note: API key for external service is {self.SECRET_TOKEN} used in fixture."
        result = scrub(text)
        assert "<redacted-key>" in result

    def test_original_token_absent(self) -> None:
        """TS-scrub-key: original secret token must not appear in scrubbed output."""
        text = f"Note: API key for external service is {self.SECRET_TOKEN} used in fixture."
        result = scrub(text)
        assert self.SECRET_TOKEN not in result

    def test_scrub_from_fixture(self) -> None:
        """TS-scrub-key: secret from secret-bearing.jsonl fixture must be scrubbed."""
        from pathlib import Path
        fixture = Path(__file__).parent / "fixtures" / "secret-bearing.jsonl"
        raw = fixture.read_text(encoding="utf-8")
        scrubbed = scrub(raw)
        assert self.SECRET_TOKEN not in scrubbed
        assert "<redacted-key>" in scrubbed

    def test_bearer_token_scrubbed(self) -> None:
        """Bearer token pattern is replaced with <redacted-bearer>."""
        text = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        result = scrub(text)
        assert "<redacted-bearer>" in result
        assert "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" not in result

    def test_private_key_block_scrubbed(self) -> None:
        """PEM private key block is replaced with <redacted-private-key>."""
        text = (
            "-----BEGIN RSA PRIVATE KEY-----\n"
            "MIIEpAIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4\n"
            "-----END RSA PRIVATE KEY-----"
        )
        result = scrub(text)
        assert "<redacted-private-key>" in result
        assert "MIIEpAIBAAKCAQEA" not in result


# ---------------------------------------------------------------------------
# TS-scrub-noop
# ---------------------------------------------------------------------------

class TestScrubNoop:
    """TS-scrub-noop: benign text is unchanged."""

    def test_plain_text_unchanged(self) -> None:
        """TS-scrub-noop: text with no secrets must pass through unmodified."""
        text = "The module handles JSONDecodeError on line 42."
        assert scrub(text) == text

    def test_empty_string_unchanged(self) -> None:
        assert scrub("") == ""

    def test_code_snippet_unchanged(self) -> None:
        """Code containing 'sk' but not the key pattern must be unchanged."""
        text = "def skip_invalid(records): return [r for r in records if r is not None]"
        assert scrub(text) == text

    def test_short_sk_prefix_not_scrubbed(self) -> None:
        """sk- followed by < 16 chars must NOT be scrubbed (not a key)."""
        text = "prefix sk-short123 suffix"
        result = scrub(text)
        assert "sk-short123" in result
