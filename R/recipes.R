# =====================================================================
# recipes.R -- COMPASS shared-nuisance recipe layer.
#
# The expensive part of every TMLE/cross-fit variant is the SuperLearner
# nuisance fit. Many named recipes share the SAME nuisance fit and differ
# only in cheap post-processing (the targeting GLM + arithmetic assembly):
#   - scheme "none"       : TMLE(pooled) + AIPW(onestep) + GCOMP(plugin)
#   - scheme "cv" qonly=F  : CV-TMLE + CV-TMLE-fold + CF-AIPW
#   - scheme "cv" qonly=T  : CVQ-TMLE + CVQ-TMLE-fold + CF-GCOMP
#   - scheme "cf3"         : DC-TMLE + DC-AIPW + DC-TMLE-pool
# so we fit the nuisances ONCE per (scheme, qonly, partition draw) and derive
# every recipe in the group from that one fit. Repetitions become repeated
# partition draws; reps={1,5,25,100} are strict PREFIXES of one R=100 draw
# and aggregation rules are post-hoc reductions (see aggregate_splits()).
#
# This layer REUSES the validated primitives in ../R/01_engine.R and
# ../R/02_variants.R without modifying them. It is numerically IDENTICAL to
# calling run_once() once per recipe -- proved in test_recipes.R.
#
# Depends on: 01_engine.R (estimate_nuisances, make_folds, .bound_g) and
#             02_variants.R (target_pooled/foldwise, assemble*, %||%).
# =====================================================================

# ---------------------------------------------------------------------
# derive_recipes(): from ONE nuisance frame, compute every recipe in a group.
#   nuis        : data.frame(g, Q1, Q0, QA, fold) from estimate_nuisances()
#   recipe_defs : list of list(label=, target=, agg_fold=)
#                 target in {"pooled","foldwise","onestep","plugin"}
# The two fluctuations (pooled / fold-specific epsilon) are each computed at
# most ONCE and reused across every recipe that needs them.
# Returns a tibble: label, r1, r0, rd, vd (vd = NA for plugin).
# ---------------------------------------------------------------------
derive_recipes <- function(Y, A, nuis, recipe_defs, gbound = 0.025) {
  needs_pooled   <- any(vapply(recipe_defs, function(r) identical(r$target, "pooled"),   logical(1)))
  needs_foldwise <- any(vapply(recipe_defs, function(r) identical(r$target, "foldwise"), logical(1)))
  # FA3 (2026-08-09, post-freeze): compute the shared fluctuations inside tryCatch so a
  # fluctuation-GLM failure degrades to a per-recipe NA (below) instead of dropping the
  # whole replicate. Number-neutral on the canonical run (no fluctuation GLM failed).
  tgp <- if (needs_pooled)   tryCatch(target_pooled(Y, A, nuis, gbound),   error = function(e) NULL) else NULL
  tgf <- if (needs_foldwise) tryCatch(target_foldwise(Y, A, nuis, gbound), error = function(e) NULL) else NULL
  gb  <- .bound_g(nuis$g, gbound)

  rows <- lapply(recipe_defs, function(r) {
    af <- isTRUE(r$agg_fold)
    est <- tryCatch(switch(r$target,
      pooled   = if (is.null(tgp)) stop("pooled fluctuation unavailable")   else assemble(Y, A, tgp$g, tgp$Q1s, tgp$Q0s, fold = nuis$fold, agg_fold = af),
      foldwise = if (is.null(tgf)) stop("foldwise fluctuation unavailable") else assemble(Y, A, tgf$g, tgf$Q1s, tgf$Q0s, fold = nuis$fold, agg_fold = af),
      onestep  = assemble_onestep(Y, A, gb, nuis$Q1, nuis$Q0, fold = nuis$fold, agg_fold = af),
      plugin   = assemble_plugin(nuis$Q1, nuis$Q0),
      stop("unknown target: ", r$target)),
      error = function(e) NULL)
    if (is.null(est))
      dplyr::tibble(label = r$label, r1 = NA_real_, r0 = NA_real_, rd = NA_real_, vd = NA_real_)
    else
      dplyr::tibble(label = r$label, r1 = est$r1, r0 = est$r0, rd = est$rd, vd = est$vd)
  })
  dplyr::bind_rows(rows)
}

# ---------------------------------------------------------------------
# fit_partition_nuisances(): draw ONE partition (seeded, for common random
# numbers) and fit the group's nuisances ONCE. Mirrors run_once()'s RNG
# sequence exactly (make_folds THEN estimate_nuisances) so the resulting frame
# is bit-identical to what run_once() would fit for the same scheme/qonly/seed.
# Returns list(nuis, Y, A) -- Y/A are subset for the ss2 (held-half) scheme.
# ---------------------------------------------------------------------
fit_partition_nuisances <- function(Y, A, W, scheme, V, sl_g, sl_Q,
                                    inner_V = 5L, qonly = FALSE, seed = NULL) {
  n <- length(Y)
  if (!is.null(seed)) set.seed(seed)

  if (scheme == "none") {
    nuis <- estimate_nuisances(Y, A, W, rep(0L, n), "none", sl_g, sl_Q, inner_V,
                               qonly_gfull = isTRUE(qonly))
    return(list(nuis = nuis, Y = Y, A = A))
  }
  if (scheme == "ss2") {
    folds <- make_folds(n, 2L)
    nuis_full <- estimate_nuisances(Y, A, W, folds, "cf2", sl_g, sl_Q, inner_V,
                                    qonly_gfull = isTRUE(qonly))
    keep <- folds == 2L
    nuis <- nuis_full[keep, , drop = FALSE]; nuis$fold <- 0L
    return(list(nuis = nuis, Y = Y[keep], A = A[keep]))
  }
  Vv <- V %||% switch(scheme, cf2 = 2L, cf3 = 3L, cv = 5L)
  folds <- make_folds(n, Vv)
  nuis <- estimate_nuisances(Y, A, W, folds, scheme, sl_g, sl_Q, inner_V,
                             qonly_gfull = isTRUE(qonly))
  list(nuis = nuis, Y = Y, A = A)
}

# ---------------------------------------------------------------------
# run_group(): run one (scheme, qonly) group over R repeated partition draws,
# deriving ALL its recipes each draw. no-split schemes ("none") use R=1.
# Returns a long tibble: label, rep, r1, r0, rd, vd  (one row per recipe x rep).
# ONE SuperLearner nuisance fit per rep serves every recipe in the group.
# ---------------------------------------------------------------------
run_group <- function(Y, A, W, scheme, V, qonly, recipe_defs, sl_g, sl_Q,
                      R = 100L, inner_V = 5L, gbound = 0.025, seed_base = 0L) {
  is_split <- !(scheme %in% "none")
  R_use <- if (is_split) R else 1L
  rows <- vector("list", R_use)
  for (r in seq_len(R_use)) {
    seed_r <- if (is_split) seed_base + r else seed_base
    fp <- tryCatch(fit_partition_nuisances(Y, A, W, scheme, V, sl_g, sl_Q,
                                           inner_V, qonly, seed = seed_r),
                   error = function(e) NULL)
    if (is.null(fp)) next
    rec <- derive_recipes(fp$Y, fp$A, fp$nuis, recipe_defs, gbound)
    rec$rep <- r
    rows[[r]] <- rec
  }
  dplyr::bind_rows(rows)
}

# ---------------------------------------------------------------------
# run_all_groups(): the full COMPASS leaderboard for ONE dataset. Loops the
# grouped catalogue; every group fits its nuisances once per rep. Returns the
# per-split long tibble across all recipes (feed to aggregate_splits()).
# ---------------------------------------------------------------------
run_all_groups <- function(Y, A, W, groups, sl_g, sl_Q,
                           R = 100L, inner_V = 5L, gbound = 0.025, seed_base = 0L) {
  out <- lapply(groups, function(g)
    run_group(Y, A, W, g$scheme, g$V, isTRUE(g$qonly), g$recipes, sl_g, sl_Q,
              R = R, inner_V = inner_V, gbound = gbound, seed_base = seed_base))
  dplyr::bind_rows(out)
}

# ---------------------------------------------------------------------
# aggregate_splits(): post-hoc reduction of the per-split long tibble to
# per-(label, R, rule) estimates. reps are strict PREFIXES of the R draws;
# rules are deterministic reductions -- NO refitting. Variance rules:
#   within        : aggregate the per-split IF variance vd (median or mean)
#   corrected(mvd): vd + (rd_split - centre)^2, then aggregated -- the
#                   between-split correction (Chernozhukov/Zivich)
#   uncorrected   : same centre, but report the within variance (no + term)
# For no-split recipes (one row) all rules collapse to that single estimate.
# ---------------------------------------------------------------------
aggregate_splits <- function(long, R_levels = c(1, 5, 10, 25, 50, 100),
                             rules = c("median", "mean")) {
  labs <- unique(long$label)
  res <- list(); k <- 0L
  for (lab in labs) {
    d <- long[long$label == lab & is.finite(long$rd), , drop = FALSE]
    d <- d[order(d$rep), , drop = FALSE]
    n_avail <- nrow(d)
    for (Rlv in R_levels) {
      if (n_avail == 0L) next
      m <- min(Rlv, n_avail)
      if (Rlv > 1L && n_avail < 2L) next          # a split recipe needs >=1 draw; skip empty
      sub <- d[seq_len(m), , drop = FALSE]
      for (rule in rules) {
        centre <- if (rule == "mean") base::mean else stats::median
        vagg   <- if (rule == "mean") base::mean else stats::median
        rd_c  <- centre(sub$rd)
        vd_a  <- vagg(sub$vd)
        mvd_a <- vagg(sub$vd + (sub$rd - rd_c)^2)   # between-split corrected
        k <- k + 1L
        res[[k]] <- dplyr::tibble(
          label = lab, R = Rlv, n_used = m, rule = rule,
          rd = rd_c, vd = vd_a, mvd = mvd_a,
          se_within = sqrt(vd_a), se_corrected = sqrt(mvd_a))
      }
    }
  }
  dplyr::bind_rows(res)
}

# ---------------------------------------------------------------------
# compass_recipe_groups(): the grouped catalogue (labels/specs match the
# validated 04b factorial exactly, now grouped so each group's nuisances are
# fit once). The 8 GRADED recipes are TMLE(Vanilla), AIPW, SS-TMLE, CVQ-TMLE,
# CV-TMLE, CF-AIPW, DCTMLE, DC-AIPW. GCOMP/CF-GCOMP (no valid SE) and the folk
# mirror cells are carried for the Supplement, flagged via graded/folk.
# ---------------------------------------------------------------------
compass_recipe_groups <- function() list(
  list(scheme = "none", V = NA, qonly = FALSE, recipes = list(
    list(label = "TMLE",          target = "pooled",   agg_fold = FALSE, graded = TRUE),   # Vanilla TMLE
    list(label = "AIPW",          target = "onestep",  agg_fold = FALSE, graded = TRUE),
    list(label = "GCOMP",         target = "plugin",   agg_fold = FALSE, graded = FALSE))),
  list(scheme = "ss2", V = 2L, qonly = FALSE, recipes = list(
    list(label = "SS-TMLE",       target = "pooled",   agg_fold = FALSE, graded = TRUE))),
  list(scheme = "cv", V = 5L, qonly = TRUE, recipes = list(
    list(label = "CVQ-TMLE",      target = "pooled",   agg_fold = FALSE, graded = TRUE),   # CVTMLE[Q]
    list(label = "CVQ-TMLE-fold", target = "foldwise", agg_fold = TRUE,  graded = FALSE, folk = TRUE),
    list(label = "CF-GCOMP",      target = "plugin",   agg_fold = FALSE, graded = FALSE))),
  list(scheme = "cv", V = 5L, qonly = FALSE, recipes = list(
    list(label = "CV-TMLE",       target = "pooled",   agg_fold = FALSE, graded = TRUE),
    list(label = "CV-TMLE-fold",  target = "foldwise", agg_fold = TRUE,  graded = FALSE, folk = TRUE),
    list(label = "CF-AIPW",       target = "onestep",  agg_fold = FALSE, graded = TRUE))),
  list(scheme = "cf2", V = 2L, qonly = FALSE, recipes = list(
    list(label = "SCTMLE",        target = "foldwise", agg_fold = TRUE,  graded = FALSE))),
  list(scheme = "cf3", V = 3L, qonly = FALSE, recipes = list(
    list(label = "DC-TMLE-pool",  target = "pooled",   agg_fold = FALSE, graded = FALSE, folk = TRUE),
    list(label = "DCTMLE",        target = "foldwise", agg_fold = TRUE,  graded = TRUE),   # DC-TMLE
    list(label = "DC-AIPW",       target = "onestep",  agg_fold = TRUE,  graded = TRUE)))
)
