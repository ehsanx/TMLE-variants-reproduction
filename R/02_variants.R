# =====================================================================
# 02_variants.R  -- targeting steps, aggregation rules, and the named
# estimators. Depends on 01_engine.R.
#
# Every estimator returns a one-row data.frame with columns:
#   r1, r0, rd   -- E[Y(1)], E[Y(0)], ATE risk difference
#   v1, v0, vd   -- influence-function variances of r1, r0, rd
# Repetition wrappers additionally return mv1, mv0, mvd (variance with the
# between-split correction) and keep the per-split runs.
# =====================================================================

# ---------------------------------------------------------------------
# TARGETING
# ---------------------------------------------------------------------

# Pooled fluctuation: ONE epsilon estimated over all supplied observations
# using their (out-of-fold) nuisances. This is the canonical CV-TMLE update
# of Zheng & van der Laan (2010): the fluctuation solves the pooled EIF
# equation across all validation folds simultaneously.
target_pooled <- function(Y, A, nuis, gbound = 0.025) {
  g  <- .bound_g(nuis$g, gbound)
  Q1 <- .bound_Q(nuis$Q1); Q0 <- .bound_Q(nuis$Q0)
  QA <- ifelse(A == 1, Q1, Q0)
  H1 <- A / g
  H0 <- (1 - A) / (1 - g)
  eps <- stats::coef(stats::glm(
    Y ~ -1 + H0 + H1 + offset(stats::qlogis(QA)),
    family = stats::binomial()))
  eps[is.na(eps)] <- 0
  Q1s <- stats::plogis(stats::qlogis(Q1) + eps["H1"] / g)
  Q0s <- stats::plogis(stats::qlogis(Q0) + eps["H0"] / (1 - g))
  list(Q1s = Q1s, Q0s = Q0s, g = g)
}

# Fold-specific fluctuation: a separate epsilon per targeting fold, using
# that fold's out-of-fold nuisances; fold-specific psi averaged across folds.
# This is the DML1 / "average the fold solutions" style and matches the
# double-cross-fit and per-fold CV-TMLE implementations in the literature.
target_foldwise <- function(Y, A, nuis, gbound = 0.025) {
  folds <- nuis$fold
  fv <- sort(unique(folds))
  n <- length(Y)
  Q1s <- Q0s <- rep(NA_real_, n)
  gb  <- .bound_g(nuis$g, gbound)
  for (k in fv) {
    idx <- folds == k
    g  <- gb[idx]
    Q1 <- .bound_Q(nuis$Q1[idx]); Q0 <- .bound_Q(nuis$Q0[idx])
    QA <- ifelse(A[idx] == 1, Q1, Q0)
    H1 <- A[idx] / g
    H0 <- (1 - A[idx]) / (1 - g)
    eps <- stats::coef(stats::glm(
      Y[idx] ~ -1 + H0 + H1 + offset(stats::qlogis(QA)),
      family = stats::binomial()))
    eps[is.na(eps)] <- 0
    Q1s[idx] <- stats::plogis(stats::qlogis(Q1) + eps["H1"] / g)
    Q0s[idx] <- stats::plogis(stats::qlogis(Q0) + eps["H0"] / (1 - g))
  }
  list(Q1s = Q1s, Q0s = Q0s, g = gb)
}

# ---------------------------------------------------------------------
# ASSEMBLE a single-split estimate from targeted nuisances.
#   agg_fold = FALSE : pooled psi and pooled EIF variance (var(D)/n)
#   agg_fold = TRUE  : fold-specific psi_k averaged, variance = mean fold
#                      IF-variance / n (matches Zivich & Breskin DCTMLE)
# ---------------------------------------------------------------------
assemble <- function(Y, A, g, Q1s, Q0s, fold = NULL, agg_fold = FALSE) {
  n <- length(Y)
  if (!agg_fold) {
    r1 <- mean(Q1s); r0 <- mean(Q0s); rd <- r1 - r0
    if1 <- eif_mean(Y, A, g, Q1s, r1, 1)
    if0 <- eif_mean(Y, A, g, Q0s, r0, 0)
    ifd <- if1 - if0
    return(dplyr::tibble(r1 = r1, r0 = r0, rd = rd,
                         v1 = stats::var(if1)/n,
                         v0 = stats::var(if0)/n,
                         vd = stats::var(ifd)/n))
  }
  fv <- sort(unique(fold))
  r1k <- r0k <- numeric(length(fv))
  v1s <- v0s <- vds <- numeric(length(fv))
  for (j in seq_along(fv)) {
    idx <- fold == fv[j]
    r1k[j] <- mean(Q1s[idx]); r0k[j] <- mean(Q0s[idx])
    if1 <- eif_mean(Y[idx], A[idx], g[idx], Q1s[idx], r1k[j], 1)
    if0 <- eif_mean(Y[idx], A[idx], g[idx], Q0s[idx], r0k[j], 0)
    v1s[j] <- stats::var(if1); v0s[j] <- stats::var(if0)
    vds[j] <- stats::var(if1 - if0)
  }
  r1 <- mean(r1k); r0 <- mean(r0k); rd <- r1 - r0
  dplyr::tibble(r1 = r1, r0 = r0, rd = rd,
                v1 = mean(v1s)/n, v0 = mean(v0s)/n, vd = mean(vds)/n)
}

# one-step / AIPW assembly (no targeting): plug g,Q into the EIF directly
assemble_onestep <- function(Y, A, g, Q1, Q0, fold = NULL, agg_fold = FALSE) {
  gb <- g
  a1 <- A/gb * (Y - Q1) + Q1               # uncentered EIF pieces
  a0 <- (1 - A)/(1 - gb) * (Y - Q0) + Q0
  n <- length(Y)
  if (!agg_fold) {
    r1 <- mean(a1); r0 <- mean(a0); rd <- r1 - r0
    return(dplyr::tibble(r1 = r1, r0 = r0, rd = rd,
                         v1 = stats::var(a1 - r1)/n,
                         v0 = stats::var(a0 - r0)/n,
                         vd = stats::var((a1 - a0) - rd)/n))
  }
  fv <- sort(unique(fold))
  r1k <- r0k <- numeric(length(fv)); v1s <- v0s <- vds <- numeric(length(fv))
  for (j in seq_along(fv)) {
    idx <- fold == fv[j]
    r1k[j] <- mean(a1[idx]); r0k[j] <- mean(a0[idx])
    v1s[j] <- stats::var(a1[idx] - r1k[j]); v0s[j] <- stats::var(a0[idx] - r0k[j])
    vds[j] <- stats::var((a1[idx] - a0[idx]) - (r1k[j] - r0k[j]))
  }
  r1 <- mean(r1k); r0 <- mean(r0k); rd <- r1 - r0
  dplyr::tibble(r1 = r1, r0 = r0, rd = rd,
                v1 = mean(v1s)/n, v0 = mean(v0s)/n, vd = mean(vds)/n)
}

# plug-in / g-computation assembly (no targeting, no augmentation).
# With ML nuisances there is no valid closed-form influence-function variance
# (Zivich & Breskin 2021), so we return the point estimate and NA variances.
assemble_plugin <- function(Q1, Q0) {
  r1 <- mean(Q1); r0 <- mean(Q0)
  dplyr::tibble(r1 = r1, r0 = r0, rd = r1 - r0,
                v1 = NA_real_, v0 = NA_real_, vd = NA_real_)
}

# ---------------------------------------------------------------------
# SINGLE-SPLIT ESTIMATOR (one random partition). Dispatches on scheme,
# nuisance layout, targeting mode.
#   variant fields:
#     scheme    : "none" | "ss2" | "cf2" | "cf3" | "cv"
#     V         : number of folds for cv/cf schemes
#     target    : "pooled" | "foldwise" | "onestep" | "plugin"
#     qonly     : Q-only cross-fit (g on full sample) -> CVQ-style
#     agg_fold  : assemble fold-specific (TRUE) vs pooled (FALSE)
# scheme "ss2" is a single 2-way split WITHOUT rotation: nuisances are fit on
# fold 1 and the estimator is targeted and evaluated on fold 2 only (the other
# half is discarded). It exists to show why cross-fit rotation is used.
# ---------------------------------------------------------------------
run_once <- function(Y, A, W, variant, sl_g, sl_Q, inner_V = 5L,
                     gbound = 0.025) {
  n <- length(Y)
  V <- variant$V %||% switch(variant$scheme, none = 1L, ss2 = 2L, cf2 = 2L, cf3 = 3L, cv = 5L)
  folds <- if (variant$scheme == "none") rep(0L, n) else make_folds(n, V)

  scheme <- variant$scheme
  if (scheme == "ss2") {
    # fit on fold 1, predict into fold 2; keep fold-2 rows only
    nuis_full <- estimate_nuisances(Y, A, W, folds, "cf2", sl_g, sl_Q, inner_V,
                                    qonly_gfull = isTRUE(variant$qonly))
    keep <- folds == 2L
    Y <- Y[keep]; A <- A[keep]
    nuis <- nuis_full[keep, , drop = FALSE]; nuis$fold <- 0L
  } else {
    nuis <- estimate_nuisances(Y, A, W, folds, scheme, sl_g, sl_Q, inner_V,
                               qonly_gfull = isTRUE(variant$qonly))
  }

  if (identical(variant$target, "plugin")) {
    return(assemble_plugin(nuis$Q1, nuis$Q0))
  }
  if (identical(variant$target, "onestep")) {
    g <- .bound_g(nuis$g, gbound)
    return(assemble_onestep(Y, A, g, nuis$Q1, nuis$Q0,
                            fold = nuis$fold, agg_fold = isTRUE(variant$agg_fold)))
  }
  tg <- if (identical(variant$target, "foldwise"))
    target_foldwise(Y, A, nuis, gbound) else target_pooled(Y, A, nuis, gbound)
  assemble(Y, A, tg$g, tg$Q1s, tg$Q0s,
           fold = nuis$fold, agg_fold = isTRUE(variant$agg_fold))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------
# REPETITION + AGGREGATION
# aggregate rules (Chernozhukov 2018 eq. for repeated splits; Zivich &
# Breskin 2021 implementation; Schader et al. 2024):
#   "median" : point = median over splits; corrected var mv = v + (r - median r)^2;
#              report median of mv  (Zivich & Breskin's implemented rule)
#   "median_mean_var" : point = median; report MEAN of mv over splits
#   "mean"   : point = mean; report mean of (v + (r - mean r)^2)
# ---------------------------------------------------------------------
aggregate_runs <- function(runs, rule = c("median", "median_mean_var", "mean")) {
  rule <- match.arg(rule)
  center <- if (rule == "mean") base::mean else stats::median
  m1 <- center(runs$r1); m0 <- center(runs$r0); md <- center(runs$rd)
  runs$mv1 <- runs$v1 + (runs$r1 - m1)^2
  runs$mv0 <- runs$v0 + (runs$r0 - m0)^2
  runs$mvd <- runs$vd + (runs$rd - md)^2
  vagg <- if (rule == "median") stats::median else base::mean
  dplyr::tibble(
    r1 = m1, r0 = m0, rd = md,
    v1 = vagg(runs$v1), v0 = vagg(runs$v0), vd = vagg(runs$vd),
    mv1 = vagg(runs$mv1), mv0 = vagg(runs$mv0), mvd = vagg(runs$mvd)
  )
}

# Run R repetitions of a splitting estimator and aggregate.
run_repeated <- function(Y, A, W, variant, sl_g, sl_Q,
                         R = 100L, rule = "median", inner_V = 5L,
                         gbound = 0.025, seed = NULL, verbose = FALSE) {
  runs <- vector("list", R)
  ok <- 0L
  for (r in seq_len(R)) {
    if (!is.null(seed)) set.seed(seed + r)   # per-rep seed for reproducibility
    res <- tryCatch(run_once(Y, A, W, variant, sl_g, sl_Q, inner_V, gbound),
                    error = function(e) NULL)
    if (!is.null(res) && all(is.finite(unlist(res)))) {
      ok <- ok + 1L; runs[[ok]] <- res
    }
    if (verbose && r %% 10 == 0) message("  rep ", r, " (", ok, " ok)")
  }
  runs <- dplyr::bind_rows(runs[seq_len(ok)])
  agg <- aggregate_runs(runs, rule)
  agg$n_ok <- ok; agg$R <- R
  list(aggregated = agg, runs = runs)
}
