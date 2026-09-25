# Post hoc diagnostic (not a pre-registered test; changes no decision). The random forest won the month-blocked
# cross-validation used to choose the model (0.699 vs 0.649) but lost on the test set (0.611 vs 0.628). The LFS keeps
# households for six consecutive months and the PUMF has no person identifier, so when folds are single months the
# same people sit on both sides of a split, and a forest can memorize them. Here the training years are cut into
# five contiguous validation blocks of about seven months, and the five months either side of each block are dropped
# from its training data, so no household can appear in both.

suppressPackageStartupMessages({ library(data.table); library(ranger); library(jsonlite) })
set.seed(20260925)
src <- readLines("R/04_model.R")
# Reuse the exact data preparation and helper functions from the model script (everything up to model choice).
eval(parse(text = src[seq_len(grep("^# --- model choice", src) - 1)]))

train[, month_index := (survyear - 2022) * 12 + survmnth]            # 1..36
blocks <- split(1:36, rep(1:5, c(7, 7, 7, 7, 8)))
res <- rbindlist(lapply(seq_along(blocks), function(b) {
  v <- blocks[[b]]
  buffer <- (min(v) - 5):(max(v) + 5)
  tr <- train[!month_index %in% buffer]; te <- train[month_index %in% v]
  data.table(block = b, months = sprintf("%d-%d", min(v), max(v)), training_rows = nrow(tr),
             logistic = wauc(predict(fit_logit(tr, f_full), te, type = "response"), te$ltu, te$w),
             forest = wauc(p_rf(fit_rf(tr), te), te$ltu, te$w))
}))
print(res)
mm <- fromJSON("data/processed/model_metrics.json")
summary <- list(buffered_block_cv = as.list(res[, .(logistic = mean(logistic), forest = mean(forest))]),
                forest_wins_blocks = sum(res$forest > res$logistic),
                month_blocked_cv = mm$cv_auc,
                test = mm$test_metrics[c("auc_logistic", "auc_forest")],
                blocks = res)
write_json(summary, "data/processed/diag_panel_cv.json", auto_unbox = TRUE, digits = 6, pretty = TRUE)
cat(sprintf("buffered block CV: logistic %.4f, forest %.4f; forest wins %d of 5 blocks\n",
            mean(res$logistic), mean(res$forest), sum(res$forest > res$logistic)))
