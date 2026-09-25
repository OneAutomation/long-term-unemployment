# Write every table the Power BI report needs into powerbi/data/.

suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
dir.create("powerbi/data", recursive = TRUE, showWarnings = FALSE)

est <- fread("data/processed/estimates.csv")
period_order <- c("2022" = 1, "2023" = 2, "2024" = 3, "2025" = 4, "2023 Jan-Aug" = 5, "2025 Jan-Aug" = 6, "2026 Jan-Aug" = 7)
est[, `:=`(period_order = period_order[period], shown = quality != "Suppressed")]
out <- est[, .(Period = period, `Period Order` = period_order, Grouping = grouping, Group = group, Measure = measure,
               Estimate = round(estimate, 4), `CI Low` = round(ci_low, 4), `CI High` = round(ci_high, 4),
               CV = round(cv, 4), `SE Bootstrap Only` = round(se_bootstrap, 4), `Person Months` = person_months,
               Quality = quality, Shown = shown)]
fwrite(out, "powerbi/data/estimates.csv")

m <- fread("data/processed/monthly_national.csv")
m[, date := as.Date(sprintf("%d-%02d-01", year, month))]
setorder(m, date)
m[, `:=`(ltu_people_3mma = frollmean(ltu_people, 3), ltu_share_3mma = frollmean(ltu_share, 3))]
fwrite(m[, .(Date = date, Year = year, Month = month, `Unemployment Rate` = round(unemployment_rate, 3),
             `Long-Term Share` = round(ltu_share, 3), `Long-Term People` = round(ltu_people),
             `Long-Term People 3-Month Average` = round(ltu_people_3mma), `Long-Term Share 3-Month Average` = round(ltu_share_3mma, 3))],
       "powerbi/data/monthly.csv")

# Where to focus (the pre-registered decision rule: direct estimates, no model tiers). Latest period, the two
# cross-classifications, ranked by the number of long-term unemployed people.
latest <- est[period == "2026 Jan-Aug" & grouping %in% c("Age x immigrant status", "Province x age")]
focus <- dcast(latest, grouping + group ~ measure, value.var = c("estimate", "ci_low", "ci_high", "quality"))
focus <- focus[, .(Dimension = grouping, Group = group,
                   `Long-Term People` = round(`estimate_Long-term unemployed (people)`),
                   `People CI Low` = round(`ci_low_Long-term unemployed (people)`),
                   `People CI High` = round(`ci_high_Long-term unemployed (people)`),
                   `Long-Term Share` = round(`estimate_Long-term share of unemployment`, 2),
                   `Share CI Low` = round(`ci_low_Long-term share of unemployment`, 2),
                   `Share CI High` = round(`ci_high_Long-term share of unemployment`, 2),
                   `People Quality` = `quality_Long-term unemployed (people)`,
                   `Share Quality` = `quality_Long-term share of unemployment`)]
focus[, c("Part 1", "Part 2") := tstrsplit(Group, " | ", fixed = TRUE)]
focus[, Shown := `People Quality` != "Suppressed" & `Share Quality` != "Suppressed"]
focus[, `Rank Within Dimension` := frank(-`Long-Term People`, ties.method = "first"), by = Dimension]
setorder(focus, Dimension, `Rank Within Dimension`)
fwrite(focus, "powerbi/data/focus_groups.csv")

v <- fread("data/processed/validation_v1.csv")
fwrite(v[series == "ltu", .(Month = as.Date(paste0(month, "-01")), Published = value, `From PUMF` = round(pumf),
                            Difference = round(diff), `Within Tolerance` = pass)], "powerbi/data/validation.csv")

mm <- fromJSON("data/processed/model_metrics.json")
dg <- fromJSON("data/processed/diag_panel_cv.json")
tests <- rbindlist(list(
  list("V1 validation", "Months matching StatCan's published 27+ week count", sum(v[series == "ltu"]$pass), NA, NA,
       "All 56 within 1%", if (all(v[series == "ltu"]$pass)) "Passed" else "Failed"),
  list("Model test", "Random forest (chosen), test AUC", mm$test_metrics$auc_forest, mm$post_hoc$auc_ci_panel_corrected$chosen[1],
       mm$post_hoc$auc_ci_panel_corrected$chosen[2], "M1: at least 0.65", if (mm$M1_auc_ge_0.65) "Passed" else "Failed"),
  list("Model test", "Gain over the age-only rule", mm$test_metrics$auc_chosen - mm$test_metrics$auc_baseline,
       mm$ci95$gain[1], mm$ci95$gain[2], "M2: at least 0.03, interval above 0", if (mm$M2_beats_baseline_by_0.03) "Passed" else "Failed"),
  list("Model test", "Age-only rule, test AUC", mm$test_metrics$auc_baseline, mm$post_hoc$auc_ci_panel_corrected$baseline[1],
       mm$post_hoc$auc_ci_panel_corrected$baseline[2], "Baseline", "Baseline"),
  list("Model test", "Logistic regression, test AUC (not chosen)", mm$test_metrics$auc_logistic, mm$post_hoc$auc_ci_panel_corrected$logistic[1],
       mm$post_hoc$auc_ci_panel_corrected$logistic[2], "For context", "Context"),
  list("Model test", "Gain over the age-only rule, panel-corrected interval (post hoc)",
       mm$test_metrics$auc_chosen - mm$test_metrics$auc_baseline, mm$post_hoc$gain_ci_panel_corrected[1],
       mm$post_hoc$gain_ci_panel_corrected[2], "Context only", if (mm$post_hoc$gain_ci_panel_corrected[1] > 0) "Still above 0" else "Includes 0"),
  list("Model test", "Brier score, random forest", mm$test_metrics$brier_chosen, mm$post_hoc$brier_ci_panel_corrected[1],
       mm$post_hoc$brier_ci_panel_corrected[2], "Lower is better", "Context"),
  list("Model test", "Brier score, predicting the training-period average for everyone", mm$test_metrics$brier_constant_train, NA, NA,
       "Reference", "Context"),
  list("Diagnostic", "Month-blocked CV AUC: forest minus logistic", dg$month_blocked_cv$forest - dg$month_blocked_cv$logistic, NA, NA,
       "Post hoc", "Forest ahead"),
  list("Diagnostic", "Buffered block CV AUC: forest minus logistic", dg$buffered_block_cv$forest - dg$buffered_block_cv$logistic, NA, NA,
       "Post hoc", sprintf("Forest wins %d of 5 blocks", dg$forest_wins_blocks))
), use.names = FALSE)
setnames(tests, c("Test", "Measure", "Value", "CI Low", "CI High", "Pass Mark", "Result"))
# Which interval each row carries: the gain row keeps the pre-registered bootstrap interval (the verdict was
# made on it); the AUC and Brier rows show intervals widened for the six-month panel (Deviation D4).
tests[, Interval := fcase(Measure == "Gain over the age-only rule", "Pre-registered bootstrap (uncorrected)",
                          !is.na(`CI Low`), "Panel-corrected", default = "")]
tests[, `:=`(Value = round(Value, 4), `CI Low` = round(`CI Low`, 4), `CI High` = round(`CI High`, 4))]
fwrite(tests, "powerbi/data/model_tests.csv")

fair <- fread("data/processed/fairness.csv")
fwrite(fair[, .(Dimension = dimension, Group = group, `Observed Share` = round(observed_share, 4),
                `Predicted Share` = round(predicted_share, 4), `Observed To Predicted` = round(ratio, 3),
                `Captured In Top 20 Percent` = round(captured_at_top20, 4), Flagged = flagged,
                `Relative To Overall` = round(ratio_relative_to_overall, 3), `Flagged Relative` = flagged_relative)],
       "powerbi/data/fairness.csv")
cc <- fread("data/processed/capture_curve.csv")
fwrite(cc[, .(`Share Of Job Searchers Reached` = reach, `Chosen Model` = round(chosen_model, 4),
              `Age-Only Rule` = round(age_only_rule, 4), Random = random)], "powerbi/data/capture_curve.csv")
cat("powerbi/data:", paste(list.files("powerbi/data"), collapse = ", "), "\n")
