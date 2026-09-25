# Building the Power BI report

About an hour the first time. Everything the report needs is in this folder: the tables in `data/`, the colour theme and every measure in `measures.dax`. The finished pages should look like the mockups in `mockups/`. Every number is precomputed in R with Statistics Canada's own variance method, so the report only arranges them; it never recalculates an estimate.

Power BI Desktop is free but runs only on Windows. On a Mac, use a Windows virtual machine or a remote Windows desktop; many universities and employers provide one.

## 1. Load the tables

Home > Get data > Text/CSV, once per file in `data/`, then **Load**. Rename the tables:

| File | Table |
|---|---|
| estimates.csv | Estimates |
| monthly.csv | Monthly |
| focus_groups.csv | Focus |
| validation.csv | Validation |
| model_tests.csv | Tests |
| fairness.csv | Fairness |
| capture_curve.csv | Capture |

In Table view, check that Monthly[Date] and Validation[Month] are Date, Estimate and CI columns are decimal numbers, and Estimates[Shown] is True/False. No relationships are needed; every table stands alone.

Select Estimates[Period] and choose Column tools > Sort by column > **Period Order**, so periods read 2022 to 2026 Jan-Aug.

## 2. Theme and measures

View > Themes > Browse for themes > `theme.json`. Then select the Estimates table and add each measure in `measures.dax` with Modeling > New measure. Format Long-Term Share, Change Since 2023 and Unemployment Rate as percentages with one decimal, and Long-Term People with thousands separators.

## 3. Page 1: The situation

The page is 1280 × 720; positions are x, y, width, height.

- **Title** (24, 14, 980, 64): "Long-term unemployment in Canada: who is stuck, and where should programs focus?" in 20 pt Segoe UI Semibold. Under it, in 11 pt grey: "Independent analysis of Statistics Canada Labour Force Survey microdata, January 2022 to August 2026. Not an ESDC or Statistics Canada product."
- **Period slicer** (1040, 22, 216, 50): Estimates[Period], dropdown, single select, default 2026 Jan-Aug.
- **Four cards** at y = 92, 96 tall, about 300 wide each:
  - `[Long-Term People]`, with `[Long-Term People CI Text]` in a card below it or as the subtitle;
  - `[Long-Term Share]` ("of the unemployed have been out 27+ weeks");
  - `[Change Since 2023]`, with `[Change On Previous Year]` in the card's label; both compare the same months (January to August against January to August);
  - `[Unemployment Rate]`, with `[Unemployment Rate Previous Year]` in its label.
- **Line chart** (24, 202, 740, 482): X-axis Monthly[Date]; Y-axis Monthly[Long-Term People] in light blue `#9ECAE1` and Monthly[Long-Term People 3-Month Average] in `#2166AC`. The period slicer doesn't affect it; turn off the slicer's interaction with this visual (Format > Edit interactions).
- **Bar chart** (780, 202, 476, 482): Y-axis Estimates[Group], X-axis Estimates[Estimate]. Filter pane: Grouping is Province, Measure is "Long-term share of unemployment", Shown is True. Sort by Estimate. Analytics > Error bars from CI Low and CI High if your version has them. Bar colour: fx > Field value > `[Quality Colour]`.

## 4. Page 2: Who's stuck

Four bar charts in a 2 × 2 grid (24, 86 / 646, 86 / 24, 336 / 646, 336; each 610 × 236), each with Y-axis Estimates[Group], X-axis Estimates[Estimate] and error bars from CI Low and CI High. Filter each to Measure "Long-term share of unemployment", Shown True, and one Grouping: Age, Gender, Immigrant status, Education. Colour by `[Quality Colour]`. Add a constant line at the Canada value for the selected period (Analytics > Constant line, value from `[Long-Term Share]` × 100 via fx). Keep the Period slicer synced from page 1 (View > Sync slicers).

Text box underneath (24, 584, 1232, 100): "Older job seekers, immigrants who arrived more than 10 years ago, and degree holders are the most likely to be out 27 weeks or more. Young people are the least likely to be stuck long, even though their unemployment rate is the highest."

## 5. Page 3: Where to focus

Header text: "Ranked by the number of people out of work 27+ weeks. The pre-registered model did not clear its bar, so this page uses direct survey estimates, as the pre-registered rule requires."

Two tables (24, 92, 610, 592 and 646, 92, 610, 592) from Focus:

- **Columns:** Rank Within Dimension, Group, Long-Term People, People Quality, Long-Term Share, Share CI Low, Share CI High, Share Quality.
- **Filters:** Shown is True on both (it drops any row whose count or share is suppressed); the left table to Dimension "Age x immigrant status"; the right to "Province x age" and Rank Within Dimension of 12 or less.
- **Sort and formatting:** sort by rank. Use conditional formatting (background, `#FDDBC7`) on Share Quality when it is Marginal.

## 6. Page 4: How far to trust this

- **Three cards** (y = 84): `[V1 Result]`, `[M1 Result]` with `[M1 Text]`, `[M2 Result]` with `[M2 Text]`. Colour the callout values with `[V1 Colour]`, `[M1 Colour]` and `[M2 Colour]` (fx > Field value).
- **Text card** (954, 84, 302, 84): "Month-by-month CV flattered the forest: with buffers so no household spans a split, it lost all five blocks."
- **Bar chart** of test AUCs (24, 180, 610, 238): Tests filtered to the rows "Random forest (chosen), test AUC", "Logistic regression, test AUC (not chosen)" and "Age-only rule, test AUC"; X-axis 0.5 to 0.7. Add a constant line at 0.65 labelled "M1 bar", with error bars from CI Low and CI High. Those intervals are panel-corrected; the Interval column says which kind each row carries.
- **Line chart** (24, 430, 610, 254): Validation[Month] with Validation[Published] (thick, light) and Validation[From PUMF] (thin, dark).
- **Table** (646, 180, 610, 504): Fairness, all columns. Conditional font colour red `#B2182B` on Observed To Predicted when Flagged is True. Under it, the note from the mockup explaining the under-prediction and the age gap in who the model would reach.

## 7. Accessibility and saving

- Every visual gets alt text (Format > General > Alt text).
- Tab order goes title, cards, charts, tables.
- Quality is always shown as text in the tables, not only as colour.
- Save as `long-term-unemployment.pbix`, export to PDF, and take one screenshot per page to replace the mockups in the README.
