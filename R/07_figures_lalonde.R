# =====================================================================
# 07_figures_lalonde.R -- figures for the LaLonde overlap teaching moment.
#   Supplementary Figure S3: propensity-score overlap (treated vs control), CPS
#             and PSID.
#   Figure 1 (main paper): vanilla TMLE estimate +/- 95% CI vs propensity-truncation bound,
#             against the randomized benchmark -- the coverage flip.
# Reads saved results only; fits nothing. Inputs:
#   output/lalonde_overlap.rds    written by 06_lalonde_overlap.R; holds the
#                                 per-unit propensity scores Figure S3 draws, so it
#                                 is NOT committed (needs the data and fitting)
#   output/lalonde_estimates.rds  aggregate only, committed; enough for Figure 1
# When the per-unit file is absent (a clone), or when the caller sets
# SAVED_ONLY <- TRUE (run_saved.R does, so that it uses committed files only),
# Figure S3 is skipped with a message and Figure 1 is drawn from
# lalonde_estimates.rds. Both files carry the same truncation sweep.
# PDFs are written with cairo_pdf so that every font is embedded (subset) and
# hyphens stay hyphens in the text layer. (The committed Figure S3 predates this:
# it was drawn with the default pdf device, which did not embed Helvetica, and
# can be redrawn only from the unshipped per-unit file, so the vector PDF was
# re-rendered with poppler's pdftocairo to embed the font; see README.)
# =====================================================================
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
resdir <- "output"
imgdir <- "images"
dir.create(imgdir, recursive = TRUE, showWarnings = FALSE)
saved_only   <- isTRUE(get0("SAVED_ONLY", ifnotfound = FALSE))
per_unit     <- file.path(resdir, "lalonde_overlap.rds")
agg_file     <- file.path(resdir, "lalonde_estimates.rds")
use_per_unit <- !saved_only && file.exists(per_unit)
if (use_per_unit) {
  L <- readRDS(per_unit)
} else {
  if (!file.exists(agg_file)) stop(agg_file, " not found; it is committed to the repository")
  L <- readRDS(agg_file)
}
bench <- L$benchmark_emp

# ---- Supplementary Figure S3: overlap (needs the per-unit propensity scores) ----
if (!use_per_unit) {
  cat("Supplementary Figure S3 (lalonde_overlap.pdf) skipped: it draws per-unit propensity scores,\n",
      "which are not shipped; R/06_lalonde_overlap.R (benchmark data + model fitting) produces them.\n",
      sep = "")
} else {
ps <- L$ps
ps$grp <- ifelse(ps$treated == 1, "Treated (NSW)", "Control (observational)")
pA <- ggplot(ps, aes(x = g, colour = grp, linetype = grp)) +
  geom_histogram(aes(y = after_stat(density)), bins = 40, fill = NA,
                 position = "identity", linewidth = 0.45) +
  facet_wrap(~ control, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c("Treated (NSW)" = "#D55E00",
                                 "Control (observational)" = "#0072B2"), name = NULL) +
  scale_linetype_manual(values = c("Treated (NSW)" = "solid",
                                   "Control (observational)" = "21"), name = NULL) +
  # no in-image title: the manuscript caption carries the message
  labs(x = "Estimated propensity score  P(treated | covariates)", y = "Density",
       title = NULL, subtitle = NULL) +
  theme_bw(base_size = 11) + theme(legend.position = "top")
# exported at its printed width (the supplement text width) so lettering prints at 8.8 pt or more
ggsave(file.path(imgdir, "lalonde_overlap.pdf"), pA, width = 6.5, height = 4.5, device = cairo_pdf)
cat("wrote lalonde_overlap.pdf\n")
}

# ---- Figure 1 (main paper): truncation sensitivity vs benchmark (aggregate inputs only) ----
cat("Figure 1 from", if (use_per_unit) per_unit else agg_file, "\n")
tr <- L$trunc
tr$xlab <- factor(sprintf("%.3f", tr$gbound), levels = sprintf("%.3f", sort(tr$gbound)))
pB <- ggplot(tr, aes(x = xlab, y = rd)) +
  geom_hline(yintercept = bench, linetype = "dashed", colour = "grey55") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2) +
  geom_point(aes(colour = covers, shape = covers), size = 3) +
  scale_colour_manual(values = c(`TRUE` = "#009E73", `FALSE` = "#999999"),
                      labels = c(`FALSE` = "interval misses benchmark", `TRUE` = "interval reaches benchmark"),
                      name = NULL) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 4),
                     labels = c(`FALSE` = "interval misses benchmark", `TRUE` = "interval reaches benchmark"),
                     name = NULL) +
  # no in-image title: the manuscript caption carries the message (the benchmark is
  # the NSW-enrollee effect, not this estimand's truth, so the image draws no "bias" claim)
  labs(x = "Propensity-score truncation bound",
       y = "Estimated ATE (risk difference)",
       title = NULL, subtitle = NULL) +
  theme_bw(base_size = 11) + theme(legend.position = "top")
# exported at its printed width (5.0 in) so lettering prints at 8.8 pt or more
ggsave(file.path(imgdir, "lalonde_truncation.pdf"), pB, width = 5.0, height = 3.3, device = cairo_pdf)
cat("wrote lalonde_truncation.pdf\n")
