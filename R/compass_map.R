# =====================================================================
# compass_map.R -- the COMPASS deliverable object: a regime-conditional
# MATERIALITY MAP from per-replicate simulation output.
#
# Input `long`: one row per (sim_id, label) within ONE regime/slice, columns
#   sim_id, label, rd, se   (se = NA for plugin recipes -> excluded from
#   coverage/validity but kept for bias/mse). CRN => the SAME sim_ids across
#   recipes, so recipe-vs-recipe comparisons are PAIRED (variance-reducing).
#
# Produces, per regime:
#   (1) per-recipe metrics with Monte Carlo SEs (Morris-White-Crowther);
#   (2) VALIDITY class: TOST of each recipe's coverage vs nominal 0.95 at a
#       pre-declared margin delta_cov -> valid / under / over / inconclusive;
#   (3) pairwise PAIRED-coverage TOST (McNemar-style) -> equivalence, and
#       ordered materiality BANDS (recipes indistinguishable within delta_cov);
#   (4) lexicographic GRADE rank: |coverage-0.95| within MCSE -> min empSE ->
#       |relSE| (the pre-registered rule);
#   (5) AXIS diagnosis: mean coverage by g-splitting and by targeting family
#       (the paper's correction route, AIPW versus TMLE), to surface which axis
#       is material in this regime.
# All "equivalence" is TOST vs a pre-declared delta, never "within 2xMCSE".
# =====================================================================
suppressPackageStartupMessages({ library(dplyr) })

# recipe -> (g-splitting, targeting family) tags for the axis diagnosis
compass_axis_map <- function() dplyr::tribble(
  ~label,          ~gsplit,        ~family,
  "TMLE",          "in-sample-g",  "fluctuation",
  "AIPW",          "in-sample-g",  "one-step",
  "GCOMP",         "in-sample-g",  "plugin",
  "SS-TMLE",       "split-half-g", "fluctuation",
  "CVQ-TMLE",      "in-sample-g",  "fluctuation",   # g in-sample (qonly)
  "CVQ-TMLE-fold", "in-sample-g",  "fluctuation",
  "CF-GCOMP",      "cross-fit-g",  "plugin",
  "CV-TMLE",       "cross-fit-g",  "fluctuation",
  "CV-TMLE-fold",  "cross-fit-g",  "fluctuation",
  "CF-AIPW",       "cross-fit-g",  "one-step",
  "SCTMLE",        "cross-fit-g",  "fluctuation",
  "DC-TMLE-pool",  "cross-fit-g",  "fluctuation",
  "DCTMLE",        "cross-fit-g",  "fluctuation",
  "DC-AIPW",       "cross-fit-g",  "one-step")

# (1) per-recipe metrics ------------------------------------------------
compass_summary <- function(long, truth) {
  long %>% dplyr::filter(is.finite(rd)) %>% dplyr::group_by(label) %>%
    dplyr::summarise(
      nsim    = dplyr::n(),
      bias    = mean(rd - truth),
      empSE   = sd(rd),
      modelSE = sqrt(mean(se^2, na.rm = TRUE)),
      relSE   = 100 * (sqrt(mean(se^2, na.rm = TRUE)) / sd(rd) - 1),
      mse     = mean((rd - truth)^2),
      cover   = mean(rd - 1.96*se <= truth & truth <= rd + 1.96*se, na.rm = TRUE),
      n_cov   = sum(is.finite(se)),
      .groups = "drop") %>%
    dplyr::mutate(cover_mcse = sqrt(cover * (1 - cover) / pmax(n_cov, 1)),
                  cover = ifelse(n_cov > 0, cover, NA_real_))
}

# (2) validity vs nominal: TOST of coverage against 0.95 +/- delta_cov ---
# 90% CI (alpha=0.05 one-sided) on coverage; verdict by where it sits.
compass_validity <- function(summ, delta_cov = 0.02, target = 0.95, alpha = 0.05) {
  z <- stats::qnorm(1 - alpha)
  summ %>% dplyr::mutate(
    ci_lo = cover - z * cover_mcse, ci_hi = cover + z * cover_mcse,
    validity = dplyr::case_when(
      is.na(cover)                              ~ "no-SE",
      ci_lo >= target - delta_cov & ci_hi <= target + delta_cov ~ "valid",
      ci_hi <  target - delta_cov               ~ "under-covers",
      ci_lo >  target + delta_cov               ~ "over-covers",
      TRUE                                      ~ "inconclusive")) %>%
    dplyr::select(label, cover, cover_mcse, validity, ci_lo, ci_hi)
}

# (3) pairwise PAIRED-coverage TOST under CRN ----------------------------
# For every ordered pair, Delta = mean(cov_a - cov_b) on shared sims; paired
# SE = sd(diff)/sqrt(n); 90% CI; equivalent if CI within +/-delta_cov.
compass_pairwise <- function(long, truth, delta_cov = 0.02, alpha = 0.05) {
  cov_ind <- long %>% dplyr::filter(is.finite(rd), is.finite(se)) %>%
    dplyr::transmute(sim_id, label, cov = as.numeric(rd - 1.96*se <= truth & truth <= rd + 1.96*se))
  labs <- sort(unique(cov_ind$label)); z <- stats::qnorm(1 - alpha)
  wide <- cov_ind %>% tidyr::pivot_wider(names_from = label, values_from = cov)
  out <- list(); k <- 0L
  for (i in seq_along(labs)) for (j in seq_along(labs)) if (i != j) {
    a <- wide[[labs[i]]]; b <- wide[[labs[j]]]
    ok <- is.finite(a) & is.finite(b); d <- a[ok] - b[ok]; nn <- length(d)
    if (nn < 2) next
    Delta <- mean(d); se_d <- sd(d) / sqrt(nn)
    lo <- Delta - z*se_d; hi <- Delta + z*se_d
    verdict <- if (lo >= -delta_cov && hi <= delta_cov) "equivalent"
               else if (hi < -delta_cov) "worse" else if (lo > delta_cov) "better" else "inconclusive"
    k <- k + 1L
    out[[k]] <- dplyr::tibble(a = labs[i], b = labs[j], dcover = Delta, se = se_d,
                              ci_lo = lo, ci_hi = hi, verdict = verdict)
  }
  dplyr::bind_rows(out)
}

# ordered materiality BANDS: sort by coverage-closeness to nominal (best first);
# walk the order, starting a new band when a recipe is NOT paired-equivalent to
# the current band anchor (|dcover| CI not within delta_cov).
compass_bands <- function(summ, pairwise, delta_cov = 0.02, target = 0.95) {
  s <- summ %>% dplyr::filter(!is.na(cover)) %>%
    dplyr::mutate(dist = abs(cover - target)) %>% dplyr::arrange(dist, empSE)
  eqv <- function(x, y) {
    r <- pairwise[pairwise$a == x & pairwise$b == y, ]
    nrow(r) == 1 && r$verdict == "equivalent"
  }
  band <- integer(nrow(s)); if (nrow(s)) band[1] <- 1L; anchor <- if (nrow(s)) s$label[1] else NA
  for (i in seq_len(nrow(s))[-1]) {
    if (eqv(anchor, s$label[i])) band[i] <- band[i-1]
    else { band[i] <- band[i-1] + 1L; anchor <- s$label[i] }
  }
  s$band <- band
  s %>% dplyr::select(band, label, cover, empSE, dist)
}

# (4) lexicographic GRADE: coverage-within-MCSE-of-0.95, then min empSE, then |relSE|
compass_grade <- function(summ, target = 0.95) {
  summ %>% dplyr::filter(!is.na(cover)) %>%
    dplyr::mutate(valid_key = as.integer(abs(cover - target) <= 1.96 * cover_mcse),
                  key1 = -valid_key,            # valid (1) sorts before invalid (0)
                  key2 = empSE, key3 = abs(relSE)) %>%
    dplyr::arrange(key1, key2, key3) %>%
    dplyr::mutate(rank = dplyr::row_number()) %>%
    dplyr::select(rank, label, cover, empSE, relSE, valid = valid_key)
}

# (5) axis diagnosis: mean coverage by g-splitting and by targeting family
compass_axis_diag <- function(summ, axis = compass_axis_map()) {
  s <- summ %>% dplyr::left_join(axis, by = "label") %>% dplyr::filter(!is.na(cover))
  list(
    by_gsplit = s %>% dplyr::group_by(gsplit) %>%
      dplyr::summarise(mean_cover = mean(cover), n = dplyr::n(), .groups = "drop") %>% dplyr::arrange(-mean_cover),
    by_family = s %>% dplyr::filter(family != "plugin") %>% dplyr::group_by(family) %>%
      dplyr::summarise(mean_cover = mean(cover), n = dplyr::n(), .groups = "drop") %>% dplyr::arrange(-mean_cover))
}

# orchestrator ----------------------------------------------------------
compass_map <- function(long, truth, delta_cov = 0.02) {
  summ <- compass_summary(long, truth)
  pw   <- compass_pairwise(long, truth, delta_cov)
  list(summary   = summ,
       validity  = compass_validity(summ, delta_cov),
       pairwise  = pw,
       bands     = compass_bands(summ, pw, delta_cov),
       grade     = compass_grade(summ),
       axis      = compass_axis_diag(summ),
       delta_cov = delta_cov, truth = truth)
}
