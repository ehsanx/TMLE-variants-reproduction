# =====================================================================
# 05_figures_rhc.R -- figures for the applied RHC comparison, built from
# the saved design-space factorial (04b_run_rhc_factorial.R). Reads saved
# results only and fits nothing, so it runs from a clone (run_saved.R):
#   Supplementary Figure S1: forest plot of ATE (risk difference) +/- 95% CI,
#             by estimator, basic SL library. GCOMP has no CI.
#   Supplementary Figure S2: model-based SE by estimator, basic vs extended
#             library.
# Inputs, both committed (output/APPLIED_PROVENANCE.md) and rewritten by a
# fresh run_all.R:
#   output/rhc_factorial_fast.rds  04b ... 10 fast  basic, SL.glm + SL.mean, R=10
#   output/rhc_factorial_rf.rds    04b ... 1 rf     extended, + SL.ranger, R=1
# The "rich" profile (+ SL.earth) was not used in the paper and is not read.
# PDFs are written with cairo_pdf so that every font is embedded (subset) and
# hyphens stay hyphens in the text layer.
# =====================================================================
suppressPackageStartupMessages({ library(dplyr); library(ggplot2); library(tidyr) })

resdir <- "output"
imgdir <- "images"
dir.create(imgdir, recursive = TRUE, showWarnings = FALSE)

BASIC_LIB    <- c("SL.glm", "SL.mean")
EXTENDED_LIB <- c("SL.glm", "SL.mean", "SL.ranger")
# The library label comes from the saved sl_lib, never from the saved 'library'
# column, which reads "Basic" in the committed extended run (a since-fixed 04b bug).
read_fac <- function(f, lib) {
  if (!file.exists(f)) stop(f, " not found. It is committed to the repository; to refit it, ",
                            "run R/04b_run_rhc_factorial.R (see run_all.R, steps 2a-2b).")
  x <- readRDS(f)
  if (!identical(x$sl_lib, lib)) stop(f, " was fitted with ", paste(x$sl_lib, collapse = " + "),
                                      ", not the paper's ", paste(lib, collapse = " + "))
  t <- x$table
  # The saved folk flag also marks CV-TMLE-fold, which has a published design counterpart (the CVTMLE[all]
  # of Smith et al. 2025); only CVQ-TMLE-fold and DC-TMLE-pool are drawn as unattested cells.
  t$folk <- t$folk & t$method != "CV-TMLE-fold"
  t$library <- if (identical(lib, BASIC_LIB)) "Basic (GLM+mean)" else
    sprintf("Extended (%s)", paste(lib, collapse = "+"))
  t
}
fast <- read_fac(file.path(resdir, "rhc_factorial_fast.rds"), BASIC_LIB)
ext  <- read_fac(file.path(resdir, "rhc_factorial_rf.rds"),   EXTENDED_LIB)

# canonical order: simplest -> most elaborate
ord <- c("GCOMP","AIPW","TMLE","SS-TMLE","CVQ-TMLE","CVQ-TMLE-fold","CF-GCOMP",
         "CV-TMLE","CV-TMLE-fold","CF-AIPW","SCTMLE","DC-TMLE-pool","DCTMLE","DC-AIPW")
lab_fac <- function(m, folk) ifelse(folk, paste0(m, "\u2020"), m)  # dagger for unattested cells

f1 <- fast %>% dplyr::mutate(disp = lab_fac(method, folk))
f1$method <- factor(f1$method, levels = rev(ord))
f1$disp   <- factor(f1$disp, levels = rev(lab_fac(ord, ord %in% f1$method[f1$folk])))

# ---- Supplementary Figure S1: forest plot (basic library) ----
p1 <- ggplot(f1, aes(x = rd, y = method)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey55") +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.25, na.rm = TRUE,
                orientation = "y") +
  geom_point(aes(shape = folk), size = 2.5, na.rm = TRUE) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1),
                     labels = c("attested", "unattested cell"), name = NULL) +
  scale_y_discrete(labels = function(x) ifelse(x %in% ord[c(1,7)], paste0(x, " (no CI)"), x)) +
  # no in-image title: the manuscript caption carries the message
  labs(x = "ATE of RHC on 30-day mortality (risk difference)", y = NULL,
       title = NULL, subtitle = NULL) +
  theme_bw(base_size = 11) +
  theme(legend.position = "top", panel.grid.major.y = element_blank())
# exported at its printed width (5.6 in) so lettering prints at 8.8 pt or more
ggsave(file.path(imgdir, "rhc_forest.pdf"), p1, width = 5.6, height = 4.2, device = cairo_pdf)
cat("wrote rhc_forest.pdf\n")

# ---- Supplementary Figure S2: SE, basic vs extended library ----
# (the output file keeps its historical name, rhc_se_basic_vs_rich.pdf, because
# the manuscript includes it under that name; the extended series is the 'rf' run)
{
  ext_lab <- "Extended (+ random forest)"
  se_tab <- dplyr::bind_rows(
    fast %>% dplyr::transmute(method, se, library = "Basic (GLM + mean)"),
    ext  %>% dplyr::transmute(method, se, library = ext_lab)
  ) %>% dplyr::filter(!is.na(se))
  se_tab$method <- factor(se_tab$method, levels = rev(ord))
  okabe2 <- setNames(c("#0072B2", "#D55E00"), c("Basic (GLM + mean)", ext_lab))
  shp2   <- setNames(c(16, 17), c("Basic (GLM + mean)", ext_lab))
  p2 <- ggplot(se_tab, aes(x = se, y = method, colour = library, shape = library, group = method)) +
    geom_line(colour = "grey70") +
    geom_point(size = 2.6) +
    scale_colour_manual(values = okabe2, name = NULL) +
    scale_shape_manual(values = shp2, name = NULL) +
    labs(x = "Model-based standard error of the ATE", y = NULL,
         title = NULL, subtitle = NULL) +
    theme_bw(base_size = 11) +
    theme(legend.position = "top", panel.grid.major.y = element_blank())
  ggsave(file.path(imgdir, "rhc_se_basic_vs_rich.pdf"), p2, width = 5.6, height = 4.2, device = cairo_pdf)
  cat("wrote rhc_se_basic_vs_rich.pdf\n")
}

# ---- manuscript table ----
mk <- function(t) t %>% dplyr::transmute(
  Library = library, Method = as.character(method), folk,
  RD = round(rd, 4), SE = ifelse(is.na(se), NA, round(se, 4)),
  `95% CI` = ifelse(is.na(se), "--", sprintf("(%.3f, %.3f)", ci_lo, ci_hi)),
  `Runtime (s)` = round(runtime_s, 0))
out <- dplyr::bind_rows(mk(fast), mk(ext)) %>%
  dplyr::arrange(Library, factor(Method, levels = ord))
write.csv(out, file.path(resdir, "rhc_table_for_manuscript.csv"), row.names = FALSE)
cat("wrote rhc_table_for_manuscript.csv\n")
print(as.data.frame(out))
