# V1 (pre-registered): the PUMF must reproduce Statistics Canada's published monthly count of people
# unemployed 27 weeks or more (table 14-10-0342-01, Canada, 15+, both genders, unadjusted).
# Any month off by more than 1% (or the table's rounding of 100 people) stops the analysis.

suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

series <- c(ltu = "1.6.1.1.1.2.0.0.0.0", unemployed = "1.1.1.1.1.2.0.0.0.0")
raw_path <- "data/raw/statcan_14100342.json"
if (!file.exists(raw_path)) {
  body <- toJSON(unname(lapply(series, function(co) list(productId = 14100342, coordinate = co, latestN = 56))),
                 auto_unbox = TRUE)
  out <- system2("curl", c("-s", "-X", "POST", "-H", shQuote("Content-Type: application/json"),
                           "-d", shQuote(body), "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromCubePidCoordAndLatestNPeriods"),
                 stdout = TRUE)
  writeLines(out, raw_path)
}
resp <- fromJSON(paste(readLines(raw_path), collapse = ""), simplifyVector = FALSE)
published <- rbindlist(lapply(seq_along(resp), function(i) {
  pts <- resp[[i]]$object$vectorDataPoint
  data.table(series = names(series)[match(resp[[i]]$object$coordinate, series)],   # the API may reorder series
             month = substr(vapply(pts, `[[`, "", "refPer"), 1, 7),
             value = vapply(pts, function(p) as.numeric(p$value), 0) * 1000)   # table is in thousands
}))

lfs <- rbindlist(lapply(2022:2026, function(y) readRDS(sprintf("data/interim/lfs_%d.rds", y))))
ours <- lfs[lfsstat == 3, .(ltu = sum(finalwt[!is.na(durunemp) & durunemp >= 27]),
                            unemployed = sum(finalwt)),
            by = .(month = sprintf("%d-%02d", survyear, survmnth))]
ours <- melt(ours, id.vars = "month", variable.name = "series", value.name = "pumf")

v <- merge(published, ours, by = c("series", "month"))
v[, diff := pumf - value]
v[, tolerance := pmax(0.01 * value, 100)]
v[, pass := abs(diff) <= tolerance]
fwrite(v[order(series, month)], "data/processed/validation_v1.csv")

ltu <- v[series == "ltu"]
cat(sprintf("V1: %d of %d months within tolerance for the 27+ week count; largest gap %s people; largest relative gap %.3f%%\n",
            sum(ltu$pass), nrow(ltu), format(round(max(abs(ltu$diff))), big.mark = ","),
            100 * max(abs(ltu$diff) / ltu$value)))
unemp <- v[series == "unemployed"]
cat(sprintf("    total unemployed (context): %d of %d months within tolerance; largest gap %.2f%%\n",
            sum(unemp$pass), nrow(unemp), 100 * max(abs(unemp$diff) / unemp$value)))
if (nrow(ltu) != 56 || !all(ltu$pass)) stop("V1 failed: fix the processing before any estimate is used")
