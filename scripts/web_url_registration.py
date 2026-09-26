"""Keep BrowserDaddy out of macOS's default web-browser choices."""

import plistlib
from pathlib import Path
import sys


def validate(info: dict) -> None:
    for entry in info.get("CFBundleURLTypes", []):
        schemes = {scheme.lower() for scheme in entry.get("CFBundleURLSchemes", [])}
        if schemes.intersection({"http", "https"}):
            raise ValueError("BrowserDaddy must not register as an HTTP or HTTPS handler")


if __name__ == "__main__":
    try:
        validate(plistlib.loads(Path(sys.argv[1]).read_bytes()))
    except (IndexError, OSError, ValueError) as error:
        raise SystemExit(str(error)) from error
