# =====================================================================
# dgm.R -- R adaptation of the Zivich & Breskin (2021) statin data-generating
# mechanism (Python original: dgm.py, zepid trapezoidal, numpy seed
# 1015033030; the upstream file comments a truth of -0.1081508).
#
# THIRD-PARTY MATERIAL, ADAPTED. Source: DoubleCrossFit/Python/dgm.py in
# pzivich/publications-code, release v2026.07.20, creator Paul Zivich,
# https://doi.org/10.5281/zenodo.21456065 -- its record declares CC BY 4.0
# (https://creativecommons.org/licenses/by/4.0/), provided as-is without
# warranties. This file MODIFIES that source: Python -> base R; zepid's
# trapezoidal sampler -> rtrapezoid(); one dataset per generate_statin() call
# instead of a CSV of all datasets; risk_score_cat category 3 inclusive at 0.2
# (as in the published eAppendix); new statin_sharp and return_potential
# arguments; new true_ate_statin(); the module-level seed and simulation-size
# settings removed (the caller sets the seed and n); the upstream seed value,
# 1015033030, reused as the default seed of true_ate_statin(); and, run
# directly, the file prints the truth instead of writing a CSV. Upstream
# material stays under CC BY 4.0; the authors' modifications are MIT. Full
# notice: THIRD_PARTY_NOTICES.md.
#
# Written so the simulation runs WITHOUT the Python/zepid stack. The DGM
# covariates and the true ATE are documented in the manuscript (Simulation
# Design) and in output/TRUTHS_PROVENANCE.md.
#
# NOTE on frailty (red-team F8): frailty is generated but influences BOTH
# treatment and outcome ONLY through risk_score (the 0.01*frailty term below),
# and risk_score IS in the analysis adjustment set. Conditioning on risk_score
# therefore blocks every frailty path, so frailty is NOT unmeasured confounding
# and identification is clean. The nuisance challenge it creates is
# outcome-surface COMPLEXITY, not confounding -- describe it that way in the
# paper (do not claim an unmeasured confounder).
#
# Adjustment set used by the estimators: age, ldl_log, diabetes, risk_score
#   (continuous risk_score; the categorical risk_score_cat drives treatment
#    assignment and is a deterministic function of risk_score).
# =====================================================================

# --- trapezoidal(a, b, c, d): rises a->b, flat b->c, falls c->d ---
# Matches zepid.sensitivity_analysis.trapezoidal (inverse-CDF sampler).
rtrapezoid <- function(n, a, b, c, d) {
  stopifnot(a <= b, b <= c, c <= d)
  u <- runif(n)
  # normalising constant: total area = 0.5*(d + c - a - b)
  # piecewise areas
  A_rise <- 0.5 * (b - a)            # area of rising triangle at height 1
  A_flat <- (c - b)                  # flat part at height 1
  A_fall <- 0.5 * (d - c)            # falling triangle at height 1
  tot <- A_rise + A_flat + A_fall
  p_rise <- A_rise / tot
  p_flat <- A_flat / tot
  # VECTORIZED inverse-CDF (output-identical to the original per-element loop:
  # same u draws, same branch logic/formulas -- a performance-only refactor for
  # the ARC package so truth-pinning at >=1e8 draws is feasible; verified equal).
  x <- numeric(n)
  i1 <- u < p_rise
  i2 <- !i1 & (u < p_rise + p_flat)
  i3 <- !i1 & !i2
  x[i1] <- a + sqrt(u[i1] / p_rise) * (b - a)
  x[i2] <- b + (u[i2] - p_rise) / p_flat * (c - b)
  if (any(i3)) {
    ur <- (u[i3] - p_rise - p_flat) / (1 - p_rise - p_flat)
    x[i3] <- d - sqrt(1 - ur) * (d - c)
  }
  x
}

# --- one simulated dataset of size n (observed columns only) ---
# statin_sharp SCALES the covariate part of the treatment model's linear
# predictor. statin_sharp = 1 is the ORIGINAL Zivich-Breskin DGM (D1, benign
# overlap). statin_sharp > 1 spreads the propensity toward 0/1 -> the D2
# NEAR-POSITIVITY regime. Crucially the true ATE = E[prY1 - prY0] depends ONLY
# on the covariate + outcome models (unchanged here), so D2 shares D1's truth
# (canonical -0.1081358, output/TRUTHS_PROVENANCE.md; the upstream comment
# gives -0.1081508); only overlap degrades. See dgm_variants.R.
generate_statin <- function(n, return_potential = FALSE, statin_sharp = 1) {
  age <- round(rtrapezoid(n, 40, 40, 60, 75), 0)
  ldl_log <- 0.005 * age + rnorm(n, log(100), 0.18)
  diabetes <- rbinom(n, 1, plogis(-4.23 + 0.03 * ldl_log - 0.02 * age +
                                    0.0009 * age^2))
  frailty <- plogis(-5.5 + 0.05 * (age - 20) + 0.001 * age^2 + rnorm(n))
  age_ln <- log(age)
  risk_score <- plogis(4.299 + 3.501 * diabetes - 2.07 * age_ln +
                         0.051 * age_ln^2 + 4.090 * ldl_log -
                         1.04 * age_ln * ldl_log + 0.01 * frailty)
  risk_score_cat <- ifelse(risk_score < 0.05, 0,
                    ifelse(risk_score < 0.075, 1,
                    ifelse(risk_score < 0.2, 2, 3)))

  statin_cov <- 1.390 * diabetes +
                0.112 * ldl_log +
                0.973 * (ldl_log > log(160)) -
                0.046 * (age - 30) +
                0.003 * (age - 30)^2 +
                0.273 * (risk_score_cat == 1) +
                1.592 * (risk_score_cat == 2) +
                2.641 * (risk_score_cat == 3)
  statin_pr <- plogis(-3.471 + statin_sharp * statin_cov)   # sharp=1 => original D1
  statin <- rbinom(n, 1, statin_pr)

  prY1 <- plogis(-6.25 - 0.75 +
                   0.35 * ifelse(ldl_log < log(130), 5 - ldl_log, 0) +
                   0.45 * sqrt(age - 39) +
                   1.75 * diabetes +
                   0.29 * exp(risk_score + 1) +
                   0.14 * ifelse(ldl_log > log(120), ldl_log^2, 0))
  prY0 <- plogis(-6.25 +
                   0.45 * sqrt(age - 39) +
                   1.75 * diabetes +
                   0.29 * exp(risk_score + 1) +
                   0.14 * ifelse(ldl_log > log(120), ldl_log^2, 0))
  Y1 <- rbinom(n, 1, prY1)
  Y0 <- rbinom(n, 1, prY0)
  Y  <- ifelse(statin == 1, Y1, Y0)

  out <- data.frame(Y = Y, statin = statin, age = age, ldl_log = ldl_log,
                    diabetes = diabetes, risk_score = risk_score,
                    risk_score_cat = risk_score_cat)
  if (return_potential) { out$prY1 <- prY1; out$prY0 <- prY0; out$Y1 <- Y1; out$Y0 <- Y0
                          out$g_true <- statin_pr }
  out
}

# --- true ATE: analytic mean of prY1 - prY0 over a very large draw ---
true_ate_statin <- function(n = 4e6, seed = 1015033030) {
  set.seed(seed)
  d <- generate_statin(n, return_potential = TRUE)
  mean(d$prY1 - d$prY0)
}

# If run directly, report the truth.
if (sys.nframe() == 0) {
  cat("Estimating true ATE (risk difference) for the statin DGM...\n")
  truth <- true_ate_statin(4e6)
  cat(sprintf("  analytic-mean-of-potential-risks ATE = %.6f\n", truth))
  cat("  (the upstream dgm.py comments -0.1081508; canonical truth: output/TRUTHS_PROVENANCE.md)\n")
}
