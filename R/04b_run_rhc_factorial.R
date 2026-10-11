# =====================================================================
# 04b_run_rhc_factorial.R -- the FULL 14-arm design-space factorial on RHC
# (the R=10 basic run saves 13 rows: every CF-GCOMP repetition is discarded,
# see applied_tables.R),
# aligned to the master taxonomy (REVIEW/VARIANT_TAXONOMY.md, section 7.1).
# Every arm is stabilised over R repetitions with median aggregation so the
# arms are comparable; no-split arms use R=1 (nothing to repeat).
# The folk flag marks the three mirror cells (CVQ-TMLE-fold, CV-TMLE-fold,
# DC-TMLE-pool) and is saved as set here. Only CVQ-TMLE-fold and DC-TMLE-pool
# are unattested: CV-TMLE-fold corresponds in design to the CVTMLE[all] of
# Smith et al. (2025), so the display code (05_figures_rhc.R, applied_tables.R)
# draws it as attested.
#
# Usage: Rscript 04b_run_rhc_factorial.R [R] [sl_profile] [out_rds]
#
# The paper uses two runs (run_all.R steps 2a-2b; Supplementary Figures S1-S2,
# Table S10):
#   Rscript R/04b_run_rhc_factorial.R 10 fast  -> output/rhc_factorial_fast.rds
#       basic library, SL.glm + SL.mean; split arms median-aggregated over R=10
#   Rscript R/04b_run_rhc_factorial.R 1 rf     -> output/rhc_factorial_rf.rds
#       extended library, SL.glm + SL.mean + SL.ranger; every arm R=1
# The "rich" profile (adds SL.earth) is available but was not used in the paper.
# =====================================================================
here <- "R"
source(file.path(here, "01_engine.R"))
source(file.path(here, "02_variants.R"))
suppressPackageStartupMessages({ library(dplyr) })

args <- commandArgs(trailingOnly = TRUE)
R_reps     <- if (length(args) >= 1) as.integer(args[1]) else 10L
sl_profile <- if (length(args) >= 2) args[2] else "fast"
out_rds    <- if (length(args) >= 3) args[3] else
  sprintf("output/rhc_factorial_%s.rds", sl_profile)

obj <- readRDS("data/rhc_analysis.rds")
d <- obj$data; covs <- obj$covariates
mm <- model.matrix(~ ., data = d[, covs, drop = FALSE])[, -1, drop = FALSE]
W <- as.data.frame(mm); names(W) <- make.names(names(W))
Y <- d$Y; A <- d$A

sl_lib <- switch(sl_profile,
  rich = c("SL.glm", "SL.mean", "SL.earth", "SL.ranger"),
  rf   = c("SL.glm", "SL.mean", "SL.ranger"),
  c("SL.glm", "SL.mean"))
cat(sprintf("RHC factorial: n=%d, %d covariates, SL=%s, R=%d\n",
            length(Y), ncol(W), paste(sl_lib, collapse="+"), R_reps))

# taxonomy arm catalogue: label, spec, whether it splits (R>1), folk (mirror cell; see header)
A1 <- function(label, spec, splits=TRUE, folk=FALSE)
  list(label=label, spec=spec, splits=splits, folk=folk)

catalogue <- list(
  A1("GCOMP",        list(scheme="none", target="plugin"),                          splits=FALSE),
  A1("AIPW",         list(scheme="none", target="onestep")),  # AIPW no-split (R=1)
  A1("TMLE",         list(scheme="none", target="pooled"),                          splits=FALSE),
  A1("SS-TMLE",      list(scheme="ss2",  target="pooled")),
  A1("CVQ-TMLE",     list(scheme="cv", V=5, qonly=TRUE, target="pooled")),
  A1("CVQ-TMLE-fold",list(scheme="cv", V=5, qonly=TRUE, target="foldwise", agg_fold=TRUE), folk=TRUE),
  A1("CF-GCOMP",     list(scheme="cv", V=5, qonly=TRUE, target="plugin")),
  A1("CV-TMLE",      list(scheme="cv", V=5, target="pooled",  agg_fold=FALSE)),
  A1("CV-TMLE-fold", list(scheme="cv", V=5, target="foldwise", agg_fold=TRUE), folk=TRUE),
  A1("CF-AIPW",      list(scheme="cv", V=5, target="onestep",  agg_fold=FALSE)),
  A1("SCTMLE",       list(scheme="cf2", target="foldwise", agg_fold=TRUE)),
  A1("DC-TMLE-pool", list(scheme="cf3", target="pooled",  agg_fold=FALSE), folk=TRUE),
  A1("DCTMLE",       list(scheme="cf3", target="foldwise", agg_fold=TRUE)),
  A1("DC-AIPW",      list(scheme="cf3", target="onestep",  agg_fold=TRUE))
)
# fix AIPW/no-split flags
catalogue[[2]]$splits <- FALSE

rows <- list()
for (item in catalogue) {
  lab <- item$label; t0 <- Sys.time(); set.seed(2026)
  R_use <- if (isTRUE(item$splits)) R_reps else 1L
  res <- tryCatch({
    if (R_use > 1L) {
      rr <- run_repeated(Y, A, W, item$spec, sl_lib, sl_lib,
                         R = R_use, rule = "median", inner_V = 5L, seed = 2026)
      out <- rr$aggregated
      # SE: between-split-corrected if targeting present, else within
      se <- if (identical(item$spec$target, "plugin")) NA_real_ else sqrt(out$mvd)
      list(rd = out$rd, se = se)
    } else {
      out <- run_once(Y, A, W, item$spec, sl_lib, sl_lib, inner_V = 5L)
      se <- if (identical(item$spec$target, "plugin")) NA_real_ else sqrt(out$vd)
      list(rd = out$rd, se = se)
    }
  }, error = function(e) { cat("  ", lab, "ERROR:", conditionMessage(e), "\n"); list(rd=NA, se=NA) })
  dt <- as.numeric(difftime(Sys.time(), t0, units="secs"))
  rows[[lab]] <- dplyr::tibble(
    order = length(rows) + 1L, method = lab, rd = res$rd, se = res$se,
    ci_lo = res$rd - 1.96*res$se, ci_hi = res$rd + 1.96*res$se,
    folk = item$folk, splits = item$splits, R = R_use, runtime_s = dt)
  cat(sprintf("  %-14s rd=% .4f  se=%s  [%.0f s]\n", lab, res$rd,
              ifelse(is.na(res$se), "  NA  ", sprintf("%.4f", res$se)), dt))
}
tab <- dplyr::bind_rows(rows)
# Label the library from what was actually fitted (sl_lib), not from the profile
# name: the old rule labelled every profile except "rich" as Basic, so the
# extended "rf" run's saved label read "Basic (GLM+mean)" although it fitted
# SL.ranger (that saved file is kept as run; applied_tables.R reports its sl_lib).
tab$library <- if (identical(sl_lib, c("SL.glm", "SL.mean"))) "Basic (GLM+mean)" else
  sprintf("Extended (%s)", paste(sl_lib, collapse = "+"))

dir.create(dirname(out_rds), recursive=TRUE, showWarnings=FALSE)
saveRDS(list(table=tab, sl_lib=sl_lib, R=R_reps, n=length(Y)), out_rds)
write.csv(tab, sub("\\.rds$", ".csv", out_rds), row.names=FALSE)
cat("Wrote", out_rds, "\n")
