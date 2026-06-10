#!/usr/bin/env python3
"""List BIDS subjects under pipeline_root/input/ → subjects.tsv."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def discover_subjects(bids_dir: Path) -> list[str]:
    if not bids_dir.is_dir():
        raise SystemExit(f"BIDS input directory not found: {bids_dir}")
    subjects = sorted(
        p.name
        for p in bids_dir.iterdir()
        if p.is_dir() and p.name.startswith("sub-")
    )
    if not subjects:
        raise SystemExit(f"No sub-* directories under {bids_dir}")
    return subjects


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pipeline-root",
        type=Path,
        required=True,
        help="AID-HS pipeline root (contains input/)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Output subjects.tsv path",
    )
    args = parser.parse_args()

    subjects = discover_subjects(args.pipeline_root / "input")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(subjects) + "\n", encoding="utf-8")
    print(f"Wrote {len(subjects)} subjects to {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
