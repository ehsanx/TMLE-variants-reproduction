
pkgs <- c(
  "SuperLearner", "tmle",
  "ranger", "earth", "glmnet", "gam", "nnet",
  "dplyr", "tidyr", "purrr", "tibble", "haven",
  "ggplot2"
)
to_install <- setdiff(pkgs, rownames(installed.packages()))
if (length(to_install)) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
}
ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
if (all(ok)) cat("dependencies ready:", paste(pkgs, collapse = ", "), "\n") else
  stop("missing: ", paste(pkgs[!ok], collapse = ", "))
