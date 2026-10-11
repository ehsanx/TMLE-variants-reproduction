#!/bin/bash
# =====================================================================
# submit_all.sh -- submit ALL COMPASS arrays (32-core mclapply engine) and chain
# ONE dependent aggregate that emails at END. Run from the bundle root on ARC
# scratch (= SLURM_SUBMIT_DIR).  bash submit_all.sh
#
# Cells (F3 pre-registration + the 2026-08-07 amendment):
#   LEADERBOARD (R=1): S2, D3, S1 at n=3000, nsim=2500      -- the map
#   N-GRADIENT       : S1, S2 also at n=1000, nsim=2500     -- "depends on n?"
#   REPS OVERLAY     : S2, D3 at R=25, n=3000, nsim=250     -- does repetition
#                      tighten the conservative cross-fit CIs under ranger?
#   S1 REPS PLATEAU  : S1 R=100, n=3000, nsim=1000          -- Axis-C benign
#   S3 SWEEP (Supp)  : sharp{1.5,2}xgbound{.001,.005,.01,.025}, R=1; the anchor
#                      (2.0,0.025) at nsim=2500, the other 7 cells at nsim=1000.
#
# 32 cores/task; per-slice SPT/time below. ~18 arrays, still far fewer tasks than
# a 1-core design. ALWAYS 'sbatch smoke.slurm' first. output/sim MUST be empty at
# first submit (skip-if-done keys on the shard filename); ship a FRESH copy.
# =====================================================================
set -uo pipefail
mkdir -p output/logs output/sim output
NSIM="${NSIM:-2500}"; NSIM_PLATEAU="${NSIM_PLATEAU:-500}"
NSIM_S3="${NSIM_S3:-1000}"; NSIM_REPS="${NSIM_REPS:-250}"; N_LOW="${N_LOW:-1000}"
ACCT=def-YOURACCOUNT   # set your Slurm allocation
IDS=()

# sub <name> <slice> <R> <sharp> <gbound> <nsim> <spt> <time> <nper>
sub () {
  local name=$1 slice=$2 r=$3 sharp=$4 gb=$5 ns=$6 spt=$7 wall=$8 nper=$9
  local nt=$(( (ns + spt - 1) / spt ))
  echo "  $name : slice=$slice R=$r sharp=$sharp gbound=$gb n=$nper array=1-$nt spt=$spt time=$wall (nsim=$ns)"
  local jid
  jid=$(sbatch --parsable -J "$name" --array=1-"$nt" --time="$wall" \
        --export=ALL,SLICE=$slice,NSIM=$ns,SIMS_PER_TASK=$spt,R=$r,SHARP=$sharp,GBOUND=$gb,NPER=$nper job.slurm)
  if [ -z "$jid" ]; then echo "FATAL: sbatch failed for $name"; exit 1; fi   # guard: no malformed afterany:ID::ID
  IDS+=("$jid")
}

echo "COMPASS submit (32-core mclapply): NSIM=$NSIM"
# Walls = the ARC 6h template for ALL slices; SPT sized from MEASURED s/rep wall
# (32 cores, ~14x effective): S2 ~5.8, D3 ~12.5, gam slices slow+variable, R=25
# ranger ~140 (statin)/~350 (rough), R=100 gam very slow. Each task fits <~3h.
# --- leaderboard regimes at n=3000 (R=1) ---
sub compass_S2 S2 1 1 0.025 "$NSIM" 250 06:00:00 3000
sub compass_D3 D3 1 1 0.025 "$NSIM" 250 06:00:00 3000
sub compass_S1 S1 1 1 0.025 "$NSIM" 100 06:00:00 3000   # gam: slow -> SPT 100
# --- n-gradient: S1 & S2 also at n=1000 ---
sub compass_S1_nlo S1 1 1 0.025 "$NSIM" 100 06:00:00 "$N_LOW"   # gam: SPT 100
sub compass_S2_nlo S2 1 1 0.025 "$NSIM" 250 06:00:00 "$N_LOW"
# --- non-benign reps overlay: S2 & D3 at R=25 (reps {1,5,25} via aggregate_splits) ---
sub compass_S2_rep S2 25 1 0.025 "$NSIM_REPS" 32 06:00:00 3000   # ~140 s/rep
sub compass_D3_rep D3 25 1 0.025 "$NSIM_REPS" 16 06:00:00 3000   # rough: ~350 s/rep -> SPT 16
# --- S1 reps plateau (R=100; Donsker) -- least-informative, so nsim=500, tiny SPT ---
sub compass_S1plat S1 100 1 0.025 "$NSIM_PLATEAU" 4 06:00:00 3000   # gam R=100 very slow -> SPT 4
# --- S3 near-positivity sweep: anchor (2.0,0.025) at full nsim, other 7 at NSIM_S3 ---
for SH in 1.5 2.0; do for GB in 0.001 0.005 0.01 0.025; do
  if [ "$SH" = "2.0" ] && [ "$GB" = "0.025" ]; then NS3="$NSIM"; else NS3="$NSIM_S3"; fi
  sub "compass_S3_${SH}_${GB}" S3 1 "$SH" "$GB" "$NS3" 100 06:00:00 3000   # gam: SPT 100
done; done

# ONE dependent aggregate. afterANY (not afterok): the aggregate ALWAYS runs once all
# arrays TERMINATE (any state; no shard is mid-write), so the COMPLETENESS GATE is
# load-bearing -- complete => maps + one END email; incomplete => the gate stops and
# prints the exact missing (slice,sharp,gbound,n,Rreps,nsim,got,missing) table + one
# FAIL email. Guarantees exactly ONE terminal signal even if a task times out.
DEP=$(IFS=:; echo "${IDS[*]}")
echo "chaining aggregate (afterany:${DEP})"
sbatch --dependency=afterany:"$DEP" --account="$ACCT" --job-name=compass_agg \
  --nodes=1 --ntasks=1 --cpus-per-task=1 --mem=16G --time=01:00:00 \
  --output=output/logs/agg_%j.out --error=output/logs/agg_%j.err \
  \
  --wrap "cd \$SLURM_SUBMIT_DIR; module load gcc/9.4.0 r/4.4.0; export R_LIBS=${R_LIBS:-} COMPASS_ENGINE=\$SLURM_SUBMIT_DIR/R COMPASS_OUT=\$SLURM_SUBMIT_DIR/output/sim COMPASS_RESULTS=\$SLURM_SUBMIT_DIR/output; Rscript R/aggregate_compass.R 0.02"

echo ""
echo "Submitted ${#IDS[@]} arrays + 1 dependent aggregate. Watch:  squeue -u $(whoami)   (or bash progress.sh)"
echo "When the dependent aggregate finishes: output/compass_maps.rds + compass_report.txt (check output/logs/agg_*.out)"
