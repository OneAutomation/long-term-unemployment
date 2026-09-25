#!/usr/bin/env bash
# Rebuild everything. Pass --fetch to download the 12 Labour Force Survey files first (about 161 MB).
set -euo pipefail
cd "$(dirname "$0")"
R="${RSCRIPT:-Rscript}"

if [[ "${1:-}" == "--fetch" ]]; then ./src/fetch_lfs.sh; fi

$R R/01_prepare.R        # read the 56 monthly files, keep the variables used
$R R/02_validate.R       # V1: match Statistics Canada's published 27+ week counts, or stop
$R R/03_estimates.R      # estimates with 1,000 calibrated Poisson bootstrap replicates (about 8 minutes)
$R R/04_model.R          # the pre-registered model tests
$R R/diag_panel_cv.R     # post hoc: buffered block cross-validation
$R R/05_exports.R        # Power BI tables
$R R/06_figures.R        # reports/figures
$R R/07_mockups.R        # powerbi/mockups
$R R/08_briefing.R       # reports/briefing-note.pdf

if [[ ! -x .venv/bin/python ]]; then
  uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python python-docx
fi
.venv/bin/python src/briefing_docx.py   # reports/briefing-note.docx
