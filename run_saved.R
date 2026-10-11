# =====================================================================
# run_saved.R -- reproduce everything that comes from SAVED RESULTS.
#
#   Rscript run_saved.R
#
# No network access, no data download, no model fitting, no simulation. Every
# step below reads files committed to this repository and formats them. On a
# fresh clone this should run in under a minute and reproduce:
#
#     Table 3          the headline simulation table (self-checks its 32 cells
#                      against the paper)
#     Figures S4-S5    (Supplement, Section N) the two-axis regime map (an authored
#                      schematic: R/08 draws it from labels in the script, no data);
#                      S2 coverage by estimator
#     Tables S1, S2    D3; the S3 sweep
#     Tables S4-S6     the n-gradient, repetition, diagnostics
#     Table S9         paired coverage comparisons at the four primary settings
#                      (self-checks against the Supplement as printed)
#     Table S3         the single-axis g-split contrast
#     Table S7         per-estimator bias and Monte Carlo SEs
#     Tables S10-S11   the applied RHC and LaLonde estimates (self-check against
#                      the Supplement as printed; Table S11 panel B is transcribed
#                      from the paper on this route, see output/APPLIED_PROVENANCE.md)
#     Figures S1-S2    (Supplement) RHC forest plot; RHC SE, basic vs extended
#                      library
#     Figure 1         LaLonde estimate vs truncation bound (the main paper's
#                      only figure)
#     plus             the recovered canonical truths and a software-environment record
#
# What this deliberately does NOT do: Supplementary Figure S3 (it draws per-unit
# propensity scores, which are derived from the benchmark data and not shipped),
# re-fitting the two applied analyses, and the engine validation. Those need the
# benchmark data downloaded and fit models; they are in run_all.R. Each step runs
# with SAVED_ONLY = TRUE, which makes the figure scripts use the committed files
# only, even if a local run has left unshipped results in output/.
# =====================================================================

Rdir <- "R"
.fail <- character(0)
.t0   <- Sys.time()

step <- function(msg, file) {
  cat("\n==>", msg, "\n")
  env <- new.env()
  assign("SAVED_ONLY", TRUE, envir = env)
  tryCatch(source(file.path(Rdir, file), local = env),
           error = function(e) {
             cat("   *** FAILED:", conditionMessage(e), "\n")
             .fail <<- c(.fail, msg)
           })
}

# Required inputs, checked up front so a missing file is named rather than
# surfacing as an obscure error three steps later.
required <- c(
  "output/compass_maps.rds"           = "canonical simulation maps",
  # historical file names: s4_ feeds Table S5 and s5_ feeds Table S6
  "output/s4_repetition_input.rds"    = "packaged Table S5 input (repetition overlays)",
  "output/s5_diagnostics_input.rds"   = "packaged Table S6 input (mechanism diagnostics)",
  "output/rhc_factorial_fast.rds"     = "RHC estimates, basic library",
  "output/rhc_factorial_rf.rds"       = "RHC estimates, extended library",
  # counts, quantiles, shares, and the minimum and maximum fitted propensities
  # (summary statistics; see output/APPLIED_PROVENANCE.md, Unit-level content)
  "output/rhc_overlap_diag.rds"       = "RHC overlap diagnostic (summary statistics)",
  "output/lalonde_estimates.rds"      = "LaLonde estimates (aggregate; Table S11 panel B transcribed)"
)
absent <- required[!file.exists(names(required))]
if (length(absent)) {
  cat("MISSING REQUIRED INPUTS:\n")
  for (i in seq_along(absent)) cat("  !", names(absent)[i], "-", absent[i], "\n")
  if (!interactive()) quit(status = 1)
}

step("Table 3 -- headline simulation table (self-checks against the paper)", "13_table4_headline.R")
step("Supplementary Figures S4-S5 -- the two-axis regime map and S2 coverage", "08_figures_sim.R")
step("Tables S1, S2, S4-S6, S9 -- supplement tables (S9 self-checks against the paper)",
     "09_supplement_tables.R")
step("Table S3 -- single-axis g-split contrast",                             "12_s3_clean_gsplit.R")
step("Table S7 -- bias and Monte Carlo SEs",                                 "10_bias_mcse_and_within_family.R")
step("Tables S10-S11 -- applied estimates (self-check against the paper)",   "applied_tables.R")
step("Supplementary Figures S1-S2 -- RHC forest plot; SE, basic vs extended library",
     "05_figures_rhc.R")
step("Figure 1 -- LaLonde estimate vs truncation bound (Supplementary Figure S3 needs per-unit data)",
     "07_figures_lalonde.R")
step("Recover the canonical pinned truths",                                  "14_recover_truths.R")
step("Record the software environment",                                      "15_record_environment.R")

# Verify the artifacts landed AND were written by this run. A step can return
# without error and write nothing, and the figures are committed, so existence
# alone would pass on a clone even if a step silently did nothing.
expected <- c(
  "output/table4_headline.md"        = "Table 3",
  "images/sim_s2_coverage.pdf"       = "Supplementary Figure S5",
  "images/sim_two_axis_map.pdf"      = "Supplementary Figure S4",
  "images/rhc_forest.pdf"            = "Supplementary Figure S1",
  "images/rhc_se_basic_vs_rich.pdf"  = "Supplementary Figure S2",
  "images/lalonde_truncation.pdf"    = "Figure 1",
  "output/supplement_tables.md"      = "Tables S1, S2, S4-S6, S9",
  "output/s3_clean_gsplit_table.md"  = "Table S3",
  "output/bias_mcse_tables.md"       = "Table S7",
  "output/applied_tables.md"         = "Tables S10-S11",
  "output/truths.rds"                = "recovered truths",
  "output/ENVIRONMENT.md"            = "environment record"
)
fresh   <- file.exists(names(expected)) & file.mtime(names(expected)) >= .t0 - 2
missing <- expected[!fresh]

cat("\n", strrep("=", 70), "\n", sep = "")
if (length(missing)) {
  cat("MISSING OR NOT REWRITTEN BY THIS RUN (", length(missing), "):\n", sep = "")
  for (i in seq_along(missing)) cat("  !", names(missing)[i], "->", missing[i], "\n")
}
if (length(.fail)) {
  cat("FAILED (", length(.fail), " step(s)):\n", sep = "")
  for (s in .fail) cat("  *", s, "\n")
}
if (length(.fail) || length(missing)) {
  cat("\nSaved-results reproduction did NOT complete.\n")
  if (!interactive()) quit(status = 1)
} else {
  cat("\nCOMPLETE: every saved-results element reproduced, with no computation:\n")
  cat("  Table 3, Figure 1, Supplementary Figures S1, S2, S4 and S5, Tables S1-S7 and S9-S11,\n")
  cat("  the truths and the environment record.\n")
  cat("Self-checked against the paper as printed: Table 3 (all 32 cell values), Table S9 and\n")
  cat("Section M (Tables S10-S11), the latter two byte for byte (MD5 of the printed text).\n")
  cat("Tables S1-S7 reproduce the printed values, not the printed formatting; they are not\n")
  cat("checked against the paper's text.\n")
  cat("Table S11 panel B on this route is TRANSCRIBED from the paper, not recomputed: its sample\n")
  cat("sizes and overlap shares, including the 185 treated men, and the 0.49 upper bound on the\n")
  cat("CPS propensity estimates come from the per-unit propensity file, which is not shipped.\n")
  cat("Supplementary Figure S3, the applied refits and the engine validation are in run_all.R.\n")
}
