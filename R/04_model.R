# Pre-registered model and tests (PREREGISTRATION.md): who among unemployed job searchers is long-term
# unemployed (27+ weeks)? Baseline = age only; candidates = logistic regression and a random forest on
# time-free predictors. Model chosen on month-blocked 5-fold cross-validation of the training years,
# then tested once on July 2025 to August 2026 (January to June 2025 left out: households stay 6 months).

suppressPackageStartupMessages({ library(data.table); library(ranger); library(jsonlite) })
set.seed(20260925)

lfs <- rbindlist(lapply(2022:2026, function(y) readRDS(sprintf("data/interim/lfs_%d.rds", y))))
lfs[, period := fcase(survyear <= 2024, "train",
                      (survyear == 2025 & survmnth >= 7) | survyear == 2026, "test",
                      default = "gap")]

js <- lfs[lfsstat == 3 & !is.na(durunemp) & !(flowunem %in% c(1, 8))]
js[, ltu := as.integer(durunemp >= 27)]
lk <- c("lkpubag", "lkemploy", "lkrels", "lkatads", "lkansads", "lkothern")
for (v in lk) set(js, j = v, value = factor(fifelse(is.na(js[[v]]), "no", "yes")))
fac <- function(x, na = "not applicable") factor(fifelse(is.na(x), na, as.character(x)))
js[, `:=`(age = fac(age_12), gender = fac(gender), marstat = fac(marstat), educ = fac(educ), immig = fac(immig),
          prov = fac(prov), cma = fac(cma), efamtype = fac(efamtype), agyownk = fac(agyownk, "none"),
          schooln = fac(schooln), unemftpt = fac(unemftpt))]
predictors <- c("age", "gender", "marstat", "educ", "immig", "prov", "cma", "efamtype", "agyownk", "schooln",
                "unemftpt", lk)

train <- js[period == "train"]
test <- js[period == "test"]
train[, w := finalwt / mean(finalwt)]
test[, w := finalwt / mean(finalwt)]
cat(sprintf("job searchers: train %s person-months (%.1f%% long-term), test %s (%.1f%% long-term)\n",
            format(nrow(train), big.mark = ","), 100 * train[, weighted.mean(ltu, w)],
            format(nrow(test), big.mark = ","), 100 * test[, weighted.mean(ltu, w)]))

# Weighted AUC: probability a random long-term case outranks a random short-term case (ties count half),
# each person counted by their survey weight.
wauc <- function(score, y, w) {
  o <- order(score)
  s <- score[o]; y <- y[o]; w <- w[o]
  wneg <- w * (y == 0); wpos <- w * (y == 1)
  grp <- cumsum(c(TRUE, diff(s) != 0))                 # tie groups
  neg_in <- as.numeric(tapply(wneg, grp, sum)); pos_in <- as.numeric(tapply(wpos, grp, sum))
  neg_below <- cumsum(neg_in) - neg_in
  sum(pos_in * (neg_below + 0.5 * neg_in)) / (sum(wpos) * sum(wneg))
}
capture <- function(score, y, w, top = 0.2) {
  # Share of weighted positives among the top `top` share of weighted people. Tied scores are split
  # pro rata, so the result doesn't depend on row order (the age-only rule has only 12 distinct scores).
  g <- data.table(score, wy = w * y, w)[, .(w = sum(w), wy = sum(wy)), by = score][order(-score)]
  budget <- top * sum(g$w); before <- cumsum(g$w) - g$w
  take <- pmin(pmax((budget - before) / g$w, 0), 1)
  sum(take * g$wy) / sum(g$wy)
}

f_full <- reformulate(predictors, "ltu")
f_base <- ltu ~ age
fit_logit <- function(d, f) suppressWarnings(glm(f, family = quasibinomial(), data = d, weights = w))
fit_rf <- function(d) ranger(reformulate(predictors, "factor(ltu)"), data = d, probability = TRUE, num.trees = 500,
                             min.node.size = 50, case.weights = d$w, seed = 20260925, num.threads = 6)
p_rf <- function(m, d) predict(m, data = d, num.threads = 6)$predictions[, "1"]

# --- model choice on the training years only: month-blocked 5-fold CV -------------------------------------
months <- unique(train[, .(survyear, survmnth)])
months[, fold := sample(rep(1:5, length.out = .N))]
train <- months[train, on = .(survyear, survmnth)]
cv <- rbindlist(lapply(1:5, function(k) {
  tr <- train[fold != k]; te <- train[fold == k]
  data.table(fold = k,
             logistic = wauc(predict(fit_logit(tr, f_full), te, type = "response"), te$ltu, te$w),
             forest = wauc(p_rf(fit_rf(tr), te), te$ltu, te$w))
}))
cv_means <- cv[, .(logistic = mean(logistic), forest = mean(forest))]
chosen <- if (cv_means$forest > cv_means$logistic) "forest" else "logistic"
cat(sprintf("CV AUC: logistic %.4f, forest %.4f -> chosen: %s\n", cv_means$logistic, cv_means$forest, chosen))

# --- final fits on all training years, one look at the test set ---------------------------------------
m_base <- fit_logit(train, f_base)
m_logit <- fit_logit(train, f_full)
m_rf <- fit_rf(train)
test[, p_base := predict(m_base, test, type = "response")]
test[, p_logit := predict(m_logit, test, type = "response")]
test[, p_rf := p_rf(m_rf, test)]
test[, p_chosen := if (chosen == "forest") p_rf else p_logit]

train_share <- train[, weighted.mean(ltu, w)]
metrics <- function(d, wcol = "w") {
  w <- d[[wcol]]
  list(auc_chosen = wauc(d$p_chosen, d$ltu, w), auc_baseline = wauc(d$p_base, d$ltu, w),
       auc_logistic = wauc(d$p_logit, d$ltu, w), auc_forest = wauc(d$p_rf, d$ltu, w),
       brier_chosen = sum(w * (d$p_chosen - d$ltu)^2) / sum(w),
       brier_logistic = sum(w * (d$p_logit - d$ltu)^2) / sum(w),
       brier_baseline = sum(w * (d$p_base - d$ltu)^2) / sum(w),
       brier_constant = { pbar <- sum(w * d$ltu) / sum(w); sum(w * (pbar - d$ltu)^2) / sum(w) },   # hindsight: test average
       brier_constant_train = sum(w * (train_share - d$ltu)^2) / sum(w),                           # knowable in advance
       observed_share = sum(w * d$ltu) / sum(w), predicted_share = sum(w * d$p_chosen) / sum(w),
       capture20_chosen = capture(d$p_chosen, d$ltu, w), capture20_baseline = capture(d$p_base, d$ltu, w))
}
point <- metrics(test)

# --- 500 calibrated Poisson bootstrap replicates on the test months (the PUMF guide's method) ---------------
full_test <- lfs[period == "test"]
wt <- as.numeric(full_test$finalwt); ck <- sqrt(pmax(wt - 1, 0) / wt)
calib_age <- function(a12, a6) fcase(a12 == 1 & a6 == 1, 1L, a12 == 1, 2L, a12 == 2, 3L, a12 == 3, 4L, a12 == 4, 5L,
                                     a12 %in% 5:6, 6L, a12 %in% 7:8, 7L, a12 == 9, 8L, a12 == 10, 9L, a12 == 11, 10L, default = 11L)
dom <- as.integer(factor(paste(full_test$survyear, full_test$survmnth, full_test$prov,
                               calib_age(full_test$age_12, full_test$age_6), full_test$gender)))
nd <- as.numeric(rowsum(wt, dom))
key_full <- paste(full_test$survyear, full_test$survmnth, seq_len(nrow(full_test)))
is_js <- full_test$lfsstat == 3 & !is.na(full_test$durunemp) & !(full_test$flowunem %in% c(1, 8))
stopifnot(sum(is_js) == nrow(test))                      # same people, same order as `test`
boot <- rbindlist(lapply(1:500, function(b) {
  s <- sample(c(-1, 1), length(wt), replace = TRUE)
  wb <- wt * (1 + s * ck); wb <- wb * (nd / as.numeric(rowsum(wb, dom)))[dom]
  test[, wboot := wb[is_js]]
  as.data.table(metrics(test, "wboot"))
}))
ci <- function(x) as.numeric(quantile(x, c(0.025, 0.975)))
diff_boot <- boot$auc_chosen - boot$auc_baseline

m1 <- point$auc_chosen >= 0.65
m2 <- (point$auc_chosen - point$auc_baseline) >= 0.03 && ci(diff_boot)[1] > 0
decision <- if (m1 && m2) "M1 and M2 passed: the dashboard may show model-based targeting beside the descriptive estimates" else
  "M1 or M2 failed: the dashboard ranks groups by directly estimated long-term share and count, with no model risk tiers"
cat(sprintf("test AUC chosen %.4f [%.4f, %.4f], baseline %.4f; gain %.4f [%.4f, %.4f]; M1 %s, M2 %s\n",
            point$auc_chosen, ci(boot$auc_chosen)[1], ci(boot$auc_chosen)[2], point$auc_baseline,
            point$auc_chosen - point$auc_baseline, ci(diff_boot)[1], ci(diff_boot)[2], m1, m2))

# --- GBA Plus fairness check on the chosen model -----------------------------------------------------------
thr <- { o <- order(-test$p_chosen); cw <- cumsum(test$w[o]) / sum(test$w); min(test$p_chosen[o][cw <= 0.2]) }
test[, `:=`(age_band = fcase(as.integer(as.character(age)) <= 2, "15 to 24", as.integer(as.character(age)) <= 8, "25 to 54",
                             default = "55 and over"),
            gender_lab = fifelse(gender == "1", "Men+", "Women+"),
            immig_lab = fcase(immig == "1", "Immigrant, landed 10 years or less", immig == "2", "Immigrant, landed over 10 years",
                              default = "Non-immigrant (incl. non-permanent residents)"))]
fair <- rbindlist(lapply(c(Gender = "gender_lab", Age = "age_band", `Immigrant status` = "immig_lab"), function(col) {
  test[, .(observed_share = sum(w * ltu) / sum(w), predicted_share = sum(w * p_chosen) / sum(w),
           captured_at_top20 = sum(w * ltu * (p_chosen >= thr)) / sum(w * ltu), respondents = .N), by = c(col)][
    , `:=`(dimension = col)][]
}), use.names = FALSE)
setnames(fair, 1, "group")
fair[, dimension := fcase(dimension == "gender_lab", "Gender", dimension == "age_band", "Age", default = "Immigrant status")]
fair[, ratio := observed_share / predicted_share]
fair[, flagged := ratio < 0.8 | ratio > 1.25]                       # the pre-registered rule, as written
overall_ratio <- point$observed_share / point$predicted_share
fair[, ratio_relative_to_overall := ratio / overall_ratio]         # post hoc: removes the overall drift
fair[, flagged_relative := ratio_relative_to_overall < 0.8 | ratio_relative_to_overall > 1.25]

# Capture curves for the planner page: share of long-term unemployed reached as outreach widens.
curve <- rbindlist(lapply(seq(0.05, 1, by = 0.05), function(q) data.table(
  reach = q, chosen_model = capture(test$p_chosen, test$ltu, test$w, q),
  age_only_rule = capture(test$p_base, test$ltu, test$w, q), random = q)))

# What drives the chosen model: permutation importance for the forest, odds ratios for the logistic.
set.seed(20260926)
chosen_model <- if (chosen == "forest") m_rf else m_logit
pred_chosen <- function(d) if (chosen == "forest") p_rf(m_rf, d) else predict(m_logit, d, type = "response")
base_auc <- wauc(test$p_chosen, test$ltu, test$w)
importance <- rbindlist(lapply(predictors, function(v) {
  drops <- vapply(1:5, function(r) {
    shuffled <- copy(test); set(shuffled, j = v, value = sample(shuffled[[v]]))
    base_auc - wauc(pred_chosen(shuffled), test$ltu, test$w)
  }, 0)
  data.table(predictor = v, auc_drop_mean = mean(drops), auc_drop_min = min(drops), auc_drop_max = max(drops))
}))[order(-auc_drop_mean)]

# Post hoc (Deviation D4): the test set spans 14 months of a six-month panel, so the bootstrap interval is too
# narrow. Inflate its SE by the largest factor the rotation allows and use the guide's normal interval.
kk <- 1:5; f14 <- sqrt(1 + 2 * sum((1 - kk / 14) * (6 - kk) / 6))
gain <- point$auc_chosen - point$auc_baseline
panel_ci <- function(reps, pt) pt + c(-2, 2) * sqrt(mean((reps - pt)^2)) * f14
gain_ci_panel <- panel_ci(diff_boot, gain)

out <- list(
  population = "unemployed job searchers (temporary layoffs and future starts excluded)",
  train = list(months = "2022-01 to 2024-12", person_months = nrow(train), ltu_share = train[, weighted.mean(ltu, w)]),
  test = list(months = "2025-07 to 2026-08", person_months = nrow(test)),
  cv_auc = as.list(cv_means), cv_folds = cv, chosen = chosen,
  test_metrics = point,
  ci95 = list(auc_chosen = ci(boot$auc_chosen), auc_baseline = ci(boot$auc_baseline), gain = ci(diff_boot),
              capture20_chosen = ci(boot$capture20_chosen), capture20_baseline = ci(boot$capture20_baseline)),
  M1_auc_ge_0.65 = m1, M2_beats_baseline_by_0.03 = m2, decision = decision, top20_threshold = thr,
  post_hoc = list(panel_factor_14_months = f14, gain_ci_panel_corrected = gain_ci_panel,
                  auc_ci_panel_corrected = list(chosen = panel_ci(boot$auc_chosen, point$auc_chosen),
                                                baseline = panel_ci(boot$auc_baseline, point$auc_baseline),
                                                logistic = panel_ci(boot$auc_logistic, point$auc_logistic)),
                  brier_ci_panel_corrected = panel_ci(boot$brier_chosen, point$brier_chosen),
                  brier_ci_chosen = ci(boot$brier_chosen), overall_observed_to_predicted = overall_ratio))
write_json(out, "data/processed/model_metrics.json", auto_unbox = TRUE, digits = 6, pretty = TRUE)
fwrite(fair, "data/processed/fairness.csv"); fwrite(curve, "data/processed/capture_curve.csv")
fwrite(importance, "data/processed/importance.csv")
print(fair[, .(dimension, group, observed = round(observed_share, 3), predicted = round(predicted_share, 3),
               ratio = round(ratio, 2), relative = round(ratio_relative_to_overall, 2), captured = round(captured_at_top20, 3),
               flagged, flagged_relative)])
cat(sprintf("Brier: forest %.4f, logistic %.4f, age-only %.4f, constant %.4f | gain CI (panel-corrected) %.4f to %.4f\n",
            point$brier_chosen, point$brier_logistic, point$brier_baseline, point$brier_constant, gain_ci_panel[1], gain_ci_panel[2]))
print(importance)
