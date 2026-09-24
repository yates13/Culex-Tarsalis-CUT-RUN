# Run once, before submitting the array job
ls "${BAM_INPUT_DIR}"/*-Cxt.bam | grep -v -- '-IN-' > "$TREATMENT_LIST"
wc -l "$TREATMENT_LIST"   # confirm it says 72
