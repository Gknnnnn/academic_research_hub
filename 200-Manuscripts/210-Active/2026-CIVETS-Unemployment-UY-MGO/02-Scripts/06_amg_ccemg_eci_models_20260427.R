suppressPackageStartupMessages(library(tidyverse))

panel <- read_csv("/tmp/civets_panel_extended_20260427.csv", show_col_types = FALSE) %>%
  mutate(ln_gdp_ppp = log(gdp_ppp)) %>%
  arrange(iso3c, year)

countries <- sort(unique(panel$iso3c))
N <- 6; T_obs <- 24

# ── Generic AMG+CCEMG+Webb function ──────────────────────────
run_amg_ccemg_webb <- function(pnl, dep, regs, B = 999, seed = 2026,
                                label = "") {
  ctries <- sort(unique(pnl$iso3c))
  Ni  <- length(ctries)
  Ti  <- length(unique(pnl$year))
  k   <- length(regs)

  cat(sprintf("\n%s\n", paste(rep("=", 65), collapse="")))
  cat(sprintf("Model: %s ~ %s\n", dep, paste(regs, collapse=" + ")))
  cat(sprintf("N=%d, T=%d, k=%d %s\n", Ni, Ti, k, label))
  cat(sprintf("%s\n", paste(rep("=", 65), collapse="")))

  # CS means for CCEMG
  cs_df <- pnl %>% group_by(year) %>%
    summarise(cs_y = mean(.data[[dep]], na.rm=TRUE),
              across(all_of(regs), ~mean(.x, na.rm=TRUE), .names="cs_{.col}"),
              .groups="drop")
  aug_vars <- c("cs_y", paste0("cs_", regs))
  pnl_cc   <- pnl %>% left_join(cs_df, by="year")

  # CDP for AMG (FD pooled + year dummies)
  fd_vars <- c(dep, regs)
  pnl_fd  <- pnl %>%
    group_by(iso3c) %>%
    mutate(across(all_of(fd_vars), ~c(NA, diff(.x)), .names="d_{.col}")) %>%
    ungroup() %>% filter(!is.na(.data[[paste0("d_", dep)]]))

  fd_dep  <- paste0("d_", dep)
  fd_regs <- paste0("d_", regs)
  fml_fd  <- as.formula(paste(fd_dep, "~",
              paste(fd_regs, collapse="+"), "+ factor(year) - 1"))
  step1   <- tryCatch(lm(fml_fd, data=pnl_fd), error=function(e) NULL)

  if (!is.null(step1)) {
    yc  <- coef(step1)[grep("factor", names(coef(step1)))]
    yr  <- as.integer(gsub("factor\\(year\\)", "", names(yc)))
    cdp <- tibble(year=yr, cdp=as.numeric(yc)) %>%
      bind_rows(tibble(year=min(pnl$year), cdp=0)) %>%
      arrange(year) %>% mutate(cdp_cum=cumsum(cdp))
  } else {
    cdp <- tibble(year=unique(pnl$year)) %>%
      arrange(year) %>% mutate(cdp_cum=seq_len(n()))
  }
  pnl_am <- pnl %>% left_join(cdp %>% select(year, cdp_cum), by="year")

  fml_cc <- as.formula(paste(dep, "~",
               paste(c(regs, aug_vars), collapse=" + ")))
  fml_am <- as.formula(paste(dep, "~",
               paste(c(regs, "cdp_cum"), collapse=" + ")))

  # Individual estimates
  bcc <- matrix(NA, Ni, k, dimnames=list(ctries, regs))
  bam <- matrix(NA, Ni, k, dimnames=list(ctries, regs))

  cat(sprintf("  %-3s", "Cty"))
  for (r in regs) cat(sprintf(" %8s", substr(r,1,8)))
  cat(" |")
  for (r in regs) cat(sprintf(" %8s", substr(r,1,8)))
  cat("\n")
  cat(paste(rep("-", 65), collapse=""), "\n")

  for (i in seq_along(ctries)) {
    sc <- pnl_cc %>% filter(iso3c==ctries[i])
    mc <- tryCatch(lm(fml_cc, data=sc), error=function(e) NULL)
    if (!is.null(mc)) { b<-coef(mc); for(r in regs) if(r %in% names(b)) bcc[i,r]<-b[r] }
    sa <- pnl_am %>% filter(iso3c==ctries[i])
    ma <- tryCatch(lm(fml_am, data=sa), error=function(e) NULL)
    if (!is.null(ma)) { b<-coef(ma); for(r in regs) if(r %in% names(b)) bam[i,r]<-b[r] }
    cat(sprintf("  %-3s", ctries[i]))
    for (r in regs) cat(sprintf(" %8.3f", bcc[i,r]))
    cat(" |")
    for (r in regs) cat(sprintf(" %8.3f", bam[i,r]))
    cat("\n")
  }
  cat(paste(rep("-", 65), collapse=""), "\n")

  beta_cc <- colMeans(bcc, na.rm=TRUE)
  se_cc   <- apply(bcc, 2, function(x) sd(x,na.rm=TRUE)/sqrt(sum(!is.na(x))))
  beta_am <- colMeans(bam, na.rm=TRUE)
  se_am   <- apply(bam, 2, function(x) sd(x,na.rm=TRUE)/sqrt(sum(!is.na(x))))

  cat(sprintf("  %-3s", "MG"))
  for (r in regs) cat(sprintf(" %8.3f", beta_cc[r]))
  cat(" |")
  for (r in regs) cat(sprintf(" %8.3f", beta_am[r]))
  cat("\n")
  cat(sprintf("  %-3s", "SE"))
  for (r in regs) cat(sprintf(" %8.3f", se_cc[r]))
  cat(" |")
  for (r in regs) cat(sprintf(" %8.3f", se_am[r]))
  cat("\n")

  # Webb bootstrap
  cat(sprintf("\nWebb bootstrap (B=%d)...\n", B))
  set.seed(seed)
  webb_w  <- c(-sqrt(1.5),-1,-sqrt(0.5),sqrt(0.5),1,sqrt(1.5))
  boot_cc <- matrix(NA, B, k, dimnames=list(NULL, regs))
  boot_am <- matrix(NA, B, k, dimnames=list(NULL, regs))

  for (b in 1:B) {
    w_i <- sample(webb_w, Ni, replace=TRUE)
    pb  <- pnl
    for (i in seq_along(ctries))
      pb[[dep]][pb$iso3c==ctries[i]] <- pb[[dep]][pb$iso3c==ctries[i]] * w_i[i]

    cs_b <- pb %>% group_by(year) %>%
      summarise(cs_y=mean(.data[[dep]],na.rm=TRUE),
                across(all_of(regs),~mean(.x,na.rm=TRUE),.names="cs_{.col}"),
                .groups="drop")
    pb_cc <- pb %>% left_join(cs_b, by="year")
    pb_am <- pb %>% left_join(cdp %>% select(year, cdp_cum), by="year")

    bc <- matrix(NA,Ni,k); ba <- matrix(NA,Ni,k)
    for (i in seq_along(ctries)) {
      sc2 <- pb_cc %>% filter(iso3c==ctries[i])
      mc2 <- tryCatch(lm(fml_cc,data=sc2),error=function(e) NULL)
      if (!is.null(mc2)) { bv<-coef(mc2); for(ri in seq_along(regs)) if(regs[ri] %in% names(bv)) bc[i,ri]<-bv[regs[ri]] }
      sa2 <- pb_am %>% filter(iso3c==ctries[i])
      ma2 <- tryCatch(lm(fml_am,data=sa2),error=function(e) NULL)
      if (!is.null(ma2)) { bv<-coef(ma2); for(ri in seq_along(regs)) if(regs[ri] %in% names(bv)) ba[i,ri]<-bv[regs[ri]] }
    }
    boot_cc[b,] <- colMeans(bc, na.rm=TRUE)
    boot_am[b,] <- colMeans(ba, na.rm=TRUE)
  }

  ci_cc_lo <- apply(boot_cc,2,quantile,0.025,na.rm=TRUE)
  ci_cc_hi <- apply(boot_cc,2,quantile,0.975,na.rm=TRUE)
  ci_am_lo <- apply(boot_am,2,quantile,0.025,na.rm=TRUE)
  ci_am_hi <- apply(boot_am,2,quantile,0.975,na.rm=TRUE)

  p_cc <- sapply(seq_along(regs), function(j) {
    bs <- boot_cc[,j]-mean(boot_cc[,j],na.rm=TRUE)
    2*min(mean(bs>=abs(beta_cc[j]),na.rm=TRUE),
          mean(bs<=-abs(beta_cc[j]),na.rm=TRUE))
  })
  p_am <- sapply(seq_along(regs), function(j) {
    bs <- boot_am[,j]-mean(boot_am[,j],na.rm=TRUE)
    2*min(mean(bs>=abs(beta_am[j]),na.rm=TRUE),
          mean(bs<=-abs(beta_am[j]),na.rm=TRUE))
  })

  sg <- function(p) if(p<0.01)"***" else if(p<0.05)"**" else if(p<0.10)"*" else "   "

  cat("\n")
  cat(sprintf("%-13s  %6s%3s  %-17s  %6s%3s  %-17s\n",
              "Variable","CCEMG","","Webb 95% CI","AMG","","Webb 95% CI"))
  cat(paste(rep("-",72),collapse=""),"\n")

  res <- list()
  for (j in seq_along(regs)) {
    r <- regs[j]
    cat(sprintf("%-13s  %6.3f%3s [%7.3f,%7.3f]  %6.3f%3s [%7.3f,%7.3f]\n",
                r, beta_cc[r],sg(p_cc[j]),ci_cc_lo[r],ci_cc_hi[r],
                   beta_am[r],sg(p_am[j]),ci_am_lo[r],ci_am_hi[r]))
    res[[r]] <- tibble(variable=r,
      ccemg=round(beta_cc[r],4), cc_lo=round(ci_cc_lo[r],4), cc_hi=round(ci_cc_hi[r],4), p_cc=round(p_cc[j],4),
      amg  =round(beta_am[r],4), am_lo=round(ci_am_lo[r],4), am_hi=round(ci_am_hi[r],4), p_am=round(p_am[j],4))
  }
  cat(paste(rep("-",72),collapse=""),"\n")
  cat("Notes: Webb (2023) {+-sqrt(0.5), +-1, +-sqrt(1.5)} | *** p<0.01 ** p<0.05 * p<0.10\n")

  bind_rows(res)
}

# ── MODEL A: Main — ln_gdp_ppp + ECI + goveff  (N=6, T=24) ──
cat("\n\n")
cat("╔══════════════════════════════════════════════════╗\n")
cat("║  MODEL A (MAIN): unemp ~ ln_gdp_ppp + eci + goveff  ║\n")
cat("╚══════════════════════════════════════════════════╝\n")
res_A <- run_amg_ccemg_webb(
  panel, "unemp", c("ln_gdp_ppp","eci","goveff"),
  B=999, label="[MAIN SPEC]"
)
write_csv(res_A, "/tmp/civets_modelA_eci_goveff_20260427.csv")

# ── MODEL B: Robustness — ln_gdp_ppp + ECI + COI (T=2004-2023) ─
panel_coi <- panel %>% filter(year >= 2004) %>%
  filter(!is.na(coi) & !is.na(eci) & !is.na(ln_gdp_ppp))

cat("\n\n")
cat("╔══════════════════════════════════════════════════╗\n")
cat("║  MODEL B (ROBUST): unemp ~ ln_gdp_ppp + eci + coi   ║\n")
cat("╚══════════════════════════════════════════════════╝\n")
res_B <- run_amg_ccemg_webb(
  panel_coi, "unemp", c("ln_gdp_ppp","eci","coi"),
  B=999, label="[T=2004-2023 subsample]"
)
write_csv(res_B, "/tmp/civets_modelB_eci_coi_20260427.csv")

# ── COMPARISON TABLE ──────────────────────────────────────────
cat("\n\n")
cat("╔══════════════════════════════════════════════════╗\n")
cat("║  COMPARISON: Model A vs Model B (AMG estimates)  ║\n")
cat("╚══════════════════════════════════════════════════╝\n")
cat(sprintf("%-13s  %10s  %10s\n","Variable","Model A AMG","Model B AMG"))
cat(paste(rep("-",40),collapse=""),"\n")
for (r in c("ln_gdp_ppp","eci","goveff")) {
  row <- res_A %>% filter(variable==r)
  if (nrow(row)) {
    sg <- function(p) if(p<0.01)"***" else if(p<0.05)"**" else if(p<0.10)"*" else ""
    cat(sprintf("%-13s  %6.3f%-4s  %s\n", r, row$amg, sg(row$p_am), "—"))
  }
}
row_eci_b <- res_B %>% filter(variable=="eci")
row_coi_b <- res_B %>% filter(variable=="coi")
if (nrow(row_eci_b)) cat(sprintf("%-13s  %10s  %6.3f%s\n","eci(B)","—",row_eci_b$amg, ifelse(row_eci_b$p_am<0.1,"*","")))
if (nrow(row_coi_b)) cat(sprintf("%-13s  %10s  %6.3f%s\n","coi(B)","—",row_coi_b$amg, ifelse(row_coi_b$p_am<0.1,"*","")))

cat("\nAll results saved.\n")
cat("  /tmp/civets_modelA_eci_goveff_20260427.csv\n")
cat("  /tmp/civets_modelB_eci_coi_20260427.csv\n")
