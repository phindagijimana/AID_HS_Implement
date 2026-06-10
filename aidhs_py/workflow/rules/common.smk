# Shared paths, subject discovery, and helpers for AID-HS Snakemake workflow.

import os
from pathlib import Path


def _aidhs_py_root() -> Path:
    # workflow/rules/common.smk → aidhs_py/
    return Path(workflow.basedir).resolve()


def _resolve(base: Path, p: str) -> Path:
    path = Path(p)
    return path if path.is_absolute() else (base / path).resolve()


AIDHS_PY = _aidhs_py_root()
PIPELINE_ROOT = _resolve(AIDHS_PY, config.get("pipeline_root", ".."))
WORKFLOW_ROOT = _resolve(AIDHS_PY, config.get("workflow_root", "."))
FLAGS_DIR = WORKFLOW_ROOT / ".flags"
LOGS_DIR = WORKFLOW_ROOT / "logs"
SCRIPTS = AIDHS_PY / "workflow" / "scripts"

LICENSE = _resolve(AIDHS_PY, config.get("license_file", "../aidhs_license.txt"))
SIF = _resolve(AIDHS_PY, config["containers"]["aidhs"])
DEMO_PATH = config.get("demographics", "config/demographics_file.csv")
if Path(DEMO_PATH).is_absolute():
    DEMO_FILE = Path(DEMO_PATH).resolve()
else:
    candidate = (AIDHS_PY / DEMO_PATH).resolve()
    DEMO_FILE = candidate if candidate.is_file() else _resolve(PIPELINE_ROOT, DEMO_PATH)

# Path inside the Apptainer container
if DEMO_FILE.is_relative_to(AIDHS_PY):
    DEMO_CONTAINER = f"/aidhs_py/{DEMO_FILE.relative_to(AIDHS_PY)}"
elif DEMO_FILE.is_relative_to(PIPELINE_ROOT):
    DEMO_CONTAINER = f"/data/{DEMO_FILE.relative_to(PIPELINE_ROOT)}"
else:
    DEMO_CONTAINER = str(DEMO_FILE)

BIDS_ROOT = config.get("bids_root", "") or ""
SUBJECTS_TSV = _resolve(AIDHS_PY, config.get("subjects_tsv", "config/subjects.tsv"))
CONTROLS_TSV = _resolve(AIDHS_PY, config.get("controls_tsv", "config/controls.tsv"))

HIPPUNFOLD_SLOTS = int(config.get("hippunfold_slots", 1))


def cfg_bool(key: str, default: bool = False) -> bool:
    val = config.get(key, default)
    if isinstance(val, bool):
        return val
    return str(val).strip().lower() in ("1", "true", "yes", "on")


RUN_VALIDATE = cfg_bool("run_validate", True)
RUN_HARMONISATION = cfg_bool("run_harmonisation", False)
SKIP_SEGMENTATION = cfg_bool("skip_segmentation", False)
HARMO_CODE = str(config.get("harmo_code", "H1"))


def _read_subjects_tsv(path: Path) -> list[str]:
    if not path.is_file():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line.split()[0])
    return out


SUBJECTS = _read_subjects_tsv(SUBJECTS_TSV)
if not SUBJECTS:
    SUBJECTS = list(config.get("subjects", []) or [])

if not SUBJECTS:
    raise ValueError(
        f"No subjects found. Populate {SUBJECTS_TSV} or set config.subjects."
    )


def stage_resources(stage: str) -> dict:
    res = dict(config.get("resources", {}).get(stage, {}))
    out = {}
    if "mem_mb" in res:
        out["mem_mb"] = int(res["mem_mb"])
    if "runtime" in res:
        out["runtime"] = int(res["runtime"])
    if "slurm_partition" in res:
        out["slurm_partition"] = str(res["slurm_partition"])
    if "slurm_account" in res:
        out["slurm_account"] = str(res["slurm_account"])
    if "slurm_extra" in res:
        out["slurm_extra"] = str(res["slurm_extra"])
    return out


def validate_flag(sid: str) -> str:
    return str(FLAGS_DIR / f"validate.{sid}.done")


def harmo_flag(code: str | None = None) -> str:
    code = code or HARMO_CODE
    return str(FLAGS_DIR / f"harmonisation.{code}.done")


def report_target(sid: str) -> str:
    return str(
        PIPELINE_ROOT / "output" / "predictions_reports" / sid / f"Report_{sid}.pdf"
    )


def all_targets() -> list[str]:
    targets = []
    if RUN_HARMONISATION:
        targets.append(harmo_flag())
    for sid in SUBJECTS:
        if RUN_VALIDATE:
            targets.append(validate_flag(sid))
        targets.append(report_target(sid))
    return targets


wildcard_constraints:
    sid=r"|".join(map(str, SUBJECTS)),
