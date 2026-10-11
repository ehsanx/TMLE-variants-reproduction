
here <- "R"
source(file.path(here, "01_engine.R")); source(file.path(here, "02_variants.R"))
suppressPackageStartupMessages({ library(haven); library(dplyr); library(tmle) })
dd <- "data/lalonde_nsw"
dw <- haven::read_dta(file.path(dd,"nsw_dw.dta")); cps <- haven::read_dta(file.path(dd,"cps_controls.dta"))
dw$emp78 <- as.integer(dw$re78>0); cps$emp78 <- as.integer(cps$re78>0)
covs <- c("age","education","black","hispanic","married","nodegree","re74","re75")
d <- dplyr::bind_rows(dw[dw$treat==1,], cps)
Y <- d$emp78; A <- as.integer(d$treat); W <- as.data.frame(lapply(d[,covs], as.numeric))
set.seed(2026); ours <- run_once(Y,A,W,list(scheme="none",target="pooled"), c("SL.glm","SL.mean"), c("SL.glm","SL.mean"))
set.seed(2026); tp <- tmle(Y=Y,A=A,W=W,Q.SL.library=c("SL.glm","SL.mean"),g.SL.library=c("SL.glm","SL.mean"),family="binomial",cvQinit=FALSE)
cat(sprintf("ours   TMLE rd=%+.5f se=%.5f\n", ours$rd, sqrt(ours$vd)))
cat(sprintf("tmle:: TMLE rd=%+.5f se=%.5f (gbound default)\n", tp$estimates$ATE$psi, sqrt(tp$estimates$ATE$var.psi)))
set.seed(2026); tp2 <- tmle(Y=Y,A=A,W=W,Q.SL.library=c("SL.glm","SL.mean"),g.SL.library=c("SL.glm","SL.mean"),family="binomial",cvQinit=FALSE,gbound=0.025)
cat(sprintf("tmle:: TMLE rd=%+.5f se=%.5f (gbound=0.025)\n", tp2$estimates$ATE$psi, sqrt(tp2$estimates$ATE$var.psi)))
cat(sprintf("min/max g (ours, bounded): treated mean g = %.4f\n", mean(.bound_g(fit_sl(A,W,binomial(),c('SL.glm','SL.mean'),5)(W),0.025)[A==1])))
