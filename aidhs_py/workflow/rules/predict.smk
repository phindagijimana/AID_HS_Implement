# Per-subject AID-HS prediction (full or prediction-only).


def _predict_inputs(wc):
    ins = {}
    if RUN_VALIDATE:
        ins["validate_flag"] = validate_flag(wc.sid)
    if RUN_HARMONISATION:
        ins["harmo_flag"] = harmo_flag()
    return ins


if not SKIP_SEGMENTATION:

    rule predict:
        input:
            **_predict_inputs,
        output:
            report=PIPELINE_ROOT / "output" / "predictions_reports" / "{sid}" / "Report_{sid}.pdf",
        log:
            LOGS_DIR / "predict.{sid}.log",
        params:
            pipeline_root=PIPELINE_ROOT,
            aidhs_py=AIDHS_PY,
            license=LICENSE,
            sif=SIF,
            demographics_container=DEMO_CONTAINER,
            exec_script=SCRIPTS / "container_exec.sh",
            bids_root=BIDS_ROOT,
            harmo_code=HARMO_CODE if RUN_HARMONISATION else "",
        resources:
            **stage_resources("predict"),
            hippunfold_slots=1,
        shell:
            """
            set -euo pipefail
            exec > >(tee -a {log}) 2>&1
            EXTRA="{params.aidhs_py}:/aidhs_py:ro"
            if [[ -n "{params.bids_root}" ]]; then
              EXTRA="{params.bids_root}:{params.bids_root}:ro,${{EXTRA}}"
            fi
            HARMO_ARGS=""
            if [[ -n "{params.harmo_code}" ]]; then
              HARMO_ARGS="-harmo_code {params.harmo_code}"
            fi
            bash {params.exec_script} {params.pipeline_root} {params.license} {params.sif} \
              "${{EXTRA}}" -- \
              python scripts/new_patient_pipeline/new_patient_pipeline.py \
                -id {wildcards.sid} \
                -demos {params.demographics_container} \
                ${{HARMO_ARGS}}
            test -f {output.report}
            """

else:

    rule predict_only:
        input:
            **_predict_inputs,
        output:
            report=PIPELINE_ROOT / "output" / "predictions_reports" / "{sid}" / "Report_{sid}.pdf",
        log:
            LOGS_DIR / "predict_only.{sid}.log",
        params:
            pipeline_root=PIPELINE_ROOT,
            aidhs_py=AIDHS_PY,
            license=LICENSE,
            sif=SIF,
            demographics_container=DEMO_CONTAINER,
            exec_script=SCRIPTS / "container_exec.sh",
            bids_root=BIDS_ROOT,
            harmo_code=HARMO_CODE if RUN_HARMONISATION else "",
        resources:
            **stage_resources("predict_only"),
            hippunfold_slots=1,
        shell:
            """
            set -euo pipefail
            exec > >(tee -a {log}) 2>&1
            EXTRA="{params.aidhs_py}:/aidhs_py:ro"
            if [[ -n "{params.bids_root}" ]]; then
              EXTRA="{params.bids_root}:{params.bids_root}:ro,${{EXTRA}}"
            fi
            HARMO_ARGS=""
            if [[ -n "{params.harmo_code}" ]]; then
              HARMO_ARGS="-harmo_code {params.harmo_code}"
            fi
            bash {params.exec_script} {params.pipeline_root} {params.license} {params.sif} \
              "${{EXTRA}}" -- \
              python scripts/new_patient_pipeline/run_pipeline_prediction.py \
                -id {wildcards.sid} \
                -demos {params.demographics_container} \
                ${{HARMO_ARGS}}
            test -f {output.report}
            """
