# Provenance of the packaged repetition and diagnostics inputs (Supplement Tables S5 and S6)

Generated 2026-10-04 from the frozen cluster output, with NO re-simulation.

**Historical file names.** These inputs were packaged when the repetition overlays and the
mechanism diagnostics were Supplement Tables S4 and S5. The Supplement has since numbered its
tables in order of appearance, so `s4_repetition_input.rds` now feeds **Table S5** (repetition
overlays) and `s5_diagnostics_input.rds` feeds **Table S6** (mechanism diagnostics). The two
files, and this note, keep their original names so that their checksums and every reference
to them stay valid.

Source: the frozen cluster output directory in the authors' project tree -- 324 `compass_*.csv`
shards (109 MB total) and 324 `diag_*.csv` shards (324 KB total).

## `s4_repetition_input.rds` (Table S5)

252000 rows x 8 columns. The `compass_*` shards subset to exactly what Table S5 consumes:
- labels: TMLE, AIPW, SS-TMLE, CV-TMLE, CF-AIPW, DC-AIPW
- slice/Rreps configurations: S1 at Rreps=100, S2 at 25, D3 at 25
- columns: sim_id, slice, Rreps, label, rep, rd, vd, truth

The other eight estimator labels, the S3 sweep cells and the unused columns are dropped;
they belong to tables that reproduce from `compass_maps.rds` instead. Per-replicate `rd`
and `vd` are retained because Table S5 medians them within each dataset at several R cutoffs,
so they cannot be pre-aggregated without fixing R.

## `s5_diagnostics_input.rds` (Table S6)

324 rows x 10 columns -- the complete `diag_*` shard set, concatenated unchanged.

## Integrity

- `s4_repetition_input.rds` md5 `5e3c333c580bda3433276e62582187b3`
- `s5_diagnostics_input.rds` md5 `501d2202a3cfebb98cca21ab300fb7db`

`09_supplement_tables.R` prefers the raw shards when `output/sim/` is populated and falls
back to these packaged inputs otherwise, so a clone reproduces Tables S5 and S6 while a
cluster run still exercises the full path.
