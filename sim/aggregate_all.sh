#!/bin/bash
# =====================================================================
# aggregate_all.sh -- pool all shards into the COMPASS materiality maps.
# Run from the bundle root on ARC (after every array has finished).
#   bash aggregate_all.sh            # delta_cov = 0.02 (pre-registered)
#   DELTA=0.01 bash aggregate_all.sh
# Output: output/compass_maps.rds + output/compass_report.txt
# =====================================================================
set -e
cd "${SLURM_SUBMIT_DIR:-.}"
module load gcc/9.4.0 r/4.4.0 2>/dev/null || true
export R_LIBS="${R_LIBS:-}"
export COMPASS_ENGINE="$PWD/R" COMPASS_OUT="$PWD/output/sim" COMPASS_RESULTS="$PWD/output"
DELTA="${DELTA:-0.02}"
NSH=$(ls output/sim/compass_*.csv 2>/dev/null | wc -l)
echo "Aggregating $NSH shard files at delta_cov=$DELTA ..."
Rscript R/aggregate_compass.R "$DELTA"
echo "Done -> output/compass_maps.rds + compass_report.txt"
