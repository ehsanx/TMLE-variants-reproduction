# =====================================================================
# aggregate_compass.R -- pool COMPASS shards into the materiality MAP, with a
# COMPLETENESS GATE so a partial/timed-out run never yields an authoritative-
# looking reduced-nsim map. Sources the engine from COMPASS_ENGINE; reads shards
# from COMPASS_OUT; writes maps + report to COMPASS_RESULTS.
#   Rscript aggregate_compass.R [delta_cov]        (default 0.02, pre-registered)
#   COMPASS_ALLOW_PARTIAL=1 forces a partial aggregate (debug only).
# =====================================================================
suppressPackageStartupMessages({ library(dplyr) })
ENGINE  <- Sys.getenv("COMPASS_ENGINE",  unset = "R")
INDIR   <- Sys.getenv("COMPASS_OUT",     unset = "output/sim")
RESULTS <- Sys.getenv("COMPASS_RESULTS", unset = "output")
source(file.path(ENGINE, "01_engine.R")); source(file.path(ENGINE, "02_variants.R"))
source(file.path(ENGINE, "recipes.R"));   source(file.path(ENGINE, "compass_map.R"))
a <- commandArgs(trailingOnly = TRUE)
delta_cov <- if (length(a) >= 1) as.numeric(a[1]) else 0.02
allow_partial <- nzchar(Sys.getenv("COMPASS_ALLOW_PARTIAL"))
dir.create(RESULTS, recursive = TRUE, showWarnings = FALSE)

files <- list.files(INDIR, pattern = "^compass_.*\\.csv$", full.names = TRUE)
if (!length(files)) stop("no compass_*.csv shards in ", INDIR)
raw <- dplyr::bind_rows(lapply(files, read.csv, stringsAsFactors = FALSE))
cat(sprintf("Loaded %d shards, %d rows; slices: %s\n", length(files), nrow(raw),
            paste(unique(raw$slice), collapse = ", ")))

# ---- COMPLETENESS GATE: expected nsim per (slice,sharp,gbound,Rreps) from manifests ----
manf <- list.files(INDIR, pattern = "^manifest_.*\\.txt$", full.names = TRUE)
exp_tab <- dplyr::bind_rows(lapply(manf, function(mf) {
  ln <- readLines(mf, warn = FALSE)[1]
  m <- regmatches(ln, regexec("slice=(\\S+) R=(\\d+) sharp=([0-9.]+) gbound=([0-9.]+) n=(\\d+) nsim=(\\d+)", ln))[[1]]
  if (length(m) == 7) data.frame(slice = m[2], Rreps = as.integer(m[3]), sharp = as.numeric(m[4]),
                                 gbound = as.numeric(m[5]), n_per = as.integer(m[6]), nsim = as.integer(m[7])) else NULL }))
incomplete <- FALSE
if (nrow(exp_tab)) {
  got <- raw %>% dplyr::group_by(slice, sharp, gbound, Rreps, n_per) %>%
    dplyr::summarise(got = dplyr::n_distinct(sim_id), .groups = "drop")
  chk <- dplyr::left_join(exp_tab, got, by = c("slice","sharp","gbound","Rreps","n_per"))
  chk$got[is.na(chk$got)] <- 0L; chk$missing <- chk$nsim - chk$got
  bad <- chk[chk$missing > 0, ]
  if (nrow(bad)) { incomplete <- TRUE
    cat("\n*** INCOMPLETE RUN -- missing replicates: ***\n")
    print(as.data.frame(bad[, c("slice","sharp","gbound","n_per","Rreps","nsim","got","missing")]), row.names = FALSE) }
} else cat("(no manifests found -- completeness gate SKIPPED; treat the map as provisional)\n")
if (incomplete && !allow_partial)
  stop("COMPLETENESS GATE: run is INCOMPLETE (see missing above). Resubmit the missing shards, or set ",
       "COMPASS_ALLOW_PARTIAL=1 to force a provisional aggregate.")

sink(file.path(RESULTS, "compass_report.txt"), split = TRUE)
if (incomplete) cat("!!! PROVISIONAL: run is INCOMPLETE, forced via COMPASS_ALLOW_PARTIAL !!!\n")

# ---- FA2 (2026-08-09, post-freeze): PER-RECIPE completeness. The gate above counts
# distinct sim_id POOLED across labels, so a group/recipe-level dropout (a sim_id present
# for some recipes but not others) is invisible to it. Report per-label shortfalls as a
# WARNING (never a hard stop): a recipe whose shared nuisance fit failed on one dataset is
# a disclosed 1/nsim event, not a reason to refuse the map; paired comparisons intersect
# shared sim_ids. Emitted into the report so per-recipe nsim is auditable.
if (nrow(exp_tab)) {
  got_lab <- raw %>% dplyr::group_by(slice, sharp, gbound, Rreps, n_per, label) %>%
    dplyr::summarise(rows_ok = dplyr::n_distinct(sim_id[is.finite(rd)]), .groups = "drop")
  chk_lab <- dplyr::left_join(got_lab, exp_tab, by = c("slice","sharp","gbound","Rreps","n_per"))
  short <- chk_lab[!is.na(chk_lab$nsim) & chk_lab$rows_ok < chk_lab$nsim, ]
  if (nrow(short)) {
    cat("\n*** PER-RECIPE DROPOUT (warning; map still built) -- recipes scored on fewer datasets than nsim: ***\n")
    print(as.data.frame(short[order(short$slice, short$sharp, short$gbound, short$label),
                              c("slice","sharp","gbound","n_per","Rreps","label","nsim","rows_ok")]), row.names = FALSE)
  }
}
maps <- list()
# LEADERBOARD = the R=1 single-split object, one map per (slice, sharp, gbound, n).
# The n-gradient (S1/S2 at n in {1000,3000}) yields a map at EACH n.
lead_all <- raw %>% dplyr::filter(Rreps == 1L, rep == 1L)
cfgs <- lead_all %>% dplyr::distinct(slice, sharp, gbound, n_per)
for (i in seq_len(nrow(cfgs))) {
  cf <- cfgs[i, ]
  lead <- lead_all %>% dplyr::filter(slice == cf$slice, sharp == cf$sharp, gbound == cf$gbound, n_per == cf$n_per)
  truth <- lead$truth[1]
  m <- compass_map(lead[, c("sim_id","label","rd","se")], truth, delta_cov = delta_cov)
  key <- sprintf("%s_sharp%.1f_gb%.3f_n%d", cf$slice, cf$sharp, cf$gbound, cf$n_per); maps[[key]] <- m
  cat(sprintf("\n===== %s  (truth=%.5f, nsim=%d, delta_cov=%.3f) =====\n",
              key, truth, max(m$summary$nsim), delta_cov))
  cat("VALIDITY + lexicographic GRADE (graded recipes):\n"); print(as.data.frame(m$grade), digits = 3, row.names = FALSE)
  cat("materiality BANDS:\n"); print(as.data.frame(m$bands), digits = 3, row.names = FALSE)
  cat("AXIS diagnosis (mean coverage):\n by g-splitting: "); print(as.data.frame(m$axis$by_gsplit), digits = 3, row.names = FALSE)
  cat(" by targeting family: "); print(as.data.frame(m$axis$by_family), digits = 3, row.names = FALSE)
}
# REPS OVERLAYS = any (slice, sharp, gbound, n, Rreps>1): the S1 R=100 plateau AND
# the S2/D3 R=25 non-benign reps overlay.
# ---------------------------------------------------------------------------------
# BUGFIX 2026-08-08 (post-freeze; logged in REVIEW/RESULTS_REREVIEW_2026-08-08.md):
# the previous overlay called aggregate_splits() after dropping sim_id, which pooled
# ALL datasets' reps and reduced to the first min(R,n) rep-sorted rows -- a
# cross-dataset artifact (rd(R=1) == the first dataset's single-split estimate), and
# it never emitted coverage. The CORRECT reps overlay aggregates the R repeated splits
# WITHIN each dataset (median method), THEN computes coverage/relSE ACROSS datasets.
rep_overlay_curve <- function(sub, truth, R_levels) {
  labs <- unique(sub$label); out <- list(); k <- 0L
  for (lab in labs) {
    d <- sub[sub$label == lab & is.finite(sub$rd), c("sim_id","rep","rd","vd")]
    if (!nrow(d)) next
    for (R in R_levels) {
      agg <- d %>% dplyr::filter(rep <= R) %>% dplyr::group_by(sim_id) %>%
        dplyr::summarise(rd_c = stats::median(rd),
                         mvd  = stats::median(vd + (rd - stats::median(rd))^2),
                         .groups = "drop")
      agg$se_c <- sqrt(agg$mvd); has_se <- all(is.finite(agg$se_c))
      cov <- if (has_se) mean(agg$rd_c - 1.96*agg$se_c <= truth &
                             truth <= agg$rd_c + 1.96*agg$se_c) else NA_real_
      k <- k + 1L
      # NOTE: this archived overlay averages the corrected SEs (modelSE = mean). The paper and
      # compass_map.R define the model-based SE as the root mean square; 09_supplement_tables.R
      # uses RMS. Left unchanged so the archived compass_report.txt still rebuilds exactly; the
      # conclusions do not change (e.g. S1 SS-TMLE relSE +34.8%..+57.8% here vs +35.6%..+58.1% RMS).
      out[[k]] <- dplyr::tibble(label = lab, R = R, nsim = nrow(agg),
        rd = mean(agg$rd_c), bias = mean(agg$rd_c) - truth, empSE = sd(agg$rd_c),
        modelSE = mean(agg$se_c), relSE = 100*(mean(agg$se_c)/sd(agg$rd_c) - 1), cover = cov)
    }
  }
  dplyr::bind_rows(out)
}
rep_cfgs <- raw %>% dplyr::filter(Rreps > 1L) %>% dplyr::distinct(slice, sharp, gbound, n_per, Rreps)
for (i in seq_len(nrow(rep_cfgs))) {
  rc <- rep_cfgs[i, ]; Rlv <- c(1,5,10,25,50,100); Rlv <- Rlv[Rlv <= rc$Rreps]
  sub <- raw %>% dplyr::filter(slice == rc$slice, sharp == rc$sharp, gbound == rc$gbound,
                               n_per == rc$n_per, Rreps == rc$Rreps)
  cat(sprintf("\n===== REPS OVERLAY %s sharp%.1f gb%.3f n%d (Rreps=%d, nsim=%d; per-dataset median -> coverage-vs-R) =====\n",
              rc$slice, rc$sharp, rc$gbound, rc$n_per, rc$Rreps, dplyr::n_distinct(sub$sim_id)))
  cur <- rep_overlay_curve(sub, sub$truth[1], Rlv)
  print(as.data.frame(cur), digits = 3, row.names = FALSE)
}
dfiles <- list.files(INDIR, pattern = "^diag_.*\\.csv$", full.names = TRUE)
if (length(dfiles)) {
  dg <- dplyr::bind_rows(lapply(dfiles, read.csv))
  cat("\n===== MECHANISM DIAGNOSTICS (mean over shards) =====\n")
  print(as.data.frame(dg %>% dplyr::group_by(slice, sharp, gbound) %>%
    dplyr::summarise(frac_g_trunc = mean(frac_g_trunc), q_insample_mse = mean(q_insample_mse),
                     q_oof_mse = mean(q_oof_mse), q_optimism = mean(q_optimism),
                     ranger_weight = mean(ranger_weight), .groups = "drop")), digits = 3, row.names = FALSE)
}
sink()
saveRDS(maps, file.path(RESULTS, "compass_maps.rds"))
cat(sprintf("\n%s -> %s and compass_report.txt\n", if (incomplete) "PROVISIONAL map" else "Complete map",
            file.path(RESULTS, "compass_maps.rds")))
