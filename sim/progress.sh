#!/bin/bash
# progress.sh -- quick COMPASS run status. Run from the bundle root on ARC.
cd "${SLURM_SUBMIT_DIR:-.}"
echo "== queue =="
squeue -u "$(whoami)" -o "%.18i %.12j %.2t %.10M %.6D %R" 2>/dev/null | head -40
echo ""
echo "== shards written (output/sim) =="
for s in S1 S2 D3 S3; do
  n=$(ls output/sim/compass_${s}_*.csv 2>/dev/null | wc -l)
  echo "  $s : $n shard csv"
done
echo "  diag : $(ls output/sim/diag_*.csv 2>/dev/null | wc -l)"
echo ""
echo "== recent errors (last 5 non-empty .err) =="
find output/logs -name '*.err' -size +0c 2>/dev/null | tail -5 | while read f; do echo "--- $f"; tail -3 "$f"; done
