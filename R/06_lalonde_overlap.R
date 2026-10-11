# =====================================================================
# 06_lalonde_overlap.R -- the LaLonde/NSW overlap teaching moment.
#
# The NSW randomized experiment gives a benchmark ATE. We then estimate the
# SAME effect using the experimental treated group plus a NON-experimental
# control group (CPS or PSID), where overlap is poor. The lesson: because all
# the variants share one influence function, they agree under good overlap and
# degrade TOGETHER under poor overlap -- so the positivity diagnosis, not the
# estimator label, carries the analysis.
#
# Binary outcome: employed in 1978 (re78 > 0), so the binary-outcome engine
# applies. (Earnings benchmark ~ $1794 is quoted for context only.)
# =====================================================================
here <- "R"
source(file.path(here, "01_engine.R"))
source(file.path(here, "02_variants.R"))
suppressPackageStartupMessages({ library(haven); library(dplyr) })

datadir <- "data/lalonde_nsw"
dw  <- haven::read_dta(file.path(datadir, "nsw_dw.dta"))   # Dehejia-Wahba experimental
cps <- haven::read_dta(file.path(datadir, "cps_controls.dta"))
psid<- haven::read_dta(file.path(datadir, "psid_controls.dta"))

prep <- function(df) {
  df$emp78 <- as.integer(df$re78 > 0)
  df
}
dw <- prep(dw); cps <- prep(cps); psid <- prep(psid)

covs <- c("age","education","black","hispanic","married","nodegree","re74","re75")

# ---- benchmark: the randomized experiment (treated vs experimental controls) ----
exp_treat <- dw[dw$treat == 1, ]; exp_ctrl <- dw[dw$treat == 0, ]
bench_emp  <- mean(exp_treat$emp78) - mean(exp_ctrl$emp78)
bench_earn <- mean(exp_treat$re78)  - mean(exp_ctrl$re78)
cat(sprintf("NSW randomized benchmark: employed78 RD = %+.4f ; earnings = $%.0f\n",
            bench_emp, bench_earn))
cat(sprintf("  (experimental: %d treated, %d controls)\n", nrow(exp_treat), nrow(exp_ctrl)))

sl_lib <- c("SL.glm", "SL.mean")

analyze <- function(ctrl_df, name) {
  d <- dplyr::bind_rows(exp_treat, ctrl_df)
  Y <- d$emp78; A <- as.integer(d$treat)
  W <- as.data.frame(d[, covs]); W[] <- lapply(W, as.numeric)
  cat(sprintf("\n--- Observational sample: experimental treated + %s controls (n=%d, treated=%d) ---\n",
              name, nrow(d), sum(A)))

  # overlap diagnostic: propensity score spread
  g <- fit_sl(A, W, stats::binomial(), sl_lib, 5L)(W)
  cat(sprintf("  propensity range [%.4f, %.4f]; %% with g<0.01 or g>0.99: %.1f%%\n",
              min(g), max(g), 100*mean(g < 0.01 | g > 0.99)))

  variants <- list(
    TMLE   = list(scheme="none", target="pooled"),
    AIPW   = list(scheme="none", target="onestep"),
    CVTMLE = list(scheme="cv", V=5, target="pooled",   agg_fold=FALSE),
    DCTMLE = list(scheme="cf3", target="foldwise", agg_fold=TRUE)
  )
  out <- list()
  for (nm in names(variants)) {
    set.seed(2026)
    res <- tryCatch({
      if (variants[[nm]]$scheme == "cf3") {
        rr <- run_repeated(Y, A, W, variants[[nm]], sl_lib, sl_lib, R=20, rule="median", seed=2026)
        r <- rr$aggregated; list(rd=r$rd, se=sqrt(r$mvd))
      } else {
        r <- run_once(Y, A, W, variants[[nm]], sl_lib, sl_lib); list(rd=r$rd, se=sqrt(r$vd))
      }
    }, error=function(e){cat("   ",nm,"ERR",conditionMessage(e),"\n"); list(rd=NA,se=NA)})
    out[[nm]] <- dplyr::tibble(control=name, method=nm, rd=res$rd, se=res$se,
                               ci_lo=res$rd-1.96*res$se, ci_hi=res$rd+1.96*res$se,
                               covers_benchmark = (res$rd-1.96*res$se <= bench_emp) & (bench_emp <= res$rd+1.96*res$se))
    cat(sprintf("  %-7s rd=%+.4f  se=%.4f  covers benchmark(%.3f): %s\n",
                nm, res$rd, res$se, bench_emp, out[[nm]]$covers_benchmark))
  }
  dplyr::bind_rows(out)
}

res_cps  <- analyze(cps,  "CPS")
res_psid <- analyze(psid, "PSID")

# ---- truncation sensitivity on the CPS sample (one estimator, several bounds) ----
# Under poor overlap the propensity-truncation rule -- an implementation detail --
# moves both the point estimate and whether the interval covers the benchmark.
cat("\n--- Truncation sensitivity (vanilla TMLE, CPS controls) ---\n")
d <- dplyr::bind_rows(exp_treat, cps)
Yc <- d$emp78; Ac <- as.integer(d$treat); Wc <- as.data.frame(lapply(d[, covs], as.numeric))
gb_default <- 5/(sqrt(length(Yc))*log(length(Yc)))   # the tmle package default
trunc_rows <- list()
for (gb in c(gb_default, 0.01, 0.025, 0.05)) {
  set.seed(2026)
  r <- run_once(Yc, Ac, Wc, list(scheme="none", target="pooled"),
                sl_lib, sl_lib, gbound = gb)
  se <- sqrt(r$vd)
  trunc_rows[[length(trunc_rows)+1]] <- dplyr::tibble(
    gbound = gb, rd = r$rd, se = se, ci_lo = r$rd-1.96*se, ci_hi = r$rd+1.96*se,
    covers = (r$rd-1.96*se <= bench_emp) & (bench_emp <= r$rd+1.96*se))
  cat(sprintf("  gbound=%.4f  rd=%+.4f  se=%.4f  covers %.3f: %s\n",
              gb, r$rd, se, bench_emp, tail(trunc_rows,1)[[1]]$covers))
}
trunc <- dplyr::bind_rows(trunc_rows)

# ---- save propensity scores for the overlap figure ----
ps_of <- function(ctrl_df) {
  dd <- dplyr::bind_rows(exp_treat, ctrl_df)
  A <- as.integer(dd$treat); W <- as.data.frame(lapply(dd[, covs], as.numeric))
  g <- fit_sl(A, W, stats::binomial(), sl_lib, 5L)(W)
  data.frame(g = g, treated = A)
}
set.seed(2026); ps_cps  <- ps_of(cps);  ps_cps$control  <- "CPS"
set.seed(2026); ps_psid <- ps_of(psid); ps_psid$control <- "PSID"

# Full results, INCLUDING the per-unit propensity vector $ps (one row per pooled
# unit) that Supplementary Figure S3 draws. Derived from the benchmark data, so
# this file is never committed or bundled (.gitignore; make_review_bundle.sh blocks it).
saveRDS(list(benchmark_emp=bench_emp, benchmark_earn=bench_earn,
             cps=res_cps, psid=res_psid, trunc=trunc,
             ps = dplyr::bind_rows(ps_cps, ps_psid)),
        "output/lalonde_overlap.rds")
cat("\nWrote lalonde_overlap.rds\n")

# ---- aggregate-only companion file: the shippable one ----
# Everything Table S11 (R/applied_tables.R) and Figure 1 (R/07_figures_lalonde.R)
# need, with NO per-unit vector: the estimates, the benchmark, the truncation
# sweep, and panel B's sample and overlap summaries computed here from the
# whole-sample (no-split) propensity estimates (counts, shares, and the CPS
# and PSID propensity maxima rounded up to 0.01, the CPS one as quoted in the
# table note; these maxima are summary order statistics). The committed copy
# of this file was built from the paper's results by
# R/16_lalonde_estimates_from_saved.R; see output/APPLIED_PROVENANCE.md.
overlap_of <- function(p, name) {
  out <- p$g < 0.025 | p$g > 0.975
  data.frame(control = name, n = nrow(p), n_treated = sum(p$treated == 1),
             n_control = sum(p$treated == 0),
             trunc_all = mean(out), trunc_treated = mean(out[p$treated == 1]),
             control_g_lt_0.01 = mean(p$g[p$treated == 0] < 0.01),
             g_max_ceil2 = ceiling(100 * max(p$g)) / 100, stringsAsFactors = FALSE)
}
plain <- function(x) { x <- as.data.frame(x, stringsAsFactors = FALSE); class(x) <- "data.frame"
  rownames(x) <- NULL; x }
saveRDS(list(benchmark_emp = bench_emp, benchmark_earn = bench_earn,
             cps = plain(res_cps), psid = plain(res_psid), trunc = plain(trunc),
             overlap = rbind(overlap_of(ps_cps, "CPS"), overlap_of(ps_psid, "PSID")),
             overlap_source = paste("computed by R/06_lalonde_overlap.R from the whole-sample",
                                    "(no-split) propensity estimates at save time"),
             provenance = paste("written by R/06_lalonde_overlap.R; aggregate values plus the CPS and",
                                "PSID propensity maxima rounded up to 0.01 (no per-unit vector)")),
        "output/lalonde_estimates.rds")
cat("Wrote lalonde_estimates.rds (aggregate values; no per-unit vector)\n")
