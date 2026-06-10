#!/usr/bin/env python3
"""Preflight checks for one AID-HS subject before container execution."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


def _fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def _find_t1w(subject_dir: Path, sid: str) -> Path | None:
    anat = subject_dir / "anat"
    if not anat.is_dir():
        return None
    for pat in (f"{sid}_T1w.nii.gz", f"{sid}_ses-*_T1w.nii.gz"):
        matches = sorted(anat.glob(pat))
        if matches:
            return matches[0]
    # Broader fallback
    matches = sorted(anat.glob("*_T1w.nii.gz"))
    return matches[0] if matches else None


def _demographics_row(demo_path: Path, sid: str) -> dict[str, str] | None:
    with demo_path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            if (row.get("ID") or "").strip() == sid:
                return row
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pipeline-root", type=Path, required=True)
    parser.add_argument("--sid", required=True, help="Subject ID, e.g. sub-001")
    parser.add_argument("--demographics", type=Path, required=True)
    args = parser.parse_args()

    sid = args.sid.strip()
    root = args.pipeline_root.resolve()

    license_file = root / "aidhs_license.txt"
    if not license_file.is_file():
        _fail(f"Missing license: {license_file}")

    sif = root / ".aid" / "aidhs.sif"
    if not sif.is_file():
        _fail(f"Missing container image: {sif} — run: ./aid install --runtime apptainer")

    for name in ("bids_config.json", "dataset_description.json"):
        cfg = root / "input" / name
        if not cfg.is_file():
            _fail(f"Missing {cfg} — copy from input/{name}.example")

    # Validate bids_config parses
    bids_cfg = root / "input" / "bids_config.json"
    try:
        json.loads(bids_cfg.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        _fail(f"Invalid JSON in {bids_cfg}: {exc}")

    subject_dir = root / "input" / sid
    if not subject_dir.exists():
        _fail(f"Subject directory not found: {subject_dir}")

    t1w = _find_t1w(subject_dir, sid)
    if t1w is None:
        _fail(f"No T1w NIfTI under {subject_dir}/anat/")

    if not args.demographics.is_file():
        _fail(f"Demographics file not found: {args.demographics}")

    row = _demographics_row(args.demographics, sid)
    if row is None:
        _fail(f"No demographics row for {sid} in {args.demographics}")

    for col in ("Age at preoperative", "Sex", "Scanner"):
        if not (row.get(col) or "").strip():
            _fail(f"Demographics missing '{col}' for {sid}")

    print(f"OK {sid}: T1w={t1w.name} age={row.get('Age at preoperative')} sex={row.get('Sex')}")


if __name__ == "__main__":
    main()
