# Clean-clone check of `run_saved.R`

_Commit identifiers in this record refer to the authors' development repository. The public reproduction repository is a single-commit snapshot of it, so those identifiers do not appear there._

## Re-run 2026-10-11 at commit `4f08570` (lettered Supplement sections; plainer wording in the checksummed blocks)

The Supplement's sections are now lettered A-N (the old labels S.dgm ... S.summary map to B-N in order; the Estimator
reference is A), so the generators print "Section J" in the Table S9 caption and "## Section M" as the heading of the
Tables S10-S11 section, with plainer wording in both blocks ("2500 simulated datasets"; "estimators" for "arms"; "a
script in the companion repository"; "our repetition code"). The stored MD5s changed accordingly; no number, input or
value check changed.

`tutorial/release/tools/clean_clone_check.sh` cloned the repository at `4f08570` into a fresh temporary directory and
ran `TZ=UTC Rscript run_saved.R` there: `COMPLETE`, 0 time-zone warnings, no `.rds` file changed (only the five redrawn
figures' creation dates and the `TRUTHS_PROVENANCE.md` date line changed, as expected). Supplementary Figure S3 was
skipped (per-unit data).

```
[check] Table S9 matches the Supplement as printed (MD5 e920b276487e32f867046debd45126e9)
[check] Section M (Tables S10-S11) matches the paper as printed (MD5 49ff017dcb2a6757ade9bcc5a8b3376b)
```

Independent comparisons against the manuscript sources: Table 3, 32 cells, 0 mismatches (`t4cmp.py`); Tables S1-S7,
485 numeric cells, 0 mismatches (`s1s7cmp.py`: S1 24, S2 72, S3 40, S4 20, S5 60, S6 77, S7 192); Figure 1 and
Supplementary Figures S1, S2, S4 and S5 pixel-identical at 100 dpi to the committed images.

## Note 2026-10-07

After the run recorded below, the paper's numbering changed again (the 25-page route): main-paper Table 4 (regime
summary) became Supplementary Table S12; Tables 5 and 6 (operational rule, reporting checklist) became Tables 4 and 5;
Figure 1 (S2 coverage) became Supplementary Figure S5; Figure 2 (regime map) became Supplementary Figure S4; and
Figure 3 (LaLonde truncation) became Figure 1, the main paper's only figure. Supplementary Figures S1-S3 and Tables
S1-S11 keep their numbers. The figure scripts now also export each figure at its printed width (lettering 8.8 pt or
more; the regime map's tile labels in sentence case; shorter axis titles on the LaLonde figure), so the five committed
figure files that `run_saved.R` redraws changed and no longer match the images compared in the runs below. No table,
number or `.rds` file changed. The next clean-clone run, to be recorded directly below this note, checks the new files.

## Re-run 2026-10-07 at commit `9829387` (figures at printed width, new numbering)

`tutorial/release/tools/clean_clone_check.sh` cloned the repository at `9829387` from its local path into a fresh
temporary directory (no `data/`, no `output/sim/`, no per-unit file) and ran `TZ=UTC Rscript run_saved.R` there:
`COMPLETE`, 0 time-zone warnings, no `.rds` file changed (only the five redrawn figures' creation dates and the
`TRUTHS_PROVENANCE.md` date line changed, as expected). Supplementary Figure S3 was skipped (per-unit data).

```
[check] Table 3: all 32 cells match the values printed in the paper
[check] Table S9 matches the Supplement as printed (MD5 b88b1db0b08b53620a5af1d3df903469)
[check] Section S.applied (Tables S10-S11) matches the paper as printed (MD5 09db33eace4b31e29a877509b9db74a4)
```

Independent comparisons against the manuscript sources: Table 3, 32 cells, 0 mismatches (`t4cmp.py`); Tables S1-S7,
485 numeric cells, 0 mismatches (`s1s7cmp.py`: S1 24, S2 72, S3 40, S4 20, S5 60, S6 77, S7 192); Figure 1 and
Supplementary Figures S1, S2, S4 and S5 pixel-identical at 100 dpi to the committed images. At the widths the paper
includes them, their smallest lettering prints at 8.8 pt (9.96 pt in the schematic).

## Re-run 2026-10-07 at commit `425e5c4`

After the generators adopted the manuscript's approved vocabulary (labels and prose only; no printed number changed),
`tutorial/release/tools/clean_clone_check.sh` cloned the repository from its local path into a fresh temporary
directory and ran `TZ=UTC Rscript run_saved.R` there: **exit status 0** in 6 seconds, `COMPLETE`, 0 time-zone warnings,
no `.rds` file changed (only the five figures' creation dates and the `TRUTHS_PROVENANCE.md` date line, as expected).

```
[check] Table 3: all 32 cells match the values printed in the paper
[check] Table S9 matches the Supplement as printed (MD5 b88b1db0b08b53620a5af1d3df903469)
[check] Section S.applied (Tables S10-S11) matches the paper as printed (MD5 09db33eace4b31e29a877509b9db74a4)
```

Independent comparisons against the manuscript sources: Table 3 (formerly Table 4), 32 cells, 0 mismatches (`t4cmp.py`); Tables S1-S7,
485 numeric cells, 0 mismatches (`s1s7cmp.py`); the five redrawn figures pixel-identical at 100 dpi to the committed
images. Figure numbering in the paper changed with the TAS relocation (2026-10-07): the S2 coverage figure, the regime
map and the truncation figure are main-text Figures 1-3; the RHC forest plot, the RHC standard-error figure and the
LaLonde overlap histograms are Supplementary Figures S1-S3. The record below keeps the older numbering.

## Earlier run (2026-10-05, commit `0575228`)

Run 2026-10-05 on Windows 11, R 4.5.1, with `TZ=UTC` set. The repository at commit `0575228` was cloned from its
local path (`git clone --no-hardlinks`, no network) into a fresh temporary directory outside
any working tree, and `Rscript run_saved.R` was run there. The clone therefore held only
committed files: no `data/`, no `output/sim/` shards, no per-unit `output/lalonde_overlap.rds`.
(The anonymized review bundle withholds this repository's commit hashes, so there the commit
reads "(withheld for review)".)

## Result

- **Exit status 0**, in 8 seconds, ending:

  ```
  COMPLETE: every saved-results element reproduced, with no computation:
    Table 4, Figures 1-4 and 6, Tables S1-S7 and S9-S11, the truths and the environment record.
  Self-checked against the paper as printed: Table 4 (all 32 cell values), Table S9 and
  Section S.applied (Tables S10-S11), the latter two byte for byte (MD5 of the printed text).
  Tables S1-S7 reproduce the printed values, not the printed formatting; they are not
  checked against the paper's text.
  Table S11 panel B on this route is TRANSCRIBED from the paper, not recomputed: its sample
  sizes and overlap shares, including the 185 treated men, and the 0.49 upper bound on the
  CPS propensity estimates come from the per-unit propensity file, which is not shipped.
  Figure 5, the applied refits and the engine validation are in run_all.R.
  ```

- Self-checks and input notes printed by the run:

  ```
  [check] Table 4: all 32 cells match the values printed in the paper
  [S5] using packaged input output/s4_repetition_input.rds - 252000 rows (see output/S4_S5_PROVENANCE.md)
  [S6] using packaged input output/s5_diagnostics_input.rds - 324 rows
  [check] Table S9 matches the Supplement as printed (MD5 1f908bb6d1108349566f74e34dbddd3e)
  [check] Section S.applied (Tables S10-S11) matches the paper as printed (MD5 408e285d6b6b86eafdfedf546c7db6e6)
  Figure 5 (lalonde_overlap.pdf) skipped: it draws per-unit propensity scores, which are not
  shipped; R/06_lalonde_overlap.R (benchmark data + model fitting) produces them.
  Figure 6 from output/lalonde_estimates.rds
  ```

  `[S5]` and `[S6]` name the Supplement tables the packaged inputs feed; the input files keep
  their historical `s4_`/`s5_` names. `applied_tables.R` also printed that Table S11 panel B is
  transcribed from the paper in the committed `output/lalonde_estimates.rds` (see
  `output/APPLIED_PROVENANCE.md`).

## Outputs written by the run

| File | Element |
|---|---|
| `output/table4_headline.md` | Table 4 |
| `images/sim_s2_coverage.pdf`, `images/sim_two_axis_map.pdf` | Figures 1-2 |
| `output/supplement_tables.md` | Tables S1, S2, S4-S6 and S9 |
| `output/s3_clean_gsplit_table.md` | Table S3 |
| `output/bias_mcse_tables.md` | Table S7 |
| `output/applied_tables.md` | Section S.applied: Tables S10-S11 |
| `images/rhc_forest.pdf`, `images/rhc_se_basic_vs_rich.pdf` | Figures 3-4 |
| `images/lalonde_truncation.pdf` | Figure 6 |
| `output/rhc_table_for_manuscript.csv` | by-product of Figures 3-4 (aggregate estimates; ignored by git) |
| `output/truths.rds`, `R/truths.rds`, `output/TRUTHS_PROVENANCE.md` | recovered truths |
| `output/ENVIRONMENT.md` | environment record |

## Independent comparison with the paper sources

Outside the scripts, the clone's outputs were compared with the manuscript sources. The Tables S1-S7
cell comparison was made at the previous check (`225ad1a`); since then their generators changed only in
heading and note text. The other comparisons below were repeated at `0575228`.

- **Table 4:** all 32 cells of `output/table4_headline.md` equal the LaTeX table in the main text.
- **Tables S1-S7:** every numeric cell of the generated markdown (485 in all: S1 24, S2 72, S3 40,
  S4 20, S5 60, S6 77, S7 192) equals the printed value at the printed precision, and the
  "not available" cells of Table S6 match. The formatting differs, as the README states: column
  labels, number formats (e.g. `-63.600` for `-63.6`, `NA` for `—`) and notes, and the Table S7
  file carries an empirical-SE MCSE column the paper omits.
- **Table S9:** the 81 lines from `### Table S9` through its note equal Section S.pairs of the
  Supplement.
- **Tables S10-S11:** `output/applied_tables.md` equals Section S.applied of the Supplement byte for
  byte (99 lines, from its heading to the line before `## References`, LF endings, including the
  three raw-LaTeX `\needspace` blocks of Table S11).
- **Figures 1, 2, 3, 4 and 6:** rendered at 100 dpi, each is pixel-identical to the committed image.
  The committed images are drawn with `cairo_pdf` (fonts embedded), and the manuscript now uses
  these same files.
- **Figure 5** is not reproduced on this route. The committed `images/lalonde_overlap.pdf` is the
  `pdftocairo` re-render of the original `pdf`-device drawing (font embedded; see the README's
  Known gaps) and is byte-identical to the manuscript's copy.

## Effect on the clone's tracked files

`git status` afterwards shows the five figures modified (the PDFs embed their creation time; the
renders are identical) and
`output/TRUTHS_PROVENANCE.md` changed in its date line only. Every committed `.rds`, including
`R/truths.rds`, was unchanged.
