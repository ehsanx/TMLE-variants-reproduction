#!/usr/bin/env Rscript
# =====================================================================
# 10_bias_mcse_and_within_family.R -- Supplement Table S7 (Section G):
# per-estimator bias and Monte Carlo standard errors at the four primary
# settings (S1, S2, D3, the S3 primary setting), formatted from the committed
# output/compass_maps.rds. Reads saved results only; fits nothing.
# Writes output/bias_mcse_tables.md; also prints the g-split contrasts within
# each correction route (AIPW versus TMLE; the "one-step" and "fluctuation"
# families below) at the S3 primary setting quoted in Section D.
# (Numbered Table S6 before the Supplement renumbered its tables in order of
# appearance.)
# =====================================================================

MAP <- "output/compass_maps.rds"
OUT <- "output/bias_mcse_tables.md"
m <- readRDS(MAP)

GRADED <- c("TMLE","AIPW","CVQ-TMLE","SS-TMLE","CV-TMLE","CF-AIPW","DCTMLE","DC-AIPW")
DELTA_BIAS <- 0.005

fmt <- function(x, d = 4) formatC(x, format = "f", digits = d)

n09_table <- function(key, recipes = GRADED) {
  r <- m[[key]]; s <- as.data.frame(r$summary); truth <- r$truth
  s <- s[match(recipes, s$label), ]
  s <- s[!is.na(s$label), ]
  data.frame(
    recipe     = s$label,
    nsim       = s$nsim,
    bias       = s$bias,
    bias_mcse  = s$empSE / sqrt(s$nsim),
    bias_gt_d  = ifelse(abs(s$bias) > DELTA_BIAS, "yes", "no"),
    empSE      = s$empSE,
    empSE_mcse = s$empSE / sqrt(2 * (s$nsim - 1)),
    relSE      = s$relSE,
    mse        = s$mse,
    cover      = s$cover,
    cover_mcse = s$cover_mcse,
    truth      = truth,
    stringsAsFactors = FALSE)
}

regimes <- c(
  S1        = "S1_sharp1.0_gb0.025_n3000",
  S2        = "S2_sharp1.0_gb0.025_n3000",
  D3        = "D3_sharp1.0_gb0.025_n3000",
  S3_anchor = "S3_sharp2.0_gb0.025_n3000")

cat("###############  N09  BIAS + per-metric MCSE  ###############\n")
n09 <- list()
for (nm in names(regimes)) {
  tab <- n09_table(regimes[[nm]])
  n09[[nm]] <- tab
  cat("\n==== ", nm, "  (", regimes[[nm]], ")  truth=", fmt(tab$truth[1], 6), " ====\n", sep = "")
  print(data.frame(
    recipe = tab$recipe,
    bias   = fmt(tab$bias),
    biasMCSE = fmt(tab$bias_mcse),
    ">d"   = tab$bias_gt_d,
    empSE  = fmt(tab$empSE),
    empSEMCSE = fmt(tab$empSE_mcse),
    relSE  = fmt(tab$relSE, 1),
    cover  = fmt(tab$cover, 3),
    covMCSE = fmt(tab$cover_mcse, 4),
    check.names = FALSE), row.names = FALSE)
}

cat("\n---- |bias|/empSE ratio (>~1 => bias co-drives mis-coverage) ----\n")
for (nm in c("S2","D3","S3_anchor")) {
  tab <- n09[[nm]]
  cat(sprintf("%-10s ", nm))
  cat(paste(sprintf("%s=%.2f", tab$recipe, abs(tab$bias)/tab$empSE), collapse = "  "), "\n")
}

cat("\n\n###############  C23  WITHIN-FAMILY g-split (S3 anchor)  ###############\n")
r3 <- m[["S3_sharp2.0_gb0.025_n3000"]]
pw <- as.data.frame(r3$pairwise)
s3 <- as.data.frame(r3$summary)
getcov <- function(lab) s3$cover[match(lab, s3$label)]

get_pair <- function(x, y) {
  hit <- pw[(pw$a == x & pw$b == y) | (pw$a == y & pw$b == x), ]
  if (nrow(hit) == 0) return(NULL)
  h <- hit[1, ]
  sgn <- if (h$a == x) 1 else -1
  data.frame(contrast = paste0(x, " - ", y),
             dcover = sgn * h$dcover,
             ci_lo = if (sgn == 1) h$ci_lo else -h$ci_hi,
             ci_hi = if (sgn == 1) h$ci_hi else -h$ci_lo,
             verdict = h$verdict, stringsAsFactors = FALSE)
}

onestep_pairs  <- list(c("CF-AIPW","AIPW"), c("DC-AIPW","AIPW"))
fluct_pairs    <- list(c("CV-TMLE","TMLE"), c("DCTMLE","TMLE"),
                       c("CV-TMLE","CVQ-TMLE"), c("DCTMLE","CVQ-TMLE"))

cat("\n-- one-step family: cross-fit-g minus in-sample-g --\n")
os <- do.call(rbind, lapply(onestep_pairs, function(p) get_pair(p[1], p[2])))
print(data.frame(contrast = os$contrast, dcover = fmt(os$dcover),
                 ci = paste0("[", fmt(os$ci_lo), ", ", fmt(os$ci_hi), "]"),
                 verdict = os$verdict, check.names = FALSE), row.names = FALSE)

cat("\n-- fluctuation family: cross-fit-g minus in-sample-g --\n")
fl <- do.call(rbind, lapply(fluct_pairs, function(p) get_pair(p[1], p[2])))
print(data.frame(contrast = fl$contrast, dcover = fmt(fl$dcover),
                 ci = paste0("[", fmt(fl$ci_lo), ", ", fmt(fl$ci_hi), "]"),
                 verdict = fl$verdict, check.names = FALSE), row.names = FALSE)

cat("\n-- mean coverage by (family x g-split location), S3 anchor --\n")
grid <- data.frame(
  family = c("one-step","one-step","fluctuation","fluctuation"),
  gsplit = c("in-sample-g","cross-fit-g","in-sample-g","cross-fit-g"),
  mean_cover = c(
    mean(getcov("AIPW")),
    mean(getcov(c("CF-AIPW","DC-AIPW"))),
    mean(getcov(c("TMLE","CVQ-TMLE"))),
    mean(getcov(c("CV-TMLE","DCTMLE")))),
  stringsAsFactors = FALSE)
grid$mean_cover <- fmt(grid$mean_cover, 3)
print(grid, row.names = FALSE)
cat("\nMarginal axis means (from map$axis):\n")
print(as.data.frame(r3$axis$by_gsplit), row.names = FALSE)
print(as.data.frame(r3$axis$by_family), row.names = FALSE)

md <- c("<!-- AUTO-GENERATED by R/10_bias_mcse_and_within_family.R -->",
        "### Table S7 — Per-implementation bias and Monte Carlo standard errors",
        "",
        "| regime | recipe | bias | bias MCSE | empSE | empSE MCSE | relSE (%) | coverage | cov MCSE |",
        "|---|---|---|---|---|---|---|---|---|")
for (nm in names(regimes)) {
  tab <- n09[[nm]]
  for (i in seq_len(nrow(tab))) {
    md <- c(md, sprintf("| %s | %s | %s | %s | %s | %s | %s | %s | %s |",
      nm, tab$recipe[i], fmt(tab$bias[i]), fmt(tab$bias_mcse[i]),
      fmt(tab$empSE[i]), fmt(tab$empSE_mcse[i]), fmt(tab$relSE[i],1),
      fmt(tab$cover[i],3), fmt(tab$cover_mcse[i],4)))
  }
}
writeLines(md, OUT)
cat("\n[written] ", OUT, "\n", sep = "")
