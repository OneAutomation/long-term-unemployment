# Descriptive estimates with Statistics Canada's own variance method (LFS PUMF user guide, section 6):
# 1,000 Poisson bootstrap replicates, each unit's weight multiplied by 1 +/- sqrt((w - 1) / w), each replicate
# calibrated to the survey weight totals of the guide's calibration domains (province x 11 age groups x gender),
# here within each month because each monthly file is calibrated on its own. Quality flags follow Table 5.

suppressPackageStartupMessages({ library(data.table); library(parallel) })
RNGkind("L'Ecuyer-CMRG")          # reproducible random streams across the forked workers
set.seed(20260925)
B <- 1000

periods <- list("2022" = list(2022, 1:12), "2023" = list(2023, 1:12), "2024" = list(2024, 1:12), "2025" = list(2025, 1:12),
                "2023 Jan-Aug" = list(2023, 1:8), "2025 Jan-Aug" = list(2025, 1:8), "2026 Jan-Aug" = list(2026, 1:8))

age_band <- function(a) fcase(a <= 2, "15 to 24", a <= 8, "25 to 54", default = "55 and over")
educ_band <- function(e) fcase(e <= 2, "High school or less", e <= 4, "Some postsecondary, certificate or diploma",
                               default = "Bachelor's or above")
immig_lab <- function(i) fcase(i == 1, "Immigrant, landed 10 years or less", i == 2, "Immigrant, landed over 10 years",
                               default = "Non-immigrant (incl. non-permanent residents)")
prov_lab <- c("10" = "Newfoundland and Labrador", "11" = "Prince Edward Island", "12" = "Nova Scotia",
              "13" = "New Brunswick", "24" = "Quebec", "35" = "Ontario", "46" = "Manitoba", "47" = "Saskatchewan",
              "48" = "Alberta", "59" = "British Columbia")

# Calibration age groups from the guide's Appendix B (11 groups).
calib_age <- function(age12, age6) fcase(age12 == 1 & age6 == 1, 1L, age12 == 1, 2L, age12 == 2, 3L, age12 == 3, 4L,
                                         age12 == 4, 5L, age12 %in% 5:6, 6L, age12 %in% 7:8, 7L, age12 == 9, 8L,
                                         age12 == 10, 9L, age12 == 11, 10L, default = 11L)

groupings <- list(
  "Canada" = function(d) rep("Canada", nrow(d)),
  "Province" = function(d) prov_lab[as.character(d$prov)],
  "Age" = function(d) age_band(d$age_12),
  "Gender" = function(d) fifelse(d$gender == 1, "Men+", "Women+"),
  "Immigrant status" = function(d) immig_lab(d$immig),
  "Education" = function(d) educ_band(d$educ),
  "Age x immigrant status" = function(d) paste(age_band(d$age_12), immig_lab(d$immig), sep = " | "),
  "Province x age" = function(d) paste(prov_lab[as.character(d$prov)], age_band(d$age_12), sep = " | ")
)

estimate_period <- function(label) {
  y <- periods[[label]][[1]]; mths <- periods[[label]][[2]]
  d <- readRDS(sprintf("data/interim/lfs_%d.rds", y))[survmnth %in% mths]
  n_months <- uniqueN(d$survmnth)
  # Households stay in the survey for six consecutive months and the PUMF has no person identifier, so the
  # bootstrap (which treats every person-month as independent) understates the variance of multi-month
  # averages. Inflate the SE by the largest factor the six-month rotation allows (a person's status perfectly
  # persistent while in the sample): sqrt(1 + 2 * sum_k (1 - k/m) * (6 - k)/6) for lags k = 1..5.
  k <- seq_len(min(5, n_months - 1))
  panel_factor <- sqrt(1 + 2 * sum((1 - k / n_months) * (6 - k) / 6))
  # Table 5's "at least 5 respondents" must mean people. A person appears at most 6 times in any stack,
  # so 30 person-months guarantee at least 5 people (single months: 5).
  min_pm <- if (n_months > 1) 30 else 5
  w <- as.numeric(d$finalwt)
  c_k <- sqrt(pmax(w - 1, 0) / w)
  dom <- as.integer(factor(paste(d$survmnth, d$prov, calib_age(d$age_12, d$age_6), d$gender)))
  n_d <- as.numeric(rowsum(w, dom))

  lf <- d$lfsstat %in% 1:3
  un <- d$lfsstat == 3
  dur <- un & !is.na(d$durunemp)
  ltu <- dur & d$durunemp >= 27
  ind <- cbind(lf = lf, un = un, dur = dur, ltu = ltu) * 1
  keep <- which(lf)                                   # only labour-force rows enter any estimate
  gid <- lapply(groupings, function(f) f(d)[keep])
  resp <- lapply(gid, function(g) rowsum(ind[keep, ], g))          # unweighted respondent counts

  sums <- function(wt) lapply(gid, function(g) rowsum(ind[keep, ] * wt[keep], g) / n_months)
  point <- sums(w)
  reps <- vector("list", B)
  for (b in seq_len(B)) {
    s <- sample(c(-1, 1), length(w), replace = TRUE)
    wb <- w * (1 + s * c_k)
    wb <- wb * (n_d / as.numeric(rowsum(wb, dom)))[dom]           # calibrate to the domain totals
    reps[[b]] <- sums(wb)
  }

  out <- list()
  for (g in names(groupings)) {
    p <- point[[g]]
    r <- simplify2array(lapply(reps, `[[`, g))                     # groups x 4 x B
    measures <- list(
      "Unemployment rate" = list(num = "un", den = "lf", scale = 100),
      "Long-term share of unemployment" = list(num = "ltu", den = "dur", scale = 100),
      "Long-term unemployment rate" = list(num = "ltu", den = "lf", scale = 100),
      "Long-term unemployed (people)" = list(num = "ltu", den = NA, scale = 1),
      "Unemployed (people)" = list(num = "un", den = NA, scale = 1))
    for (m in names(measures)) {
      mm <- measures[[m]]
      est <- if (is.na(mm$den)) p[, mm$num] else p[, mm$num] / p[, mm$den] * mm$scale
      bs <- if (is.na(mm$den)) r[, mm$num, , drop = FALSE][, 1, ] else r[, mm$num, , drop = FALSE][, 1, ] / r[, mm$den, , drop = FALSE][, 1, ] * mm$scale
      bs <- matrix(bs, nrow = nrow(p))
      se_boot <- sqrt(rowMeans((bs - est)^2))
      se <- se_boot * panel_factor                     # Deviation D4: panel correction for multi-month averages
      n_resp <- resp[[g]][rownames(p), mm$num]          # person-months, not people
      cv <- se / est
      out[[length(out) + 1]] <- data.table(
        period = label, grouping = g, group = rownames(p), measure = m, estimate = est, se = se, se_bootstrap = se_boot,
        cv = cv, ci_low = est - 2.0 * se, ci_high = est + 2.0 * se,   # the guide's normal interval, t = 2.0 for 95%
        person_months = n_resp,
        quality = fcase(n_resp < min_pm | is.na(cv) | cv > 0.35, "Suppressed", cv >= 0.15, "Marginal", default = "Acceptable"))
    }
  }
  rbindlist(out)
}

t0 <- Sys.time()
res <- rbindlist(mclapply(names(periods), estimate_period, mc.cores = 3, mc.set.seed = TRUE))
cat(sprintf("bootstrap done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
fwrite(res, "data/processed/estimates.csv")

# Monthly national series for the trend chart (point estimates only).
monthly <- rbindlist(lapply(2022:2026, function(y) {
  d <- readRDS(sprintf("data/interim/lfs_%d.rds", y))
  d[, .(unemployment_rate = 100 * sum(finalwt[lfsstat == 3]) / sum(finalwt[lfsstat %in% 1:3]),
        ltu_share = 100 * sum(finalwt[lfsstat == 3 & !is.na(durunemp) & durunemp >= 27]) /
          sum(finalwt[lfsstat == 3 & !is.na(durunemp)]),
        ltu_people = sum(finalwt[lfsstat == 3 & !is.na(durunemp) & durunemp >= 27])),
    by = .(year = survyear, month = survmnth)]
}))
fwrite(monthly, "data/processed/monthly_national.csv")

cat("panel factors:", paste(sprintf("%s x%.2f", res[, unique(period)], res[, .(f = se[1] / se_bootstrap[1]), by = period]$f), collapse = "; "), "\n")
show <- res[grouping == "Canada" & measure %in% c("Unemployment rate", "Long-term share of unemployment", "Long-term unemployed (people)")]
print(show[, .(period, measure, estimate = round(estimate, 2), ci_low = round(ci_low, 2), ci_high = round(ci_high, 2),
               cv = round(cv, 3), quality)])
cat("quality counts:\n"); print(res[, .N, by = quality])
