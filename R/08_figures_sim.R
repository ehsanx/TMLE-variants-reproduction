# =====================================================================
# 08_figures_sim.R -- figures for the COMPASS known-truth simulation section.
#   Fig sim_s2_coverage : S2 (statin + random forest) coverage by estimator,
#       coloured by where the propensity is fit (in-sample / cross-fit /
#       split-half) -> the in-sample collapse vs cross-fit recovery.
#   Fig sim_two_axis_map: schematic of the regime-conditional materiality map
#       (learner class x overlap -> which design dimension is material). An
#       authored figure: its tiles and labels are written below and it reads
#       no data and carries no numbers.
# Supplementary Figure S5 (sim_s2_coverage) reads the corrected/archived
# compass_maps.rds (leaderboard identical to the ARC output); Supplementary
# Figure S4 (sim_two_axis_map) reads no data. Style matches 05_figures_rhc.R
# (theme_bw); each figure is exported at its printed width (5.6 in) so that its
# lettering prints at 8.8 pt or more.
# PDFs are written with cairo_pdf so that every font is embedded (subset) and
# hyphens stay hyphens in the text layer.
# =====================================================================
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })

maps <- readRDS("output/compass_maps.rds")
imgdir <- "images"
dir.create(imgdir, recursive = TRUE, showWarnings = FALSE)

graded8 <- c("TMLE","AIPW","CVQ-TMLE","SS-TMLE","CV-TMLE","CF-AIPW","DCTMLE","DC-AIPW")
gtag <- tibble::tribble(
  ~label,      ~gsplit,
  "TMLE",      "in-sample g",
  "AIPW",      "in-sample g",
  "CVQ-TMLE",  "in-sample g",
  "SS-TMLE",   "split-half g",
  "CV-TMLE",   "cross-fit g",
  "CF-AIPW",   "cross-fit g",
  "DCTMLE",    "cross-fit g",
  "DC-AIPW",   "cross-fit g")

# ---- Supplementary Figure S5: S2 coverage by estimator ----
s2 <- maps[["S2_sharp1.0_gb0.025_n3000"]]$summary %>%
  dplyr::filter(label %in% graded8) %>%
  dplyr::select(label, cover, cover_mcse) %>%
  dplyr::left_join(gtag, by = "label") %>%
  dplyr::mutate(
    gsplit = factor(gsplit, levels = c("in-sample g","split-half g","cross-fit g")),
    lo = cover - 1.96*cover_mcse, hi = pmin(1, cover + 1.96*cover_mcse))
# order: group, then coverage within group
s2 <- s2 %>% dplyr::arrange(gsplit, cover) %>% dplyr::mutate(label = factor(label, levels = label))

pal <- c("in-sample g" = "#D55E00", "split-half g" = "#999999", "cross-fit g" = "#0072B2")
shp <- c("in-sample g" = 17, "split-half g" = 15, "cross-fit g" = 16)
p1 <- ggplot(s2, aes(x = cover, y = label, colour = gsplit, shape = gsplit)) +
  annotate("rect", xmin = 0.93, xmax = 0.97, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.6) +
  geom_vline(xintercept = 0.95, linetype = "dashed", colour = "grey40") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.22, na.rm = TRUE) +
  geom_point(size = 3, na.rm = TRUE) +
  scale_colour_manual(values = pal, name = NULL) +
  scale_shape_manual(values = shp, name = NULL) +
  scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.1)) +
  labs(x = "95% interval coverage (S2: statin + random forest, n = 3000)", y = NULL,
       title = NULL) +
  theme_bw(base_size = 11) +
  theme(legend.position = "top", panel.grid.major.y = element_blank())
# exported at its printed width (5.6 in) so lettering prints at 8.8 pt or more
ggsave(file.path(imgdir, "sim_s2_coverage.pdf"), p1, width = 5.6, height = 3.7, device = cairo_pdf)
cat("wrote sim_s2_coverage.pdf\n")

# ---- Supplementary Figure S4: two-axis materiality map (schematic) ----
tiles <- tibble::tribble(
  ~x, ~y, ~overlap,          ~learner,        ~regime, ~material,                       ~fill,
   1,  2, "good overlap",    "low-complexity\nlibrary", "S1", "no material difference\namong full-sample\nestimators (n = 3000)", "neither",
   2,  2, "near-positivity", "low-complexity\nlibrary", "S3", "Correction route\n(AIPW vs TMLE):\nassess truncation and\nAIPW-vs-TMLE sensitivity", "family",
   1,  1, "good overlap",    "single random\nforest",   "S2", "Nuisance splitting:\ncross-fit g and Q",       "gsplit",
   2,  1, "near-positivity", "single random\nforest",   "\u2014", "(not simulated)",          "both")
fillpal <- c(neither = "#eef2f3", gsplit = "#d4e6f1", family = "#fcf3cf", both = "#f2f2f2")

p2 <- ggplot(tiles, aes(x, y)) +
  geom_tile(aes(fill = fill), colour = "grey55", width = 0.98, height = 0.98) +
  geom_text(aes(label = regime), nudge_y = 0.34, fontface = "bold", size = 4.2) +
  geom_text(aes(label = material), size = 3.5, lineheight = 0.95) +
  scale_fill_manual(values = fillpal, guide = "none") +
  scale_x_continuous(breaks = c(1, 2), labels = c("good overlap", "near-positivity"),
                     position = "top", expand = c(0, 0)) +
  scale_y_continuous(breaks = c(1, 2), labels = c("single random\nforest", "low-complexity\nlibrary"),
                     expand = c(0, 0)) +
  # no in-image title: the manuscript caption carries the message
  labs(x = NULL, y = NULL, title = NULL) +
  coord_equal() +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(),
        axis.text.x = element_text(face = "bold", size = 11),
        axis.text.y = element_text(face = "bold", size = 11),
        plot.title = element_text(size = 12, face = "bold", hjust = 0.5))
# exported at its printed width (5.6 in) so lettering prints at 8.8 pt or more
ggsave(file.path(imgdir, "sim_two_axis_map.pdf"), p2, width = 5.6, height = 4.0, device = cairo_pdf)
cat("wrote sim_two_axis_map.pdf\n")
cat("DONE\n")
