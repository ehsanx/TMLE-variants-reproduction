#!/usr/bin/env Rscript
# =====================================================================
# 12_s3_clean_gsplit.R -- Supplement Table S3 (Section D): the g-splitting
# contrast across the S3 near-positivity sweep with the correction route held
# fixed, alongside the gap between the correction routes (AIPW versus TMLE),
# formatted from the committed output/compass_maps.rds. Reads saved results
# only; fits nothing. Writes output/s3_clean_gsplit_table.md, whose text keeps
# the earlier wording ("targeting form", "targeting-family gap").
# (Numbered Table S7 before the Supplement renumbered its tables in order of
# appearance; the script keeps its historical name, whose "s3" is the S3 regime.)
# =====================================================================

MAP <- "output/compass_maps.rds"
OUT <- "output/s3_clean_gsplit_table.md"
m <- readRDS(MAP)
cells <- expand.grid(sharp = c(1.5, 2.0), gb = c(0.001, 0.005, 0.010, 0.025))
cov_of <- function(s, lab) s$cover[match(lab, s$label)]

rows <- lapply(seq_len(nrow(cells)), function(i) {
  key <- sprintf("S3_sharp%.1f_gb%.3f_n3000", cells$sharp[i], cells$gb[i])
  s <- as.data.frame(m[[key]]$summary)
  fam <- m[[key]]$axis$by_family
  data.frame(
    sharpening = cells$sharp[i], gbound = cells$gb[i],
    nsim       = max(s$nsim),
    clean_fluct_pp   = round(100 * (cov_of(s, "CV-TMLE") - cov_of(s, "CVQ-TMLE")), 1),
    clean_onestep_pp = round(100 * (cov_of(s, "CF-AIPW") - cov_of(s, "AIPW")), 1),
    family_gap_pp    = round(100 * (fam$mean_cover[fam$family == "one-step"] -
                                    fam$mean_cover[fam$family == "fluctuation"]), 1))
})
tab <- do.call(rbind, rows); tab <- tab[order(tab$sharpening, tab$gbound), ]
print(tab, row.names = FALSE)

md <- c("### Table S3 — g-splitting contrast across the S3 sweep, targeting form held fixed",
        "",
        paste0("The g contrast with the targeting form held fixed. The fluctuation pair CVQ-TMLE",
               " (in-sample $g$) vs CV-TMLE (cross-fit $g$) isolates g cleanly (Q cross-fit in both arms).",
               " The one-step pair AIPW vs CF-AIPW holds the targeting form fixed but moves Q from in-sample",
               " to cross-fit along with g; under the Donsker library, where Q-splitting is immaterial (S1),",
               " it approximates the g effect. Compared with the targeting-family gap. Anchor cell",
               " (sharpening 2.0, trunc. bound 0.025) at nsim = 2500, others nsim = 1000",
               " (MCSE $\\approx$ 1.1--1.6 pp on the fluctuation forms)."),
        "",
        "| sharpening | trunc. bound | fluctuation g-gap (pp) | one-step gap (pp) | targeting-family gap (pp) |",
        "|---|---|---|---|---|")
for (i in seq_len(nrow(tab))) {
  md <- c(md, sprintf("| %.1f | %.3f | %s | %s | %s |",
    tab$sharpening[i], tab$gbound[i], tab$clean_fluct_pp[i], tab$clean_onestep_pp[i], tab$family_gap_pp[i]))
}
md <- c(md, "",
  paste0("_The clean single-axis g contrast (fluctuation CVQ-TMLE vs CV-TMLE) is at most $2.1$ pp at the anchor",
         " and under strong sharpening (sharpening 2.0) and at most $6.5$ pp across the sweep (sharpening 1.5, bound 0.001);",
         " the one-step AIPW vs CF-AIPW gap (which also switches Q) is likewise small ($\\le 4.2$ pp), both",
         " far below the targeting-family gap (5.8--48.6 pp). The larger marginal gap (Table S2, up to 8.9 pp)",
         " and the naive within-family group-mean gap (up to 18 pp) are composition artifacts -- the latter",
         " driven by pooled vs fold-specific targeting (DCTMLE is fold-specific), not by g-location._"))
writeLines(md, OUT)
cat("\n[written]", OUT, "\n")
