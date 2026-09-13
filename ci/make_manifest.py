#!/usr/bin/env python3
"""Build the update manifest the app polls, from the artifacts CI just produced.

The manifest is itself published as a release asset named ``manifest.json``, and
every URL in it points at ``releases/latest/download/<name>``. That path always
redirects to the newest release, so a shipped build never has to know a release
tag, call the GitHub API, or deal with rate limits -- it just fetches one stable
URL.

Every artifact is hashed here, and the app refuses to install a download whose
SHA-256 does not match.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import sys

SCHEMA_VERSION = 1
VALID_KINDS = ("binary", "content")


def sha256_of(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_artifact(raw: str) -> tuple[str, str, pathlib.Path]:
    """Parse a ``kind:platform:path`` triple, e.g. ``binary:android:build/x.apk``."""
    try:
        kind, platform, path = raw.split(":", 2)
    except ValueError:
        raise SystemExit(f"--artifact must be kind:platform:path, got {raw!r}")
    if kind not in VALID_KINDS:
        raise SystemExit(f"unknown artifact kind {kind!r}, expected one of {VALID_KINDS}")
    resolved = pathlib.Path(path)
    if not resolved.is_file():
        raise SystemExit(f"artifact not found: {resolved}")
    return kind, platform, resolved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="owner/name on GitHub")
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--binary-version", required=True, type=int)
    parser.add_argument("--content-version", required=True, type=int)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument(
        "--artifact",
        action="append",
        default=[],
        metavar="KIND:PLATFORM:PATH",
        help="repeatable; KIND is 'binary' or 'content'",
    )
    parser.add_argument("--out", required=True, type=pathlib.Path)
    args = parser.parse_args()

    base_url = f"https://github.com/{args.repo}/releases/latest/download"
    artifacts: dict[str, dict[str, dict]] = {kind: {} for kind in VALID_KINDS}

    for raw in args.artifact:
        kind, platform, path = parse_artifact(raw)
        artifacts[kind][platform] = {
            "file": path.name,
            "url": f"{base_url}/{path.name}",
            "size": path.stat().st_size,
            "sha256": sha256_of(path),
        }

    manifest = {
        "schema": SCHEMA_VERSION,
        "version_name": args.version_name,
        "binary_version": args.binary_version,
        "content_version": args.content_version,
        "commit": args.commit,
        "release_tag": args.tag,
        "released_at": datetime.datetime.now(datetime.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
        "artifacts": artifacts,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
