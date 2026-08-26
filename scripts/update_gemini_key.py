#!/usr/bin/env python3
"""Update and validate Google Gemini API Key in ~/.zshrc."""

import os
import re
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path


def test_gemini_key(api_key: str) -> bool:
    """Validate the API key by querying Google Generative Language API."""
    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
    req = urllib.request.Request(url, headers={"User-Agent": "macomrade-key-updater/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return "models" in data
    except urllib.error.HTTPError as err:
        print(f"[-] Validation failed (HTTP {err.code}): {err.reason}", file=sys.stderr)
        return False
    except Exception as err:
        print(f"[-] Connection failed: {err}", file=sys.stderr)
        return False


def update_zshrc(api_key: str) -> bool:
    """Update GEMINI_API_KEY and GOOGLE_API_KEY in ~/.zshrc."""
    zshrc_path = Path.home() / ".zshrc"
    if not zshrc_path.exists():
        zshrc_path.touch(mode=0o600)

    content = zshrc_path.read_text(encoding="utf-8")
    gemini_pattern = re.compile(r'^export GEMINI_API_KEY=.*$', re.MULTILINE)
    google_pattern = re.compile(r'^export GOOGLE_API_KEY=.*$', re.MULTILINE)

    new_gemini_line = f'export GEMINI_API_KEY="{api_key}"'
    new_google_line = 'export GOOGLE_API_KEY="$GEMINI_API_KEY"'

    if gemini_pattern.search(content):
        content = gemini_pattern.sub(new_gemini_line, content)
    else:
        content = content.rstrip() + f"\n{new_gemini_line}\n"

    if google_pattern.search(content):
        content = google_pattern.sub(new_google_line, content)
    else:
        content = content.rstrip() + f"\n{new_google_line}\n"

    zshrc_path.write_text(content, encoding="utf-8")
    return True


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
        print("Usage: update-gemini-key [NEW_API_KEY] | --check")
        print("\nOptions:")
        print("  --check    Validate the currently configured GEMINI_API_KEY")
        print("  --help     Show this help message")
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        current_key = os.environ.get("GEMINI_API_KEY")
        if not current_key:
            zshrc = (Path.home() / ".zshrc").read_text(encoding="utf-8", errors="ignore")
            match = re.search(r'^export GEMINI_API_KEY="?([^"\n]+)"?', zshrc, re.MULTILINE)
            current_key = match.group(1) if match else None

        if not current_key:
            print("[-] No GEMINI_API_KEY found in environment or ~/.zshrc")
            sys.exit(1)

        print(f"[*] Testing current key: {current_key[:6]}...{current_key[-4:]}")
        if test_gemini_key(current_key):
            print("[+] Current Gemini API Key is valid and active!")
            sys.exit(0)
        else:
            print("[-] Current Gemini API Key is invalid.")
            sys.exit(1)

    key = sys.argv[1].strip() if len(sys.argv) > 1 else input("Enter new Gemini API Key: ").strip()

    if not key:
        print("[-] API key cannot be empty.", file=sys.stderr)
        sys.exit(1)

    print(f"[*] Validating new Gemini Key: {key[:6]}...{key[-4:]}")
    if not test_gemini_key(key):
        print("[-] Aborted: The provided Gemini key failed verification.", file=sys.stderr)
        sys.exit(1)

    print("[+] Validation passed! Updating ~/.zshrc ...")
    update_zshrc(key)
    print(f"[+] Successfully updated GEMINI_API_KEY in {Path.home() / '.zshrc'}")
    print("[*] To apply immediately in current session, run: source ~/.zshrc")


if __name__ == "__main__":
    main()
