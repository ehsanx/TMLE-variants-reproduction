# Provenance of the recovered canonical truths

Recovered 2026-10-04, with NO draws taken and no simulation re-run.

Source: the packaged repetition input output/s4_repetition_input.rds (the Table S5 input; historical file name). Every per-replicate record carries, in its `truth` column, the
value that run actually scored coverage against, so these are the canonical values by
construction rather than by recomputation.

| Quantity | Recovered | `run_compass.R` fallback | Difference |
|---|---|---|---|
| D1 (statin, backs S1/S2/S3) | `-0.1081358` | `-0.1081508` | `1.5e-05` |
| D3 (rough surface) | `0.1006854` | `0.10068` | `5.4e-06` |

The fallbacks are close but not equal, so a cluster re-run without this file would score
coverage against slightly different truths than the reported results did. That is the gap
this file closes.

## What is NOT recovered

`pin_truths.R` also records `nD1`/`nD3`, the number of draws used to pin each truth
(its default is 1e8). **Those are not recoverable from the saved record**: the shards store
the resulting value, not the draw count, and no `pin_truths.R` log survives in the project.
They are written as `NA` rather than guessed. Nothing in the pipeline reads them --
`run_compass.R:37-38` reads only `$D1` and `$D3` -- so this does not affect reproduction.

## Independent corroboration

The 16 per-shard run manifests record `truth_source=pinned` together with
`D1=-0.1081358 D3=0.1006854` -- the same values recovered here, from a different place in the
saved record. They also confirm the production run really did read a pinned file rather than
falling back, which is what makes these the canonical values rather than merely the observed ones.

## Consistency check

The upstream `dgm.py` of Zivich and Breskin carries the value `-0.1081508` in a code comment; it is not
reported in their published article or eAppendix. The recovered D1 differs from it by `1.5e-05`, the order
expected from a large-but-finite Monte Carlo pinning, so the recovered value is consistent with that
reference value without being identical to it.

## Use

`run_compass.R` reads `$COMPASS_ENGINE/truths.rds` and prefers it over the fallbacks. To use
this file for a cluster re-run, place it at the engine root, e.g. `cp output/truths.rds R/`.
