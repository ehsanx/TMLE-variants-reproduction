# =====================================================================
# 16_lalonde_estimates_from_saved.R -- build the shippable AGGREGATE LaLonde
# file output/lalonde_estimates.rds from the saved LaLonde results, once.
#
#   Rscript R/16_lalonde_estimates_from_saved.R [lalonde_overlap.rds]
#
# Fits nothing. Run once, by the authors, to create the committed file; a
# clone does not need to run it (and cannot: its input is not shipped).
#
# Why this exists. 06_lalonde_overlap.R saves output/lalonde_overlap.rds, which
# holds the aggregate estimates AND a per-unit propensity vector ($ps, one row
# per pooled unit) for the overlap figure (Supplementary Figure S3). Per-unit
# values derived from the benchmark data are never committed or bundled (see the
# README, Data), so that file stays out of the repository. This script copies ONLY its
# aggregate elements -- benchmark_emp, benchmark_earn, cps, psid, trunc -- into
# a new file. The $ps element is dropped immediately after loading and is never
# read, summarized or written.
#
# The sample and overlap summaries of Supplement Table S11 panel B (pooled n,
# treated, comparison units, truncated shares, share with g < 0.01) and the
# upper end of the CPS propensity range quoted in that table's note are
# per-unit-derived. They are NOT recomputed here from $ps; they are TRANSCRIBED
# from the paper as printed (Supplement Table S11, panel B and note, rounded to
# 0.1 percentage point), where the authors' generator had computed them from the
# saved whole-sample (no-split) propensity estimate. They are marked as transcribed inside
# the file ($overlap_source) and in output/APPLIED_PROVENANCE.md. One of them is
# cross-checked against the saved estimates: the CPS pooled n must reproduce the
# saved default truncation bound 5/(sqrt(n) log n) to 1e-12.
#
# Future runs of 06_lalonde_overlap.R write output/lalonde_estimates.rds
# directly, with the overlap summaries computed (unrounded) at save time, so
# this script is needed only for the results reported in the paper.
# =====================================================================
args <- commandArgs(trailingOnly = TRUE)
SRC  <- if (length(args) >= 1) args[1] else "output/lalonde_overlap.rds"
OUT  <- "output/lalonde_estimates.rds"
# SHA-256 of the canonical LaLonde results file the paper reports (the copy
# produced by 06_lalonde_overlap.R and used for Figure 1, Supplementary Figure S3
# and Table S11).
SRC_SHA256 <- "37d02d11154aa3520bb90496ff799c484271211917f2e9ac17377a314f8c2ff8"

if (!file.exists(SRC)) stop("source not found: ", SRC,
  " (this one-off step needs the unshipped per-unit results file; a clone does not need it)")
if (exists("sha256sum", envir = asNamespace("tools"))) {
  h <- unname(tools::sha256sum(SRC))
  if (!identical(h, SRC_SHA256)) stop("source SHA-256 ", h, " is not the canonical ", SRC_SHA256)
  cat("[check] source is the canonical LaLonde results file (SHA-256 ", h, ")\n", sep = "")
} else cat("(tools::sha256sum unavailable in this R; source checksum not verified)\n")

L <- readRDS(SRC)
L <- L[setdiff(names(L), "ps")]   # drop the per-unit element before anything else
AGG <- c("benchmark_emp", "benchmark_earn", "cps", "psid", "trunc")
if (!identical(sort(names(L)), sort(AGG))) stop("unexpected elements: ", paste(names(L), collapse = ", "))

plain <- function(x) { x <- as.data.frame(x, stringsAsFactors = FALSE); class(x) <- "data.frame"
  rownames(x) <- NULL; x }
out <- list(
  benchmark_emp  = L$benchmark_emp,
  benchmark_earn = L$benchmark_earn,
  cps   = plain(L$cps),     # 4 estimators x (rd, se, ci_lo, ci_hi, covers_benchmark)
  psid  = plain(L$psid),
  trunc = plain(L$trunc),   # vanilla TMLE, CPS comparison, 4 truncation bounds (Figure 1)
  # Supplement Table S11 panel B and note, transcribed as printed (see header).
  overlap = data.frame(
    control           = c("CPS", "PSID"),
    n                 = c(16177L, 2675L),
    n_treated         = c(185L, 185L),
    n_control         = c(15992L, 2490L),
    trunc_all         = c(0.948, 0.797),   # share with g outside [0.025, 0.975]
    trunc_treated     = c(0.151, 0.032),   # same, among the treated
    control_g_lt_0.01 = c(0.906, 0.784),   # share of comparison units with g < 0.01
    g_max_ceil2       = c(0.49, NA),       # ceiling(100 * max g) / 100; PSID not printed
    stringsAsFactors  = FALSE),
  overlap_source = paste(
    "TRANSCRIBED from the paper as printed (Supplement Table S11 panel B and its note; shares",
    "rounded to 0.1 percentage point), not recomputed: the per-unit propensity file they derive",
    "from is not shipped. CPS n cross-checked against the saved default truncation bound."),
  provenance = paste(
    "Aggregate elements copied unchanged from output/lalonde_overlap.rds",
    paste0("(SHA-256 ", SRC_SHA256, "; its per-unit $ps element dropped unread)"),
    "by R/16_lalonde_estimates_from_saved.R."))

# The values carried over are unchanged.
for (k in c("cps", "psid", "trunc"))
  if (!isTRUE(all.equal(as.list(out[[k]]), as.list(as.data.frame(L[[k]])), tolerance = 0)))
    stop("copy of ", k, " differs from the source")
# Internal consistency of the transcription.
ov <- out$overlap
stopifnot(all(ov$n == ov$n_treated + ov$n_control))
n_cps <- ov$n[ov$control == "CPS"]
if (abs(out$trunc$gbound[1] - 5 / (sqrt(n_cps) * log(n_cps))) > 1e-12)
  stop("transcribed CPS n does not reproduce the saved default truncation bound")
cat("[check] transcribed CPS n =", n_cps, "reproduces the saved default bound",
    format(out$trunc$gbound[1], digits = 10), "\n")
stopifnot(max(out$trunc$rd) < 1, all(ov$trunc_all <= 1))

saveRDS(out, OUT)
cat("wrote", OUT, "\n")
