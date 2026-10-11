# Provenance of the committed applied-analysis results

Added 2026-10-05, with NO model refit and no data read. These four files let Supplement
Tables S10-S11, Supplementary Figures S1-S2 and main-paper Figure 1 reproduce from a clone
without the benchmark data (`run_saved.R`). They hold summary results: estimates, intervals, counts,
quantiles, shares and, in `rhc_overlap_diag.rds`, the minimum and maximum fitted propensity
scores overall and within each arm. See [Unit-level content](#unit-level-content).

| File | What it is | Produced by | SHA-256 |
|---|---|---|---|
| `rhc_factorial_fast.rds` | RHC, basic library (`SL.glm` + `SL.mean`), split arms median-aggregated over R = 10: one row per arm | `Rscript R/04b_run_rhc_factorial.R 10 fast` | `052ea34c9e0489e34706937b78488e8ffae058a60d8a9b3a47ab3dee8dbc626c` |
| `rhc_factorial_rf.rds` | RHC, extended library (`SL.glm` + `SL.mean` + `SL.ranger`), every arm R = 1: one row per arm | `Rscript R/04b_run_rhc_factorial.R 1 rf` | `f1276c2bed9d45c899b9e510422b26816330d136ca505ac0cc81a9bbb4ff256d` |
| `rhc_overlap_diag.rds` | RHC overlap diagnostic of a logistic propensity fit: counts, quantiles, shares, and the minimum and maximum fitted propensity overall and by arm | `Rscript R/11_rhc_overlap_diagnostic.R` | `ab4df66f8fbead99a3fd8a00249ddb5a308598be40e63b999b786ba557cedf6d` |
| `lalonde_estimates.rds` | LaLonde/NSW: estimates, benchmark, truncation sweep, sample and overlap summaries | `Rscript R/16_lalonde_estimates_from_saved.R` (see below) | `286bb74c039bde6d2f021634958b39059bb13d3119c4db8e5494159bf804520f` |

MD5s (checked by `R/applied_tables.R`): `3b86264c718258d9ab664cd3cdd6e03b`,
`d5a2b94523bd225acce518698aaf5602`, `106c4e7b3044272d89b35f8bf9aca41c`,
`c2a7d69c770aefc277eac0d0e4c60c0e`, in the order of the table.

## Where they came from

**The three RHC files** are byte-for-byte copies (SHA-256 equal) of the saved outputs of the
runs reported in the paper, taken from the authors' results directory; they were produced by
the commands in the table, on the 5,735-patient RHC analysis file. Contents:

- `rhc_factorial_fast.rds`, `rhc_factorial_rf.rds`: `list(table, sl_lib, R, n)`. `table` has one
  row per estimator arm (13 and 14 rows) with columns `order, method, rd, se, ci_lo, ci_hi, folk,
  splits, R, runtime_s, library`: the point estimate, its SE and interval, flags, the number of
  repetitions and the run time in seconds. `n` is 5735. The `library` column of the extended
  file reads `"Basic (GLM+mean)"` because `04b` then labelled every profile except `rich` as
  Basic (fixed since; the label is now built from `sl_lib`). The library actually used is the
  saved `sl_lib`, which `applied_tables.R` reports. The file is kept unchanged, label included,
  so that it remains the run's own output.
- `rhc_overlap_diag.rds`: 15 elements: `n`, `n_treated`, `prev_treated`; the minimum and
  maximum of the fitted propensity overall and by arm; its 1/5/25/50/75/95/99% quantiles; and
  the fractions below 0.025 and 0.01, above 0.975 and 0.99, and outside [0.025, 0.975]. The
  minima and maxima are summary order statistics of the fitted score, like its quantiles. The
  paper quotes the overall range (0.002 to 0.978).

**`lalonde_estimates.rds`** is new. `R/06_lalonde_overlap.R` saves its results as
`output/lalonde_overlap.rds` (SHA-256
`37d02d11154aa3520bb90496ff799c484271211917f2e9ac17377a314f8c2ff8` for the run the paper
reports). That file also holds `$ps`, the estimated propensity score of every pooled unit (one
row per unit, for Supplementary Figure S3), so it is never committed or bundled. `R/16_lalonde_estimates_from_saved.R`
loads it, drops `$ps` unread, checks the source checksum, and copies the aggregate elements
unchanged: `benchmark_emp` and `benchmark_earn` (the NSW experimental differences), `cps` and
`psid` (four estimators each: estimate, SE, interval, whether it reaches the benchmark) and
`trunc` (vanilla TMLE on the CPS comparison at four truncation bounds, as in main-paper Figure 1).

Its `overlap` table (Table S11 panel B: pooled n, treated, comparison units, the truncated
shares and the share of comparison units with g < 0.01) and the CPS propensity maximum quoted
in that table's note (0.49, rounded up to 0.01) are **transcribed from the paper as printed**,
not recomputed; so is the treated count, 185, that the table's introduction quotes, which
`applied_tables.R` reads from the same `overlap` table. They come from the per-unit results
file and its `$ps`, which is not shipped and was not read for this file. The shares are
therefore stored rounded to 0.1 percentage point, as printed.
One of them is checked against the saved estimates: the CPS pooled n, 16,177, reproduces the
saved default truncation bound 5/(sqrt(n) log n) = 0.004056364034 to 1e-12. The file states
this in its own `overlap_source` element, and `applied_tables.R` prints it when it runs.
A clone can therefore **verify panel B only for consistency, not reproduce it**. From now
on, `R/06_lalonde_overlap.R` writes `output/lalonde_estimates.rds` itself, with the same
structure and the overlap summaries computed unrounded from the propensity estimates at save
time, so a fresh run needs neither the transcription nor script 16.

## Unit-level content

Checked by listing every element of each file (`str()`). The longest component has 13, 14, 7
and 4 elements respectively (estimator arms, quantiles, estimators), against analysis
samples of 5,735 (RHC) and 16,177 and 2,675 (LaLonde). No file holds a covariate, an outcome,
an identifier or a per-unit vector of fitted values.

The files also hold summary order statistics of the fitted propensity scores, listed here so
that their content is explicit:

- `rhc_overlap_diag.rds`: `g_min`, `g_max`, `g_min_treated`, `g_max_treated`,
  `g_min_control` and `g_max_control`, the minimum and maximum fitted propensity scores overall
  and within each arm.
- `lalonde_estimates.rds`: `g_max_ceil2`, the CPS propensity maximum, stored only as an upper
  bound rounded up to 0.01 (0.49), as the paper prints it.

Like the quantiles beside them, these are summary statistics of the fitted scores, not
covariates, outcomes or identifiers.

Besides the simulation results, these four are the only `.rds` files that
`make_review_bundle.sh` allows; it still blocks `lalonde_overlap*.rds` and `rhc_analysis*.rds`.

The benchmark data's own terms (README, Data) still apply to the data. These files carry
results of analyses of those data at the level the paper reports them.

## Overwritten by a full re-run

`run_all.R` re-runs `04b`, `06` and `11`, which rewrite these files in place (run times, and
the panel-B overlap summaries now unrounded, change the bytes even when the estimates
reproduce). In a git checkout, `git diff --stat output/` then shows them modified and
`git checkout -- output/` restores the committed versions the paper reports; from an unpacked
archive, unpack it again.
