# Preflight validation per subject.

if RUN_VALIDATE:


    rule validate_inputs:
        input:
            subjects_tsv=SUBJECTS_TSV,
        output:
            flag=FLAGS_DIR / "validate.{sid}.done",
        log:
            LOGS_DIR / "validate.{sid}.log",
        params:
            pipeline_root=PIPELINE_ROOT,
            demographics=DEMO_FILE,
            bids_root=BIDS_ROOT,
            validate_py=SCRIPTS / "validate_subject.py",
            link_script=SCRIPTS / "link_bids_subjects.sh",
        resources:
            **stage_resources("validate"),
        shell:
            """
            set -euo pipefail
            exec > >(tee -a {log}) 2>&1
            mkdir -p {params.pipeline_root}/input {params.pipeline_root}/logs
            if [[ -n "{params.bids_root}" ]]; then
              bash {params.link_script} {params.pipeline_root} {params.bids_root} {input.subjects_tsv}
            fi
            python3 {params.validate_py} \
              --pipeline-root {params.pipeline_root} \
              --sid {wildcards.sid} \
              --demographics {params.demographics}
            touch {output.flag}
            """
