# Convenience targets for aidhs_py Snakemake workflow.
SNAKEFILE := Snakefile
PROFILE   := profiles/slurm
CONFIG    := config/config.yaml

.PHONY: help subjects lint dry run slurm report dag clean

help:
	@echo "Targets:"
	@echo "  make subjects   — regenerate config/subjects.tsv from BIDS"
	@echo "  make lint       — dry-run DAG (local)"
	@echo "  make dry        — list jobs without executing"
	@echo "  make run        — local execution (debug)"
	@echo "  make slurm      — submit Slurm driver job"
	@echo "  make report     — HTML workflow report"
	@echo "  make dag        — write dag.svg"
	@echo "  make clean      — remove sentinels (not pipeline outputs)"

subjects:
	python3 workflow/scripts/list_subjects.py \
		--pipeline-root "$$(python3 -c "import yaml;from pathlib import Path;c=yaml.safe_load(open('$(CONFIG)'));print((Path('.')/c['pipeline_root']).resolve())")" \
		--out config/subjects.tsv

lint:
	snakemake -s $(SNAKEFILE) -n -p -q

dry:
	snakemake -s $(SNAKEFILE) -n

run:
	snakemake -s $(SNAKEFILE) --cores 1

slurm:
	sbatch submit_snakemake.sh

report:
	snakemake -s $(SNAKEFILE) --report report.html

dag:
	snakemake -s $(SNAKEFILE) --dag | dot -Tsvg > dag.svg

clean:
	rm -rf .flags .snakemake
