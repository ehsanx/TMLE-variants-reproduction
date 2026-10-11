# =====================================================================
# 15_record_environment.R -- record the software environment.
#
#   Rscript R/15_record_environment.R
#
# Writes output/ENVIRONMENT.md: R version, platform, and the installed version
# of every package the pipeline actually loads, then the production (cluster)
# versions logged in the run manifests, which are the simulation column of the
# paper's Table S8. It lets a later reader tell whether a difference in their
# run is a version difference.
#
# Two limitations:
#   - The session part records the environment of whoever RUNS it, not the
#     environment that produced the committed canonical results. The cluster
#     environment is known through the per-shard run manifests, which logged at
#     run time the R version and five package versions (SuperLearner, ranger,
#     gam, dplyr, tidyr; repeated in the output). The version of nnls, which
#     SuperLearner loads, and of any other package the manifests did not log is
#     unknown; a version installed today cannot establish what the jobs loaded.
#   - dependencies.R does not pin versions, so a fresh install takes current
#     CRAN. The applied analyses are seeded, so they are reproducible within a
#     version set, not across one.
# =====================================================================

OUT <- "output/ENVIRONMENT.md"

# Packages the pipeline loads, gathered from the scripts themselves rather than
# hard-coded, so this cannot drift from the code.
rfiles <- list.files("R", pattern = "\\.R$", full.names = TRUE)
src <- unlist(lapply(rfiles, readLines, warn = FALSE))
pat <- "(?:library|require)\\(\\s*['\"]?([A-Za-z][A-Za-z0-9.]*)|([A-Za-z][A-Za-z0-9.]*)::"
hits <- regmatches(src, gregexpr(pat, src, perl = TRUE))
pkgs <- unique(unlist(lapply(unlist(hits), function(h) {
  m <- regmatches(h, regexec(pat, h, perl = TRUE))[[1]]
  p <- m[2]; if (is.na(p) || !nzchar(p)) p <- m[3]
  p
})))
pkgs <- sort(setdiff(pkgs[nzchar(pkgs)], c("base", "stats", "utils", "tools", "methods", "parallel", "graphics", "grDevices")))

ver <- vapply(pkgs, function(p) {
  v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  if (is.na(v)) "NOT INSTALLED" else v
}, character(1))

si <- utils::sessionInfo()
md <- c(
  "# Software environment",
  "",
  sprintf("Recorded %s by `R/15_record_environment.R`.", Sys.Date()),
  "",
  "## This session",
  "",
  sprintf("- %s", si$R.version$version.string),
  sprintf("- platform: %s", si$platform),
  sprintf("- running: %s", si$running),
  "",
  "## Packages the pipeline loads",
  "",
  "Gathered by scanning `R/*.R` for `library()`, `require()` and `::` uses, so this list",
  "cannot drift from the code. Base packages are omitted.",
  "",
  "| Package | Version in this session |",
  "|---|---|",
  sprintf("| `%s` | %s |", names(ver), ver),
  "",
  "## The PRODUCTION environment (what actually produced the committed results)",
  "",
  "This was captured at run time, in the per-shard run manifests. All 16 agree:",
  "",
  "| Component | Production version |",
  "|---|---|",
  "| R | 4.4.0 (2024-04-24) |",
  "| `SuperLearner` | 2.0.40 |",
  "| `ranger` | 0.18.0 |",
  "| `gam` | 1.22.7 |",
  "| `dplyr` | 1.1.4 |",
  "| `tidyr` | 1.3.1 |",
  "",
  "The same manifests record `truth_source=pinned` with `D1=-0.1081358 D3=0.1006854`, which",
  "independently corroborates the recovered truths in `output/TRUTHS_PROVENANCE.md`, and the",
  "engine build `fb161fe`.",
  "",
  "**Genuinely unknown:** the manifests cover only the packages the cluster worker loaded. The",
  "versions of `tmle`, `ggplot2`, `haven`, `purrr` and `tibble` used for the applied analyses and",
  "the figures appear in no manifest and are **not recoverable** — they are unknown, not assumed",
  "to match the table above.",
  "",
  "## Limitations, stated plainly",
  "",
  "1. **The table in the previous section is the production environment; the table above it is",
  "   this session's.** Where they differ, a difference in your run may be a version difference",
  "   rather than a reproduction failure. `output/compass_maps.rds` and `output/compass_report.txt`",
  "   remain the authoritative results.",
  "2. **Versions are not pinned.** `dependencies.R` installs current CRAN. The applied analyses",
  "   are seeded (`set.seed(2026)`), so they reproduce within a version set but not necessarily",
  "   across one — Super Learner and `ranger` in particular can change fitted values across major",
  "   versions.",
  "",
  "To pin for a future run, capture this file's table with `renv::snapshot()` or an explicit",
  "version list and install against it."
)
writeLines(md, OUT)

cat("\nR:", si$R.version$version.string, "\n")
cat("platform:", si$platform, "\n\n")
print(data.frame(package = names(ver), version = unname(ver), row.names = NULL))
cat("\n[written]", OUT, "\n")
