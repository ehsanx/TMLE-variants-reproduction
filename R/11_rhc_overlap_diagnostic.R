#!/usr/bin/env Rscript
# =====================================================================
# 11_rhc_overlap_diagnostic.R -- RHC overlap diagnostic quoted in the paper's
# applied section: a logistic propensity fit on the adjustment set, summarized.
# Needs data/rhc_analysis.rds (00_prepare_rhc.R) and fits a model; run_all.R
# step 6. Writes output/rhc_overlap_diag.rds: counts, quantiles, shares, and the
# minimum and maximum fitted propensity overall and within each arm (summary
# statistics; output/APPLIED_PROVENANCE.md, Unit-level content).
# =====================================================================

obj  <- readRDS("data/rhc_analysis.rds")
d    <- obj$data
covs <- obj$covariates
stopifnot(all(c("A") %in% names(d)))

fml <- stats::reformulate(covs, response = "A")
g_fit <- stats::glm(fml, family = stats::binomial(), data = d)
g <- stats::fitted(g_fit)

n   <- length(g)
tr  <- d$A == 1
gb  <- 0.025

frac <- function(cond) mean(cond)
diag <- list(
  n              = n,
  n_treated      = sum(tr),
  prev_treated   = mean(tr),
  g_min          = min(g),
  g_max          = max(g),
  g_q            = stats::quantile(g, c(.01,.05,.25,.5,.75,.95,.99)),
  frac_lt_0.025  = frac(g < 0.025),
  frac_gt_0.975  = frac(g > 0.975),
  frac_lt_0.01   = frac(g < 0.01),
  frac_gt_0.99   = frac(g > 0.99),
  frac_trunc_025 = frac(g < gb | g > (1 - gb)),

  g_min_treated  = min(g[tr]),  g_max_treated  = max(g[tr]),
  g_min_control  = min(g[!tr]), g_max_control  = max(g[!tr])
)

cat("=====================================================\n")
cat(" RHC overlap diagnostic (logistic propensity, Connors set)\n")
cat("=====================================================\n")
cat(sprintf("n = %d,  treated = %d (%.1f%%)\n", diag$n, diag$n_treated, 100*diag$prev_treated))
cat(sprintf("estimated g = P(RHC | W):  range [%.3f, %.3f]\n", diag$g_min, diag$g_max))
cat("quantiles (1/5/25/50/75/95/99%):\n"); print(round(diag$g_q, 3))
cat(sprintf("fraction g < 0.025 : %.4f (%d obs)\n", diag$frac_lt_0.025, round(diag$frac_lt_0.025*n)))
cat(sprintf("fraction g > 0.975 : %.4f (%d obs)\n", diag$frac_gt_0.975, round(diag$frac_gt_0.975*n)))
cat(sprintf("fraction g < 0.01  : %.4f (%d obs)\n", diag$frac_lt_0.01,  round(diag$frac_lt_0.01*n)))
cat(sprintf("fraction g > 0.99  : %.4f (%d obs)\n", diag$frac_gt_0.99,  round(diag$frac_gt_0.99*n)))
cat(sprintf("=> fraction truncated at [0.025,0.975]: %.4f (%d obs)\n",
            diag$frac_trunc_025, round(diag$frac_trunc_025*n)))
cat(sprintf("treated g in [%.3f, %.3f];  control g in [%.3f, %.3f]\n",
            diag$g_min_treated, diag$g_max_treated, diag$g_min_control, diag$g_max_control))

saveRDS(diag, "output/rhc_overlap_diag.rds")
cat("\n[written] output/rhc_overlap_diag.rds\n")
