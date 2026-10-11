# When Sample-Splitting Choices Matter in TMLE and AIPW: Cross-Fitting, Targeting, and Repetition

Code, saved results and figures for the paper. Every estimator is built from one influence function on
a shared nuisance-and-fold engine, so any difference between two estimators is a design choice, not the
implementation.

**The known-truth simulation is not re-run here.** It ran on a Slurm cluster; its aggregated result is
committed as `output/compass_maps.rds`, and the scripts below *format* that saved result into the
paper's simulation tables and figures. The two applied analyses (RHC, LaLonde) and the engine
validation do compute, on a laptop, in a few minutes each; their saved results are committed too,
so their tables and all but one of their figures also reproduce without the data.

## Quick start

```r
source("dependencies.R")   # install the required R packages

source("run_saved.R")      # saved results only: no network, no data, no fitting, under a minute
source("run_all.R")        # downloads the data, refits the applied analyses and the engine
                           # validation, then formats the tables and figures as run_saved.R
                           # does (the recovered truths and the environment record come from
                           # run_saved.R only)
```

`run_saved.R` reproduces every element that comes from committed results: **Table 3, Figure 1,
Supplementary Figures S1, S2, S4 and S5, and Supplement Tables S1-S7 and S9-S11**, plus the recovered canonical
truths and a software-environment record. It fits nothing, downloads nothing and reads no benchmark data.
Three elements check themselves against the paper as printed, and only these: Table 3 compares its
32 cell values with the printed ones, string for string, and Table S9 and Section M
(Tables S10-S11) are compared byte for byte with the Supplement's text (by MD5). The generated
markdown for Tables S1-S7 reproduces the printed **values** but not the printed formatting (table
titles, regime and column labels, number formats, notes; the Table S7 file also carries an empirical-SE MCSE column the paper
omits), so compare those tables by value. The figures are not compared automatically. It does
**not** produce **Supplementary Figure S3**, which draws per-unit propensity
scores that are not shipped (see [What reproduces from what](#what-reproduces-from-what)). It ends
with `COMPLETE` and exit status 0 only if every step ran and every expected file was **rewritten by
that run** (the figures are committed, so existence alone would prove nothing).

Run from the repository root; all paths are repo-relative. `run_all.R` applies the same rule. It
ends in exactly one of three states, and the exit status matches:

| Outcome | Exit | Meaning |
|---|---|---|
| `COMPLETE` | 0 | every step ran and every expected artifact was written by this run |
| `PARTIAL` | 2 | everything runnable ran, but items listed as `UNAVAILABLE` were not attempted |
| `FAILED` / `MISSING ARTIFACTS` | 1 | a step errored, or ran without writing its output |

A clean clone with network access should report **`COMPLETE`**. Its refits rewrite the committed
saved results in `output/` (see [Canonical results](#canonical-results)); with package
versions other than the paper's, Tables S10-S11 may then differ from the printed ones, which
`R/applied_tables.R` reports without failing.

## What reproduces from what

Three routes, from cheapest to most expensive:

- **Saved** — formatted from files committed to this repository. No data, no model fitting, no network.
  Run by `run_saved.R` (and by `run_all.R`).
- **Data + fitting** — needs the benchmark data, which `data-raw/get_data.R` downloads (not
  redistributed; see [Data](#data)), and fits Super Learners on a laptop. Run by `run_all.R`.
- **Cluster** — needs the Slurm simulation (`sim/`); its aggregate output is committed, so nothing in
  the paper *needs* this route unless you want to regenerate `output/compass_maps.rds` itself.

| Element | Route | Script | Inputs |
|---|---|---|---|
| Table 1 (design dimensions), Table 2 (eight estimators), Table 4 (operational rule), Table 5 (reporting checklist) | authored | none | none |
| Table 3 (headline simulation table) | saved | `R/13_table4_headline.R` (historical file name) | `output/compass_maps.rds` |
| Figure 1 (LaLonde truncation sweep) | saved | `R/07_figures_lalonde.R` | `output/lalonde_estimates.rds` |
| Tables S1, S2 and S4 (D3, S3 sweep, *n*-gradient) | saved | `R/09_supplement_tables.R` | `output/compass_maps.rds` |
| Table S3 (g-splitting contrast) | saved | `R/12_s3_clean_gsplit.R` | `output/compass_maps.rds` |
| Table S5 (repetition overlays) | saved | `R/09_supplement_tables.R` | `output/s4_repetition_input.rds` (historical file name; a packaged subset of the cluster shards; the full shards in `output/sim/` are used when present) |
| Table S6 (mechanism diagnostics) | saved | `R/09_supplement_tables.R` | `output/s5_diagnostics_input.rds` (historical file name; likewise) |
| Table S7 (bias, Monte Carlo SEs) | saved | `R/10_bias_mcse_and_within_family.R` | `output/compass_maps.rds` |
| Table S8 (software environment) | authored | none (see the note below the element map) | the cluster run manifests; the applied-analysis session |
| Table S9 (paired comparisons) | saved | `R/09_supplement_tables.R` | `output/compass_maps.rds` |
| Supplementary Figure S1 (RHC forest plot) | saved | `R/05_figures_rhc.R` | `output/rhc_factorial_fast.rds` |
| Supplementary Figure S2 (RHC SE, basic vs extended library) | saved | `R/05_figures_rhc.R` | `output/rhc_factorial_fast.rds`, `output/rhc_factorial_rf.rds` |
| Supplementary Figure S3 (LaLonde propensity overlap) | **data + fitting** | `R/06_lalonde_overlap.R` → `R/07_figures_lalonde.R` | `data/lalonde_nsw/` → `output/lalonde_overlap.rds` (per-unit; never committed) |
| Table S10 (RHC, both libraries) | saved | `R/applied_tables.R` | `output/rhc_factorial_fast.rds`, `output/rhc_factorial_rf.rds`, `output/rhc_overlap_diag.rds` |
| Table S11 (LaLonde/NSW) | saved, except panel B | `R/applied_tables.R` | `output/lalonde_estimates.rds` |
| Table S12 (regime summary) | authored; its ranges are checkable against saved results | none | `output/compass_maps.rds` |
| Supplementary Figure S4 (regime map) | authored schematic, drawn by a script | `R/08_figures_sim.R` | none: its tiles and labels are written into the script, which reads no data for it |
| Supplementary Figure S5 (S2 coverage) | saved | `R/08_figures_sim.R` | `output/compass_maps.rds` |
| Engine validation (Supplement Section A, estimator reference) | fitting on simulated data; no benchmark data | `R/03_verify_engine.R` | none (optional third-party reference file) |
| The saved applied results themselves | data + fitting | `R/00_prepare_rhc.R`, `R/04b_run_rhc_factorial.R` (`10 fast`, `1 rf`), `R/11_rhc_overlap_diagnostic.R`, `R/06_lalonde_overlap.R` | `data/` |
| `output/compass_maps.rds` itself | cluster | `sim/` + `R/{run_compass,aggregate_compass,compass_map,recipes,dgm,dgm_variants,learners}.R` | none (simulated data) |

**Table S11 panel B is the one exception on the saved route.** Its sample sizes and overlap shares
(including the 185 treated men, a count the table's introduction also quotes, and the 0.49 upper bound
on the CPS propensity estimates quoted in the table's note) come from the per-unit propensity file, which is not
shipped. The committed `output/lalonde_estimates.rds` therefore carries them
**transcribed from the paper as printed**, marked as such inside the file; a clone can check them for
consistency (the CPS *n* reproduces the saved default truncation bound exactly) but not recompute
them. A fresh `run_all.R` computes them from the refitted propensities. See
`output/APPLIED_PROVENANCE.md`.

Supplement Sections A (estimator reference), B (the data-generating mechanism as implemented) and
J (analysis plan and reproducibility) are authored text. Section B describes `R/dgm.R`; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Implementation details that the Supplement
summarizes in words are in
[Implementation details moved from the Supplement](#implementation-details-moved-from-the-supplement).

## Code → paper element map

Numbers refer to the compiled paper (Tables 1-5, Figure 1) and its Supplementary Materials
(Tables S1-S12, Figures S1-S5; Sections A-N: A estimator reference, B data-generating mechanism,
C second data-generating mechanism (D3), D near-positivity sweep, E sample size, F repetition,
G diagnostics, H additional design cells, I prior evidence, J analysis plan and reproducibility,
K paired comparisons, L real-data context, M real-data estimates, N summary). The Supplement numbers
its tables and figures in order of appearance; Section N, the last section, holds the simulation
summary (Table S12, Figures S4-S5) that the main paper refers to. The section letters date from
2026-10-11 and replace labels of the form S.dgm, S.D3, S.S3, S.n, S.reps, S.diag, S.additional,
S.prior, S.pre, S.pairs, S.realdata, S.applied and S.summary (Sections B-N in that order; the
estimator reference, now Section A, had no label), which dated records such as
`output/CLEAN_CLONE_CHECK.md` still use. The table and figure numbers date from 2026-10-07: before then the
regime summary was main-paper Table 4, the operational rule and reporting checklist were Tables 5
and 6, and the S2 coverage plot, the regime map and the LaLonde truncation sweep were Figures 1-3.

Some file names predate the current numbering and are kept so that checksums and references stay
valid: `R/13_table4_headline.R` writes `output/table4_headline.md`, which is
main-paper **Table 3**; `output/s4_repetition_input.rds` feeds **Table S5** and
`output/s5_diagnostics_input.rds` feeds **Table S6** (both described in
`output/S4_S5_PROVENANCE.md`); and `R/12_s3_clean_gsplit.R`, whose "s3" is the S3 regime, emits
**Table S3**.

### Main paper — figures

| Element | Script | Input (saved route) | Output |
|---|---|---|---|
| **Figure 1** — LaLonde estimate vs truncation bound | `R/07_figures_lalonde.R` | `output/lalonde_estimates.rds` | `images/lalonde_truncation.pdf` |

Figure 1 is the main paper's only figure. The RHC forest plot, the RHC standard-error figure and the
LaLonde propensity-score histograms are Supplementary Figures S1-S3, and the two-axis regime map and
the S2 coverage plot are Supplementary Figures S4-S5; see [Supplementary Materials](#supplementary-materials).

### Main paper — tables

| Element | Provenance |
|---|---|
| **Table 1** — the five design dimensions | Authored in the paper. The dimensions are the arguments of `R/02_variants.R`; no script emits this table. |
| **Table 2** — the eight estimators as design choices | Authored in the paper. Each row corresponds to one named estimator defined in `R/02_variants.R`; no script emits this table. |
| **Table 3** — headline: two primary regimes at *n*=3000, nsim=2500 | `R/13_table4_headline.R` → `output/table4_headline.md` (historical file names, from when this was Table 4), formatted from `output/compass_maps.rds` (regimes `S1_sharp1.0_gb0.025_n3000`, `S2_sharp1.0_gb0.025_n3000`). The script **checks all 32 cells against the values printed in the paper** and fails if any disagree. |
| **Table 4** — the operational rule (four questions) | Authored in the paper; interpretation, not output. |
| **Table 5** — reporting checklist | Authored in the paper; interpretation, not output. |

The regime summary is Supplementary Table S12; see [Supplementary Materials](#supplementary-materials).

### Supplementary Materials

| Element | Section | Script | Output |
|---|---|---|---|
| **Table S1** — D3 (rough surface + random forest) | C | `R/09_supplement_tables.R` | `output/supplement_tables.md` |
| **Table S2** — S3 near-positivity sweep | D | `R/09_supplement_tables.R` | `output/supplement_tables.md` |
| **Table S3** — g-splitting contrast, correction route held fixed | D | `R/12_s3_clean_gsplit.R` | `output/s3_clean_gsplit_table.md` |
| **Table S4** — *n*-gradient | E | `R/09_supplement_tables.R` | `output/supplement_tables.md` |
| **Table S5** — repetition overlays, coverage vs *R* | F | `R/09_supplement_tables.R` (packaged input `output/s4_repetition_input.rds`, historical name; see `output/S4_S5_PROVENANCE.md`) | `output/supplement_tables.md` |
| **Table S6** — mechanism diagnostics | G | `R/09_supplement_tables.R` (packaged input `output/s5_diagnostics_input.rds`, historical name; see `output/S4_S5_PROVENANCE.md`) | `output/supplement_tables.md` |
| **Table S7** — per-estimator bias + Monte Carlo SEs | G | `R/10_bias_mcse_and_within_family.R` | `output/bias_mcse_tables.md` |
| **Table S8** — software environment | J | authored; see the note below | — |
| **Table S9** — paired coverage comparisons at the four primary settings (S1, S3, S2, D3) | K | `R/09_supplement_tables.R`; checks itself against the Supplement as printed | `output/supplement_tables.md` |
| **Figure S1** — RHC forest plot, ATE on 30-day mortality, basic library | L | `R/05_figures_rhc.R` (input `output/rhc_factorial_fast.rds`) | `images/rhc_forest.pdf` |
| **Figure S2** — RHC model-based SE, basic vs extended library | L | `R/05_figures_rhc.R` (inputs `output/rhc_factorial_fast.rds`, basic: GLM + mean, R = 10; `output/rhc_factorial_rf.rds`, extended: GLM + mean + random forest, R = 1) | `images/rhc_se_basic_vs_rich.pdf` (historical file name, kept because the manuscript includes it; the extended series is the `rf` run, not the unused `rich` profile) |
| **Figure S3** — LaLonde propensity-score overlap | L | `R/06_lalonde_overlap.R` → `R/07_figures_lalonde.R`; no saved-route input: needs `data/lalonde_nsw/` and fitting | `images/lalonde_overlap.pdf` |
| **Table S10** — RHC, every estimator under the basic and extended libraries | M | `R/applied_tables.R`; checks itself against the Supplement as printed | `output/applied_tables.md` |
| **Table S11** — LaLonde/NSW: CPS and PSID comparisons, samples and overlap, truncation sweep | M | `R/applied_tables.R` (panel B transcribed; see above) | `output/applied_tables.md` |
| **Table S12** — summary of the known-truth simulation, by regime | N | none: an **authored synthesis** (see below) | — |
| **Figure S4** — which design dimension mattered, by regime (two-axis map) | N | `R/08_figures_sim.R`; none: an authored two-by-two schematic whose tiles and labels are written into the script; it carries no numbers and reads no data | `images/sim_two_axis_map.pdf` |
| **Figure S5** — S2 coverage by estimator (statin + random forest, *n*=3000) | N | `R/08_figures_sim.R` (input `output/compass_maps.rds`) | `images/sim_s2_coverage.pdf` |

`output/applied_tables.md` is the whole Section M (heading, introduction, both tables and
their notes), byte-identical to the Supplement when formatted from the committed inputs.

**Table S12** is an authored synthesis with five rows: one per regime (S1, S2, D3, S3) and a fifth,
"All regimes", on the finer within-route choices (pooled vs fold-specific targeting; single vs double
cross-fit), which summarizes the paired comparisons of Table S9 and Section H. Its columns
are a prose "main empirical pattern" and a "practical implication". Its numerical ranges (e.g. S1
`0.928`–`0.939`, S2 in-sample-*g* `0.12`–`0.48`) are read from `output/compass_maps.rds`;
per-estimator values are in Table 3 and the Supplement. It is not a table form of Figure S4, which is
a two-by-two schematic of learner class against overlap and carries no numbers. No script emits this
table.

**Table S8** is authored from two records. Its simulation column gives the cluster versions logged in
the 16 per-shard run manifests, which `R/15_record_environment.R` also writes into
`output/ENVIRONMENT.md`; `nnls`, which no manifest logged, is reported as not recorded (see
[Software environment and Table S8](#software-environment-and-table-s8)). Its applied column gives the
versions installed on the workstation when the environment was recorded (2026-10-05); the workstation
runs logged no package versions. `R/15_record_environment.R` otherwise records the environment of
whoever runs it, so it documents a reproduction rather than regenerating Table S8.

### Supporting elements (no numbered table or figure)

| Element | Script | Note |
|---|---|---|
| The estimator engine and the variant definitions | `R/01_engine.R`, `R/02_variants.R` | function libraries; sourced by everything else, run nothing on their own |
| Engine validation against the `tmle` package | `R/03_verify_engine.R` | the agreement claim in Supplement Section A (estimator reference); see [Checks against other implementations](#checks-against-other-implementations) |
| RHC overlap diagnostic (propensity range, truncated fraction) | `R/11_rhc_overlap_diagnostic.R` | numbers quoted in the applied section; writes `output/rhc_overlap_diag.rds` |
| The shippable LaLonde aggregate, built once from the paper's results | `R/16_lalonde_estimates_from_saved.R` | needs the unshipped per-unit file; a clone does not run it (see `output/APPLIED_PROVENANCE.md`) |
| LaLonde sample-size / benchmark cross-check | `R/06b_lalonde_check.R` | not called by `run_all.R`; run by hand |
| Recovered canonical truths | `R/14_recover_truths.R` | see `output/TRUTHS_PROVENANCE.md` |
| Software-environment record | `R/15_record_environment.R` | writes `output/ENVIRONMENT.md` |
| Pinned simulation truths | `R/pin_truths.R` | cluster step; feeds the DGMs |
| The cluster simulation itself | `R/{recipes,dgm,dgm_variants,learners,run_compass,aggregate_compass,compass_map}.R` via `sim/` | produces `output/compass_maps.rds` |

## Layout

```
R/         numbered pipeline scripts (00-16) and applied_tables.R, plus the un-numbered engine
           and cluster-harness files they source
sim/       Slurm orchestration (job.slurm, submit_all.sh, aggregate_all.sh, smoke.slurm,
           progress.sh)
data-raw/  get_data.R -- fetches the benchmark data from its canonical sources
data/      benchmark data landing dir (fetched, never committed; see Data)
output/    committed saved results and their provenance notes; the scripts write the rest here
images/    figures (PDF, colour-blind-safe: redundant colour + line type)
```

The figure scripts write PDFs with `cairo_pdf`, which embeds (subsets) every font and keeps hyphens
as hyphens in the text layer. Each figure is exported at the width at which it is printed, so its
lettering prints at 8.8 pt or more. The committed Figure 1 and Supplementary Figures S1, S2, S4 and S5
were drawn that way on Windows, so they
embed Arial; on another system the platform's sans-serif font is embedded instead. `cairo_pdf`
stamps each file with its local creation time and UTC offset, so the committed figures were drawn
with `TZ=UTC` set in the environment (`TZ=UTC Rscript run_saved.R`); setting `TZ` from inside R
does not reach the PDF writer. Supplementary Figure S3 was drawn before both changes: its script now
exports it at 6.5 x 4.5 in, but the committed file stays as it is until someone with the per-unit data
re-runs it (printed at the full supplement width, its lettering is about 8.1 pt); see [Known gaps](#known-gaps).

## Known gaps

Stated plainly so a reader is not surprised:

- **Tables 1, 2, 4 and 5 are authored in the paper**, not generated. They are a taxonomy,
  definitions and interpretation.
- **Supplementary Table S12 has no formatting script.** It is an authored synthesis; its numerical ranges are read
  from `output/compass_maps.rds`, which is committed, so they are *verifiable* but not *regenerable*.
- **Supplementary Figure S3 does not reproduce from a clone without the data.** It plots one propensity score per
  pooled unit, a per-unit value derived from the benchmark data, which is never committed or bundled.
  `run_all.R` downloads the data and produces it. The committed `images/lalonde_overlap.pdf` was drawn
  with R's default `pdf` device, before the switch to `cairo_pdf`, and used the base-14 font Helvetica
  without embedding it. Because it cannot be redrawn without the per-unit file, that vector PDF was
  re-rendered with poppler's `pdftocairo` (`TZ=UTC pdftocairo -pdf in.pdf out.pdf`), which keeps every
  path and embeds the font (an Arial subset); the render matches the original apart from glyph
  shapes. A `run_all.R` run redraws it with `cairo_pdf`.
- **Table S11 panel B is transcribed, not recomputed, on the saved route** (see
  [What reproduces from what](#what-reproduces-from-what)).
- **Tables S5 and S6 reproduce from packaged inputs.** Their raw inputs are 109 MB of per-replicate
  shards, too large to commit, so the subset those two tables actually consume is packaged as
  `output/s4_repetition_input.rds` (3.4 MB; Table S5) and `output/s5_diagnostics_input.rds` (7 KB;
  Table S6). The file names are historical: they date from when these were Tables S4 and S5. The script
  prefers the raw shards when `output/sim/` is populated and falls back to the packaged inputs
  otherwise, so a cluster run still exercises the full path. Provenance, including the subsetting
  rule and MD5s, is in `output/S4_S5_PROVENANCE.md`.
- **Table S8 has no script** (see the note under the Supplementary Materials map).
- **Package versions are not pinned.** `dependencies.R` installs current CRAN. The applied analyses are
  seeded (`set.seed(2026)`), so they are reproducible given the same versions; across major Super
  Learner or `ranger` versions small differences are possible. `R/15_record_environment.R` writes
  `output/ENVIRONMENT.md` for the running session.
- **The canonical pinned truths were never committed, and `run_compass.R`'s fallbacks differ from
  them** (`-0.1081508`/`0.10068` against the actual `-0.1081358`/`0.1006854`). `R/14_recover_truths.R`
  recovers the real values from the saved per-replicate output and writes `output/truths.rds`; see
  `output/TRUTHS_PROVENANCE.md`. The draw counts `nD1`/`nD3` are **not** recoverable and are `NA`.

## Canonical results

`output/compass_maps.rds` and `output/compass_report.txt` are the authoritative simulation output.
The full per-estimator results the Supplement refers to (all 14 estimators of the design grid, including the two
plug-in comparators, in all 13 regimes, with coverage Monte Carlo standard errors, and the paired TOST
comparisons) are in `output/compass_maps.rds`, as `m[[regime]]$summary` and `m[[regime]]$pairwise`.
`output/compass_report.txt` is the **corrected** aggregate — an earlier aggregate contained a
repetition-handling bug and must not be used.

The committed applied results — `output/rhc_factorial_fast.rds`, `output/rhc_factorial_rf.rds`,
`output/rhc_overlap_diag.rds` and `output/lalonde_estimates.rds` — are the runs the paper reports.
They hold estimates, SEs, intervals, counts and summary statistics of the fitted propensity scores:
quantiles, shares beyond the truncation bounds and, in `output/rhc_overlap_diag.rds`, the minimum and
maximum overall and within each arm (the paper quotes the overall range, 0.002 to 0.978). The LaLonde
file records the CPS propensity maximum as the paper prints it, rounded up to 0.01 (0.49). No file
holds a covariate, an outcome, an identifier or a per-unit vector of fitted values. `output/APPLIED_PROVENANCE.md` gives, for each, what it is, where it came from, the
script that produced it and its SHA-256. A `run_all.R` refit rewrites them in place; in a git checkout,
`git checkout -- output/` restores the committed versions, and from an unpacked archive, unpacking it
again does.

## Data

The benchmark data are **not redistributed** here. `data-raw/get_data.R` downloads them from the
sources below into `data/` (run automatically by `run_all.R`) and checks their MD5s against the files
the paper used. Each source sets its own terms; please follow them.

- **RHC (SUPPORT).** Data obtained from http://hbiostat.org/data courtesy of the Vanderbilt University
  Department of Biostatistics. The datasets page grants permission to use its data sets and asks users to
  reference the original paper and to include that note. Original paper: Connors AF Jr, Speroff T,
  Dawson NV, et al. The effectiveness of right heart catheterization in the initial care of critically
  ill patients. *JAMA*. 1996;276(11):889-897. <https://doi.org/10.1001/jama.1996.03540110043030>
- **LaLonde / NSW, with the CPS and PSID comparison groups.** From Rajeev Dehejia's data page,
  <https://users.nber.org/~rdehejia/nswdata2.html>, which distributes them for attributable
  non-commercial use under CC BY-NC 2.0 (<https://creativecommons.org/licenses/by-nc/2.0/>) and asks
  users to cite:
  - Dehejia RH, Wahba S. Causal effects in nonexperimental studies: reevaluating the evaluation of
    training programs. *Journal of the American Statistical Association*. 1999;94(448):1053-1062.
    <https://doi.org/10.1080/01621459.1999.10473858>
  - Dehejia RH, Wahba S. Propensity score-matching methods for nonexperimental causal studies.
    *Review of Economics and Statistics*. 2002;84(1):151-161. <https://doi.org/10.1162/003465302317331982>
  - LaLonde RJ. Evaluating the econometric evaluations of training programs with experimental data.
    *American Economic Review*. 1986;76(4):604-620.

  The PSID comparison group is the extract LaLonde built from the Panel Study of Income Dynamics for his
  1986 paper, as distributed on that page; this repository obtains it from that page only.

No file holding unit-level data, and no per-unit vector of derived values, is committed or bundled:
`data/` is ignored as a whole, the per-unit `output/lalonde_overlap.rds` is ignored, and
`make_review_bundle.sh` aborts if any such file would ship. The committed applied results are summary
results, among them the minimum and maximum fitted propensity scores in `output/rhc_overlap_diag.rds`
(see [Canonical results](#canonical-results)).

| File | Description | Source |
|---|---|---|
| `rhc.csv` | SUPPORT right-heart-catheterization study (*n*=5735). | Vanderbilt University Department of Biostatistics, <https://hbiostat.org/data/> |
| `rhc_analysis.rds` | RHC analysis file (treatment, 30-day mortality, covariate set), from `R/00_prepare_rhc.R`. | derived |
| `lalonde_nsw/nsw_dw.dta` | NSW experimental sample (Dehejia–Wahba subsample). | Rajeev Dehejia's data page (CC BY-NC 2.0; see above) |
| `lalonde_nsw/cps_controls.dta` | CPS observational comparison group. | Rajeev Dehejia's data page (CC BY-NC 2.0; see above) |
| `lalonde_nsw/psid_controls.dta` | PSID observational comparison group. | Rajeev Dehejia's data page (CC BY-NC 2.0; see above) |
| `reference/` | Optional third-party reference estimator for `R/03_verify_engine.R`: `DoubleCrossFit/R/estimators.R` from release v2026.07.20 of Paul Zivich's `publications-code` (<https://doi.org/10.5281/zenodo.21456065>; CC BY 4.0 per the release record), saved as `zivich_breskin_estimators.R`. Not redistributed; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). The primary validation is against the `tmle` package and runs without it. | Zenodo (CC BY 4.0 per the record) |

The simulation uses no external data; its data-generating mechanisms are code (`R/dgm.R`,
`R/dgm_variants.R`). `R/dgm.R` adapts third-party code whose release record declares CC BY 4.0; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Reproducing the full simulation on a cluster

`output/compass_maps.rds` is committed, so most of the paper reproduces without a cluster. To
regenerate it: set your Slurm allocation in `sim/*.slurm` and `sim/submit_all.sh` (currently
`def-YOURACCOUNT`) and adapt their `module load` lines to your site's R installation, then from the repository root install packages (`Rscript R/install_deps.R`) and
put the canonical truths in place with `Rscript R/14_recover_truths.R`, which writes
`output/truths.rds` **and installs a copy at `R/truths.rds`, where the worker reads it**. Then
submit the arrays (`bash sim/submit_all.sh`) and aggregate (`bash sim/aggregate_all.sh`).

Use `R/14_recover_truths.R`, not `R/pin_truths.R`, unless you specifically want to re-pin: recovery
reproduces the exact values the published results were scored against, whereas re-pinning draws
fresh Monte Carlo truths that will differ in the last few digits. The harness reads `COMPASS_ENGINE` (default `R`),
`COMPASS_OUT` (default `output/sim`) and `COMPASS_RESULTS` (default `output`).

## Implementation details moved from the Supplement

The Supplement states in words what these checks and records found; the file names, code calls,
hashes and execution details it used to carry are kept here.

### The estimators as calls to the shared engine

(From Supplement Section A.) Every estimator is one call to `run_once()` in `R/02_variants.R`, which
uses the engine in `R/01_engine.R`. Vanilla TMLE is
`run_once(Y, A, W, list(scheme="none", target="pooled"))`; each row below changes only the listed
arguments. `scheme` sets where the nuisances are fit, `qonly=TRUE` cross-fits $Q$ only (leaving $g$
in-sample), `target` selects a pooled or fold-specific TMLE fluctuation or the AIPW form
(`target="onestep"`), and `agg_fold=TRUE` averages fold-specific plug-ins and uses the fold-averaged
variance (the mean within-fold variance divided by $n$; Supplement Section A, Variance conventions).
Labels match the eight-estimator table in the main paper and the design grid in Supplement Section A.

| Estimator | `list(...)` passed to `run_once()` |
|---|---|
| Vanilla TMLE | `scheme="none", target="pooled"` |
| AIPW | `scheme="none", target="onestep"` |
| CVQ-TMLE | `scheme="cv", qonly=TRUE, target="pooled"` |
| CV-TMLE | `scheme="cv", target="pooled"` |
| CV-TMLE-fold | `scheme="cv", target="foldwise", agg_fold=TRUE` |
| CF-AIPW | `scheme="cv", target="onestep"` |
| SS-TMLE | `scheme="ss2", target="pooled"` |
| Single cross-fit (SCTMLE) | `scheme="cf2", target="foldwise", agg_fold=TRUE` |
| Double cross-fit (DCTMLE) | `scheme="cf3", target="foldwise", agg_fold=TRUE` |
| DC-AIPW | `scheme="cf3", target="onestep", agg_fold=TRUE` |

### Checks against other implementations

(From Supplement Section A.) The script is `R/03_verify_engine.R`. It fits one simulated dataset
(*n* = 4000, from a three-covariate logistic mechanism defined in the script; true ATE 0.126) with the
library `SL.glm` + `SL.mean` for both nuisances and compares our engine with
`tmle::tmle(cvQinit = FALSE)` and, when the reference file is present, with the R code accompanying
Zivich and Breskin (2021).

- **Reference file.** The comparisons with Zivich and Breskin's R code run only when their
  `R/estimators.R` (folder `DoubleCrossFit` of `pzivich/publications-code`, release v2026.07.20) is
  saved as `data/reference/zivich_breskin_estimators.R`; see [Data](#data) and
  [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Their code is not redistributed here. The `tmle`
  comparison runs without it.
- **Which file was compared.** The script prints the SHA-256 of the reference source it loads; the
  file used for the paper's comparison begins `7d33ee07118f` (the full value is in the script's
  comments).
- **Plain TMLE.** For the plain `TMLE()` function the script prints an absolute difference of 0 from
  our estimate and 0 from our SE.
- **Double cross-fit pairing.** `DCTMLE_Single()` indexes its fitted models by the row order of
  `group_by(s) %>% nest()`, then pairs each targeting split with models from two other rows; those
  models were trained on the other two splits only if the rows come out in split order. Under the
  runtime used for the paper (`tidyr` 1.3.2) they come out in first-appearance order (3, 2, 1 at the
  script's seed), and the pairing diagnostic in the script shows two of the three targeting splits
  using a model trained on their own split.

### Software environment and Table S8

(From Supplement Section J and the Table S8 note.)

- **Run manifests.** Each simulation slice writes a run manifest recording the R version and the
  versions of the five packages it loads directly (`SuperLearner`, `ranger`, `gam`, `dplyr`, `tidyr`).
  The 16 per-shard manifests agree; `R/15_record_environment.R` writes their versions into
  `output/ENVIRONMENT.md`.
- **`nnls`.** `nnls` is a hard dependency of `SuperLearner`
  (`Depends: R (>= 2.14.0), nnls, gam (>= 1.15)`), so it is attached whenever `SuperLearner` is
  loaded, and the default metalearner `method.NNLS` calls `nnls()` to compute the ensemble weights on
  every nuisance fit, including the single-learner random-forest libraries of S2 and D3, where the
  metalearner is invoked regardless of library size and returns weight 1. The manifests log a fixed
  five-package list, so the cluster's `nnls` version was never written down. The cluster used a
  shared environment module and a personal library rather than a pinned container image, so a
  version queried today (the installed version or its `Built` date) would not establish what
  produced the archived runs. Table S8 therefore reports it as not recorded.
- **Cores.** The cluster runs used 32 cores per task.
- **Build label.** The build label in `R/BUILD_INFO.txt` predates the pre-run code changes and does
  not identify the exact engine that ran.
- **Seeds, as code.** In the simulation, replicate `s`'s dataset is generated after
  `set.seed(10000 + s)` and its `r`-th outer partition after `set.seed(20000 + 1000*s + r)`, both set
  inside the replicate, so the draws do not depend on how replicates are distributed across workers.
  The applied analyses call `set.seed(2026)` before fitting each estimator. The random-number kinds
  are R's defaults (`RNGkind()`: Mersenne-Twister, Inversion, Rejection).

## Anonymized bundle for peer review

`make_review_bundle.sh` builds a name-free ZIP for double-anonymized submission: it exports a clean
tree (no `.git`), stubs `CITATION.cff` and the licence copyright line, drops `.zenodo.json`, shortens
this section, removes institution-identifying strings, replaces the cluster allocation and module
names with placeholders, and withholds this repository's own commit hashes. It aborts if benchmark
data, a per-unit file, an unreviewed `.rds` or a file with an unreviewed extension would ship; if an
identity pattern (including local paths and account names) survives; if any hex token still resolves
to a commit; if a PDF carries a local time zone; if the third-party credit is missing; or if any ZIP
entry has an extra field or a timestamp other than the fixed one. Pass an output path in an existing
directory outside the repository. See that script's header for exactly what it rewrites.

## Licence and citation

- **Code.** The authors' code is MIT-licensed; see [`LICENSE`](LICENSE). One exception: `R/dgm.R` adapts
  the statin data-generating mechanism from Paul Zivich's `publications-code` (release v2026.07.20,
  <https://doi.org/10.5281/zenodo.21456065>), whose Zenodo release record declares CC BY 4.0. The upstream
  material in that file stays under CC BY 4.0, and the authors' changes are MIT; the attribution, licence
  link and list of changes are in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
- **Figures and saved results.** The files in `images/` (the paper's figures) and `output/` (saved results
  and their provenance notes; `R/truths.rds` is a copy of `output/truths.rds`) are licensed under CC BY 4.0,
  <https://creativecommons.org/licenses/by/4.0/>. To attribute them, cite the paper
  ([`CITATION.cff`](CITATION.cff)) and, for results derived from the RHC or LaLonde data, keep the
  data-source credits in [Data](#data).
- **Not covered.** These licences cover only the authors' own rights. They grant no rights in the benchmark
  data, which are not included and remain under their providers' terms (see [Data](#data)), and they do not
  cover the text of the paper.

Citation metadata: [`CITATION.cff`](CITATION.cff). Archive metadata for the repository's Zenodo release:
[`.zenodo.json`](.zenodo.json) (licences MIT and CC BY 4.0, scoped as above; it records the upstream
release, DOI 10.5281/zenodo.21456065, as `isDerivedFrom`). No deposit has been made yet.
