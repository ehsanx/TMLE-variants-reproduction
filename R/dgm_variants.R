# =====================================================================
# dgm_variants.R -- COMPASS stress DGMs beyond the benign statin surface (D1).
#
#   D2 (near-positivity) : generate_statin(..., statin_sharp > 1) in dgm.R.
#                          Shares D1's truth (-0.1081508); only overlap degrades.
#   D3 (rough surface)   : generate_rough() below -- the FALLBACK for the
#                          non-Donsker premise if a random forest fails to break
#                          in-sample coverage on the smooth p=4 statin surface
#                          (red-team RF-26/27). The outcome surface here is
#                          genuinely non-smooth (thresholds, interactions,
#                          high-frequency terms) so a glm/gam (Donsker) learner
#                          is MISSPECIFIED and a forest is genuinely needed --
#                          and overfits in-sample. Overlap is MODERATE by design
#                          so roughness is isolated from positivity.
# =====================================================================

# --- D3: rough-surface binary-outcome DGM (moderate overlap) ---
# p = 8 covariates; treatment is smooth/moderate-overlap; the OUTCOME logit is
# rough. Constant treatment effect on the logit scale (clean, well-defined ATE
# on the risk-difference scale = E[prY1 - prY0]).
generate_rough <- function(n, tau_lp = 0.6, return_potential = FALSE) {
  X <- matrix(rnorm(n * 8), n, 8)
  colnames(X) <- paste0("X", 1:8)
  x1 <- X[,1]; x2 <- X[,2]; x3 <- X[,3]; x4 <- X[,4]
  x5 <- X[,5]; x6 <- X[,6]; x7 <- X[,7]; x8 <- X[,8]

  # --- treatment: smooth, MODERATE overlap (this is NOT the stressor) ---
  glp <- 0.30 * x1 - 0.40 * x2 + 0.30 * x3 * x4
  g   <- plogis(glp)
  A   <- rbinom(n, 1, g)

  # --- outcome: ROUGH logit surface (thresholds + interactions + high-freq) ---
  rough <- 0.90 * (x1 > 0.5) - 0.80 * (x2 < -0.5) +
           1.10 * x1 * x3 - 0.90 * x2 * x4 +
           0.80 * sin(3 * x5) + 0.70 * (x6 > 0) * (x7 > 0) +
           0.60 * abs(x8) - 0.50 * (x3 > 1) * x1
  lp0  <- -0.30 + rough
  prY0 <- plogis(lp0)
  prY1 <- plogis(lp0 + tau_lp)            # constant logit shift -> clean ATE
  Y1 <- rbinom(n, 1, prY1); Y0 <- rbinom(n, 1, prY0)
  Y  <- ifelse(A == 1, Y1, Y0)

  out <- data.frame(Y = Y, A = A, X)
  if (return_potential) { out$prY1 <- prY1; out$prY0 <- prY0
                          out$Y1 <- Y1; out$Y0 <- Y0; out$g_true <- g }
  out
}

# --- true ATE for D3 (vectorized -> can go to large n cheaply) ---
# Computed in chunks so 1e8 draws do not exhaust memory.
true_ate_rough <- function(n = 2e7, tau_lp = 0.6, seed = 20260806, chunk = 2e6) {
  set.seed(seed)
  tot <- 0; done <- 0
  while (done < n) {
    m <- min(chunk, n - done)
    d <- generate_rough(m, tau_lp = tau_lp, return_potential = TRUE)
    tot <- tot + sum(d$prY1 - d$prY0)
    done <- done + m
  }
  tot / n
}

if (sys.nframe() == 0) {
  cat("Estimating true ATE (risk difference) for the D3 rough DGM...\n")
  truth <- true_ate_rough(2e7)
  cat(sprintf("  D3 rough-surface ATE = %.6f\n", truth))
}
