# =====================================================================
# 01_engine.R  -- shared machinery for all TMLE / cross-fit variants
#
# Design principle: every estimator in this tutorial targets the SAME
# efficient influence function (EIF) for the ATE (risk difference) on a
# binary outcome. The estimators differ ONLY along these five design
# dimensions (the paper's Table 1):
#
#   (1) SPLITTING     : none | K-fold CV | 2-way cross-fit | 3-way cross-fit
#   (2) NUISANCE FIT  : where g (propensity) and Q (outcome) are fit for
#                       each observation (in-sample vs out-of-fold)
#   (3) BIAS CORRECTION: AIPW one-step (no targeting) | pooled TMLE epsilon |
#                       fold-specific TMLE epsilon
#   (4) REPETITION    : R repeated random splits
#   (5) AGGREGATION   : how R repeats are combined (point + variance rule)
#
# This file provides the reusable pieces. Named estimators live in
# 02_variants.R and are thin wrappers that select options here.
#
# Notation (matches Zivich & Breskin reference code where possible):
#   g(W) = P(A=1|W)   propensity
#   Q_a(W) = E[Y|A=a,W]  outcome regression, a in {0,1}
#   psi = E[Q_1(W) - Q_0(W)]  ATE risk difference
#   EIF: D(O) = A/g (Y - Q1) - (1-A)/(1-g) (Y - Q0) + Q1 - Q0 - psi
# =====================================================================

suppressPackageStartupMessages({
  library(SuperLearner)
  library(dplyr)
})

# ---------------------------------------------------------------------
# Bounding helpers
# ---------------------------------------------------------------------
.bound_g <- function(g, gbound = 0.025) {
  pmin(pmax(g, gbound), 1 - gbound)
}
.bound_Q <- function(q, qbound = 1e-8) {
  # keep strictly inside (0,1) so qlogis() is finite
  pmin(pmax(q, qbound), 1 - qbound)
}

# ---------------------------------------------------------------------
# Shared fold construction. Every variant that splits uses THIS, so any
# performance gap is estimator-driven, not fold-scheme-driven.
#   scheme "cv"  : V folds, standard cross-validation partition
#   scheme "cf2" : 2 folds (single cross-fit)
#   scheme "cf3" : 3 folds (double cross-fit)
# Returns an integer vector of fold ids of length n.
# ---------------------------------------------------------------------
make_folds <- function(n, V) {
  sample(rep(seq_len(V), length.out = n))
}

# ---------------------------------------------------------------------
# Fit a SuperLearner and return a predictor closure. Centralises the
# cvControl so EVERY nuisance fit uses the same inner CV (default V=5),
# matching the manuscript's "5-fold within SL" claim.
# ---------------------------------------------------------------------
fit_sl <- function(Y, X, family, sl_lib, inner_V = 5L) {
  fit <- SuperLearner::SuperLearner(
    Y = Y, X = X, family = family, SL.library = sl_lib,
    cvControl = SuperLearner::SuperLearner.CV.control(V = inner_V)
  )
  function(newX) {
    p <- predict(fit, newdata = newX, onlySL = TRUE)$pred
    as.numeric(p)
  }
}

# Design matrices: Q needs A in the design; g does not.
.Qdesign <- function(A, W) cbind(A = A, W)

# ---------------------------------------------------------------------
# NUISANCE ESTIMATION under a chosen splitting scheme.
#
# Returns a data frame with, for every observation i:
#   g   = \hat g(W_i)           (propensity)
#   Q1  = \hat Q_1(W_i)         (outcome pred under A=1)
#   Q0  = \hat Q_0(W_i)         (outcome pred under A=0)
#   QA  = \hat Q_{A_i}(W_i)     (outcome pred at observed A)
#   fold= fold id (targeting fold), or 0 for the no-split case
#
# scheme:
#   "none": fit g,Q on the full sample; predictions are in-sample (vanilla).
#   "cf2" : 2-way cross-fit. Fold-k obs get g,Q fitted on the OTHER fold.
#           (Q-only cross-fit if qonly_gfull=TRUE: g fit on full sample.)
#   "cf3" : 3-way cross-fit with the Newey/Zivich rotation: for targeting
#           fold k, g comes from one other fold and Q from a THIRD fold, so
#           g and Q never share training data with each other or with k.
#   "cv"  : V-fold. Fold-k obs get g,Q fitted on the other V-1 folds
#           (pooled, so it matches CV-TMLE's out-of-fold nuisances).
#
# All predictions are computed for A=0 and A=1 so downstream targeting and
# the EIF can use counterfactual outcome predictions.
# ---------------------------------------------------------------------
estimate_nuisances <- function(Y, A, W, folds, scheme,
                               sl_g, sl_Q, inner_V = 5L,
                               qonly_gfull = FALSE) {
  n <- length(Y)
  famQ <- stats::binomial()
  famg <- stats::binomial()
  g <- Q1 <- Q0 <- rep(NA_real_, n)

  W1 <- W; # design with A=1 / A=0
  Qd_all1 <- .Qdesign(rep(1, n), W)
  Qd_all0 <- .Qdesign(rep(0, n), W)

  if (scheme == "none") {
    gpred <- fit_sl(A, W, famg, sl_g, inner_V)
    Qpred <- fit_sl(Y, .Qdesign(A, W), famQ, sl_Q, inner_V)
    g  <- gpred(W)
    Q1 <- Qpred(Qd_all1)
    Q0 <- Qpred(Qd_all0)
    fold <- rep(0L, n)

  } else if (scheme %in% c("cf2", "cv")) {
    # out-of-fold nuisances: for each fold k, train on all OTHER folds
    Vv <- sort(unique(folds))
    # optional full-sample g for Q-only cross-fit
    gpred_full <- if (qonly_gfull) fit_sl(A, W, famg, sl_g, inner_V) else NULL
    for (k in Vv) {
      tr <- folds != k
      te <- folds == k
      Qpred <- fit_sl(Y[tr], .Qdesign(A[tr], W[tr, , drop = FALSE]),
                      famQ, sl_Q, inner_V)
      Q1[te] <- Qpred(Qd_all1[te, , drop = FALSE])
      Q0[te] <- Qpred(Qd_all0[te, , drop = FALSE])
      if (qonly_gfull) {
        g[te] <- gpred_full(W[te, , drop = FALSE])
      } else {
        gpred <- fit_sl(A[tr], W[tr, , drop = FALSE], famg, sl_g, inner_V)
        g[te] <- gpred(W[te, , drop = FALSE])
      }
    }
    fold <- as.integer(folds)

  } else if (scheme == "cf3") {
    # 3-way double cross-fit rotation (Newey & Robins 2018; Zivich & Breskin
    # 2021). For targeting fold s, propensity from fit on fold pi_src[s] and
    # outcome from fit on fold mu_src[s]; the three fold indices are distinct.
    stopifnot(length(unique(folds)) == 3)
    # Fit g and Q separately on EACH fold
    gfits <- vector("list", 3); Qfits <- vector("list", 3)
    for (j in 1:3) {
      idx <- folds == j
      gfits[[j]] <- fit_sl(A[idx], W[idx, , drop = FALSE], famg, sl_g, inner_V)
      Qfits[[j]] <- fit_sl(Y[idx], .Qdesign(A[idx], W[idx, , drop = FALSE]),
                           famQ, sl_Q, inner_V)
    }
    # rotation: targeting fold 1 uses g from 2, Q from 3; 2 uses g3,Q1; 3 uses g1,Q2
    pi_src <- c(`1` = 2, `2` = 3, `3` = 1)
    mu_src <- c(`1` = 3, `2` = 1, `3` = 2)
    for (s in 1:3) {
      te <- folds == s
      g[te]  <- gfits[[ pi_src[[as.character(s)]] ]](W[te, , drop = FALSE])
      Q1[te] <- Qfits[[ mu_src[[as.character(s)]] ]](Qd_all1[te, , drop = FALSE])
      Q0[te] <- Qfits[[ mu_src[[as.character(s)]] ]](Qd_all0[te, , drop = FALSE])
    }
    fold <- as.integer(folds)
  } else {
    stop("unknown scheme: ", scheme)
  }

  QA <- ifelse(A == 1, Q1, Q0)
  data.frame(g = g, Q1 = Q1, Q0 = Q0, QA = QA, fold = fold)
}

# ---------------------------------------------------------------------
# EIF for the ATE and its variance, given (possibly targeted) Q's and g.
#   D_i = A/g (Y-Q1) - (1-A)/(1-g)(Y-Q0) + (Q1-Q0) - psi
#   Var(psihat) = var(D)/n
# For split estimators the influence function is evaluated with the
# out-of-fold / targeted nuisances passed in.
# ---------------------------------------------------------------------
eif_ate <- function(Y, A, g, Q1, Q0, psi) {
  A/g * (Y - Q1) - (1 - A)/(1 - g) * (Y - Q0) + (Q1 - Q0) - psi
}

# component EIFs for the treatment-specific means (for r1, r0 variances)
eif_mean <- function(Y, A, g, Qa, ra, a) {
  if (a == 1) A/g * (Y - Qa) + Qa - ra
  else        (1 - A)/(1 - g) * (Y - Qa) + Qa - ra
}
