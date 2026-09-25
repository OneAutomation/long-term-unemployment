# Pre-registration: who is stuck in long-term unemployment, and where should programs focus?

Written 2026-09-25 at 3:46 PM EDT, **before any model was trained or any test result was seen**. The data files have been downloaded and their codebook and user guide read; no estimate has been computed. The SHA-256 of this text is recorded in `PREREGISTRATION.sha256`. Later changes go in the Deviations section at the bottom, with the reason, and never overwrite the text above it.

## The question

Canada's job market softened in 2025 and early 2026; Statistics Canada reported employment falling by a combined 109,000 in January and February 2026. People out of work for 27 weeks or more are the hardest to bring back and the usual target of employment programs. **Among unemployed job searchers, who is most likely to be long-term unemployed, and which groups should programs reach first?**

This is an independent analysis of public data. It is not an ESDC or Statistics Canada product.

## Data

Statistics Canada, Labour Force Survey public use microdata files (71M0001X), January 2022 to August 2026: 56 monthly files, about 100,000 people each. Every estimate uses the final survey weight `FINALWT`. Multi-month averages stack the monthly files and divide the weight by the number of months, as the PUMF user guide instructs.

## Definitions

- **Unemployed:** `LFSSTAT = 3`.
- **Long-term unemployed (LTU):** unemployed with duration of unemployment `DURUNEMP` of 27 weeks or more, Statistics Canada's own threshold.
- **Descriptive population:** all unemployed with a recorded duration (job searchers and temporary layoffs; future starts have none).
- **Model population:** unemployed **job searchers**, which excludes temporary layoffs (`FLOWUNEM = 1`) and future starts (`FLOWUNEM = 8`). Programs aim at job searchers, and temporary layoffs are waiting for recall.

## Validation that can stop the analysis

**V1.** For every month from January 2022 to August 2026, the weighted count of Canadians aged 15 and over unemployed 27 weeks or more, computed from the PUMF, must match Statistics Canada table 14-10-0342-01 (unadjusted estimate, both genders) within 1% or within the table's rounding of 100 people, whichever is larger. **Any month that fails means a processing bug.** Estimation stops until it is found, and the fix is recorded as a deviation.

## Descriptive estimates and their reliability

Annual averages for 2022 to 2025 and the January to August 2026 average; the unemployment rate, the LTU share of unemployment and the LTU rate. They cover Canada, each province, age band (15 to 24, 25 to 54, 55 and over), gender, immigrant status (landed 10 years or less, landed more than 10 years, non-immigrant) and education (high school or less, some postsecondary or certificate or diploma, bachelor's or above).

Variance follows the PUMF user guide exactly. It uses 1,000 Poisson bootstrap replicate weights, each unit's weight multiplied by 1 ± √((w − 1)/w) with a random sign. Each replicate is calibrated to the survey weight totals in the guide's 220 domains (province × 11 age groups × gender). Quality follows the guide's Table 5:

| Label | Rule | Treatment |
|---|---|---|
| Acceptable | 5 or more respondents and a CV under 15% | shown as is |
| Marginal | a CV of 15% to 35% | shown with a warning |
| Suppressed | fewer than 5 respondents or a CV over 35% | not shown |

95% intervals are the 2.5th and 97.5th percentiles of the bootstrap estimates.

## The model and its tests

**Predictors, fixed now.** Only characteristics that are known when someone walks into a program and that do not encode how long they have been out of work:

- age group, gender, marital status, education, immigrant status;
- province and census metropolitan area;
- economic family type, age of youngest child, student status;
- full-time or part-time work sought;
- the six job-search-method flags.

**Excluded because they leak the answer.** Duration of joblessness (`DURJLESS`) is elapsed time itself. Several others are defined only for people who worked in the past 12 months, or split their categories on it, so their presence or value caps the duration: `EVERWORK`, `FLOWUNEM` (used only to define the population), `WHYLEFTO`, `WHYLEFTN`, `PREVTEN`, `NAICS_21`, `NOC_10` and `NOC_43`.

**Split.** Train on January 2022 to December 2024 and test on July 2025 to August 2026. The Labour Force Survey keeps each household for six months, so January to June 2025 is left out of both sets to stop the same people appearing on both sides of the split.

**Models.** All are trained with `FINALWT` as case weights:

- the **baseline**, a logistic regression on age group alone, which is the "target older job seekers" rule;
- a **logistic regression** on all the predictors above;
- a **random forest** (`ranger`, 500 trees, minimum node size 50, other settings at their defaults).

The better of the two full models on the training data's out-of-bag or cross-validated AUC is chosen **before** the test set is touched.

**Metrics on the test set.** All are weighted by `FINALWT`:

- AUC;
- the Brier score;
- calibration-in-the-large;
- **capture**, the share of long-term unemployed people found among the 20% of job searchers the model ranks highest.

Intervals come from 500 of the calibrated Poisson bootstrap replicates, applied to the test set.

**Pass marks, fixed now:**

- **M1:** the chosen model's weighted test AUC is at least 0.65.
- **M2:** the chosen model beats the age-only baseline's weighted test AUC by at least 0.03, and the 95% bootstrap interval of that difference excludes zero.

**Decision rule, fixed now.** If M1 or M2 fails, the dashboard's "where to focus" page ranks groups by the directly estimated LTU share and count (the descriptive estimates) and does not show model risk tiers. If both pass, it shows model-based targeting alongside the descriptive estimates.

**Fairness check (GBA Plus), reported whatever the result.** For the chosen model on the test set, by gender, age band and immigrant status, report:

- the ratio of observed to predicted LTU share;
- the share of each group's long-term unemployed captured at the top-20% threshold.

A group whose observed-to-predicted ratio falls outside 0.8 to 1.25 is flagged in every output. Risk tiers are not shown for that group without a warning.

## What this analysis will not claim

It will not claim to predict any individual's unemployment, and it is not a tool for deciding who gets services. The model ranks groups to help plan outreach, not to screen people. The PUMF has no person identifiers and ignores the survey's panel structure, so multi-month intervals are somewhat too narrow. The survey measures ongoing spells of unemployment, not completed ones.

## Deviations

Added 2026-09-25 at 3:49 PM EDT. Nothing above this heading was edited.

**D1, a bug in the V1 check itself, found by V1.** The first run of `R/02_validate.R` failed in all 56 months, by 88% for the 27-week count and 748% for total unemployment. Statistics Canada's API had returned the two requested series in the opposite order, and the script labelled them by position, so each PUMF count was compared with the other series. The script now matches series on their returned coordinates. Rerun, V1 passes in all 56 months, with a largest gap of 254 people (0.14%) on the 27-week count and 0.01% on total unemployment. The PUMF processing itself was never wrong. The analysis was stopped until this was found, as the rule requires.

Added 2026-09-25 at 4:05 PM EDT, after the pre-registered tests had run.

**D2, a post hoc diagnostic (no decision changed).** The random forest won the pre-registered month-blocked cross-validation (0.699 against 0.649 for the logistic regression) and was chosen, but on the test set it scored 0.611 against the logistic regression's 0.628. The Labour Force Survey keeps households for six months and the PUMF has no person identifier, so month-blocked folds put the same people on both sides of a split, and a forest can memorize them. Re-running the comparison with year-blocked folds (2022, 2023, 2024 held out in turn) gives logistic 0.641 and forest 0.633: the forest's lead disappears. The pre-registered choice stands and is reported. It does not change the outcome, because M1 fails for either model (0.611 and 0.628 are both below 0.65).

Added 2026-09-25 at 4:47 PM EDT, after an independent review of the analysis code and outputs.

**D3, a labelling error (the review's blocker).** Immigrant status code 3 is "Non-immigrant" in the codebook, and this pre-registration used that term, but the first scripts labelled it "Born in Canada". The PUMF has only three codes, and its population includes non-permanent residents and Canadian citizens born abroad, so they are in code 3. Every output now says "Non-immigrant (incl. non-permanent residents)". No number changed; the first briefing draft's "Canadian-born" wording was wrong and was never published.

**D4, a variance correction (post hoc).** The Poisson bootstrap treats every person-month as independent, but the survey keeps households for six consecutive months and the PUMF has no person identifier, so intervals for multi-month averages were too narrow. Standard errors are now multiplied by the largest factor the rotation allows, sqrt(1 + 2 * sum over k = 1 to 5 of (1 - k/m)(6 - k)/6) for an m-month average: 2.24 for years, 2.13 for January to August. Intervals now use the guide's normal form, the estimate plus or minus 2.0 standard errors. Table 5's "at least 5 respondents" is applied as at least 30 person-months, which guarantees 5 people. Result:

- In the pre-registered groupings, 740 estimates are acceptable, 30 marginal and 0 suppressed.
- In the cross-classifications (D5), 813 are acceptable, 489 marginal and 63 suppressed.
- The model's test set spans 14 months (factor 2.27). With the correction, M2's interval for the gain is 0.0216 to 0.0523, still above zero. The pre-registered verdicts stand: M1 fails and M2 passes.

**D5, estimates added beyond the pre-registration.** Four additions:

- Two January-to-August periods (2023 and 2025), because comparing a partial 2026 with full-year averages mixes seasons. Like for like, long-term unemployment went from 165,500 (January to August 2023) to 351,600 (2026), and was 355,500 in January to August 2025.
- The cross-classifications "Age x immigrant status" and "Province x age".
- The two count measures, long-term unemployed and unemployed people.
- A note on the long-term share: its denominator leaves out future starts, as defined above, so it runs about one point above the ratio implied by Statistics Canada's published table (January 2022: 18.6% here against 17.7%).

**D6, corrections to D1 and D2.**

- D1's largest gap is 254 people (0.075% of that month). The largest relative gap is 0.135% (July 2022).
- D2 called the month-blocked cross-validation "pre-registered". The pre-registration allowed out-of-bag or cross-validated AUC, and out-of-bag would have leaked just as badly: the reviewer measured the forest at 0.906 in-sample and 0.711 out-of-bag.
- D2's year-blocked check still shared households across year boundaries: up to five months of them, not only December and January. It is replaced in `R/diag_panel_cv.R` by five contiguous validation blocks with the five months either side removed from training. Logistic scores 0.642 and forest 0.623; the forest wins 0 of 5 blocks. Memorization of repeated households explains the forest's cross-validation lead.
- The forest remains the reported choice, as registered.

**D7, how to read the fairness flags.** The pre-registered rule, applied as written, flags six groups whose observed-to-predicted ratio is outside 0.8 to 1.25. But the overall ratio is 1.295, itself outside the band, because long-term unemployment rose from 18.8% of job searchers in training to 24.4% in the test period. Divided by the overall ratio, the group ratios run from 0.86 to 1.21 and none is flagged. The flags describe drift, not group-specific miscalibration. The real group difference is in who a top-20% list reaches: 60% of long-term unemployed people aged 55 and over, 4% of those aged 15 to 24.

**D8, what the model measures, and three fixes.** Job-search method flags change with time out of work (public employment agency use is about 9% at 1 to 4 weeks and 16% from 14 weeks on), and the survey samples people who are currently unemployed. So the model estimates how common long-term unemployment is among people currently unemployed with given characteristics; it does not predict risk at intake as this document's wording implied. There were also three fixes:

- Variable importance is now permutation importance on the test set with the chosen forest, five repeats.
- The capture measure splits tied scores pro rata, so the age-only rule no longer depends on row order.
- `R/03_estimates.R` now uses reproducible parallel random streams (L'Ecuyer-CMRG); `set.seed` alone had no effect inside the forked workers.

Brier scores on the test set: forest 0.1828, logistic 0.1806 and age-only 0.1853. Predicting the training-period average (18.8%) for everyone scores 0.1874. Predicting the test period's own average, knowable only in hindsight, scores 0.1843.
