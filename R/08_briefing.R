# Two-page briefing note. Every number is read from the pipeline outputs. Writes reports/briefing-note.json
# (content, also used for the DOCX) and reports/briefing-note.pdf (HTML rendered by headless Chrome).

suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
chrome <- Sys.getenv("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
e <- fread("powerbi/data/estimates.csv"); f <- fread("powerbi/data/focus_groups.csv")
mm <- fromJSON("data/processed/model_metrics.json"); v <- fread("powerbi/data/validation.csv")
fair <- fread("powerbi/data/fairness.csv")
val <- function(grouping, measure, period = "2026 Jan-Aug", group = NULL) {
  d <- e[Grouping == grouping & Measure == measure & Period == period]
  if (!is.null(group)) d <- d[Group == group]
  d
}
k <- function(x) format(round(x, -2), big.mark = ",")
ltu26 <- val("Canada", "Long-term unemployed (people)"); ltu23 <- val("Canada", "Long-term unemployed (people)", "2023 Jan-Aug")
ltu25 <- val("Canada", "Long-term unemployed (people)", "2025 Jan-Aug")
sh26 <- val("Canada", "Long-term share of unemployment"); ur23 <- val("Canada", "Unemployment rate", "2023 Jan-Aug")
ur25 <- val("Canada", "Unemployment rate", "2025 Jan-Aug"); ur26 <- val("Canada", "Unemployment rate")
gap_abs <- max(abs(v$Difference)); gap_rel <- 100 * max(abs(v$Difference) / v$Published)
s <- function(grouping, group) val(grouping, "Long-term share of unemployment", group = group)$Estimate
youth_ur <- val("Age", "Unemployment rate", group = "15 to 24")$Estimate
f1 <- f[Dimension == "Age x immigrant status"][order(`Rank Within Dimension`)]
f2 <- f[Dimension == "Province x age"][order(`Rank Within Dimension`)]
cap <- function(g) 100 * fair[Group == g, `Captured In Top 20 Percent`]

content <- list(
  title = "Long-term unemployment has doubled since 2023: where employment programs should focus",
  sections = list(
    list("Issue", list(sprintf(
      "About %s people in Canada were unemployed for 27 weeks or more on average from January to August 2026, roughly double the %s of the same months in 2023 and close to the %s of January to August 2025. Nearly one in four unemployed people (%.1f%%) has now been out of work that long. Employment programs need to know whom to reach first.",
      k(ltu26$Estimate), k(ltu23$Estimate), k(ltu25$Estimate), sh26$Estimate))),
    list("Background", list(sprintf(
      "Statistics Canada counts someone as long-term unemployed after 27 weeks of continuous unemployment. Over the same January-to-August months the unemployment rate went from %.1f%% in 2023 to %.1f%% in 2025 and %.1f%% in 2026. This analysis uses the Labour Force Survey public use microdata, about 100,000 people a month from January 2022 to August 2026, with Statistics Canada's bootstrap method for margins of error (widened for the survey's six-month panel) and its rules for which estimates are reliable enough to publish. Computed monthly, the count of long-term unemployed matched Statistics Canada's published figures in all %d months, never off by more than %s people or %.2f%%.",
      ur23$Estimate, ur25$Estimate, ur26$Estimate, nrow(v), format(gap_abs, big.mark = ","), gap_rel))),
    list("Analysis", list(
      sprintf("Who is stuck longest. The long-term share of unemployment is highest for people aged 55 and over (%.1f%%), immigrants who arrived more than 10 years ago (%.1f%%) and bachelor's degree holders (%.1f%%, against %.1f%% for high school or less). Young people are the least likely to be out that long (%.1f%%), even though their unemployment rate is the highest, at %.1f%%.",
              s("Age", "55 and over"), s("Immigrant status", "Immigrant, landed over 10 years"), s("Education", "Bachelor's or above"),
              s("Education", "High school or less"), s("Age", "15 to 24"), youth_ur),
      sprintf("Where the people are. By numbers, the largest groups are non-immigrants aged 25 to 54 (%s; the survey's non-immigrant group also includes non-permanent residents such as international students and temporary workers), non-immigrant youth (%s) and immigrants aged 25 to 54 who arrived more than 10 years ago (%s, with a share of %.1f%%). By province and age, Ontario's 25 to 54 group alone accounts for %s long-term unemployed people, a share of %.1f%%.",
              k(f1$`Long-Term People`[1]), k(f1$`Long-Term People`[2]), k(f1$`Long-Term People`[3]), f1$`Long-Term Share`[3],
              k(f2$`Long-Term People`[1]), f2$`Long-Term Share`[1]),
      sprintf("Can a model pick out individuals? A pre-registered test, published before any model ran, asked whether characteristics recorded in the survey (age, education, family, province, job-search methods) could rank job searchers by their chance of being long-term unemployed. On July 2025 to August 2026 data the chosen model scored an AUC of %.3f against a bar of 0.65, better than age alone (%.3f) but not good enough to target people. Job-search methods change the longer someone is out of work, so even this describes who is currently stuck rather than predicting it at intake. The model under-predicted every group as conditions worsened; relative to that overall drift no group stood out, but its top-20%% list would have reached %.0f%% of long-term unemployed people aged 55 and over and only %.0f%% of those aged 15 to 24.",
              mm$test_metrics$auc_chosen, mm$test_metrics$auc_baseline, cap("55 and over"), cap("15 to 24")))),
    list("Considerations", list(
      "The survey measures spells still under way, not completed ones. The public file has no person identifiers, so margins of error for multi-month averages were widened by the most the six-month panel allows, up to 2.2 times.",
      sprintf("Every estimate shown meets Statistics Canada's release rules, applied to people rather than person-months: of the %s estimates computed, %d carry a marginal-quality warning and %d were suppressed. The long-term share leaves future starts out of its denominator, so it runs about one point above the ratio implied by Statistics Canada's published table.",
              format(nrow(e), big.mark = ","), e[Quality == "Marginal", .N], e[Quality == "Suppressed", .N]),
      "Any individual risk-scoring tool used to allocate services would also need an Algorithmic Impact Assessment under the Treasury Board Directive on Automated Decision-Making. The accuracy seen here would not support one.")),
    list("Recommendation", list(
      "Direct outreach and program capacity to the groups where long-term unemployment is both large and concentrated: prime-age workers in Ontario, established immigrants aged 25 and over, and older job seekers, who have the highest share of any age group. Degree holders' long spells deserve a closer look; the survey can show them but not explain them.",
      "Do not build an individual risk score from demographic survey characteristics. If profiling is pursued, test it on administrative data such as employment insurance histories, and repeat the fairness check by age before any use.",
      "Refresh these estimates as each monthly survey file is released; the pipeline reruns in about 20 minutes."))),
  footer = "Prepared by Ahmad Bilal Hashimi, September 2026. Independent analysis of Statistics Canada Labour Force Survey public use microdata. Not an ESDC or Statistics Canada document.")
dir.create("reports", showWarnings = FALSE)
write_json(content, "reports/briefing-note.json", auto_unbox = TRUE, pretty = TRUE)

n <- 0; body <- character()
for (sec in content$sections) {
  body <- c(body, sprintf("<h3>%s</h3>", toupper(sec[[1]])))
  for (p in sec[[2]]) { n <- n + 1; body <- c(body, sprintf("<p><span class='n'>%d.</span> %s</p>", n, p)) }
  if (sec[[1]] == "Analysis") body <- c(body, "<img src='figures/fig2_groups.png'>")
}
html <- sprintf("<!doctype html><html><head><meta charset='utf-8'><style>
@page { size: Letter; margin: 15mm 18mm; } body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; line-height: 1.36; color: #1F1F1F; }
.cls { text-align: center; font-weight: bold; font-size: 8.5pt; } .kind { font-weight: bold; font-size: 11pt; margin-top: 10px; }
h2 { font-size: 12.5pt; margin: 2px 0 8px 0; } h3 { font-size: 10pt; margin: 11px 0 4px 0; } p { margin: 0 0 6px 0; } .n { font-weight: bold; }
img { display: block; width: 70%%; margin: 6px auto 4px auto; }
.foot { font-size: 8pt; color: #5A5A5A; font-style: italic; margin-top: 10px; border-top: 1px solid #BDBDBD; padding-top: 6px; }
</style></head><body><div class='cls'>UNCLASSIFIED / NON CLASSIFI&Eacute;</div><div class='kind'>BRIEFING NOTE</div><h2>%s</h2>%s<div class='foot'>%s</div></body></html>",
                content$title, paste(body, collapse = ""), content$footer)
writeLines(html, "reports/briefing-note.html")
system2(chrome, c("--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                  paste0("--print-to-pdf=", normalizePath("reports/briefing-note.pdf", mustWork = FALSE)),
                  paste0("file://", normalizePath("reports/briefing-note.html"))), stdout = FALSE, stderr = FALSE)
file.remove("reports/briefing-note.html")
cat("reports/briefing-note.pdf and briefing-note.json written\n")
