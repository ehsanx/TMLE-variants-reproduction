# =====================================================================
# pin_truths.R -- pin the two DGM truths at high precision and cache them to
# engine/truths.rds, which run_compass.R then reads (overriding its defaults).
# Do this ONCE before the arrays. Fast: rtrapezoid is vectorized and D3 is fully
# vectorized, so 1e8 draws take a couple of minutes.
#   Rscript engine/pin_truths.R [nD1] [nD3]     (defaults 1e8, 1e8; chunked)
# =====================================================================
ENGINE <- Sys.getenv("COMPASS_ENGINE", unset = "R")
source(file.path(ENGINE, "dgm.R")); source(file.path(ENGINE, "dgm_variants.R"))
a <- commandArgs(trailingOnly = TRUE)
nD1 <- if (length(a) >= 1) as.numeric(a[1]) else 1e8
nD3 <- if (length(a) >= 2) as.numeric(a[2]) else 1e8

# D1 (statin) truth: E[prY1 - prY0], chunked so memory is bounded.
true_ate_statin_chunked <- function(n, seed = 1015033030, chunk = 2e6) {
  set.seed(seed); tot <- 0; done <- 0
  while (done < n) { m <- min(chunk, n - done)
    d <- generate_statin(m, return_potential = TRUE); tot <- tot + sum(d$prY1 - d$prY0); done <- done + m }
  tot / n
}
cat(sprintf("Pinning D1 (statin) truth at n=%.0e ...\n", nD1)); D1 <- true_ate_statin_chunked(nD1)
cat(sprintf("  D1 = %.7f  (value in a comment of the upstream dgm.py: -0.1081508)\n", D1))
cat(sprintf("Pinning D3 (rough) truth at n=%.0e ...\n", nD3));  D3 <- true_ate_rough(nD3)
cat(sprintf("  D3 = %.7f\n", D3))
mcse1 <- NA; # (point estimate; MCSE < 1e-5 by construction at n=1e8)
saveRDS(list(D1 = D1, D3 = D3, nD1 = nD1, nD3 = nD3), file.path(ENGINE, "truths.rds"))
cat(sprintf("Wrote %s  (D1=%.7f, D3=%.7f)\n", file.path(ENGINE, "truths.rds"), D1, D3))
