# =====================================================================
# install_deps.R -- idempotent installer for the COMPASS engine. Checks first;
# installs ONLY the missing packages; installs nothing if all are present.
#   Rscript engine/install_deps.R
# =====================================================================
pkgs <- c("SuperLearner", "dplyr", "tidyr", "ranger", "gam")   # origami dropped (unused; make_folds is local)
miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (!length(miss)) {
  cat("All COMPASS dependencies present:\n  ", paste(pkgs, collapse = ", "), "\n")
} else {
  cat("Installing missing packages:", paste(miss, collapse = ", "), "\n")
  repo <- getOption("repos"); if (is.null(repo[["CRAN"]]) || repo[["CRAN"]] == "@CRAN@")
    repo <- c(CRAN = "https://cloud.r-project.org")
  install.packages(miss, repos = repo)
  still <- miss[!vapply(miss, requireNamespace, logical(1), quietly = TRUE)]
  if (length(still)) stop("FAILED to install: ", paste(still, collapse = ", "))
  cat("Done. All dependencies now present.\n")
}
cat("R", as.character(getRversion()), "\n")
