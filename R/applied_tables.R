# =====================================================================
# applied_tables.R -- Supplement Section M: Tables S10 (RHC) and S11
# (LaLonde/NSW), formatted from the SHIPPED saved applied-analysis outputs.
# Reads only; fits nothing; needs no benchmark data.
#
#   Rscript R/applied_tables.R [results_dir] [out_md]
#
#   Table S10: every RHC estimator under the basic and extended Super
#              Learner libraries (estimate, SE, 95% CI, outer split,
#              bias correction, repetitions R).
#   Table S11: LaLonde/NSW CPS and PSID comparisons (four estimators),
#              sample and overlap summaries, and the vanilla-TMLE truncation
#              sweep plotted in the main paper's truncation figure (Figure 1).
#
# Writes out_md (default output/applied_tables.md): the whole Section M
# of the Supplementary Materials as printed -- heading, introductory paragraph,
# Tables S10 and S11 with their notes, and the three raw-LaTeX \needspace blocks
# before the panels of Table S11 -- as UTF-8 with LF line endings.
#
# Inputs (results_dir, default "output"; all four are committed summary results;
# see output/APPLIED_PROVENANCE.md). None is rerun here:
#   rhc_factorial_fast.rds  Rscript R/04b_run_rhc_factorial.R 10 fast
#   rhc_factorial_rf.rds    Rscript R/04b_run_rhc_factorial.R 1 rf
#                           (the extended library of the paper, GLM + mean +
#                           ranger; NOT the "rich" profile, which adds SL.earth
#                           and was not used. The saved 'library' column of this
#                           file reads "Basic (GLM+mean)", a labelling bug since
#                           fixed in 04b; the library actually used is the saved
#                           sl_lib field, which is what this script reports.)
#   rhc_overlap_diag.rds    Rscript R/11_rhc_overlap_diagnostic.R
#   lalonde_estimates.rds   the aggregate elements of 06_lalonde_overlap.R's
#                           results; panel B of Table S11, the 185 treated men
#                           quoted in its introduction and the 0.49 in its note
#                           are transcribed from the paper in the committed copy
#                           (see R/16_lalonde_estimates_from_saved.R).
#
# Checks. The script stops if any saved value fails a consistency check. It
# then compares its output with the Section M printed in the paper
# (by MD5, below): when the inputs are the committed files, a difference is an
# error; when they are fresh outputs of run_all.R, it is reported, not fatal.
# =====================================================================
args    <- commandArgs(trailingOnly = TRUE)
RES     <- if (length(args) >= 1) args[1] else "output"
OUT     <- if (length(args) >= 2) args[2] else "output/applied_tables.md"
RHC_BASIC <- file.path(RES, "rhc_factorial_fast.rds")  # 04b_run_rhc_factorial.R 10 fast
RHC_EXT   <- file.path(RES, "rhc_factorial_rf.rds")    # 04b_run_rhc_factorial.R 1 rf
RHC_DIAG  <- file.path(RES, "rhc_overlap_diag.rds")    # 11_rhc_overlap_diagnostic.R
LALONDE   <- file.path(RES, "lalonde_estimates.rds")   # 06_lalonde_overlap.R (aggregate part)
INPUTS    <- c(RHC_BASIC, RHC_EXT, RHC_DIAG, LALONDE)

# MD5 of the committed inputs, and of Section M as printed in the paper
# (from its "## Section M" heading to the line before the next level-2 heading, LF endings;
# since 2026-10-07 that heading is the summary section's ("## Section N" since 2026-10-11, "## S.summary" before), earlier it was "## References").
SHIPPED_MD5 <- c(rhc_factorial_fast.rds = "3b86264c718258d9ab664cd3cdd6e03b",
                 rhc_factorial_rf.rds   = "d5a2b94523bd225acce518698aaf5602",
                 rhc_overlap_diag.rds   = "106c4e7b3044272d89b35f8bf9aca41c",
                 lalonde_estimates.rds  = "c2a7d69c770aefc277eac0d0e4c60c0e")
PAPER_MD5   <- "49ff017dcb2a6757ade9bcc5a8b3376b"

for (f in INPUTS) if (!file.exists(f)) stop("missing saved input: ", f)
dir.create(dirname(OUT), recursive = TRUE, showWarnings = FALSE)

check <- function(ok, msg) if (!isTRUE(all(ok))) stop("consistency check failed: ", msg)
# binary mode: UTF-8 bytes with LF line endings on every platform, as in the manuscript sources
con <- file(OUT, "wb")
w <- function(...) writeBin(charToRaw(enc2utf8(paste0(..., "\n"))), con)

# pipe table with relative column widths set by the dash counts in `dashes`
mdtab <- function(df, dashes) {
  stopifnot(length(dashes) == ncol(df))
  w("| ", paste(names(df), collapse = " | "), " |")
  w("|", paste(strrep("-", dashes), collapse = "|"), "|")
  for (i in seq_len(nrow(df))) w("| ", paste(unlist(df[i, ]), collapse = " | "), " |")
  w("")
}
# Raw-LaTeX block, as printed before each panel of Table S11: keeps a panel's
# label with its table across a page break in the PDF (pandoc passes it through).
needspace <- function() {
  w("```{=latex}"); w("\\needspace{10\\baselineskip}"); w("```"); w("")
}
DASH <- "—"   # not available (plug-in arms), as in Table S6
f4  <- function(x) ifelse(is.na(x), DASH, sprintf("%.4f", x))
ci3 <- function(lo, hi) ifelse(is.na(lo), DASH, sprintf("%.3f to %.3f", lo, hi))
pct <- function(x) sprintf("%.1f%%", 100 * x)
yn  <- function(x) ifelse(x, "yes", "no")

## ------------------------------------------------------------------
## Section heading and introduction (as printed)
## ------------------------------------------------------------------
w("## Section M — Real-data estimates: RHC and LaLonde")
w("")
w("This section tabulates every estimate behind the real-data illustrations, including two sets that")
w("the main text only summarizes: the RHC estimates under the extended library and the LaLonde comparison")
w("with the Panel Study of Income Dynamics (PSID) sample. Every value is read from the saved analysis")
w("outputs; nothing was refit for this supplement, and a script in the companion repository, run on those")
w("files, rebuilds both tables. Neither analysis has a known truth for its estimand, so the tables show how")
w("far the estimator choices moved the estimates, not which estimate is correct.")
w("")

## ------------------------------------------------------------------
## Table S10 -- RHC
## ------------------------------------------------------------------
B <- readRDS(RHC_BASIC); E <- readRDS(RHC_EXT); D <- readRDS(RHC_DIAG)
# The saved 'library' column of the extended run reads "Basic (GLM+mean)":
# 04b_run_rhc_factorial.R then labelled every profile except "rich" as Basic. The
# library actually used is the saved sl_lib field, which is what we report.
check(identical(B$sl_lib, c("SL.glm", "SL.mean")), "basic sl_lib")
check(identical(E$sl_lib, c("SL.glm", "SL.mean", "SL.ranger")), "extended sl_lib")
check(B$n == 5735L && E$n == 5735L && D$n == 5735L, "RHC n")
check(B$R == 10L && E$R == 1L, "saved R")

# Outer split and bias correction of each arm: the catalogue in 04b_run_rhc_factorial.R
# (scheme / qonly / target) with the fold counts of run_once() in 02_variants.R.
cfg <- data.frame(
  method = c("GCOMP", "AIPW", "TMLE", "SS-TMLE", "CVQ-TMLE", "CVQ-TMLE-fold", "CF-GCOMP",
             "CV-TMLE", "CV-TMLE-fold", "CF-AIPW", "SCTMLE", "DC-TMLE-pool", "DCTMLE", "DC-AIPW"),
  split  = c("none", "none", "none", "half-sample, no rotation", "5-fold, $Q$ only",
             "5-fold, $Q$ only", "5-fold, $Q$ only", "5-fold", "5-fold", "5-fold",
             "2-way cross-fit", "3-way cross-fit", "3-way cross-fit", "3-way cross-fit"),
  target = c("none (plug-in)", "AIPW", "pooled", "pooled", "pooled", "fold-specific", "none (plug-in)",
             "pooled", "fold-specific", "AIPW", "fold-specific", "pooled",
             "fold-specific", "AIPW"),
  stringsAsFactors = FALSE)

rhc_panel <- function(tab) {
  tab <- as.data.frame(tab)
  check(all(tab$method %in% cfg$method), "unknown RHC arm")
  tab <- tab[order(match(tab$method, cfg$method)), ]
  ok <- !is.na(tab$se)
  check(abs(tab$ci_lo[ok] - (tab$rd[ok] - 1.96 * tab$se[ok])) < 1e-12 &
        abs(tab$ci_hi[ok] - (tab$rd[ok] + 1.96 * tab$se[ok])) < 1e-12, "RHC CI = rd +/- 1.96 se")
  check(is.na(tab$se) == grepl("GCOMP", tab$method), "only the plug-in arms lack an SE")
  m <- match(tab$method, cfg$method)
  # The saved folk flag also marks CV-TMLE-fold. It has a published design counterpart, the CVTMLE[all]
  # of Smith et al. (2025), so it is not daggered; the unattested cells are CVQ-TMLE-fold and DC-TMLE-pool.
  unattested <- tab$folk & tab$method != "CV-TMLE-fold"
  data.frame(
    estimator = ifelse(unattested, paste0(tab$method, "$^\\dagger$"), tab$method),
    `outer split` = cfg$split[m], `bias correction` = cfg$target[m], R = as.character(tab$R),
    estimate = f4(tab$rd), SE = f4(tab$se), `95% CI` = ci3(tab$ci_lo, tab$ci_hi),
    check.names = FALSE, stringsAsFactors = FALSE)
}
Bt <- as.data.frame(B$table); Et <- as.data.frame(E$table)
check(c(Bt$R[Bt$splits] == 10L, Bt$R[!Bt$splits] == 1L), "basic: split arms R=10, no-split R=1")
check(identical(Bt$splits, Bt$method != "GCOMP" & Bt$method != "AIPW" & Bt$method != "TMLE") &&
      identical(Et$splits, Et$method != "GCOMP" & Et$method != "AIPW" & Et$method != "TMLE"),
      "only GCOMP, AIPW and TMLE are no-split arms")
check(Et$R == 1L, "extended: every arm R=1")
check(!("CF-GCOMP" %in% Bt$method) && ("CF-GCOMP" %in% Et$method), "CF-GCOMP only in the extended run")
# Why the basic run has no CF-GCOMP row: run_repeated() in 02_variants.R keeps a
# repetition only if all(is.finite(...)) over its estimate AND variances, and the
# plug-in assembly always returns NA variances, so at R = 10 all ten repetitions
# were dropped; the empty aggregate gave a zero-row tibble in 04b (whose 'order'
# counter still advanced) and an empty log line. The saved order skips 7 accordingly.
check(identical(as.integer(Bt$order), c(1:6, 8:14)) &&
      identical(as.integer(Et$order), 1:14) &&
      Et$method[Et$order == 7L] == "CF-GCOMP", "catalogue order: basic run skips CF-GCOMP (7)")
check(nrow(Bt) == 13L && nrow(Et) == 14L, "arm counts")
widths_rhc <- c(22, 24, 16, 3, 8, 8, 15)

w("### Table S10 — RHC: every estimator under the basic and extended libraries, n = ", B$n)
w("")
# 49 covariates: the adjustment set of 00_prepare_rhc.R (20 continuous, 12 history flags, 17 categorical).
w(sprintf(paste0(
  "ATE of RHC on 30-day mortality (risk difference); $n = %d$ (%d treated), adjusting for 49 covariates ",
  "with categorical covariates expanded to indicator columns. Both nuisances use the same Super Learner ",
  "library, with 5-fold inner cross-validation in every fit, and propensities are truncated to ",
  "$[0.025, 0.975]$. The seed is set to 2026 before fitting each estimator, and estimators with the same number of ",
  "outer folds share the same partitions. $R$ is the number of random splits. With $R = 10$ the estimate ",
  "is the median over splits (repetition seeds $2026 + r$) and its SE is the median-method SE, which ",
  "includes the between-split term; with $R = 1$ it is the influence-function SE of a single split or fit. ",
  "Variance conventions are in Section A. Intervals are estimate $\\pm 1.96$ SE. GCOMP and ",
  "CF-GCOMP are plug-in estimators, to which no EIF-based SE applies, so only their estimates are shown. ",
  "$\\dagger$ marks the two unattested cells; CV-TMLE-fold corresponds in design to the CVTMLE[all] of ",
  "@smith2024performance, with a different fluctuation submodel."),
  B$n, D$n_treated))
w("")
w("**Basic library** (`", paste(B$sl_lib, collapse = "` + `"), "`)")
w("")
mdtab(rhc_panel(Bt), widths_rhc)
w("**Extended library** (`", paste(E$sl_lib, collapse = "` + `"), "`)")
w("")
mdtab(rhc_panel(Et), widths_rhc)
bfs <- Bt$method != "SS-TMLE"
cf7 <- c("CV-TMLE", "CV-TMLE-fold", "CF-AIPW", "SCTMLE", "DC-TMLE-pool", "DCTMLE", "DC-AIPW")
w(sprintf(paste0(
  "_CF-GCOMP appears only under the extended library. Our repetition code keeps a repetition only if ",
  "its estimate and variances are all finite, and a plug-in estimator has no variance estimate, so at ",
  "$R = 10$ every basic-library CF-GCOMP repetition was discarded and no CF-GCOMP estimate was saved; the ",
  "extended analysis ($R = 1$) fits each estimator once, without that filter. The two panels differ in $R$ as well as ",
  "in library: every extended-library estimator uses one split, so its split estimators carry ",
  "single-partition noise, and for those estimators the panels cannot isolate the library's effect. ",
  "The no-split estimators (GCOMP, AIPW, TMLE) use one fit under both libraries. Range of estimates, basic library: %.3f to %.3f (full-sample estimators, all but SS-TMLE: ",
  "%.3f to %.3f); extended library: %.3f to %.3f (the seven fully cross-fit estimators: %.3f to %.3f)._"),
  min(Bt$rd), max(Bt$rd), min(Bt$rd[bfs]), max(Bt$rd[bfs]), min(Et$rd), max(Et$rd),
  min(Et$rd[Et$method %in% cf7]), max(Et$rd[Et$method %in% cf7])))
w("")

## ------------------------------------------------------------------
## Table S11 -- LaLonde / NSW
## ------------------------------------------------------------------
L <- readRDS(LALONDE)
check(!("ps" %in% names(L)), "lalonde_estimates.rds must hold no per-unit element")
b <- L$benchmark_emp
reach <- function(lo, hi) lo <= b & b <= hi
est <- rbind(as.data.frame(L$cps), as.data.frame(L$psid))
check(abs(est$ci_lo - (est$rd - 1.96 * est$se)) < 1e-12 &
      abs(est$ci_hi - (est$rd + 1.96 * est$se)) < 1e-12, "LaLonde CI = rd +/- 1.96 se")
check(reach(est$ci_lo, est$ci_hi) == est$covers_benchmark, "LaLonde benchmark flags")
check(identical(est$method, rep(c("TMLE", "AIPW", "CVTMLE", "DCTMLE"), 2)), "LaLonde arms")
tr <- as.data.frame(L$trunc)
check(abs(tr$ci_lo - (tr$rd - 1.96 * tr$se)) < 1e-12 & reach(tr$ci_lo, tr$ci_hi) == tr$covers,
      "truncation sweep")
# Sample and overlap summaries (panel B). Computed by 06_lalonde_overlap.R at
# save time in a fresh run; transcribed from the paper in the committed copy.
ov <- as.data.frame(L$overlap)
check(identical(ov$control, c("CPS", "PSID")), "overlap rows")
check(ov$n == ov$n_treated + ov$n_control, "pooled n = treated + comparison units")
check(ov$n_treated[1] == ov$n_treated[2], "same treated men in both comparisons")
n_cps <- ov$n[ov$control == "CPS"]
check(abs(tr$gbound[1] - 5 / (sqrt(n_cps) * log(n_cps))) < 1e-12, "default bound 5/(sqrt(n) log n)")
check(abs(tr$gbound[3] - 0.025) < 1e-12 &&
      all(abs(tr$rd[3] - L$cps$rd[L$cps$method == "TMLE"]) < 1e-12),
      "sweep at 0.025 equals the panel-A vanilla TMLE estimate")
if (!is.null(L$overlap_source)) cat("[S11] panel B and the CPS propensity maximum:", L$overlap_source, "\n")

w("### Table S11 — LaLonde/NSW: CPS and PSID comparisons and the truncation sweep")
w("")
# Covariates and estimator settings: 06_lalonde_overlap.R (covs, variants, R = 20, set.seed(2026)).
w(sprintf(paste0(
  "Outcome: employed in 1978 (positive 1978 earnings). The %d treated men of the Dehejia--Wahba subsample ",
  "of the National Supported Work (NSW) experiment [@dehejia1999] are pooled with comparison units from the ",
  "Current Population Survey (CPS) or the Panel Study of Income Dynamics (PSID). The adjustment set is age, ",
  "years of education, Black, Hispanic, married, no high-school degree, and 1974 and 1975 earnings. Both ",
  "nuisances use the library `SL.glm` + `SL.mean` with 5-fold inner cross-validation, and propensities are ",
  "truncated to $[0.025, 0.975]$ except in panel C. The seed is set to 2026 before fitting each estimator. ",
  "TMLE and AIPW use no split; CV-TMLE uses one 5-fold split with pooled targeting ($R = 1$); DCTMLE uses ",
  "3-way cross-fitting with fold-specific targeting, median-aggregated over $R = 20$ splits (repetition ",
  "seeds $2026 + r$). DCTMLE's SE is therefore the median-method SE, which includes the between-split term ",
  "(as in Table S10); the other three report the influence-function SE of a single fit or split. Intervals ",
  "are estimate $\\pm 1.96$ SE. The benchmark, $+%.4f$, is the experimental difference in 1978 employment ",
  "among NSW enrollees (the corresponding earnings difference is \\$%s), not this estimand's truth (main ",
  "text)."),
  ov$n_treated[ov$control == "CPS"], b, format(round(L$benchmark_earn), big.mark = ",")))
w("")
needspace()
w("**A. Estimates** (truncation bound 0.025)")
w("")
A <- data.frame(
  comparison = est$control, estimator = sub("CVTMLE", "CV-TMLE", est$method),
  estimate = f4(est$rd), SE = f4(est$se), `95% CI` = ci3(est$ci_lo, est$ci_hi),
  `interval reaches benchmark` = yn(est$covers_benchmark),
  check.names = FALSE, stringsAsFactors = FALSE)
mdtab(A, c(12, 16, 10, 10, 18, 14))

needspace()
w("**B. Samples and overlap**")
w("")
smp <- data.frame(
  comparison = ov$control, `pooled $n$` = format(ov$n, big.mark = ","),
  treated = as.character(ov$n_treated),
  `comparison units` = format(ov$n_control, big.mark = ","),
  `truncated, all` = pct(ov$trunc_all), `truncated, treated` = pct(ov$trunc_treated),
  `comparison units with $g < 0.01$` = pct(ov$control_g_lt_0.01),
  check.names = FALSE, stringsAsFactors = FALSE)
smp[] <- lapply(smp, trimws)   # format() pads to a common width; the table prints unpadded
mdtab(smp, c(12, 8, 9, 12, 11, 12, 16))

needspace()
w("**C. Truncation sweep** (vanilla TMLE, CPS comparison; the main paper's truncation figure)")
w("")
C <- data.frame(
  `truncation bound` = sprintf("%.4f", tr$gbound), estimate = f4(tr$rd), SE = f4(tr$se),
  `95% CI` = ci3(tr$ci_lo, tr$ci_hi), `interval reaches benchmark` = yn(tr$covers),
  check.names = FALSE, stringsAsFactors = FALSE)
mdtab(C, c(14, 10, 10, 18, 14))
w(sprintf(paste0(
  "_Panel B: shares of the whole-sample (no-split) propensity estimate saved for Figure S3 ",
  "(same library, inner folds ",
  "and seed as the no-split fits) lying outside $[0.025, 0.975]$; the split estimators truncate their ",
  "own out-of-fold estimates, which were not saved. Panel C: each bound $b$ truncates to $[b, 1 - b]$. The ",
  "smallest, %.4f, is $5/(\\sqrt{n}\\log n)$ at $n = %s$, the default bound of the `tmle` package ",
  # (n printed with a braced comma so LaTeX math does not add a space after it)
  "(version 2.1.1), applied from below to both $\\hat g$ and $1 - \\hat g$; no saved CPS-comparison ",
  "propensity estimate exceeds %.2f, so $1 - b$ does not bind. The row at 0.0250 is the vanilla TMLE ",
  "estimate of panel A._"),
  tr$gbound[1], gsub(",", "{,}", format(n_cps, big.mark = ",")),
  ov$g_max_ceil2[ov$control == "CPS"]))
w("")   # the section ends with a blank line, immediately before the next level-2 heading
close(con)
cat("wrote", OUT, "\n")

## ------------------------------------------------------------------
## Compare with Section M as printed in the paper
## ------------------------------------------------------------------
in_md5  <- unname(tools::md5sum(INPUTS))
shipped <- identical(in_md5, unname(SHIPPED_MD5))
out_md5 <- unname(tools::md5sum(OUT))
if (identical(out_md5, PAPER_MD5)) {
  cat("[check] Section M (Tables S10-S11) matches the paper as printed (MD5 ", out_md5, ")\n", sep = "")
} else if (shipped) {
  stop("Tables S10-S11 formatted from the committed inputs differ from the paper as printed ",
       "(MD5 ", out_md5, ", expected ", PAPER_MD5, ")")
} else {
  cat("[note] Tables S10-S11 differ from the paper as printed (MD5 ", out_md5, " vs ", PAPER_MD5,
      "); expected when the inputs are fresh refits rather than the committed files.\n", sep = "")
}
