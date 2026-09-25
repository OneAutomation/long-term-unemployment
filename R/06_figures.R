# Figures for the README and briefing note (reports/figures/), drawn with ggplot2.

suppressPackageStartupMessages({ library(data.table); library(ggplot2); library(jsonlite) })
dir.create("reports/figures", recursive = TRUE, showWarnings = FALSE)
INK <- "#1F1F1F"; MUTED <- "#5A5A5A"; BLUE <- "#2166AC"; RED <- "#B2182B"; LIGHT <- "#9ECAE1"
theme_set(theme_minimal(base_size = 11) +
            theme(plot.title = element_text(face = "bold", colour = INK, size = 13),
                  plot.subtitle = element_text(colour = MUTED, size = 9.5), plot.title.position = "plot",
                  axis.text = element_text(colour = MUTED), panel.grid.minor = element_blank(),
                  plot.caption = element_text(colour = MUTED, size = 8, hjust = 0)))

# 1. Monthly trend in the number of long-term unemployed.
m <- fread("powerbi/data/monthly.csv")
p1 <- ggplot(m, aes(Date)) +
  geom_line(aes(y = `Long-Term People` / 1000), colour = LIGHT, linewidth = 0.6) +
  geom_line(aes(y = `Long-Term People 3-Month Average` / 1000), colour = BLUE, linewidth = 1.2, na.rm = TRUE) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "k")) +
  labs(title = "Long-term unemployment has roughly doubled since 2023",
       subtitle = "People unemployed 27 weeks or more, Canada, monthly (light) and 3-month average (dark), not seasonally adjusted",
       x = NULL, y = NULL, caption = "Source: Statistics Canada, Labour Force Survey public use microdata, Jan 2022 to Aug 2026.")
ggsave("reports/figures/fig1_trend.png", p1, width = 9, height = 4.2, dpi = 200, bg = "white")

# 2. Long-term share of unemployment by group, January to August 2026, with 95% bootstrap intervals.
e <- fread("powerbi/data/estimates.csv")[Period == "2026 Jan-Aug" & Measure == "Long-term share of unemployment" &
                                            Grouping %in% c("Age", "Gender", "Immigrant status", "Education")]
canada <- fread("powerbi/data/estimates.csv")[Period == "2026 Jan-Aug" & Measure == "Long-term share of unemployment" &
                                                 Grouping == "Canada", Estimate]
e[, Group := factor(Group, levels = rev(unique(Group)))]
e[, Grouping := factor(Grouping, levels = c("Age", "Gender", "Immigrant status", "Education"))]
p2 <- ggplot(e, aes(Estimate, Group)) +
  geom_vline(xintercept = canada, colour = MUTED, linetype = "dashed") +
  geom_errorbar(aes(xmin = `CI Low`, xmax = `CI High`), width = 0.25, colour = INK, orientation = "y") +
  geom_point(aes(colour = Quality), size = 2.6) +
  scale_colour_manual(values = c(Acceptable = BLUE, Marginal = "#EF8A62"), drop = FALSE) +
  facet_grid(Grouping ~ ., scales = "free_y", space = "free_y") +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Who is stuck: long-term share of unemployment, January to August 2026",
       subtitle = sprintf("Share of the unemployed out of work 27+ weeks; 95%% intervals from StatCan's bootstrap, widened for the six-month panel; dashed line = Canada (%.1f%%)", canada),
       x = NULL, y = NULL, colour = "StatCan quality") +
  theme(strip.text.y = element_text(angle = 0, hjust = 0, face = "bold", colour = INK), legend.position = "bottom")
ggsave("reports/figures/fig2_groups.png", p2, width = 9, height = 5.6, dpi = 200, bg = "white")

# 3. The pre-registered model test.
mm <- fromJSON("data/processed/model_metrics.json")
t3 <- data.table(model = factor(c("Age-only rule", "Logistic regression", "Random forest (chosen by CV)"),
                                levels = c("Age-only rule", "Logistic regression", "Random forest (chosen by CV)")),
                 auc = c(mm$test_metrics$auc_baseline, mm$test_metrics$auc_logistic, mm$test_metrics$auc_forest),
                 lo = c(mm$post_hoc$auc_ci_panel_corrected$baseline[1], mm$post_hoc$auc_ci_panel_corrected$logistic[1], mm$post_hoc$auc_ci_panel_corrected$chosen[1]),
                 hi = c(mm$post_hoc$auc_ci_panel_corrected$baseline[2], mm$post_hoc$auc_ci_panel_corrected$logistic[2], mm$post_hoc$auc_ci_panel_corrected$chosen[2]))
p3 <- ggplot(t3, aes(auc, model)) +
  geom_point(size = 3, colour = BLUE) +                      # first layer fixes the discrete y axis
  geom_vline(xintercept = 0.65, colour = RED, linetype = "dashed") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2, na.rm = TRUE, orientation = "y") +
  annotate("text", x = 0.651, y = 3.45, label = "M1 bar (0.65)", colour = RED, hjust = 0, size = 3.2) +
  geom_text(aes(label = sprintf("%.3f", auc)), nudge_y = 0.28, size = 3.3, colour = INK) +
  scale_x_continuous(limits = c(0.5, 0.7)) +
  labs(title = "Survey characteristics can't reliably pick out who is long-term unemployed",
       subtitle = "Weighted AUC on July 2025 to August 2026 job searchers; trained on 2022 to 2024; 95% intervals widened for the six-month panel",
       x = "AUC", y = NULL)
ggsave("reports/figures/fig3_model_test.png", p3, width = 9, height = 3.4, dpi = 200, bg = "white")

# 4. Validation against Statistics Canada's published counts.
v <- fread("powerbi/data/validation.csv")
p4 <- ggplot(v, aes(Month)) +
  geom_line(aes(y = Published / 1000, colour = "Published (table 14-10-0342-01)"), linewidth = 2.2, alpha = 0.35) +
  geom_line(aes(y = `From PUMF` / 1000, colour = "Computed from the PUMF"), linewidth = 0.7) +
  scale_colour_manual(values = c("Published (table 14-10-0342-01)" = BLUE, "Computed from the PUMF" = INK)) +
  scale_y_continuous(labels = function(x) paste0(x, "k")) +
  labs(title = "The processing reproduces Statistics Canada's published numbers",
       subtitle = sprintf("People unemployed 27+ weeks, unadjusted: all %d months within 1%%, largest gap %s people",
                          nrow(v), format(max(abs(v$Difference)), big.mark = ",")),
       x = NULL, y = NULL, colour = NULL) + theme(legend.position = "bottom")
ggsave("reports/figures/fig4_validation.png", p4, width = 9, height = 3.8, dpi = 200, bg = "white")
cat("figures:", paste(list.files("reports/figures"), collapse = ", "), "\n")
