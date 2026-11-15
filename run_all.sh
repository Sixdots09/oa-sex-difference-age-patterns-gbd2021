#!/usr/bin/env bash
# Run the whole analysis from the GBD 2021 input files and rebuild every table and figure.
#
#   bash run_all.sh                     everything (about one hour on 2 cores; the simulation takes most of it)
#   SKIP_SIMULATION=1 bash run_all.sh   keep the simulation batch files already in outputs/simulation/ (a few minutes)
#   CORES=4 bash run_all.sh             cores used by the simulation (default 2)
#
# The input files are looked for in data/raw/, or in the folder named by the environment variable GBD_RAW_DIR.
set -euo pipefail
cd "$(dirname "$0")"
CORES="${CORES:-2}"

Rscript R/00_check_inputs.R
Rscript R/01_main_age_curves.R
Rscript R/02_main_model_comparison.R
Rscript R/03_constant_rate_ratio.R
Rscript R/04_overall_burden_table1.R
Rscript R/05_calendar_time.R
Rscript R/06_robustness.R
if [ "${SKIP_SIMULATION:-0}" = "1" ]; then
  Rscript R/07_simulation.R "$CORES" none
else
  Rscript R/07_simulation.R "$CORES"
fi
Rscript R/08_bounds_daly_prevalence.R
Rscript R/09_country_sdi.R
Rscript R/10_figure1.R
Rscript R/11_figures_2_3.R
Rscript R/12_supplementary_figures.R
python3 python/12_finalize_tiffs.py
python3 python/13_supplementary_tables.py
Rscript R/14_session_info.R
python3 python/14_session_info.py
echo "Done. Results are in outputs/."
