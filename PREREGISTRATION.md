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

None yet.
