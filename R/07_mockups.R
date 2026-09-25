# Design mockups of the four Power BI pages, rendered from the real exported data with ggplot2 and HTML,
# screenshotted by headless Chrome. They are the target for powerbi/BUILD-GUIDE.md, not the report itself.

suppressPackageStartupMessages({ library(data.table); library(ggplot2); library(jsonlite) })
chrome <- Sys.getenv("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
out <- "powerbi/mockups"; assets <- file.path(out, "assets")
dir.create(assets, recursive = TRUE, showWarnings = FALSE)
INK <- "#1F1F1F"; MUTED <- "#5A5A5A"; BLUE <- "#2166AC"; LIGHT <- "#9ECAE1"; RED <- "#B2182B"; ORANGE <- "#EF8A62"
theme_set(theme_minimal(base_size = 12) + theme(panel.grid.minor = element_blank(), axis.text = element_text(colour = MUTED),
                                                 plot.background = element_rect(fill = "transparent", colour = NA)))
save_png <- function(p, name, w, h) ggsave(file.path(assets, name), p, width = w, height = h, dpi = 150, bg = "transparent")

est <- fread("powerbi/data/estimates.csv"); mon <- fread("powerbi/data/monthly.csv")
focus <- fread("powerbi/data/focus_groups.csv"); tests <- fread("powerbi/data/model_tests.csv")
fair <- fread("powerbi/data/fairness.csv"); val <- fread("powerbi/data/validation.csv")
mm <- fromJSON("data/processed/model_metrics.json")
latest <- "2026 Jan-Aug"
g <- function(grouping, measure, period = latest) est[Grouping == grouping & Measure == measure & Period == period]
fmtk <- function(x) format(round(x, -2), big.mark = ",")

css <- "
* { box-sizing: border-box; } body { margin: 0; width: 1280px; height: 720px; background: #F4F4F4; color: #1F1F1F;
  font-family: 'Segoe UI', -apple-system, Helvetica, Arial, sans-serif; position: relative; overflow: hidden; }
.abs { position: absolute; } .panel { background: #fff; border-radius: 4px; box-shadow: 0 1px 2px rgba(0,0,0,.12); }
h1 { font-size: 22px; font-weight: 600; margin: 0 0 4px 0; } .sub { font-size: 12.5px; color: #5A5A5A; }
.card { padding: 10px 16px; } .v { font-size: 30px; font-weight: 600; line-height: 1.15; } .l { font-size: 12px; color: #5A5A5A; margin-top: 2px; }
.s { font-size: 17px; font-weight: 600; } .title { font-size: 13px; font-weight: 600; padding: 10px 14px 4px 14px; }
table { border-collapse: collapse; width: 100%; font-size: 12px; } th { text-align: left; color: #5A5A5A; font-weight: 600;
  border-bottom: 1px solid #BDBDBD; padding: 5px 8px; font-size: 11.5px; } td { padding: 4.5px 8px; border-bottom: 1px solid #EEE; }
.num { text-align: right; } .foot { font-size: 10.5px; color: #5A5A5A; } .tag { font-size: 10px; color: #8C8C8C; text-align: right; }
.nav { font-size: 11.5px; color: #5A5A5A; } .nav span { margin-right: 14px; } .nav .on { color: #2166AC; font-weight: 600; border-bottom: 2px solid #2166AC; }
.pass { color: #2166AC; font-weight: 600; } .fail { color: #B2182B; font-weight: 600; }
.slicer { padding: 8px 14px; font-size: 12px; color: #5A5A5A; } .slicer b { color: #1F1F1F; font-size: 13px; }
.q { font-size: 10.5px; padding: 1px 5px; border-radius: 3px; background: #FDDBC7; }"
pages <- c("The situation", "Who's stuck", "Where to focus", "How far to trust this")
box <- function(x, y, w, h, inner, cls = "panel") sprintf("<div class='abs %s' style='left:%dpx;top:%dpx;width:%dpx;height:%dpx'>%s</div>", cls, x, y, w, h, inner)
nav <- function(active) box(24, 692, 900, 20, paste0("<div class='nav'>", paste(sprintf("<span class='%s'>%s</span>", ifelse(pages == active, "on", ""), pages), collapse = ""), "</div>"), "")
tag <- box(930, 694, 330, 18, "<div class='tag'>Design mockup from the real data. Build it with BUILD-GUIDE.md</div>", "")
render <- function(name, body) {
  html <- file.path(out, paste0(name, ".html"))
  writeLines(sprintf("<!doctype html><html><head><meta charset='utf-8'><style>%s</style></head><body>%s</body></html>", css, body), html)
  png <- file.path(out, paste0(name, ".png"))
  system2(chrome, c("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1.5",
                    "--window-size=1280,720", paste0("--screenshot=", normalizePath(png, mustWork = FALSE)),
                    paste0("file://", normalizePath(html))), stdout = FALSE, stderr = FALSE)
  png
}

# ---------- page 1: the situation ----------
ltu <- g("Canada", "Long-term unemployed (people)"); share <- g("Canada", "Long-term share of unemployment")
rate <- g("Canada", "Unemployment rate"); ltu23 <- g("Canada", "Long-term unemployed (people)", "2023 Jan-Aug")
ltu25 <- g("Canada", "Long-term unemployed (people)", "2025 Jan-Aug"); rate25 <- g("Canada", "Unemployment rate", "2025 Jan-Aug")
p <- ggplot(mon, aes(Date)) + geom_line(aes(y = `Long-Term People` / 1000), colour = LIGHT) +
  geom_line(aes(y = `Long-Term People 3-Month Average` / 1000), colour = BLUE, linewidth = 1.1, na.rm = TRUE) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "k")) + labs(x = NULL, y = NULL)
save_png(p, "trend.png", 7.2, 3.9)
prov <- g("Province", "Long-term share of unemployment")[order(Estimate)]
prov[, Group := factor(Group, levels = Group)]
p <- ggplot(prov, aes(Estimate, Group)) + geom_col(aes(fill = Quality), width = 0.65) +
  geom_errorbar(aes(xmin = `CI Low`, xmax = `CI High`), width = 0.25, orientation = "y", colour = INK) +
  scale_fill_manual(values = c(Acceptable = BLUE, Marginal = ORANGE)) + labs(x = "%", y = NULL, fill = NULL) +
  theme(legend.position = "bottom")
save_png(p, "provinces.png", 4.9, 3.9)
body <- paste0(
  box(24, 14, 980, 64, "<h1>Long-term unemployment in Canada: who is stuck, and where should programs focus?</h1><div class='sub'>Independent analysis of Statistics Canada Labour Force Survey microdata, January 2022 to August 2026. Not an ESDC or Statistics Canada product.</div>", ""),
  box(1040, 22, 216, 50, "<div class='slicer'>Period<br><b>2026 Jan-Aug</b> &#9662;</div>"),
  box(24, 92, 300, 96, sprintf("<div class='card'><div class='v'>%s</div><div class='l'>People unemployed 27+ weeks, Jan-Aug 2026 (95%% CI %s to %s)</div></div>", fmtk(ltu$Estimate), fmtk(ltu$`CI Low`), fmtk(ltu$`CI High`))),
  box(334, 92, 300, 96, sprintf("<div class='card'><div class='v'>%.1f%%</div><div class='l'>of the unemployed have been out 27+ weeks</div></div>", share$Estimate)),
  box(644, 92, 300, 96, sprintf("<div class='card'><div class='v'>+%.0f%%</div><div class='l'>since Jan-Aug 2023 (%s); %+.1f%% on Jan-Aug 2025</div></div>", 100 * (ltu$Estimate / ltu23$Estimate - 1), fmtk(ltu23$Estimate), 100 * (ltu$Estimate / ltu25$Estimate - 1))),
  box(954, 92, 302, 96, sprintf("<div class='card'><div class='v'>%.1f%%</div><div class='l'>unemployment rate (%.1f%% in Jan-Aug 2025)</div></div>", rate$Estimate, rate25$Estimate)),
  box(24, 202, 740, 482, "<div class='title'>People unemployed 27+ weeks, monthly and 3-month average</div><img src='assets/trend.png' style='width:700px;margin:0 20px'>"),
  box(780, 202, 476, 482, "<div class='title'>Long-term share of unemployment by province, 2026 Jan-Aug</div><img src='assets/provinces.png' style='width:450px;margin:0 13px'>"),
  nav(pages[1]), tag)
pngs <- render("page1_the_situation", body)

# ---------- page 2: who's stuck ----------
dot <- function(grouping, file) {
  d <- g(grouping, "Long-term share of unemployment"); d[, Group := factor(Group, levels = rev(Group))]
  p <- ggplot(d, aes(Estimate, Group)) + geom_vline(xintercept = share$Estimate, linetype = "dashed", colour = MUTED) +
    geom_errorbar(aes(xmin = `CI Low`, xmax = `CI High`), width = 0.2, orientation = "y") +
    geom_point(aes(colour = Quality), size = 3) + scale_colour_manual(values = c(Acceptable = BLUE, Marginal = ORANGE), guide = "none") +
    scale_x_continuous(limits = c(15, 34), labels = function(x) paste0(x, "%")) + labs(x = NULL, y = NULL)
  save_png(p, file, 5.9, 2.2)
}
dot("Age", "age.png"); dot("Gender", "gender.png"); dot("Immigrant status", "immig.png"); dot("Education", "educ.png")
panel <- function(x, y, title, img) box(x, y, 610, 236, sprintf("<div class='title'>%s</div><img src='assets/%s' style='width:585px;margin:0 12px'>", title, img))
body <- paste0(
  box(24, 10, 1232, 64, sprintf("<h1>Who is stuck: long-term share of unemployment, 2026 Jan-Aug</h1><div class='sub'>Dots are estimates with 95%% intervals from Statistics Canada's bootstrap, widened for the survey's six-month panel; the dashed line is Canada at %.1f%%. Orange marks StatCan's &ldquo;marginal&rdquo; quality; suppressed estimates are not shown.</div>", share$Estimate), ""),
  panel(24, 86, "Age", "age.png"), panel(646, 86, "Gender", "gender.png"),
  panel(24, 336, "Immigrant status", "immig.png"), panel(646, 336, "Education", "educ.png"),
  box(24, 584, 1232, 100, "<div class='card'><div class='s'>Older job seekers, immigrants who arrived more than 10 years ago, and degree holders are the most likely to be out 27 weeks or more.</div><div class='l'>Young people are the least likely to be stuck long, even though their unemployment rate is the highest. The gap between men and women is within the margin of error.</div></div>"),
  nav(pages[2]), tag)
pngs <- c(pngs, render("page2_whos_stuck", body))

# ---------- page 3: where to focus ----------
tbl <- function(dim, n = 10) {
  d <- focus[Dimension == dim & Shown == TRUE][order(`Rank Within Dimension`)][1:n]
  qual <- ifelse(d$`Share Quality` == "Acceptable" & d$`People Quality` == "Acceptable", "",
                 sprintf("<span class='q'>%s</span>", ifelse(d$`Share Quality` != "Acceptable", d$`Share Quality`, d$`People Quality`)))
  rows <- paste0(sprintf("<tr><td class='num'>%d</td><td>%s</td><td class='num'>%s</td><td class='num'>%.1f%%</td><td class='num'>%.1f to %.1f</td><td>%s</td></tr>",
                         d$`Rank Within Dimension`, gsub(" \\(incl. non-permanent residents\\)", "", gsub(" \\| ", ", ", d$Group)), fmtk(d$`Long-Term People`), d$`Long-Term Share`,
                         d$`Share CI Low`, d$`Share CI High`, qual), collapse = "")
  paste0("<table><tr><th class='num'>#</th><th>Group</th><th class='num'>Long-term unemployed</th><th class='num'>Share</th><th class='num'>95% CI</th><th></th></tr>", rows, "</table>")
}
body <- paste0(
  box(24, 10, 1232, 72, "<h1>Where to focus: the largest groups of long-term unemployed, 2026 Jan-Aug</h1><div class='sub'>Ranked by the number of people out of work 27+ weeks. The pre-registered model did not clear its bar, so this page uses direct survey estimates, as the pre-registered rule requires, and shows no individual risk scores. Non-immigrant includes non-permanent residents such as international students and temporary workers.</div>", ""),
  box(24, 92, 610, 592, paste0("<div class='title'>By age and immigrant status</div><div style='padding:0 8px'>", tbl("Age x immigrant status", 9), "</div>")),
  box(646, 92, 610, 592, paste0("<div class='title'>By province and age (top 12)</div><div style='padding:0 8px'>", tbl("Province x age", 12), "</div>")),
  nav(pages[3]), tag)
pngs <- c(pngs, render("page3_where_to_focus", body))

# ---------- page 4: how far to trust this ----------
t3 <- data.table(model = factor(c("Age-only rule", "Logistic regression", "Random forest (chosen)"),
                                levels = c("Age-only rule", "Logistic regression", "Random forest (chosen)")),
                 auc = c(mm$test_metrics$auc_baseline, mm$test_metrics$auc_logistic, mm$test_metrics$auc_forest),
                 lo = c(mm$post_hoc$auc_ci_panel_corrected$baseline[1], mm$post_hoc$auc_ci_panel_corrected$logistic[1], mm$post_hoc$auc_ci_panel_corrected$chosen[1]),
                 hi = c(mm$post_hoc$auc_ci_panel_corrected$baseline[2], mm$post_hoc$auc_ci_panel_corrected$logistic[2], mm$post_hoc$auc_ci_panel_corrected$chosen[2]))
p <- ggplot(t3, aes(auc, model)) + geom_point(size = 3, colour = BLUE) + geom_vline(xintercept = 0.65, colour = RED, linetype = "dashed") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2, orientation = "y", na.rm = TRUE) +
  geom_text(aes(label = sprintf("%.3f", auc)), nudge_y = 0.3, size = 3.4) + scale_x_continuous(limits = c(0.5, 0.7)) + labs(x = "Test AUC", y = NULL)
save_png(p, "auc.png", 5.9, 2.3)
p <- ggplot(val, aes(Month)) + geom_line(aes(y = Published / 1000), colour = BLUE, linewidth = 2, alpha = 0.35) +
  geom_line(aes(y = `From PUMF` / 1000), colour = INK, linewidth = 0.6) + scale_y_continuous(labels = function(x) paste0(x, "k")) + labs(x = NULL, y = NULL)
save_png(p, "validation.png", 5.9, 2.0)
frows <- paste0(sprintf("<tr><td>%s</td><td>%s</td><td class='num'>%.1f%%</td><td class='num'>%.1f%%</td><td class='num %s'>%.2f</td><td class='num %s'>%.2f</td><td class='num'>%.0f%%</td></tr>",
                        fair$Dimension, gsub(" \\(incl. non-permanent residents\\)", "*", fair$Group), 100 * fair$`Observed Share`, 100 * fair$`Predicted Share`,
                        ifelse(fair$Flagged, "fail", ""), fair$`Observed To Predicted`, ifelse(fair$`Flagged Relative`, "fail", ""),
                        fair$`Relative To Overall`, 100 * fair$`Captured In Top 20 Percent`), collapse = "")
overall <- mm$post_hoc$overall_observed_to_predicted
m1 <- tests[grepl("^Random forest", Measure)]; m2 <- tests[Measure == "Gain over the age-only rule"]
body <- paste0(
  box(24, 10, 1232, 64, "<h1>How far to trust this</h1><div class='sub'>The numbers match Statistics Canada's own. The model did not clear its pre-registered bar, so it is reported but not used to target anyone.</div>", ""),
  box(24, 84, 300, 84, "<div class='card'><div class='v pass'>Passed</div><div class='l'>V1: all 56 months match StatCan's published count</div></div>"),
  box(334, 84, 300, 84, sprintf("<div class='card'><div class='v fail'>%s</div><div class='l'>M1: model AUC %.3f, bar 0.65</div></div>", m1$Result, m1$Value)),
  box(644, 84, 300, 84, sprintf("<div class='card'><div class='v pass'>%s</div><div class='l'>M2: beats age alone by %.3f (%.3f to %.3f; %.3f to %.3f panel-corrected)</div></div>", m2$Result, m2$Value, m2$`CI Low`, m2$`CI High`, mm$post_hoc$gain_ci_panel_corrected[1], mm$post_hoc$gain_ci_panel_corrected[2])),
  box(954, 84, 302, 84, "<div class='card'><div class='s'>Month-by-month CV flattered the forest</div><div class='l'>With buffers so no household spans a split, it lost all five blocks.</div></div>"),
  box(24, 180, 610, 238, "<div class='title'>Test AUC, July 2025 to August 2026 (panel-corrected 95% intervals; dashed line = M1 bar)</div><img src='assets/auc.png' style='width:585px;margin:0 12px'>"),
  box(24, 430, 610, 254, "<div class='title'>Validation: computed (dark) against published (light), people unemployed 27+ weeks</div><img src='assets/validation.png' style='width:585px;margin:0 12px'>"),
  box(646, 180, 610, 504, paste0("<div class='title'>GBA Plus check of the model (not used for targeting)</div><div style='padding:0 8px'><table style='font-size:11.5px'><tr><th>Dimension</th><th>Group</th><th class='num'>Observed</th><th class='num'>Predicted</th><th class='num'>Ratio</th><th class='num'>Relative</th><th class='num'>Top-20% reach</th></tr>",
                                 frows, sprintf("</table><div class='foot' style='padding:8px 4px'>Red marks ratios outside 0.8 to 1.25. Every group is under-predicted because the whole market worsened: overall, observed over predicted is %.2f. Relative to that drift (the &ldquo;Relative&rdquo; column) no group stands out. The real disparity is who a top-20%% list would reach: %.0f%% of long-term unemployed people aged 55 and over, only %.0f%% of those aged 15 to 24. *Non-immigrant includes non-permanent residents.</div></div>",
                                 overall, 100 * fair[Group == "55 and over", `Captured In Top 20 Percent`], 100 * fair[Group == "15 to 24", `Captured In Top 20 Percent`]))),
  nav(pages[4]), tag)
pngs <- c(pngs, render("page4_how_far_to_trust_this", body))
cat(pngs, sep = "\n")
