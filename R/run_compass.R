# =====================================================================
# run_compass.R -- COMPASS ARC worker. One SLURM array task = one block of
# Monte Carlo replicates for ONE slice; replicates run ACROSS the allocated
# cores via parallel::mclapply(mc.cores=SLURM_CPUS_PER_TASK). Sources the engine
# from COMPASS_ENGINE, writes per-replicate long + a per-shard diagnostic to
# COMPASS_OUT.
#
#   Rscript run_compass.R <slice> <nsim> <sims_per_task> <R> <sharp> <gbound> [n_per]
#     slice  : S1 | S2 | D3 | S3     R: 1 leaderboard | 100 S1 reps plateau
#     sharp  : statin_sharp (S1/S2=1; S3 sweep in {1.5,2}); ignored for D3
#     gbound : propensity bound (0.025 default; S3 sweep in {0.001..0.025})
#   Env: SLURM_ARRAY_TASK_ID, SLURM_CPUS_PER_TASK, COMPASS_ENGINE, COMPASS_OUT.
#   Truths: COMPASS_ENGINE/truths.rds (from pin_truths.R) OVERRIDES the defaults.
# =====================================================================
suppressPackageStartupMessages({ library(SuperLearner); library(dplyr); library(parallel) })
ENGINE <- Sys.getenv("COMPASS_ENGINE", unset = "R")
OUT    <- Sys.getenv("COMPASS_OUT",    unset = "output/sim")
for (f in c("01_engine.R","02_variants.R","recipes.R","dgm.R","dgm_variants.R","learners.R"))
  source(file.path(ENGINE, f))

a <- commandArgs(trailingOnly = TRUE)
slice         <- if (length(a) >= 1) a[1]             else "S2"
nsim          <- if (length(a) >= 2) as.integer(a[2]) else 2500L
sims_per_task <- if (length(a) >= 3) as.integer(a[3]) else 250L
R             <- if (length(a) >= 4) as.integer(a[4]) else 1L
sharp         <- if (length(a) >= 5) as.numeric(a[5]) else 1
gbound        <- if (length(a) >= 6) as.numeric(a[6]) else 0.025
n_per         <- if (length(a) >= 7) as.integer(a[7]) else 3000L

cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "1"))
if (is.na(cores) || cores < 1L) cores <- 1L
if (.Platform$OS.type == "windows") cores <- 1L      # mclapply forking is POSIX-only

# truths: prefer the pinned file (>=1e8), else the validated defaults
D1_TRUTH <- -0.1081508; D3_TRUTH <- 0.10068; truth_src <- "default"
tf <- file.path(ENGINE, "truths.rds")
if (file.exists(tf)) { tr <- readRDS(tf)
  if (!is.null(tr$D1)) D1_TRUTH <- tr$D1; if (!is.null(tr$D3)) D3_TRUTH <- tr$D3; truth_src <- "pinned" }

cfg <- switch(slice,
  S1 = list(gen = function(n) generate_statin(n, statin_sharp = sharp), kind = "statin", lib = sl_donsker,     truth = D1_TRUTH),
  S2 = list(gen = function(n) generate_statin(n, statin_sharp = sharp), kind = "statin", lib = sl_ranger_pure, truth = D1_TRUTH),
  D3 = list(gen = function(n) generate_rough(n),                        kind = "rough",  lib = sl_ranger_pure, truth = D3_TRUTH),
  S3 = list(gen = function(n) generate_statin(n, statin_sharp = sharp), kind = "statin", lib = sl_donsker,     truth = D1_TRUTH),
  stop("unknown slice: ", slice))
if (slice == "D3" && truth_src == "default")
  warning("D3 truth using the 5-sig-fig DEFAULT (0.10068); run pin_truths.R for the >=1e8 value.")

adapt <- function(d) if (cfg$kind == "statin")
  list(Y = d$Y, A = d$statin, W = d[, c("age","ldl_log","diabetes","risk_score")]) else
  list(Y = d$Y, A = d$A, W = d[, paste0("X", 1:8)])

slice_diag <- function(Y, A, W, lib, gbound, inner_V = 5L) {
  fam <- stats::binomial()
  gp <- fit_sl(A, W, fam, lib, inner_V); g <- gp(W)
  Qp <- fit_sl(Y, .Qdesign(A, W), fam, lib, inner_V); QA_ins <- Qp(.Qdesign(A, W))
  n <- length(Y); folds <- make_folds(n, 3L); QA_oof <- rep(NA_real_, n)
  for (k in 1:3) { tr <- folds != k; te <- folds == k
    Qk <- fit_sl(Y[tr], .Qdesign(A[tr], W[tr, , drop=FALSE]), fam, lib, inner_V)
    QA_oof[te] <- Qk(.Qdesign(A[te], W[te, , drop=FALSE])) }
  data.frame(frac_g_trunc = mean(g < gbound | g > 1 - gbound),
             q_insample_mse = mean((Y - QA_ins)^2), q_oof_mse = mean((Y - QA_oof)^2),
             q_optimism = mean((Y - QA_oof)^2) - mean((Y - QA_ins)^2))
}

task_id <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", unset = "1"))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- guards: --array must match ceil(nsim/sims_per_task); no downward range ----
exp_tasks <- as.integer(ceiling(nsim / sims_per_task))
act <- Sys.getenv("SLURM_ARRAY_TASK_COUNT")
if (task_id == 1L) message(sprintf("[grid] nsim=%d / spt=%d => set --array=1-%d", nsim, sims_per_task, exp_tasks))
if (nzchar(act) && as.integer(act) != exp_tasks)
  stop(sprintf("ARRAY/GRID MISMATCH: --array has %s tasks but nsim/spt needs %d", act, exp_tasks))
start <- (task_id - 1L) * sims_per_task + 1L; end <- min(task_id * sims_per_task, nsim)
if (start > end) { message("[compass] task ", task_id, " has no replicates (start>end); exiting 0."); quit(save = "no", status = 0L) }

# shard tag now includes R and n so the R=1 leaderboard and R=100 plateau NEVER collide
tag  <- sprintf("%s_sh%02.0f_gb%04.0f_R%03d_n%04d_task%03d", slice, sharp*10, gbound*1000, R, n_per, task_id)
outf <- file.path(OUT, sprintf("compass_%s.csv", tag))
if (file.exists(outf) && file.size(outf) > 0L) {   # skip-if-done: a resubmit never recomputes a finished shard
  message("[compass] shard already complete, skipping: ", tag); quit(save = "no", status = 0L)
}

# ---- per-run manifest (task 1 of each array) ----
if (task_id == 1L) {
  bi <- tryCatch(readLines(file.path(ENGINE, "BUILD_INFO.txt"), warn = FALSE)[1], error = function(e) NA)
  man <- c(sprintf("COMPASS run manifest  slice=%s R=%d sharp=%.2f gbound=%.3f n=%d nsim=%d spt=%d",
                   slice, R, sharp, gbound, n_per, nsim, sims_per_task),
           sprintf("build=%s  truth_source=%s  D1=%.7f D3=%.7f  cores=%d", bi, truth_src, D1_TRUTH, D3_TRUTH, cores),
           R.version.string,
           paste(sprintf("%s %s", c("SuperLearner","ranger","gam","dplyr","tidyr"),
                         vapply(c("SuperLearner","ranger","gam","dplyr","tidyr"),
                                function(p) as.character(packageVersion(p)), "")), collapse = " | "))
  writeLines(man, file.path(OUT, sprintf("manifest_%s.txt", sub("_task\\d+$", "", tag))))
}

t0 <- Sys.time()
message(sprintf("[compass] %s task %d: reps %d..%d  R=%d sharp=%.2f gbound=%.3f n=%d cores=%d truth(%s D1=%.6f D3=%.6f)",
                slice, task_id, start, end, R, sharp, gbound, n_per, cores, truth_src, D1_TRUTH, D3_TRUTH))

# ---- one replicate (CRN: seed keyed on s; fork-safe -> mclapply preserves it) ----
run_rep <- function(s) {
  set.seed(10000 + s)
  d <- cfg$gen(n_per); da <- adapt(d)
  long <- tryCatch(run_all_groups(da$Y, da$A, da$W, groups, cfg$lib, cfg$lib,
                    R = R, inner_V = 5L, gbound = gbound, seed_base = 20000 + s * 1000),
                   error = function(e) { message("  sim ", s, " ERROR: ", conditionMessage(e)); NULL })
  if (is.null(long)) return(NULL)
  long$se <- sqrt(long$vd); long$sim_id <- s; long$slice <- slice
  long$sharp <- sharp; long$gbound <- gbound; long$truth <- cfg$truth
  long$Rreps <- R; long$n_per <- n_per
  long$ok <- is.finite(long$rd)   # FA3 (2026-08-09): explicit per-recipe success flag
  long[, c("sim_id","slice","sharp","gbound","n_per","Rreps","label","rep","rd","se","vd","truth","ok")]
}
groups <- compass_recipe_groups()
res <- mclapply(start:end, run_rep, mc.cores = cores, mc.preschedule = FALSE)
rows <- res[!vapply(res, is.null, logical(1))]

# one mechanism diagnostic for this shard (the first replicate's dataset)
set.seed(10000 + start); d0 <- cfg$gen(n_per); da0 <- adapt(d0)
dg <- tryCatch(slice_diag(da0$Y, da0$A, da0$W, cfg$lib, gbound), error = function(e) NULL)

write.csv(dplyr::bind_rows(rows), outf, row.names = FALSE)
if (!is.null(dg)) { dg$sim_id <- start; dg$slice <- slice; dg$sharp <- sharp; dg$gbound <- gbound; dg$R <- R
  dg$ranger_weight <- if (identical(cfg$lib, sl_ranger_pure)) 1 else NA
  write.csv(dg, file.path(OUT, sprintf("diag_%s.csv", tag)), row.names = FALSE) }
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
message(sprintf("[compass] wrote %s  (%d rows, %d/%d reps ok, %.0f s -> %.1f s/rep wall)",
                tag, sum(vapply(rows, nrow, 0L)), length(rows), end - start + 1L, secs, secs / (end - start + 1L)))
