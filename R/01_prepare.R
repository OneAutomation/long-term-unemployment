# Read the 56 monthly Labour Force Survey PUMF files straight out of their zip archives,
# keep the variables the analysis uses, and save one compact file per year.
# Run from the project root: Rscript R/01_prepare.R

suppressPackageStartupMessages(library(data.table))

keep <- c("SURVYEAR", "SURVMNTH", "LFSSTAT", "PROV", "CMA", "AGE_12", "AGE_6", "GENDER", "MARSTAT",
          "EDUC", "IMMIG", "EFAMTYPE", "AGYOWNK", "SCHOOLN", "UNEMFTPT", "FLOWUNEM", "DURUNEMP",
          "LKPUBAG", "LKEMPLOY", "LKRELS", "LKATADS", "LKANSADS", "LKOTHERN", "FINALWT")

zips <- sort(list.files("data/raw", pattern = "^lfs_.*\\.zip$", full.names = TRUE))
dir.create("data/interim", showWarnings = FALSE)

months <- list()
for (z in zips) {
  members <- unzip(z, list = TRUE)$Name
  for (m in grep("pub[0-9]{4}\\.csv$", members, value = TRUE)) {
    d <- fread(cmd = sprintf("unzip -p '%s' '%s'", z, m), select = keep, showProgress = FALSE)
    setnames(d, tolower(names(d)))
    months[[length(months) + 1]] <- d
  }
}
lfs <- rbindlist(months)
rm(months)

# One row per person-month. Report what came in so a bad file is visible immediately.
check <- lfs[, .(respondents = .N, population = sum(finalwt)), by = .(survyear, survmnth)][order(survyear, survmnth)]
stopifnot(nrow(check) == 56, all(check$respondents > 80000))
cat(sprintf("%d person-months across %d months; respondents per month %s to %s; population 15+ %s to %s\n",
            nrow(lfs), nrow(check), format(min(check$respondents), big.mark = ","),
            format(max(check$respondents), big.mark = ","), format(min(check$population), big.mark = ","),
            format(max(check$population), big.mark = ",")))
fwrite(check, "data/interim/monthly_counts.csv")

for (y in sort(unique(lfs$survyear))) {
  saveRDS(lfs[survyear == y], sprintf("data/interim/lfs_%d.rds", y))
}
cat("saved:", paste(sprintf("lfs_%d.rds", sort(unique(lfs$survyear))), collapse = ", "), "\n")
