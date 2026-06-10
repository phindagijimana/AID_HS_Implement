# Optional cohort-level harmonisation (once per harmo_code).

if RUN_HARMONISATION:

    CONTROLS_LIST = str(PIPELINE_ROOT / "input" / "controls_list_harmo.txt")


    rule prepare_controls_list:
        input:
            controls=CONTROLS_TSV,
        output:
            CONTROLS_LIST,
        log:
            LOGS_DIR / "prepare_controls.log",
        shell:
            """
            cp {input.controls} {output}
            """


    rule harmonisation:
        input:
            controls=CONTROLS_LIST,
        output:
            flag=FLAGS_DIR / f"harmonisation.{HARMO_CODE}.done",
        log:
            LOGS_DIR / f"harmonisation.{HARMO_CODE}.log",
        params:
            pipeline_root=PIPELINE_ROOT,
            aidhs_py=AIDHS_PY,
            license=LICENSE,
            sif=SIF,
            demographics_container=DEMO_CONTAINER,
            exec_script=SCRIPTS / "container_exec.sh",
            bids_root=BIDS_ROOT,
            link_script=SCRIPTS / "link_bids_subjects.sh",
            controls_tsv=CONTROLS_TSV,
            harmo_code=HARMO_CODE,
        resources:
            **stage_resources("harmonisation"),
        shell:
            """
            set -euo pipefail
            exec > >(tee -a {log}) 2>&1
            mkdir -p {params.pipeline_root}/input
            if [[ -n "{params.bids_root}" ]]; then
              bash {params.link_script} {params.pipeline_root} {params.bids_root} {params.controls_tsv}
            fi
            EXTRA=""
            if [[ -n "{params.bids_root}" ]]; then
              EXTRA="{params.bids_root}:{params.bids_root}:ro,{params.aidhs_py}:/aidhs_py:ro"
            else
              EXTRA="{params.aidhs_py}:/aidhs_py:ro"
            fi
            bash {params.exec_script} {params.pipeline_root} {params.license} {params.sif} \
              "${{EXTRA}}" -- \
              python scripts/new_patient_pipeline/new_patient_pipeline.py \
                -ids input/controls_list_harmo.txt \
                -demos {params.demographics_container} \
                -harmo_code {params.harmo_code} --harmo_only
            touch {output.flag}
            """
