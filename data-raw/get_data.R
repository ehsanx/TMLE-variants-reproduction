#!/usr/bin/env Rscript
# Download the public benchmark data from their canonical sources into data/.
# Usage:  Rscript data-raw/get_data.R [target_dir]   (default target_dir = "data")
# Idempotent: files already present are kept. run_all.R calls this first.
#
# Sources and terms (this repository does not redistribute the data; see README.md, Data):
#   rhc.csv -- Data obtained from http://hbiostat.org/data courtesy of the Vanderbilt
#     University Department of Biostatistics. Cite Connors et al. (1996), JAMA 276:889-897.
#   nsw_dw.dta, cps_controls.dta, psid_controls.dta -- Rajeev Dehejia's data page,
#     https://users.nber.org/~rdehejia/nswdata2.html, distributed for attributable
#     non-commercial use (CC BY-NC 2.0, https://creativecommons.org/licenses/by-nc/2.0/).
#     Cite Dehejia and Wahba (1999, 2002) and LaLonde (1986).

args     <- commandArgs(trailingOnly = TRUE)
dest_dir <- if (length(args) >= 1) args[1] else "data"
dir.create(file.path(dest_dir, "lalonde_nsw"), recursive = TRUE, showWarnings = FALSE)

get1 <- function(url, path) {
  if (file.exists(path)) { cat("  have    ", path, "\n"); return(invisible()) }
  cat("  download", url, "\n")
  utils::download.file(url, path, mode = "wb", quiet = TRUE)
}

nber <- "https://users.nber.org/~rdehejia/data"
get1("https://hbiostat.org/data/repo/rhc.csv",       file.path(dest_dir, "rhc.csv"))
get1(file.path(nber, "nsw_dw.dta"),        file.path(dest_dir, "lalonde_nsw", "nsw_dw.dta"))
get1(file.path(nber, "cps_controls.dta"),  file.path(dest_dir, "lalonde_nsw", "cps_controls.dta"))
get1(file.path(nber, "psid_controls.dta"), file.path(dest_dir, "lalonde_nsw", "psid_controls.dta"))
# Integrity: the MD5s of the files this paper used. A mismatch means the source changed.
expected_md5 <- c(
  "rhc.csv"                       = "a765300feca874a1bed613b2a7df374b",
  "lalonde_nsw/nsw_dw.dta"        = "e3367ddd449e25cb4c54c04263978800",
  "lalonde_nsw/cps_controls.dta"  = "16c15fe26d6dd2b12107f94f357321fd",
  "lalonde_nsw/psid_controls.dta" = "1ae3ab3bc7c40048f41b0953a5e634f8")
got <- tools::md5sum(file.path(dest_dir, names(expected_md5)))
bad <- names(expected_md5)[unname(got) != unname(expected_md5)]
if (length(bad)) stop("MD5 mismatch (the source file differs from the one the paper used): ",
                      paste(bad, collapse = ", "))
cat("benchmark data ready in", dest_dir, "(MD5 verified)\n")
