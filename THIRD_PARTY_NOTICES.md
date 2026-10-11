# Third-party material

The MIT licence in [`LICENSE`](LICENSE) applies to the authors' own code; the figures in `images/` and the
saved results in `output/` are under CC BY 4.0 (README, Licence and citation). One file contains material
adapted from a third-party source under a different licence, recorded here. This notice records the terms
as the upstream release declares them; it is not legal advice.

## `R/dgm.R` — the statin/ASCVD data-generating mechanism (adapted)

`R/dgm.R` is an R adaptation of the statin data-generating mechanism in `DoubleCrossFit/Python/dgm.py`
of the `publications-code` repository that accompanies Zivich P.N. and Breskin A. (2021), "Machine
learning for causal inference: on the use of cross-fit estimators", *Epidemiology* 32(3):393–401.

- **Source:** `pzivich/publications-code`, release v2026.07.20 (GitHub tag `v2026.07.20`), archived on
  Zenodo: <https://doi.org/10.5281/zenodo.21456065> (all versions: <https://doi.org/10.5281/zenodo.8100057>).
  File adapted: `DoubleCrossFit/Python/dgm.py`.
- **Creator, as listed in the release record:** Paul Zivich.
- **Licence of the source:** Creative Commons Attribution 4.0 International (CC BY 4.0),
  <https://creativecommons.org/licenses/by/4.0/>, as declared in the Zenodo record's licence metadata (the
  upstream repository itself contains no licence file). The source is provided as-is, without warranties
  (CC BY 4.0, Section 5).
- **Changes made (this file is modified, not a copy):**
  - translated from Python (NumPy, pandas, SciPy, zepid) to base R;
  - zepid's trapezoidal sampler replaced by an R inverse-CDF sampler (`rtrapezoid`);
  - restructured as a function, `generate_statin(n)`, returning one dataset per call instead of one long
    table of all simulated datasets written to CSV;
  - `risk_score_cat` category 3 is inclusive at 0.2 (`>= 0.2`), following the published eAppendix; the
    upstream code uses a strict `> .2`;
  - new argument `statin_sharp`, which scales the covariate part of the treatment model's linear
    predictor (`statin_sharp = 1` gives the original mechanism; values above 1 give this study's
    near-positivity regime);
  - new option `return_potential` to return the potential-outcome probabilities, potential outcomes and
    true propensity;
  - new function `true_ate_statin()`, which computes the true ATE as the Monte Carlo mean of the
    potential-outcome probabilities `prY1 - prY0`, where the upstream file comments a value computed
    from realized potential outcomes;
  - the module-level random seed and simulation-size settings are removed; the caller sets them (the
    seed with `set.seed()`, the sample size through `generate_statin(n)`, and the number of datasets by
    how many times it calls the function);
  - the upstream seed value, `1015033030`, is reused as the default `seed` argument of
    `true_ate_statin()`;
  - run directly (`Rscript R/dgm.R`), the file prints the true ATE instead of writing a CSV.
- **Licensing of this repository's version:** the upstream material in `R/dgm.R` remains under CC BY 4.0,
  with the attribution above; the authors' own modifications are offered under the MIT licence. Anyone
  reusing `R/dgm.R` should keep this notice (or equivalent attribution, the licence link and the list of
  changes).

`R/dgm_variants.R` calls `generate_statin()` for the near-positivity regime; its own rough-surface
mechanism (`generate_rough()`) is the authors' work.

## Upstream code used only for an optional check (not redistributed)

`R/03_verify_engine.R` can compare this repository's vanilla TMLE with the `TMLE()` function in
`DoubleCrossFit/R/estimators.R` of the same upstream release. That file is **not** included here. To run
the comparison, download release v2026.07.20 from <https://doi.org/10.5281/zenodo.21456065> and save the
file as `data/reference/zivich_breskin_estimators.R` (that path is git-ignored). The script prints the
SHA-256 of the file it loads; the copy used for the paper's check had
`7d33ee07118fd5f994f9b0c0e3f10abd8b8102d9ffadcd720a769f51e5ce8105` (a fresh download may differ only in
line endings, which changes the checksum but not the code).

## Benchmark data (not included)

This repository contains no benchmark data. `data-raw/get_data.R` downloads them from their providers,
whose terms apply: the RHC data from the Vanderbilt University Department of Biostatistics
(http://hbiostat.org/data), and the NSW, CPS and PSID files from Rajeev Dehejia's data page
(https://users.nber.org/~rdehejia/nswdata2.html; CC BY-NC 2.0). The citations and the courtesy note
the providers ask for are in the Data section of README.md.
