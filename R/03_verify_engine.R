
here <- "R"
source(file.path(here, "01_engine.R"))
source(file.path(here, "02_variants.R"))
suppressPackageStartupMessages({ library(tmle); library(dplyr) })

set.seed(20260806)

sim_data <- function(n) {
  W1 <- rnorm(n); W2 <- rnorm(n); W3 <- rbinom(n, 1, 0.5)
  gW <- plogis(-0.4 + 0.5*W1 - 0.3*W2 + 0.4*W3)
  A  <- rbinom(n, 1, gW)

  lp0 <- -0.5 + 0.7*W1 + 0.3*W2 - 0.5*W3
  b   <- 0.6
  pY1 <- plogis(lp0 + b); pY0 <- plogis(lp0)
  Y1 <- rbinom(n, 1, pY1); Y0 <- rbinom(n, 1, pY0)
  Y  <- ifelse(A == 1, Y1, Y0)
  list(Y = Y, A = A, W = data.frame(W1, W2, W3), truth_rd = mean(pY1 - pY0))
}

big <- sim_data(2e6); TRUTH <- big$truth_rd
cat(sprintf("TRUE ATE (risk difference) ~ %.5f\n\n", TRUTH))

sl_lib <- c("SL.glm", "SL.mean")

d <- sim_data(4000)
Y <- d$Y; A <- d$A; W <- d$W

variants <- list(
  vanilla        = list(scheme="none", target="pooled"),
  cvtmle_pooled  = list(scheme="cv", V=5, target="pooled",  agg_fold=FALSE),
  cvtmle_fold    = list(scheme="cv", V=5, target="foldwise", agg_fold=TRUE),
  cvq            = list(scheme="cv", V=5, target="pooled",  qonly=TRUE, agg_fold=FALSE),
  sctmle         = list(scheme="cf2", target="foldwise", agg_fold=TRUE),
  dctmle         = list(scheme="cf3", target="foldwise", agg_fold=TRUE),
  aipw           = list(scheme="none", target="onestep"),
  dcaipw         = list(scheme="cf3", target="onestep", agg_fold=TRUE)
)

cat("---- (1) single-split point estimates at n=4000 (truth", round(TRUTH,4), ") ----\n")
for (nm in names(variants)) {
  set.seed(11)
  res <- tryCatch(run_once(Y, A, W, variants[[nm]], sl_lib, sl_lib),
                  error = function(e) {cat(nm, "ERROR:", conditionMessage(e), "\n"); NULL})
  if (!is.null(res))
    cat(sprintf("  %-14s rd=% .4f  se=%.4f  bias=% .4f\n",
                nm, res$rd, sqrt(res$vd), res$rd - TRUTH))
}

cat("\n---- (2) vanilla TMLE cross-check on identical data ----\n")
set.seed(11); ours <- run_once(Y, A, W, variants$vanilla, sl_lib, sl_lib)

set.seed(11)
tp <- tmle(Y = Y, A = A, W = W,
           Q.SL.library = sl_lib, g.SL.library = sl_lib,
           family = "binomial", cvQinit = FALSE)
cat(sprintf("  ours vanilla     rd=% .5f  se=%.5f\n", ours$rd, sqrt(ours$vd)))
cat(sprintf("  tmle::tmle ATE   rd=% .5f  se=%.5f\n",
            tp$estimates$ATE$psi, sqrt(tp$estimates$ATE$var.psi)))

stopifnot(
  "vanilla TMLE disagrees with tmle::tmle beyond 3 decimals" =
    abs(ours$rd - tp$estimates$ATE$psi) < 3e-3 &&
    abs(sqrt(ours$vd) - sqrt(tp$estimates$ATE$var.psi)) < 3e-3,
  "vanilla TMLE fails to recover the known ATE within 0.05" =
    abs(ours$rd - TRUTH) < 0.05)

ref_path <- "data/reference/zivich_breskin_estimators.R"
if (file.exists(ref_path)) {
  suppressPackageStartupMessages({library(tidyr); library(purrr)})

  refenv <- new.env()

  sys.source(ref_path, envir = refenv, chdir = TRUE)
  # Identify exactly which reference source was compared. The paper's statements
  # refer to the file with sha256 7d33ee07118fd5f994f9b0c0e3f10abd8b8102d9ffadcd720a769f51e5ce8105.
  if (requireNamespace("digest", quietly = TRUE))
    cat("  reference source sha256:", digest::digest(file = ref_path, algo = "sha256"), "\n")
  dat <- data.frame(Y = Y, statin = A, W)
  ctrl <- SuperLearner::SuperLearner.CV.control(V = 5)
  set.seed(11)
  refres <- tryCatch(
    refenv$TMLE(dat, "statin", "Y", names(W), names(W), sl_lib, ctrl),
    error = function(e) {cat("  reference TMLE error:", conditionMessage(e), "\n"); NULL})
  if (!is.null(refres)) {
    cat(sprintf("  reference TMLE   rd=% .5f  se=%.5f\n", refres$rd, sqrt(refres$vd)))
    cat(sprintf("  |ours - reference TMLE|  rd=%.1e  se=%.1e\n",
                abs(ours$rd - refres$rd), abs(sqrt(ours$vd) - sqrt(refres$vd))))
  }
} else cat("  (reference estimators.R not found)\n")

cat("\n---- (3) reference double cross-fit: printed for information, NOT a check ----\n")
cat("  (independent partitions; see also the split/fit pairing diagnostic below)\n")
set.seed(7); ours_dc  <- run_once(Y, A, W, variants$dctmle, sl_lib, sl_lib)
if (exists("refenv")) {
  dat <- data.frame(Y = Y, statin = A, W)
  ctrl <- SuperLearner::SuperLearner.CV.control(V = 5)

  # Split/fit pairing diagnostic (no model fitting). DCTMLE_Single() draws its
  # three-way split with its first random call, nests the data with
  # group_by(s) %>% nest(), fits one propensity and one outcome model per ROW of
  # that nested table, and indexes the fits by row (pi_fit[[k]], mu_fit[[k]]).
  # Its targeting step (the epsilon_1..epsilon_3 lines of the source checksummed
  # above) pairs split 1 with (g row 2, Q row 3), split 2 with (3, 1) and split 3
  # with (1, 2). Those pairings are disjoint only if the nested rows come out in
  # split order 1, 2, 3. This reproduces the split at the same seed and reports
  # which split each paired model was actually trained on.
  set.seed(7)
  zb_s <- sample(rep(1:3, diff(floor(nrow(dat) * c(0, 1/3, 2/3, 3/3)))))
  nest_order <- (data.frame(i = seq_along(zb_s), s = zb_s) %>%
                   group_by(s) %>% tidyr::nest())$s
  cat(sprintf("  tidyr %s: nested row order of the splits = %s\n",
              as.character(packageVersion("tidyr")), paste(nest_order, collapse = ", ")))
  pair <- data.frame(targeting_split = 1:3, g_row = c(2L, 3L, 1L), Q_row = c(3L, 1L, 2L))
  pair$g_trained_on <- nest_order[pair$g_row]
  pair$Q_trained_on <- nest_order[pair$Q_row]
  pair$uses_own_split <- pair$g_trained_on == pair$targeting_split |
                         pair$Q_trained_on == pair$targeting_split
  print(pair, row.names = FALSE)

  set.seed(7)
  ref_dc <- tryCatch(refenv$DCTMLE_Single(dat, "statin", "Y", names(W), names(W), sl_lib, ctrl),
                     error = function(e) {cat("  ref DCTMLE error:", conditionMessage(e), "\n"); NULL})
  cat(sprintf("  ours   DCTMLE rd=% .5f  se=%.5f\n", ours_dc$rd, sqrt(ours_dc$vd)))
  if (!is.null(ref_dc))
    cat(sprintf("  ref    DCTMLE rd=% .5f  se=%.5f\n", ref_dc$rd, sqrt(ref_dc$vd)))
}

cat("\nDONE.\n")
