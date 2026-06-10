# aidhs_py — Snakemake cohort workflow

Cohort-scale Slurm orchestration for the parent [`./aid`](../aid) pipeline.

**Documentation:** see [USER_GUIDE.md](../USER_GUIDE.md) (sections *Snakemake cohort runs* and *Site-specific jobs*).

Quick entry from the pipeline root:

```bash
./aid cohort setup
./aid cohort lint
./aid cohort slurm
./aid cohort status
```

Files in this directory:

```text
aidhs_py/
├── Snakefile
├── Makefile
├── submit_snakemake.sh
├── config/config.yaml
├── profiles/slurm/
└── workflow/rules/
```
