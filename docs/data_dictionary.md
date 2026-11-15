# Data dictionary

All files are under `outputs/`. Rates are per 100,000 population. "DALY" is disability-adjusted life-year.

## Terms used in several files

| Term | Meaning |
|---|---|
| `category` / `cause` | `Overall` (osteoarthritis, all sites), `Hip`, `Knee`, `Hand`, `Other` (other sites) |
| `scale` | The measure: `ratio` = log female-to-male DALY-rate ratio (primary); `diff` = female-minus-male DALY-rate difference per 100,000 (secondary) |
| age groups | 5-year groups `30-34` to `90-94` (13 groups); their midpoints (32.5 to 92.5 years) are the ages used in the models. The open-ended `95+` group is not modelled |
| `LINEAR`, `HINGE`, `NS`, `CUBIC`, `GAM` | The five models: linear; changepoint (two linear segments joined at an age searched over a grid); natural spline with one knot; cubic polynomial; thin-plate generalized additive model |
| BIC, AICc | Bayesian information criterion; small-sample corrected Akaike information criterion. Lower is better |
| LOOCV RMSE | Leave-one-out cross-validated root mean squared error, on the scale of the measure. Lower is better |
| `status` | Classification of a curve: `CHANGEPOINT_PREFERRED`, `NON_CHANGEPOINT_PREFERRED` or `INCONCLUSIVE` (rule in the README) |

### Columns of every model-comparison file

`main/model_comparison_main.csv`, `calendar_time/model_comparison_*.csv` and `robustness/model_comparison_*.csv` have one
row per analysis, category and measure, with these columns:

| Column | Meaning |
|---|---|
| `analysis` | Name of the analysis, specification, period or year |
| `cause`, `scale` | Category and measure |
| `status` | Classification of the curve |
| `dominant` | Models that beat the changepoint model on all three criteria (BIC and AICc lower by at least the threshold, lower LOOCV RMSE), separated by `;`. Empty if none |
| `boundary` | Changepoint age selected by the search in the full data (years) |
| `orig_rule` | Linear-versus-changepoint step: `NO_BREAK` (changepoint BIC not lower than linear BIC by the threshold), `AMBIGUOUS` (a candidate age at least 5 years from the selected one has BIC within the threshold) or `UNIQUE_BREAK` |
| `adv_bic`, `adv_aicc`, `adv_cv` | Changepoint advantage: best value among the three smooth models (`NS`, `CUBIC`, `GAM`) minus the changepoint model's value, for BIC, AICc and LOOCV RMSE. Positive values favour the changepoint model |
| `exact` | Number of cross-validation folds in which the changepoint was supported over the linear model and the selected age equalled the full-data age |
| `within5` | The same, with the selected age within 5 years of the full-data age |
| `best_bic`, `best_aicc`, `best_cv` | Model with the lowest BIC, AICc and LOOCV RMSE |
| `gam_edf_k` | Effective parameter count of the GAM (from its log-likelihood, including the variance) |
| `gam_converged` | Whether the GAM converged in the full data and in every fold |

## `main/`

**`age_curves_main.csv`** – 70 rows: 5 categories × 14 age groups. Equal-year means over 1990–2021.

| Column | Meaning |
|---|---|
| `category`, `age_group`, `age_midpoint_years` | Category, age group, midpoint (empty for `95+`) |
| `used_in_models` | `TRUE` for the 13 age groups used in the models |
| `n_years` | Number of years averaged (32) |
| `mean_female_daly_rate_per_100000`, `mean_male_daly_rate_per_100000` | Mean of the annual DALY rates |
| `log_rate_ratio` | Mean of the annual log(female rate ÷ male rate) |
| `rate_ratio` | exp(`log_rate_ratio`) |
| `rate_difference_per_100000` | Mean of the annual female-minus-male rate differences |

**`model_comparison_main.csv`** – 10 rows (main analysis; Table 2). Columns as above, plus
`linear_minus_changepoint_bic` (linear BIC minus the lowest changepoint BIC) and `n_folds` (number of cross-validation folds, 13).

**`model_fits_main.csv`** – 50 rows: 10 curves × 5 models. `parameter_count` (K, including the variance; the changepoint
model counts one parameter for the search), `bic`, `aicc`, `loocv_rmse`.

**`changepoint_candidates_main.csv`** – 80 rows: 10 curves × 8 candidate ages. `candidate_changepoint_age` (45 to 80 years), `bic`.

**`constant_rate_ratio_curves.csv`** – 260 rows: 5 categories × 4 constructions × 13 age groups. For each category the
female-to-male ratio is held constant across age groups at the geometric mean of the 13 observed ratios.

| Column | Meaning |
|---|---|
| `construction` | `GEOMETRIC_MEAN_SYMMETRIC` (keeps the geometric mean of the two sexes' rates; primary), `ARITHMETIC_MEAN_SYMMETRIC` (keeps their arithmetic mean), `MALE_ANCHORED` (keeps the male rate), `FEMALE_ANCHORED` (keeps the female rate) |
| `observed_rate_difference_per_100000` | Observed difference (as in `age_curves_main.csv`) |
| `constant_rate_ratio` | The constant ratio used |
| `constructed_female_rate_per_100000`, `constructed_male_rate_per_100000`, `constructed_rate_difference_per_100000` | Rates and difference under the constant ratio |

**`constant_rate_ratio_summary.csv`** – 20 rows: 5 categories × 4 constructions. Linear-versus-changepoint step applied
to the observed and to the constructed difference curves: `observed_status`, `constant_ratio_status` (values as `orig_rule`),
`observed_delta_bic`, `constant_ratio_delta_bic` (linear BIC minus lowest changepoint BIC), `constant_ratio_best_age`,
`observed_competitive_ages`, `constant_ratio_competitive_ages` (candidate ages with BIC within the threshold of the lowest).

## `overall_burden/`

**`table1_overall.csv`** – Table 1 of the article (overall osteoarthritis): prevalent cases, prevalence rate, DALYs and
DALY rate in 1990 and 2021 with 95% uncertainty intervals, and the estimated annual percentage change (EAPC) of the rate
with its 95% confidence interval and p value, for both sexes, by sex and by age group. Rates in the "Global" and sex rows
are age-standardized; rates in age-group rows are age-specific.

**`burden_eapc_all_categories.csv`** – The same table for each of the five categories (column `category`).

**`table1_selected_age_sex_contrasts.csv`** – Female and male DALY rates in 2021 (95% uncertainty interval) and their
difference for three age groups quoted in the article.

**`overall_burden_summary.csv`** – Single numbers quoted in the text (`quantity`, `value`).

## `calendar_time/`

**`age_curves_by_weighting_and_period.csv`** – 325 rows: 5 analyses × 5 categories × 13 age groups (Table S7, Figure S2).
`analysis`: main (equal year weights, 1990–2021); population-weighted years; periods 1990–1999, 2000–2009 and 2010–2021.
`age_lab` (age group), `rate_ratio` (exponentiated mean log ratio), `rate_difference_per_100000`.

**`model_comparison_by_weighting_and_period.csv`** – 70 rows: the five analyses above and two alternative periods
(1990–2005, 2006–2021) × 10 curves (Table S8).

**`model_comparison_single_years.csv`** – 320 rows: each year 1990–2021 × 10 curves (Table S8). `analysis` is the year.

## `robustness/`

**`model_comparison_sensitivity_settings.csv`** – 190 rows: main analysis and 18 alternative specifications × 10 curves
(Table S3). `analysis` names the setting that was changed.

**`model_comparison_drop_one_age_group.csv`** – 130 rows: each of the 13 age groups removed in turn × 10 curves (Table S4).
`analysis` gives the midpoint of the removed age group.

**`fit_diagnostics.csv`** – 50 rows: 10 curves × 5 models (Table S5). `resid_sd` (residual standard deviation),
`max_abs_std_resid` (largest absolute standardized residual), `max_leverage`, `max_cooks_d` (largest Cook's distance), and
the age midpoint of the largest raw residual (`age_max_resid`) and largest Cook's
 distance (`age_max_cooks_d`). `age_max_leverage` is text containing every tied
 maximum-leverage midpoint, separated by semicolons. A tie means a difference
 no larger than `1e-12 * max(1, abs(maximum leverage))`. Table S5 converts these
 midpoints to age-group labels. This reporting tolerance does not enter model fitting
 or classification. The largest standardized residual and the age of the largest
 raw residual are distinct diagnostics.

**`residuals_main.csv`** – 650 rows: 10 curves × 5 models × 13 ages (Figure S1). `residual` = observed minus fitted.

## `simulation/`

**`simulation_batch1.csv` … `simulation_batch4.csv`** – 120 rows each: 10 curves × 2 truths × 3 autocorrelations × 2
noise levels. The four batches (35, 65, 40 and 60 replicates) together give 200 simulated curves per row.

| Column | Meaning |
|---|---|
| `curve` | Observed curve that supplied the truth (category and measure) |
| `truth` | `smooth` (fitted best smooth model) or `changepoint` (fitted changepoint model) |
| `rho` | First-order autocorrelation of the errors across age groups (0, 0.5, 0.8) |
| `noise_mult`, `sigma` | Noise multiplier (1 or 2) and the resulting error standard deviation |
| `true_changepoint` | Changepoint age of the fitted changepoint model (years) |
| `smooth_model` | Smooth model used as the smooth truth |
| `reps` | Replicates in the batch |
| `n_C`, `n_n`, `n_q` | Replicates classified changepoint preferred, non-changepoint preferred, inconclusive |
| `n_loc`, `n_C_loc` | Replicates whose selected age equalled `true_changepoint`; the same among those classified changepoint preferred |
| `p_*` | The corresponding proportions |

**`simulation_pooled_summary.csv`** – 12 rows: the four batches and ten curves pooled (2,000 simulated curves per
scenario; Table S6). `truth`, `noise_multiplier`, `ar1_rho`, `simulated_curves`, `p_changepoint_preferred`,
`p_non_changepoint_preferred`, `p_inconclusive`.

## `uncertainty/`

**`bounds_daly_vs_prevalence.csv`** – 65 rows: 5 categories × 13 age groups (Table S9). All quantities are calculated in
each year and averaged over 1990–2021 (rate ratios and their bounds on the log scale, then exponentiated).

| Column | Meaning |
|---|---|
| `dalys_per_case_female_over_male` | (DALY rate ÷ prevalence rate) in females divided by the same in males |
| `daly_rate_ratio`, `prevalence_rate_ratio` | Female-to-male ratio of DALY rates and of prevalence rates |
| `daly_bound_low`, `daly_bound_high`, `prev_bound_low`, `prev_bound_high` | Opposite-limit bounds for the ratio: female lower limit ÷ male upper limit, and female upper limit ÷ male lower limit (95% uncertainty limits) |
| `daly_rate_difference`, `daly_diff_bound_low`, `daly_diff_bound_high` | Female-minus-male DALY-rate difference and its opposite-limit bounds |
| `daly_bound_excludes_1`, `prev_bound_excludes_1`, `daly_diff_bound_excludes_0` | Whether the bounds exclude the null value |
| `daly_ui_upper_over_lower`, `prev_ui_upper_over_lower` | Upper ÷ lower 95% uncertainty limit of the rate, mean of the female and male values |

The bounds make no assumption about the dependence between the sexes; they are not confidence intervals.

## `country/`

Contrasts are in age-standardized DALY rates for 1990, 2000, 2010 and 2021. Only summary statistics across countries
are stored.

**`country_direction_weighted.csv`** – 20 rows: 5 categories × 4 years (Table S10, Part A).

| Column | Meaning |
|---|---|
| `n` | Countries and territories (204) |
| `prop_female_higher` | Share of countries in which the female rate exceeds the male rate |
| `pop_share_female_higher` | Share of the population living in those countries (all-age population, both sexes, back-calculated as number ÷ rate) |
| `median_rr`, `pop_weighted_median_rr` | Median and population-weighted median of the female-to-male rate ratio |
| `prop_female_higher_narrow_ui_half` | `prop_female_higher` within the half of countries with the narrowest uncertainty intervals |
| `ui_width_p05`, `ui_width_p95` | 5th and 95th percentiles across countries of the uncertainty-interval width (upper ÷ lower limit, geometric mean of the two sexes) |

**`sdi_correlations_bootstrap_weighted.csv`** – 40 rows: 5 categories × 2 measures × 4 years (Table S10, Part B).
Here `scale` is `ratio` for the female-to-male ratio and `diff` for the female-minus-male difference in age-standardized rates.

| Column | Meaning |
|---|---|
| `n_countries` | Countries and territories in the correlation (203; Georgia excluded) |
| `rho` | Spearman correlation between the contrast and the Socio-demographic Index |
| `ci_low`, `ci_high` | Percentile bootstrap 95% interval (5,000 resamples of countries) |
| `rho_population_weighted` | Weighted Spearman correlation with all-age population as weight |
| `rho_interval_width_weighted` | Weighted Spearman correlation with the inverse squared width of the uncertainty interval (log scale) as weight |
| `rho_narrow_ui_half` | Spearman correlation within the half of countries with the narrowest uncertainty intervals |

## `figures/` and `supplementary/`

`Figure_1.pdf`, `Figure_2.pdf`, `Figure_3.pdf`, `Figure_S1_residuals.pdf`, `Figure_S2_age_curves_by_period.pdf`, and
`supplementary/Additional_file_2_Tables_S2-S10.xlsx` (Tables S2–S10; each sheet carries its own notes).

`session_info.txt` lists the R and Python versions and package versions used for the run.
Pillow finalizes TIFF resolution tags and lossless compression; it does not alter pixel values.
