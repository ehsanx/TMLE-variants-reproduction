# =====================================================================
# 09_supplement_tables.R -- generate Supplement Tables S1, S2, S4-S6 and S9
# (markdown) from the archived corrected results, so every number is reproducible.
# Reads only saved files and fits nothing:
#   output/compass_maps.rds              S1, S2, S4, S9
#   output/sim/compass_*.csv, diag_*.csv the raw cluster shards, when present;
#   otherwise output/s4_repetition_input.rds and output/s5_diagnostics_input.rds
#                                        S5, S6 (see output/S4_S5_PROVENANCE.md)
#   The packaged inputs keep their historical file names: s4_repetition_input.rds
#   feeds Table S5 and s5_diagnostics_input.rds feeds Table S6 (the Supplement
#   renumbered its tables in order of appearance; the files were not renamed).
# Emits output/supplement_tables.md:
#   Table S1  D3 (rough surface + random forest)       Section C
#   Table S2  S3 near-positivity sweep                 Section D
#   Table S4  n-gradient                               Section E
#   Table S5  corrected repetition overlays            Section F
#   Table S6  mechanism diagnostics                    Section G
#   Table S9  paired coverage comparisons at the four  Section K
#             primary settings (S1, S3, S2, D3); its subsection is emitted
#             verbatim as printed in the Supplement (heading, intro, two
#             panels, note) and stops if the saved maps disagree with its prose.
# Table S3 (the g-splitting contrast) comes from 12_s3_clean_gsplit.R, Table S7
# (bias and Monte Carlo SEs) from 10_bias_mcse_and_within_family.R, and
# Tables S10-S11 from applied_tables.R.
# =====================================================================
suppressPackageStartupMessages({ library(dplyr) })
RES  <- "output"
SIM  <- "output/sim"
OUT  <- "output/supplement_tables.md"
maps <- readRDS(file.path(RES, "compass_maps.rds"))
con  <- file(OUT, "w", encoding = "UTF-8"); w <- function(...) cat(..., "\n", file = con, sep = "")

mdtab <- function(df, digits = 3) {
  df[] <- lapply(df, function(c) if (is.numeric(c)) formatC(round(c, digits), format = "f", digits = digits) else as.character(c))
  w("| ", paste(names(df), collapse = " | "), " |")
  w("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  for (i in seq_len(nrow(df))) w("| ", paste(df[i, ], collapse = " | "), " |")
  w("")
}
graded8 <- c("TMLE","AIPW","CVQ-TMLE","SS-TMLE","CV-TMLE","CF-AIPW","DCTMLE","DC-AIPW")

## ---- Section C table: second DGM (rough + ranger), n=3000 ----
w("### Table S1 — D3 (rough surface + random forest), n=3000, nsim=2500")
d3 <- maps[["D3_sharp1.0_gb0.025_n3000"]]
s <- d3$summary %>% dplyr::left_join(d3$validity[,c("label","validity")], by="label") %>%
  dplyr::filter(label %in% graded8) %>%
  dplyr::transmute(recipe=label, cover, empSE, relSE=round(relSE,1), validity) %>%
  dplyr::arrange(match(recipe, graded8))
mdtab(as.data.frame(s), 3)
w(sprintf("_Truth %.5f. In-sample-g recipes collapse; cross-fit-g recipes all TOST-valid — the S2 non-Donsker result on a second DGM._\n", d3$truth))

## ---- Section D table: near-positivity sweep, two-cut summary ----
w("### Table S2 — S3 near-positivity sweep: targeting-family vs g-splitting axis (mean coverage)")
s3keys <- grep("^S3_", names(maps), value = TRUE)
rows <- lapply(s3keys, function(k) {
  m <- maps[[k]]; ax <- m$axis
  fam <- ax$by_family; gs <- ax$by_gsplit
  pp <- as.numeric(sub(".*sharp([0-9.]+)_.*","\\1",k)); gb <- as.numeric(sub(".*gb([0-9.]+)_.*","\\1",k))
  data.frame(sharp=pp, gbound=gb, nsim=max(m$summary$nsim),
    onestep=fam$mean_cover[fam$family=="one-step"], fluct=fam$mean_cover[fam$family=="fluctuation"],
    crossfit_g=gs$mean_cover[gs$gsplit=="cross-fit-g"], insample_g=gs$mean_cover[gs$gsplit=="in-sample-g"])
})
s3 <- dplyr::bind_rows(rows) %>% dplyr::mutate(`fam gap`=onestep-fluct, `gsplit gap`=crossfit_g-insample_g) %>%
  dplyr::arrange(sharp, gbound)
s3d <- as.data.frame(s3)
names(s3d) <- c("sharpening","trunc. bound","nsim","one-step","fluctuation","cross-fit-g","in-sample-g","family gap","g-split gap")
mdtab(s3d, 3)
w("_Anchor = (sharpening 2.0, truncation bound 0.025, nsim=2500); other cells nsim=1000. The targeting-family gap is large and grows as the truncation bound shrinks toward 0.001; the g-splitting gap is secondary: holding the targeting form fixed it is equivalent at the anchor and material only at sharpening 1.5 with bounds 0.001 and 0.005 (Table S3). Sharpening is the propensity-sharpening parameter (larger = worse overlap); the truncation bound is the propensity-truncation bound._\n")

## ---- Section E table: n-gradient ----
w("### Table S4 — n-gradient: axis materiality and the efficiency penalty")
ngrad <- lapply(c("S1","S2"), function(sl) lapply(c(1000,3000), function(n) {
  m <- maps[[sprintf("%s_sharp1.0_gb0.025_n%d", sl, n)]]; gs <- m$axis$by_gsplit
  ss <- m$summary$empSE[m$summary$label=="SS-TMLE"]
  data.frame(regime=sl, n=n, crossfit_g=gs$mean_cover[gs$gsplit=="cross-fit-g"],
    insample_g=gs$mean_cover[gs$gsplit=="in-sample-g"],
    `gsplit gap`=gs$mean_cover[gs$gsplit=="cross-fit-g"]-gs$mean_cover[gs$gsplit=="in-sample-g"],
    `SS-TMLE empSE`=ss, check.names=FALSE)
}))
mdtab(as.data.frame(dplyr::bind_rows(unlist(ngrad, recursive=FALSE))), 3)
w("_The non-Donsker axis gap (S2) is n-robust; the splitting efficiency penalty (SS-TMLE empSE) shrinks as n grows. S1 stays a near-tie at both n._\n")

## ---- Section F table: corrected coverage-vs-R (per-dataset median, then coverage) ----
w("### Table S5 — Repetition overlays (corrected): coverage vs R")
# Prefer the raw per-replicate shards when a cluster run has populated output/sim/;
# otherwise fall back to the packaged subset committed to this repo -- the same
# shards restricted to the labels and slice/Rreps configurations this table
# consumes (see output/S4_S5_PROVENANCE.md; the file keeps its historical s4_
# name). A clone therefore reproduces Table S5, while a cluster run still
# exercises the full path.
files <- list.files(SIM, pattern="^compass_.*\\.csv$", full.names=TRUE)
if (length(files)) {
  raw <- dplyr::bind_rows(lapply(files, read.csv))
  cat("[S5] using", length(files), "raw shards from", SIM, "\n")
} else {
  pk <- "output/s4_repetition_input.rds"
  if (!file.exists(pk))
    stop("Table S5 needs either raw shards in ", SIM,
         " or the packaged input ", pk, " (neither found)")
  raw <- readRDS(pk)
  cat("[S5] using packaged input", pk, "-", nrow(raw), "rows",
      "(see output/S4_S5_PROVENANCE.md)\n")
}
rep_curve <- function(sub, truth, Rlv, labs) {
  out <- list(); k <- 0L
  for (lab in labs) { d <- sub[sub$label==lab & is.finite(sub$rd), c("sim_id","rep","rd","vd")]
    if (!nrow(d)) next
    for (R in Rlv) { agg <- d %>% dplyr::filter(rep<=R) %>% dplyr::group_by(sim_id) %>%
        dplyr::summarise(rd_c=stats::median(rd), mvd=stats::median(vd+(rd-stats::median(rd))^2), .groups="drop")
      agg$se <- sqrt(agg$mvd); k<-k+1L
      out[[k]] <- data.frame(recipe=lab, R=R, cover=mean(agg$rd_c-1.96*agg$se<=truth & truth<=agg$rd_c+1.96*agg$se),
        # model-based SE as the root mean square of the corrected SEs, as in compass_map.R and
        # the paper (aggregate_compass.R's archived report averages the SEs; same conclusion)
        relSE=round(100*(sqrt(mean(agg$se^2))/sd(agg$rd_c)-1),0)) } }
  dplyr::bind_rows(out)
}
show <- c("TMLE","AIPW","SS-TMLE","CV-TMLE","CF-AIPW","DC-AIPW")
for (cfg in list(c("S1",100), c("S2",25), c("D3",25))) {
  sl <- cfg[1]; Rmax <- as.integer(cfg[2])
  sub <- raw %>% dplyr::filter(slice==sl, Rreps==Rmax); truth <- sub$truth[1]
  Rlv <- c(1,5,25,Rmax); Rlv <- sort(unique(Rlv[Rlv<=Rmax]))
  cur <- rep_curve(sub, truth, Rlv, show)
  wide <- reshape(cur[,c("recipe","R","cover")], idvar="recipe", timevar="R", direction="wide")
  names(wide) <- sub("cover\\.","R=",names(wide)); wide <- wide[match(show, wide$recipe),]
  w(sprintf("**%s** (nsim=%d): coverage by R", sl, dplyr::n_distinct(sub$sim_id))); mdtab(as.data.frame(wide), 3)
}
w("_No-split recipes (TMLE, AIPW) are R-invariant; split recipes plateau by R≈5–10 and grow more conservative, not toward nominal._\n")

## ---- Section G table: mechanism diagnostics ----
w("### Table S6 — Mechanism diagnostics (mean over shards)")
# Same preference order as Table S5 above; the packaged diagnostics (historical
# file name s5_diagnostics_input.rds) are the complete diag_* shard set
# concatenated unchanged (output/S4_S5_PROVENANCE.md).
dfiles <- list.files(SIM, pattern="^diag_.*\\.csv$", full.names=TRUE)
if (length(dfiles)) {
  draw <- dplyr::bind_rows(lapply(dfiles, read.csv))
  cat("[S6] using", length(dfiles), "raw diag shards from", SIM, "\n")
} else {
  pk5 <- "output/s5_diagnostics_input.rds"
  if (!file.exists(pk5))
    stop("Table S6 needs either diag shards in ", SIM,
         " or the packaged input ", pk5, " (neither found)")
  draw <- readRDS(pk5)
  cat("[S6] using packaged input", pk5, "-", nrow(draw), "rows\n")
}
dg <- draw %>% dplyr::group_by(slice, sharp, gbound) %>%
  dplyr::summarise(frac_g_trunc=mean(frac_g_trunc), q_insample_mse=mean(q_insample_mse),
    q_oof_mse=mean(q_oof_mse), q_optimism=mean(q_optimism), ranger_weight=mean(ranger_weight), .groups="drop") %>%
  dplyr::arrange(slice, sharp, gbound)
dgd <- as.data.frame(dg)
names(dgd) <- c("regime","sharpening","trunc. bound","frac. truncated","Q in-sample MSE","Q oof MSE","Q optimism","forest SL weight")
mdtab(dgd, 3)
w("_Q optimism (out-of-fold − in-sample MSE) is large only under the random forest (S2, D3; forest SL weight 1); near-zero under the low-complexity library (S1, S3)._")

## ---- Table S9: paired coverage comparisons among the eight main estimators ----
## ---- at each regime's primary setting (replaces the former S1-only block)   ----
# Reads only the saved maps (no fitting): for each primary setting it takes
# maps[[key]]$pairwise (a, b, dcover, ci_lo, ci_hi, verdict). Each unordered pair is
# stored in both orientations; the row whose a comes first in e8 is used.
# The map's "worse"/"better" are SIGNED (a's coverage below/above b's) and both mean
# "materially different"; the table prints the letter M with the signed difference, so
# overcoverage on S2 is never labelled "better".
# Emits, verbatim, the Table S9 subsection of _supplement.md (heading, intro, two panels,
# note); the stopifnot() checks fail loudly if the saved maps disagree with the prose.
e8 <- c("TMLE","AIPW","CVQ-TMLE","SS-TMLE","CV-TMLE","CF-AIPW","DCTMLE","DC-AIPW")
s9_keys <- c(S1 = "S1_sharp1.0_gb0.025_n3000", S3 = "S3_sharp2.0_gb0.025_n3000",
             S2 = "S2_sharp1.0_gb0.025_n3000", D3 = "D3_sharp1.0_gb0.025_n3000")
pp <- function(v) { s <- sprintf("%+.1f", 100*v); ifelse(s %in% c("+0.0","-0.0"), "0.0", s) }
s9_letter <- function(v) {
  out <- ifelse(v %in% c("worse","better"), "M",
         ifelse(v == "equivalent", "E", ifelse(v == "inconclusive", "I", NA_character_)))
  stopifnot(!anyNA(out)); out
}
s9_pairs <- function(key) {
  m <- maps[[key]]; pw <- m$pairwise; d <- m$delta_cov
  stopifnot(isTRUE(all.equal(d, 0.02)))
  out <- do.call(rbind, lapply(1:7, function(i) do.call(rbind, lapply((i+1):8, function(j) {
    r <- pw[pw$a == e8[i] & pw$b == e8[j], ]
    stopifnot(nrow(r) == 1)
    # the stored verdict must be the TOST interval rule at delta_cov = 0.02
    rule <- if (r$ci_lo > -d && r$ci_hi < d) "E" else if (r$ci_lo >= d || r$ci_hi <= -d) "M" else "I"
    stopifnot(rule == s9_letter(r$verdict))
    data.frame(a = e8[i], b = e8[j], letter = rule, dcover = r$dcover,
               cell = paste0(pp(r$dcover), " (", pp(r$ci_lo), " to ", pp(r$ci_hi), ") ", rule))
  }))))
  stopifnot(nrow(out) == 28)
  out
}
s9 <- lapply(s9_keys, s9_pairs)

# facts the prose states; stop if the saved maps say otherwise
s1 <- s9$S1
stopifnot(all(s1$letter[s1$a != "SS-TMLE" & s1$b != "SS-TMLE"] == "E"),            # 21 full-sample pairs
          s1$letter[s1$a == "TMLE" & s1$b == "SS-TMLE"] == "E",
          sum(s1$letter[s1$a == "SS-TMLE" | s1$b == "SS-TMLE"] == "I") == 6)
d3s <- maps[[s9_keys[["D3"]]]]$summary
stopifnot(all(d3s$nsim[d3s$label %in% c("TMLE","AIPW")] == 2499),
          all(d3s$nsim[d3s$label %in% setdiff(e8, c("TMLE","AIPW"))] == 2500),
          all(sapply(s9_keys[c("S1","S2","S3")], function(k) {
            s <- maps[[k]]$summary; all(s$nsim[s$label %in% e8] == 2500) })))

w("### Table S9 — Paired coverage comparisons among the eight main estimators at each primary setting")
w("")
w("Each cell is a paired TOST (Section J) on the coverage difference between estimators a and b, computed")
w("under common random numbers at n = 3000 with 2500 simulated datasets: S1, S2 and D3 with truncation bound 0.025, and S3")
w("at its primary setting (sharpening 2.0, bound 0.025). A cell gives the difference a - b in percentage")
w("points, its paired 90% confidence interval, and the verdict under the 0.02 margin: E, equivalent (interval")
w("inside $\\pm 2$ pp); M, materially different (interval wholly outside); I, inconclusive (otherwise). The sign")
w("gives only the direction of the coverage difference: on S2 several estimators overcover, so higher")
w("coverage is not necessarily better. On D3 one dataset failed the no-split fit, so pairs involving TMLE or")
w("AIPW use 2499 datasets. Limits are rounded to 0.1 pp and verdicts use the unrounded limits, so a printed")
w("limit of $\\pm 2.0$ can accompany either verdict. Readers who prefer another margin can apply it to the")
w("intervals directly. In S1 the seven full-sample estimators are equivalent in all 21 of their pairs, and")
w("SS-TMLE is equivalent to TMLE and inconclusive against the other six.")
w("")
s9_panel <- function(label, k1, k2) {
  stopifnot(identical(s9[[k1]]$a, s9[[k2]]$a), identical(s9[[k1]]$b, s9[[k2]]$b))
  w(label); w("")
  w("| a | b | ", k1, " | ", k2, " |")
  # dash counts set the relative column widths (15/15/35/35%; "CVQ-TMLE" needs the 15%);
  # the separator exceeds 72 characters, so pandoc uses these widths rather than equal ones
  w("|------------|------------|----------------------------|----------------------------|")
  for (r in seq_len(28))
    w("| ", s9[[k1]]$a[r], " | ", s9[[k1]]$b[r], " | ", s9[[k1]]$cell[r], " | ", s9[[k2]]$cell[r], " |")
  w("")
}
s9_panel("**(a) Low-complexity library: S1 and the S3 primary setting**", "S1", "S3")
s9_panel("**(b) Single random forest: S2 and D3**", "S2", "D3")
cnt <- sapply(s9[c("S1","S3","S2","D3")], function(x)
  sprintf("%d/%d/%d", sum(x$letter == "E"), sum(x$letter == "M"), sum(x$letter == "I")))
w("_Table S9 note._ Verdict counts over the 28 pairs (E/M/I): ", paste(names(cnt), cnt, collapse = "; "), ".")
close(con); cat("wrote", OUT, "\n")

## ---- Self-check: Table S9 against the Supplement as printed ----
# Table S9 is formatted from the fixed canonical maps, so its subsection (from the
# "### Table S9" heading through the note, LF line endings) must equal Section
# Section K of the Supplement byte for byte; its MD5 there is S9_PAPER_MD5.
S9_PAPER_MD5 <- "e920b276487e32f867046debd45126e9"
txt <- readLines(OUT, encoding = "UTF-8", warn = FALSE)
i0 <- grep("^### Table S9", txt); i1 <- grep("^_Table S9 note\\._", txt)
stopifnot(length(i0) == 1L, length(i1) == 1L, i1 > i0)
tf <- tempfile(fileext = ".md"); con9 <- file(tf, "wb")
writeBin(charToRaw(enc2utf8(paste0(paste(txt[i0:i1], collapse = "\n"), "\n"))), con9); close(con9)
s9_md5 <- unname(tools::md5sum(tf)); unlink(tf)
if (!identical(s9_md5, S9_PAPER_MD5))
  stop("Table S9 differs from the Supplement as printed (MD5 ", s9_md5, ", expected ", S9_PAPER_MD5, ")")
cat("[check] Table S9 matches the Supplement as printed (MD5 ", s9_md5, ")\n", sep = "")
