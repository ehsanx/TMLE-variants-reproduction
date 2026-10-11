# =====================================================================
# run_all.R -- reproduce the laptop-runnable elements of the paper.
#
# Run from the repository root; every path below is repo-relative.
#
#   Rscript run_all.R        (or source("run_all.R") in an R session)
#
# What this does and does NOT do
# ------------------------------
# The known-truth SIMULATION is not re-run here. It ran on a Slurm cluster and
# its aggregated result is committed as output/compass_maps.rds, so steps 4-5
# FORMAT those saved results into the paper's tables and figures. To regenerate
# the map itself from scratch, see sim/ and the README.
#
# Steps 0-3 and 6 do compute: they fit Super Learners on the two applied
# datasets and on simulated data for the engine validation. Each is seeded, so
# the published numbers are reproducible given the same package versions --
# note that dependencies.R does NOT pin versions (see the README caveat).
# They rewrite the committed saved results in output/ (rhc_factorial_*.rds,
# rhc_overlap_diag.rds, lalonde_estimates.rds; see output/APPLIED_PROVENANCE.md)
# and write the unshipped per-unit output/lalonde_overlap.rds for Supplementary
# Figure S3.
# Everything that needs no fitting is also in run_saved.R, which uses the
# committed results only.
#
# Failures are LOUD. Every step that errors is recorded, reported at the end,
# and the script exits non-zero. A run that prints "COMPLETE" really did
# reproduce; anything else did not.
# =====================================================================

Rdir <- "R"
.t0  <- Sys.time()

.failures <- character(0)
.skipped  <- character(0)

step <- function(msg, expr) {
  cat("\n==>", msg, "\n")
  tryCatch(
    force(expr),
    error = function(e) {
      cat("   *** FAILED:", conditionMessage(e), "\n")
      .failures <<- c(.failures, msg)
    }
  )
}

# A step whose inputs are legitimately absent from a public clone (the
# per-replicate cluster shards). Recorded separately so it is never mistaken
# for a reproduction failure -- but still reported, never silent.
step_optional <- function(msg, expr) {
  cat("\n==>", msg, "\n")
  tryCatch(
    force(expr),
    error = function(e) {
      cat("   --- UNAVAILABLE:", conditionMessage(e), "\n")
      .skipped <<- c(.skipped, msg)
    }
  )
}

step("0. Fetch the benchmark data + prepare the RHC analysis file",
     { source("data-raw/get_data.R"); source(file.path(Rdir, "00_prepare_rhc.R")) })

step("1. Validate the engine against the tmle package",
     source(file.path(Rdir, "03_verify_engine.R")))

# Supplementary Figure S2 and Table S10 compare the BASIC and EXTENDED Super
# Learner libraries, so the factorial runs twice, exactly as in the paper:
#   basic    SL.glm + SL.mean              split arms over R = 10 splits ("10 fast")
#   extended SL.glm + SL.mean + SL.ranger  every arm one split, R = 1   ("1 rf")
# The "rich" profile (+ SL.earth) was NOT used in the paper. The commandArgs
# override is scoped to each local() so it cannot leak into later steps.
step("2a. RHC factorial, basic library (GLM + mean), R = 10",
     local({ commandArgs <- function(trailingOnly = FALSE) c("10", "fast")
             source(file.path(Rdir, "04b_run_rhc_factorial.R"), local = environment()) }))
step("2b. RHC factorial, extended library (GLM + mean + ranger), R = 1",
     local({ commandArgs <- function(trailingOnly = FALSE) c("1", "rf")
             source(file.path(Rdir, "04b_run_rhc_factorial.R"), local = environment()) }))
step("2c. RHC figures (Supplementary Figures S1-S2: forest plot; SE, basic vs extended)",
     source(file.path(Rdir, "05_figures_rhc.R"), local = new.env()))

step("3. LaLonde application: overlap + truncation, then Supplementary Figure S3 and Figure 1",
     { source(file.path(Rdir, "06_lalonde_overlap.R"))
       source(file.path(Rdir, "07_figures_lalonde.R")) })

step("4. Simulation figures (Supplementary Figures S4-S5), from the committed output/compass_maps.rds",
     source(file.path(Rdir, "08_figures_sim.R")))

# Split out so one unavailable table cannot take the others down with it.
# Tables S5/S6 read the raw shards when a cluster run has populated output/sim/,
# and otherwise the packaged inputs committed here (historical file names
# s4_repetition_input.rds and s5_diagnostics_input.rds), so this is no longer optional.
step("5a. Supplement Tables S1, S2, S4-S6 and S9",
     source(file.path(Rdir, "09_supplement_tables.R"), local = new.env()))
step("5b. Table 3: headline simulation table, formatted from the committed maps",
     source(file.path(Rdir, "13_table4_headline.R"), local = new.env()))

step("5c. Supplement Table S7: per-estimator bias + Monte Carlo SEs",
     source(file.path(Rdir, "10_bias_mcse_and_within_family.R"), local = new.env()))
step("5d. Supplement Table S3: single-axis g-split contrast",
     source(file.path(Rdir, "12_s3_clean_gsplit.R"), local = new.env()))

step("6. RHC overlap diagnostic",
     source(file.path(Rdir, "11_rhc_overlap_diagnostic.R"), local = new.env()))

# After steps 2, 3 and 6, which rewrote its inputs. With freshly refitted inputs a
# difference from the printed tables is reported, not fatal (package versions).
step("7. Supplement Tables S10-S11: applied estimates, from the results above",
     source(file.path(Rdir, "applied_tables.R"), local = new.env()))

# ---------------------------------------------------------------------
# Check the artifacts actually landed AND were written by this run. A step can
# return without error and still not write its output, and the figures are
# committed, so existence alone would pass even if a step silently did nothing.
# ---------------------------------------------------------------------
expected <- c(
  "images/sim_s2_coverage.pdf"       = "Supplementary Figure S5",
  "images/sim_two_axis_map.pdf"      = "Supplementary Figure S4",
  "images/rhc_forest.pdf"            = "Supplementary Figure S1",
  "images/rhc_se_basic_vs_rich.pdf"  = "Supplementary Figure S2",
  "images/lalonde_overlap.pdf"       = "Supplementary Figure S3",
  "images/lalonde_truncation.pdf"    = "Figure 1",
  "output/table4_headline.md"        = "Table 3",
  "output/supplement_tables.md"      = "Tables S1, S2, S4-S6, S9",
  "output/s3_clean_gsplit_table.md"  = "Table S3",
  "output/bias_mcse_tables.md"       = "Table S7",
  "output/applied_tables.md"         = "Tables S10-S11"
)
missing <- expected[!(file.exists(names(expected)) &
                      file.mtime(names(expected)) >= .t0 - 2)]

# ---------------------------------------------------------------------
# Report, and make the exit status mean something.
# ---------------------------------------------------------------------
cat("\n", strrep("=", 70), "\n", sep = "")
if (length(.skipped)) {
  cat("UNAVAILABLE (inputs not present in this clone):\n")
  for (s in .skipped) cat("  -", s, "\n")
}
if (length(missing)) {
  cat("MISSING ARTIFACTS (", length(missing), "): not written by this run:\n", sep = "")
  for (i in seq_along(missing)) cat("  !", missing[i], "->", names(missing)[i], "\n")
}
if (length(.failures)) {
  cat("FAILED (", length(.failures), " step(s)):\n", sep = "")
  for (s in .failures) cat("  *", s, "\n")
}

if (length(.failures) || length(missing)) {
  cat("\nThe reproduction did NOT complete. See images/ and output/ for what did succeed.\n")
  if (!interactive()) quit(status = 1)
} else if (length(.skipped)) {
  cat("\nPARTIAL: every step that could run did run, and every expected artifact above\n")
  cat("was produced -- but the items listed as UNAVAILABLE were not attempted.\n")
  cat("Those items need inputs this clone does not have (see the README).\n")
  if (!interactive()) quit(status = 2)
} else {
  cat("\nCOMPLETE: every step ran and every expected artifact was produced.\n")
  cat("The known-truth simulation itself runs on a cluster; see sim/ and the README.\n")
}
