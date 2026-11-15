# Female–male osteoarthritis burden by age: analysis code and derived outputs (GBD 2021)

Code and derived outputs for the article

> **Female–male osteoarthritis burden follows different age patterns across joints and measures: an ecological analysis**

The analysis uses Global Burden of Disease Study 2021 (GBD 2021) estimates of disability-adjusted life-year (DALY) rates
for overall osteoarthritis and osteoarthritis of the hip, knee, hand and other sites, by sex and 5-year age group, 1990–2021.
It describes how the female-to-male rate ratio (primary measure, analysed on the log scale) and the female-minus-male rate
difference (secondary measure) change with age, and compares five models of each age curve: linear, searched changepoint,
natural spline, cubic polynomial and a generalized additive model (GAM).

## What is in this repository

| Folder / file | Content |
|---|---|
| `R/` | Analysis and figure scripts, numbered in the order in which they run |
| `python/13_supplementary_tables.py` | Builds Additional file 2 (Tables S2–S10) from the analysis outputs |
| `outputs/` | The derived outputs reported in the article: age curves, model comparisons, sensitivity and simulation results, tables, vector figures |
| `data/input_files.csv` | The 14 input files that were analysed: file name, content, record count, size and SHA-256 checksum |
| `data/README.md` | How to obtain the inputs from IHME, with the query specifications |
| `docs/data_dictionary.md` | Description of every output file and column |
| `run_all.sh` | Runs everything in order |

**Not included:** the GBD 2021 files downloaded from IHME. The IHME data-use agreement does not allow them to be
redistributed. The 13 estimate files come from the GBD Results tool. The separate SDI table and its unrecovered download record are explained in `data/README.md`. The repository contains selected article tables, derived contrasts and summary statistics; it does not include the downloaded input datasets.

## Requirements

- R (≥ 4.3) with the packages `mgcv`, `ggplot2`, `patchwork` and `scales` (`splines` and `parallel` come with R).
  `digest` is needed only for checksum comparison on R < 4.5.
- Python >= 3.11 with `pandas`, `numpy`, `openpyxl` and `Pillow`: `python3 -m pip install -r requirements.txt`. Python builds the workbook and finalizes TIFF metadata.
- A UTF-8 locale (the default on macOS and most Linux systems), because some input file names contain non-ASCII characters.
- Cairo graphics are preferred (macOS Cairo requires XQuartz). The scripts probe the device before use. If unavailable, they use base PDF and a native TIFF device; font rendering can differ. Any failed export stops the run.
- `run_all.sh` needs a Unix shell (macOS, Linux, or WSL on Windows). The simulation uses forked parallel processes; where
  these are not available, run the pipeline on one core (`CORES=1 bash run_all.sh`). Results do not depend on the number of cores.

The article analyses used R 4.3.3 and mgcv 1.9-1. This readable-code release was
validated on macOS with R 4.3.3, mgcv 1.9-1 and Python 3.12.14. Exact package
versions are recorded in `outputs/session_info.txt`. See `docs/validation.md`
for the full-run comparison and its limits.

## How to run

1. Obtain the 14 input files (`data/README.md`) and put them in `data/raw/`, or put them anywhere and set the environment
   variable `GBD_RAW_DIR` to that folder.
2. From the repository root:

```bash
bash run_all.sh                      # everything; about one hour on 2 cores (the simulation takes most of it)
SKIP_SIMULATION=1 bash run_all.sh    # reuse the simulation batch files in outputs/simulation/; a few minutes
```

Scripts can also be run one at a time from the repository root, for example `Rscript R/02_main_model_comparison.R`.
Scripts 02, 03, 06, 07, 11 and 12 and the table-building Python script read only files in `outputs/`, so they can be run without the GBD inputs.

## Scripts and where their results appear

| Script | What it does | Outputs (`outputs/…`) | In the article |
|---|---|---|---|
| `R/00_check_inputs.R` | Checks that the inputs are present; compares record counts and checksums with the analysed files | – | Additional file 2: Table S2 |
| `R/01_main_age_curves.R` | Equal-year mean female–male contrasts by age group, 1990–2021 | `main/age_curves_main.csv` | Figures 2 and 3 |
| `R/02_main_model_comparison.R` | Five-model comparison of the ten curves (main analysis) | `main/model_comparison_main.csv`, `model_fits_main.csv`, `changepoint_candidates_main.csv` | Table 2, Figure 3 |
| `R/03_constant_rate_ratio.R` | Constant-rate-ratio sensitivity analysis | `main/constant_rate_ratio_*.csv` | Results, Supplementary Methods |
| `R/04_overall_burden_table1.R` | Numbers, rates and estimated annual percentage change (EAPC) | `overall_burden/*.csv` | Table 1, overall-burden paragraph |
| `R/05_calendar_time.R` | Population-weighted years, calendar periods, single years | `calendar_time/*.csv` | Tables S7 and S8, Figure S2 |
| `R/06_robustness.R` | 18 alternative specifications, drop-one-age-group, fit diagnostics, residuals | `robustness/*.csv` | Tables S3–S5, Figure S1 |
| `R/07_simulation.R` | Operating characteristics of the decision rule on simulated curves | `simulation/*.csv` | Table S6 |
| `R/08_bounds_daly_prevalence.R` | Opposite-limit bounds from DALY and prevalence rates; DALYs per prevalent case | `uncertainty/bounds_daly_vs_prevalence.csv` | Table S9 |
| `R/09_country_sdi.R` | Country-level direction of the contrast; correlations with the Socio-demographic Index | `country/*.csv` | Table S10 |
| `R/10_figure1.R` | Figure 1 | `figures/Figure_1.pdf` (`.tif`) | Figure 1 |
| `R/11_figures_2_3.R` | Figures 2 and 3 | `figures/Figure_2.pdf`, `Figure_3.pdf` (`.tif`) | Figures 2 and 3 |
| `R/12_supplementary_figures.R` | Figures S1 and S2 | `figures/Figure_S1_residuals.pdf`, `Figure_S2_age_curves_by_period.pdf` | Additional file 1 |
| `python/12_finalize_tiffs.py` | Sets resolution tags and lossless TIFF compression | `figures/Figure_*.tif` | Figures 1-3 |
| `python/13_supplementary_tables.py` | Tables S2–S10 as one workbook | `supplementary/Additional_file_2_Tables_S2-S10.xlsx` | Additional file 2 |
| `R/14_session_info.R`, `python/14_session_info.py` | Records software versions | `session_info.txt` | – |

`R/setup.R` (paths, input reading, record checks, figure helpers) and `R/engine.R` (model fitting, information criteria,
cross-validation and the decision rule) are shared by the other scripts.

## Model comparison in brief

The code uses explicit loops and small functions. `docs/code_guide.md` gives a reading order.

Each curve has 13 points (5-year age groups from 30–34 to 90–94 years; the open-ended ≥95-year group is not modelled).
Five models are fitted: linear (K = 3), changepoint with the location searched over 45–80 years in 5-year steps (K = 5),
natural spline with one knot at 62.5 years (K = 4), cubic polynomial (K = 5), and a thin-plate GAM (k = 5, maximum
likelihood). They are compared by BIC, AICc and leave-one-out cross-validated RMSE, and each curve is classified as

- `CHANGEPOINT_PREFERRED`: the initial comparison with a line supports one unique changepoint (BIC advantage at least 2; no candidate at least 5 years away within 2 BIC units). The changepoint also beats every smooth comparator by at least 2 BIC and AICc units and has lower LOOCV RMSE. At least 10/13 folds support and reproduce the exact age and at least 12/13 support an age within 5 years;
- `NON_CHANGEPOINT_PREFERRED`: the same non-changepoint model beats the changepoint by at least 2 BIC and AICc units and has lower LOOCV RMSE;
- `INCONCLUSIVE`: neither.

In the output files the changepoint model is labelled `HINGE`, the natural spline `NS`, and the two measures `ratio`
(log female-to-male rate ratio) and `diff` (female-minus-male rate difference per 100,000). All settings are in
`default_opts()` in `R/engine.R`; `docs/data_dictionary.md` explains every column.

## Reproducibility

- Input checks cover required columns, expected years, measures, causes, ages,
  sex categories and locations; row checks cover duplicates, missing values,
  finite/nonnegative estimates and ordered intervals. The analysed positive-rate
  subsets receive additional checks. A different checksum is a warning because
  re-export formatting can change it; semantic checks still apply.
- All four simulation batches (24,000 simulated curves) and the rest of the
  pipeline were run for this release. Classifications, selected changepoint ages
  and simulation counts matched the original results exactly. Other CSV numbers
  matched within `atol=1e-10, rtol=1e-10`; the observed largest absolute difference
  was approximately `1.03e-12`. See `docs/validation.md`.
- Table S5 lists all numerically tied maximum-leverage ages, rather than letting
  floating-point noise select one endpoint. This is a reporting change only.
- Seeds and scenario order are fixed. Matrix precomputation and parallel scenario
  execution are retained in script 07; the statistical rules are unchanged.
- Figures can differ in font metrics between devices and operating systems.
  Figure 1 reproduces the article's eight panels in one layout. PDFs are included;
  regenerated TIFFs are excluded from Git and finalized at 1200 dpi (Figure 1)
  or 800 dpi (Figures 2-3), with lossless compression.
- PDF/workbook metadata and floating-point tails can differ between runs. Do not
  use byte identity or `git diff --stat` as a numerical equivalence test.

To compare a run, preserve a separate copy of `outputs/` before running, then use:

```bash
python3 tests/compare_outputs.py /path/to/reference/outputs
Rscript tests/check_input_guards.R
Rscript tests/check_figure_exports.R
```

The input-guard test needs the global age-sex input and writes only temporary
copies. The comparison checks 25 CSV files, with exact checks for classifications,
selected changepoint ages and simulation counts. The documented leverage-tie
reporting change is handled separately.

**Data availability limit:** the local SDI preparation is reproducible, but its
original official download record has not been recovered. A successful run on
archived inputs is not proof that an external reader can independently retrieve
an identical official SDI source. See `data/README.md`.

## Data source and terms of use

GBD 2021 estimates are produced by the Institute for Health Metrics and Evaluation (IHME) and are available from the
GBD Results tool (https://vizhub.healthdata.org/gbd-results/) under the IHME Free-of-Charge Non-commercial User Agreement.
Any re-extraction must use the GBD 2021 release, because estimates for the same years are revised between GBD rounds.
The files in `outputs/` are summaries derived from these estimates; please respect the same terms when reusing them.

## License

Project code is licensed under MIT, copyright (c) 2026 Dean. This does not license
IHME data or the derived data, tables and figures. See `LICENSE` and `DATA_TERMS.md`.

## Citation

Please cite the article (full reference to be added on publication) and the GBD 2021 data source.
Questions can be addressed to the corresponding authors named in the article.
