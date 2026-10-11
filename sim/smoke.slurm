#!/bin/bash
# =====================================================================
# smoke.slurm -- validate ALL paths fast as a SUBMITTED JOB (never on login).
# Runs one S2 task with a tiny nsim; if it writes a shard + manifest, submit the
# full run with submit_all.sh.  sbatch smoke.slurm
# =====================================================================
#SBATCH --account=def-YOURACCOUNT
#SBATCH --job-name=compass_smoke
#SBATCH --array=1-1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=output/logs/%x_%A_%a.out
#SBATCH --error=output/logs/%x_%A_%a.err

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
mkdir -p output/logs output/sim output
module load gcc/9.4.0
module load r/4.4.0
export R_LIBS="${R_LIBS:-}"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export COMPASS_ENGINE="$SLURM_SUBMIT_DIR/R" COMPASS_OUT="$SLURM_SUBMIT_DIR/output/smoke" COMPASS_RESULTS="$SLURM_SUBMIT_DIR/output"
echo "[compass smoke] $(date) on $(hostname); cores=$SLURM_CPUS_PER_TASK"
# tiny: 4 replicates of S2 at n=800 -> should write one shard + manifest
Rscript "$COMPASS_ENGINE/run_compass.R" S2 4 4 1 1 0.025 800 \
  && echo "SMOKE OK -> submit the full run: bash submit_all.sh" \
  || { echo "SMOKE FAILED"; exit 1; }
ls -la output/smoke 2>/dev/null
