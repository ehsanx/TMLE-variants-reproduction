# =====================================================================
# learners.R -- SuperLearner libraries for COMPASS + non-Donsker diagnostics.
#
# Two profiles, deliberately clean for the "Donsker vs non-Donsker" contrast:
#   sl_donsker     : glm + gam + mean -- parametric/smooth-additive, a genuine
#                    Donsker (finite-entropy) class that stays calibrated.
#   sl_ranger_pure : a SINGLE random forest, so its SuperLearner weight is 1 by
#                    construction. A null RF result then cannot be dismissed as
#                    "ranger was downweighted to ~0 inside a convex ensemble."
#                    min.node.size is PINNED (report sensitivity in the pilot);
#                    a small leaf size makes the forest rough enough to overfit
#                    IN-SAMPLE -- the mechanism that breaks in-sample inference
#                    when nuisances are not cross-fit.
# =====================================================================
suppressPackageStartupMessages({ library(SuperLearner) })

# ---- Donsker (smooth) profile ----
sl_donsker <- c("SL.glm", "SL.gam", "SL.mean")

# ---- pure non-Donsker profile (single learner, weight = 1) ----
# Pinned: num.trees = 500, min.node.size = 5, probability forest for binary Y.
SL.ranger.rough <- function(..., num.trees = 500, min.node.size = 5, probability = TRUE, num.threads = 1)
  SL.ranger(..., num.trees = num.trees, min.node.size = min.node.size,
            probability = probability, num.threads = num.threads)
environment(SL.ranger.rough) <- asNamespace("SuperLearner")
sl_ranger_pure <- c("SL.ranger.rough")

# ---------------------------------------------------------------------
# Diagnostics for the non-Donsker premise (logged in the pilot / sim).
# ---------------------------------------------------------------------
# residual mean-square of a fitted outcome model on a set of rows. Comparing
# the IN-SAMPLE value (no-split fit, predicted on its own training rows) to the
# OUT-OF-FOLD value (cross-fit) quantifies in-sample optimism: in-sample << oof
# means the forest memorized its training rows (the coverage-breaking mechanism).
resid_mse <- function(Y, QA) mean((Y - QA)^2, na.rm = TRUE)

# mean residual (calibration) -- the raw "mean(Y - QA)" the design names.
mean_resid <- function(Y, QA) mean(Y - QA, na.rm = TRUE)

# realized SuperLearner weight on a named learner (verify pure-ranger == 1).
# Returns the coef vector of a SuperLearner fit (for logging), NA if unavailable.
sl_weights <- function(sl_fit) {
  if (!is.null(sl_fit$coef)) sl_fit$coef else NA
}
