# =====================================================================
# 14_recover_truths.R -- recover the CANONICAL pinned truths from saved
# results and write them where the cluster harness expects them.
#
#   Rscript R/14_recover_truths.R
#
# WHY THIS EXISTS
# run_compass.R prefers R/truths.rds (written by pin_truths.R) and otherwise
# falls back to hard-coded defaults. That file was never committed, and the
# fallbacks are NOT the values the reported results were computed against:
#
#     fallback in run_compass.R:35   D1 = -0.1081508   D3 = 0.10068
#     actually used (per the shards) D1 = -0.1081358   D3 = 0.1006854
#
# So a cluster re-run without truths.rds would silently score coverage against
# slightly different truths than the paper did. This script closes that by
# RECOVERING the values from saved output rather than recomputing them: every
# per-replicate shard records, in its `truth` column, the value that run actually
# used.
#
# No draws are taken and no simulation is re-run.
# =====================================================================

OUT_RDS  <- "output/truths.rds"
OUT_PROV <- "output/TRUTHS_PROVENANCE.md"

# Source 1 (preferred): the raw shards, if a cluster run is present.
# Source 2: the packaged repetition input behind Supplement Table S5 (historical
# file name s4_repetition_input.rds), which carries the same `truth` column.
SIM <- "output/sim"
shards <- list.files(SIM, pattern = "^compass_.*\\.csv$", full.names = TRUE)

if (length(shards)) {
  recs <- unique(do.call(rbind, lapply(shards, function(f) {
    d <- utils::read.csv(f); unique(d[, c("slice", "truth")])
  })))
  src <- sprintf("%d raw shards in %s", length(shards), SIM)
} else {
  pk <- "output/s4_repetition_input.rds"
  if (!file.exists(pk))
    stop("need either raw shards in ", SIM, " or the packaged input ", pk)
  d <- readRDS(pk)
  recs <- unique(d[, c("slice", "truth")])
  src <- sprintf("the packaged repetition input %s (the Table S5 input; historical file name)", pk)
}
recs <- unique(recs)

# One truth per DGM: the statin mechanism (D1) backs S1/S2/S3; D3 is its own.
d1 <- unique(recs$truth[recs$slice %in% c("S1", "S2", "S3")])
d3 <- unique(recs$truth[recs$slice == "D3"])
if (length(d1) != 1L) stop("statin slices disagree on the truth: ", paste(d1, collapse = ", "))
if (length(d3) != 1L) stop("D3 shards disagree on the truth: ",     paste(d3, collapse = ", "))

# nD1/nD3 -- the draw counts pin_truths.R used -- are NOT recoverable. The
# shards record the resulting value, not how many draws produced it, and no
# pin_truths log survives in the project. Recorded as NA rather than guessed.
truths <- list(D1 = d1, D3 = d3, nD1 = NA_real_, nD3 = NA_real_,
               source = "recovered from saved per-replicate output")
saveRDS(truths, OUT_RDS)

ZB_REF <- -0.1081508
prov <- c(
  "# Provenance of the recovered canonical truths",
  "",
  sprintf("Recovered %s, with NO draws taken and no simulation re-run.", Sys.Date()),
  "",
  sprintf("Source: %s. Every per-replicate record carries, in its `truth` column, the", src),
  "value that run actually scored coverage against, so these are the canonical values by",
  "construction rather than by recomputation.",
  "",
  "| Quantity | Recovered | `run_compass.R` fallback | Difference |",
  "|---|---|---|---|",
  sprintf("| D1 (statin, backs S1/S2/S3) | `%.7f` | `-0.1081508` | `%.1e` |", d1, abs(d1 - (-0.1081508))),
  sprintf("| D3 (rough surface) | `%.7f` | `0.10068` | `%.1e` |", d3, abs(d3 - 0.10068)),
  "",
  "The fallbacks are close but not equal, so a cluster re-run without this file would score",
  "coverage against slightly different truths than the reported results did. That is the gap",
  "this file closes.",
  "",
  "## What is NOT recovered",
  "",
  "`pin_truths.R` also records `nD1`/`nD3`, the number of draws used to pin each truth",
  "(its default is 1e8). **Those are not recoverable from the saved record**: the shards store",
  "the resulting value, not the draw count, and no `pin_truths.R` log survives in the project.",
  "They are written as `NA` rather than guessed. Nothing in the pipeline reads them --",
  "`run_compass.R:37-38` reads only `$D1` and `$D3` -- so this does not affect reproduction.",
  "",
  "## Independent corroboration",
  "",
  "The 16 per-shard run manifests record `truth_source=pinned` together with",
  "`D1=-0.1081358 D3=0.1006854` -- the same values recovered here, from a different place in the",
  "saved record. They also confirm the production run really did read a pinned file rather than",
  "falling back, which is what makes these the canonical values rather than merely the observed ones.",
  "",
  "## Consistency check",
  "",
  # (The value is a code comment upstream, not a published result; see Supplement Section B.)
  sprintf("The upstream `dgm.py` of Zivich and Breskin carries the value `%.7f` in a code comment; it is not", ZB_REF),
  sprintf("reported in their published article or eAppendix. The recovered D1 differs from it by `%.1e`, the order", abs(d1 - ZB_REF)),
  "expected from a large-but-finite Monte Carlo pinning, so the recovered value is consistent with that",
  "reference value without being identical to it.",
  "",
  "## Use",
  "",
  "`run_compass.R` reads `$COMPASS_ENGINE/truths.rds` and prefers it over the fallbacks. To use",
  "this file for a cluster re-run, place it at the engine root, e.g. `cp output/truths.rds R/`."
)
writeLines(prov, OUT_PROV)

# Install where the cluster worker actually looks. run_compass.R:36 reads
# file.path(COMPASS_ENGINE, "truths.rds") and COMPASS_ENGINE defaults to "R",
# so a copy in output/ alone would be ignored and the worker would silently fall
# back to the wrong defaults.
ENGINE_RDS <- file.path("R", "truths.rds")
ok <- file.copy(OUT_RDS, ENGINE_RDS, overwrite = TRUE)

cat(sprintf("\nD1 (statin) = %.7f   [fallback %.7f, diff %.1e]\n", d1, -0.1081508, abs(d1 + 0.1081508)))
cat(sprintf("D3 (rough)  = %.7f   [fallback %.7f, diff %.1e]\n", d3, 0.10068, abs(d3 - 0.10068)))
cat("\n[written]", OUT_RDS, "and", OUT_PROV, "\n")
if (ok) cat("[installed]", ENGINE_RDS, "-- where run_compass.R reads it\n") else
  cat("*** could not install", ENGINE_RDS, "- the cluster worker will use its fallbacks\n")
cat("[note] nD1/nD3 are NA -- the draw counts are not recoverable from saved output\n")
