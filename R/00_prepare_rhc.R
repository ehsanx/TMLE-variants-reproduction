# =====================================================================
# 00_prepare_rhc.R
# Prepare the Right Heart Catheterization (RHC / SUPPORT) data for the
# TMLE-variants tutorial.
#
# Source: Connors et al. (1996) JAMA; public copy from the Vanderbilt University
# Department of Biostatistics (hbiostat.org/data), downloaded by
# data-raw/get_data.R. This script reads data/rhc.csv and writes a clean
# analysis file.
#
# Estimand: ATE (risk difference) of RHC (swang1 == "RHC") on 30-day mortality.
#   A = 1 if RHC within 24h of admission, else 0
#   Y = 1 if died within 30 days (dth30 == "Yes"), else 0
# Adjustment set: the standard Hirano-Imbens / Connors covariate set.
# =====================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
rhc_csv <- if (length(args) >= 1) args[1] else
  "data/rhc.csv"
out_rds <- if (length(args) >= 2) args[2] else
  "data/rhc_analysis.rds"

raw <- read.csv(rhc_csv, stringsAsFactors = FALSE)

# ---- treatment and outcome ----
raw$A <- as.integer(raw$swang1 == "RHC")
raw$Y <- as.integer(raw$dth30 == "Yes")   # 30-day mortality

# ---- covariates (Connors / Hirano-Imbens adjustment set) ----
# Continuous physiologic and demographic measures
cont_vars <- c("age", "edu",
               "das2d3pc",  # DASI activity index
               "aps1",      # APACHE III score
               "scoma1",    # Glasgow coma score
               "meanbp1", "wblc1", "hrt1", "resp1", "temp1",
               "pafi1", "alb1", "hema1", "bili1", "crea1",
               "sod1", "pot1", "paco21", "ph1",
               "wtkilo1")

# Binary comorbidity history flags (already "Yes"/"No")
hx_vars <- c("cardiohx", "chfhx", "dementhx", "psychhx", "chrpulhx",
             "renalhx", "liverhx", "gibledhx", "malighx", "immunhx",
             "transhx", "amihx")

# Categorical
cat_vars <- c("sex", "race", "income", "ninsclas", "cat1", "ca",
              "resp", "card", "neuro", "gastr", "renal", "meta",
              "hema", "seps", "trauma", "ortho", "dnr1")

keep <- c("A", "Y", cont_vars, hx_vars, cat_vars)
d <- raw[, keep, drop = FALSE]

# hx flags: some are already 0/1 integers, some "Yes"/"No" — coerce all to 0/1
for (v in hx_vars) {
  if (is.character(d[[v]])) d[[v]] <- as.integer(d[[v]] == "Yes")
  d[[v]] <- as.integer(d[[v]])
}

# categoricals -> factors
for (v in cat_vars) d[[v]] <- as.factor(d[[v]])

# complete cases on the analysis variables
n0 <- nrow(d)
d <- d[stats::complete.cases(d), , drop = FALSE]
message(sprintf("RHC: %d rows, %d after complete-case (%d dropped)",
                n0, nrow(d), n0 - nrow(d)))
message(sprintf("Treated (RHC): %d  Control: %d", sum(d$A), sum(1 - d$A)))
message(sprintf("30-day mortality: overall %.3f | RHC %.3f | no-RHC %.3f",
                mean(d$Y), mean(d$Y[d$A == 1]), mean(d$Y[d$A == 0])))
message(sprintf("Unadjusted risk difference: %.4f",
                mean(d$Y[d$A == 1]) - mean(d$Y[d$A == 0])))

covariates <- c(cont_vars, hx_vars, cat_vars)
attr(d, "covariates") <- covariates
attr(d, "outcome") <- "Y"
attr(d, "treatment") <- "A"

dir.create(dirname(out_rds), recursive = TRUE, showWarnings = FALSE)
saveRDS(list(data = d, covariates = covariates,
             outcome = "Y", treatment = "A"),
        out_rds)
message("Wrote ", out_rds)
