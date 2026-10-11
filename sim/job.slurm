#!/bin/bash
# =====================================================================
# job.slurm -- COMPASS per-task worker. One array task = one replicate block
# for one slice; the engine parallelises the block across the 32 cores via
# parallel::mclapply(SLURM_CPUS_PER_TASK). Reads CODE from engine/, writes
# output under output/sim. output/ ships EMPTY. submit_all.sh sbatches this.
# =====================================================================
#SBATCH --account=def-YOURACCOUNT
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=06:00:00
#SBATCH --output=output/logs/%x_%A_%a.out
#SBATCH --error=output/logs/%x_%A_%a.err

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
mkdir -p output/logs output/sim output

module load gcc/9.4.0
module load r/4.4.0
export R_LIBS="${R_LIBS:-}"
# Pin BLAS to 1 thread: we fork SLURM_CPUS_PER_TASK workers with mclapply; a
# threaded BLAS would oversubscribe the cores.
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
       VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1

export COMPASS_ENGINE="$SLURM_SUBMIT_DIR/R"
export COMPASS_OUT="$SLURM_SUBMIT_DIR/output/sim"
export COMPASS_RESULTS="$SLURM_SUBMIT_DIR/output"

# Per-run knobs (submit_all.sh exports these; defaults = an S2 leaderboard task)
SLICE="${SLICE:-S2}"; NSIM="${NSIM:-2500}"; SIMS_PER_TASK="${SIMS_PER_TASK:-250}"
R="${R:-1}"; SHARP="${SHARP:-1}"; GBOUND="${GBOUND:-0.025}"; NPER="${NPER:-3000}"

echo "[compass] job $SLURM_JOB_ID task ${SLURM_ARRAY_TASK_ID:-NA} SLICE=$SLICE R=$R SHARP=$SHARP GBOUND=$GBOUND cores=$SLURM_CPUS_PER_TASK on $(hostname) $(date)"
Rscript "$COMPASS_ENGINE/run_compass.R" "$SLICE" "$NSIM" "$SIMS_PER_TASK" "$R" "$SHARP" "$GBOUND" "$NPER"
