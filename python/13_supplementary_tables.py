# Build supplementary tables from the analysis CSV files.
import os
import sys
import pandas as pd
import numpy as np
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side
from openpyxl.utils import get_column_letter
if not os.path.exists(os.path.join('R', 'setup.R')):
    sys.exit('Run this script from the repository root (the folder that contains R/, data/ and outputs/).')

def out(*parts):
    return os.path.join('outputs', *parts)
DEST = out('supplementary', 'Additional_file_2_Tables_S2-S10.xlsx')
os.makedirs(os.path.dirname(DEST), exist_ok=True)
F = 'Arial'
f_title, f_part, f_head, f_body, f_note = (Font(name=F, size=12, bold=True), Font(name=F, size=10, bold=True), Font(name=F, size=10, bold=True), Font(name=F, size=10), Font(name=F, size=9, italic=True))
fill_head = PatternFill('solid', start_color='D9E2F3')
thin = Side(style='thin', color='999999')
CAT = {'Overall': 'Overall', 'Hip': 'Hip', 'Knee': 'Knee', 'Hand': 'Hand', 'Other': 'Other-site'}
CATS = list(CAT)
MEAS = {'ratio': 'Rate ratio (log scale)', 'lrr': 'Rate ratio (log scale)', 'Relative (log F/M)': 'Rate ratio (log scale)', 'diff': 'Rate difference', 'rd': 'Rate difference', 'Absolute (F-M)': 'Rate difference', 'difference': 'Rate difference'}
MORD = ['Rate ratio (log scale)', 'Rate difference']
STAT = {'NON_CHANGEPOINT_PREFERRED': 'Non-changepoint preferred', 'INCONCLUSIVE': 'Inconclusive', 'CHANGEPOINT_PREFERRED': 'Changepoint preferred'}
CODE = {'NON_CHANGEPOINT_PREFERRED': 'N', 'INCONCLUSIVE': 'I', 'CHANGEPOINT_PREFERRED': 'C'}
MODEL = {'LINEAR': 'Linear', 'HINGE': 'Changepoint', 'NS': 'Natural spline', 'CUBIC': 'Cubic polynomial', 'GAM': 'GAM'}
values_1 = []
for a in range(30, 95, 5):
    values_1.append(f'{a}-{a + 4}')
AGES = values_1

def models(sheet):
    values_2 = []
    for x in str(sheet).split(';'):
        values_2.append(MODEL.get(x, x))
    return '' if pd.isna(sheet) else '; '.join(values_2)

def dash(sheet):
    return str(sheet).replace('-', '–')

def new_sheet(wb, name, title):
    sheet = {}
    sheet['worksheet'] = wb.create_sheet(name)
    sheet['row'] = 1
    sheet['widths'] = {}
    sheet['note_rows'] = []
    sheet['column_count'] = 2
    c = sheet['worksheet'].cell(1, 1, title)
    c.font = f_title
    sheet['row'] = 3
    return sheet

def add_part(sheet, text):
    sheet['worksheet'].cell(sheet['row'], 1, text).font = f_part
    sheet['row'] += 1

def add_table(sheet, headers, rows, fmts=None, freeze=False):
    fmts = fmts or {}
    sheet['column_count'] = max(sheet['column_count'], len(headers))
    for j, h in enumerate(headers, 1):
        c = sheet['worksheet'].cell(sheet['row'], j, h)
        c.font = f_head
        c.fill = fill_head
        c.alignment = Alignment(wrap_text=True, vertical='center', horizontal='center')
        c.border = Border(top=thin, bottom=thin)
        values_3 = []
        for w in str(h).split():
            values_3.append(len(w))
        sheet['widths'][j] = max(sheet['widths'].get(j, 0), min(max(values_3) + 2, 40), 9)
    values_4 = []
    for h in headers:
        values_4.append(int(np.ceil(len(str(h)) / 14)))
    sheet['worksheet'].row_dimensions[sheet['row']].height = 15 * max(1, max(values_4))
    if freeze:
        sheet['worksheet'].freeze_panes = sheet['worksheet'].cell(sheet['row'] + 1, 1)
    sheet['row'] += 1
    for row in rows:
        for j, v in enumerate(row, 1):
            if isinstance(v, (np.floating,)):
                v = float(v)
            if isinstance(v, (np.integer,)):
                v = int(v)
            if isinstance(v, float) and np.isnan(v):
                v = None
            c = sheet['worksheet'].cell(sheet['row'], j, v)
            c.font = f_body
            if isinstance(v, (int, float)) and (not isinstance(v, bool)):
                c.alignment = Alignment(horizontal='right', vertical='top')
                if headers[j - 1] in fmts:
                    c.number_format = fmts[headers[j - 1]]
            else:
                long = len(str(v or '')) > 30
                c.alignment = Alignment(horizontal='left' if j <= 2 or long else 'center', vertical='top', wrap_text=True)
                sheet['widths'][j] = max(sheet['widths'][j], min(len(str(v or '')) + 2, 62 if j == 1 else 44))
        sheet['row'] += 1
    for j in range(1, len(headers) + 1):
        sheet['worksheet'].cell(sheet['row'] - 1, j).border = Border(bottom=thin)
    sheet['row'] += 1

def add_notes(sheet, lines):
    for t in lines:
        sheet['worksheet'].cell(sheet['row'], 1, t).font = f_note
        sheet['note_rows'].append((sheet['row'], t))
        sheet['row'] += 1
    sheet['row'] += 1

def finish_sheet(sheet):
    for j, w in sheet['widths'].items():
        sheet['worksheet'].column_dimensions[get_column_letter(j)].width = w
    n = max(sheet['column_count'], 2)
    values_5 = []
    for j in range(1, n + 1):
        values_5.append(sheet['widths'].get(j, 9))
    total = sum(values_5)
    for r, t in sheet['note_rows']:
        sheet['worksheet'].merge_cells(start_row=r, start_column=1, end_row=r, end_column=n)
        sheet['worksheet'].cell(r, 1).alignment = Alignment(wrap_text=True, vertical='top')
        sheet['worksheet'].row_dimensions[r].height = 12.5 * max(1, int(np.ceil(len(t) / (total * 1.15))))
    sheet['worksheet'].sheet_view.showGridLines = False

def curve_cols():
    values_6 = []
    for c in CATS:
        for m in MORD:
            values_6.append(f"{CAT[c]}: {m.split(' (')[0].lower()}")
    return values_6

def tidy(d):
    d = d.copy()
    d['cat'] = d['cause'].map(CAT)
    d['meas'] = d['scale'].map(MEAS)
    assert d['cat'].notna().all() and d['meas'].notna().all()
    return d

def matrix(d, order, relabel):
    """rows = analyses, columns = ten curves, cell = classification code and selected changepoint age"""
    d = tidy(d)
    rows = []
    for a in order:
        r = [relabel(a)]
        for c in CATS:
            for m in MORD:
                x = d[(d['analysis'] == a) & (d['cause'] == c) & (d['meas'] == m)]
                assert len(x) == 1, (a, c, m, len(x))
                r.append(f"{CODE[x['status'].iloc[0]]} ({x['boundary'].iloc[0]:g})")
        cnt = d[d['analysis'] == a]['status'].map(CODE).value_counts()
        rows.append(r + [int(cnt.get('N', 0)), int(cnt.get('I', 0)), int(cnt.get('C', 0))])
    return (['Analysis'] + curve_cols() + ['N', 'I', 'C'], rows)
DET_H = ['Analysis', 'Category', 'Measure', 'Classification', 'Selected changepoint age (years)', 'Changepoint advantage: BIC', 'Changepoint advantage: AICc', 'Changepoint advantage: LOOCV RMSE', 'Folds reproducing the selected age exactly', 'Folds within 5 years of the selected age', 'Comparators better on all three criteria', 'Best model: BIC', 'Best model: AICc', 'Best model: LOOCV RMSE', 'GAM effective parameter count']
DET_F = {'Changepoint advantage: BIC': '0.00', 'Changepoint advantage: AICc': '0.00', 'Changepoint advantage: LOOCV RMSE': '0.0000', 'GAM effective parameter count': '0.00', 'Selected changepoint age (years)': '0.0'}

def details(d, order, relabel):
    d = tidy(d)
    rows = []
    for a in order:
        for c in CATS:
            for m in MORD:
                x = d[(d['analysis'] == a) & (d['cause'] == c) & (d['meas'] == m)].iloc[0]
                rows.append([relabel(a), CAT[c], m, STAT[x['status']], x['boundary'], x['adv_bic'], x['adv_aicc'], x['adv_cv'], x['exact'], x['within5'], models(x['dominant']), MODEL[x['best_bic']], MODEL[x['best_aicc']], MODEL[x['best_cv']], x['gam_edf_k']])
    return rows
NOTE_CODE = 'Cells show the classification and, in parentheses, the changepoint age selected by the search (years). N, non-changepoint preferred; I, inconclusive; C, changepoint preferred. The last three columns count the ten curves in each class.'
NOTE_RULE = 'A changepoint was preferred only if the initial comparison with a line supported one unique candidate location (BIC advantage at least the stated threshold, with no competitive location at least 5 years away), and it had lower BIC and AICc by at least the threshold (2 units unless stated) and lower LOOCV RMSE than every smooth comparator, and if its location was reproduced in enough cross-validation folds. A smooth comparator was preferred only if the same comparator was better than the changepoint model on all three criteria. All other results were inconclusive.'
NOTE_ADV = 'Changepoint advantage = best smooth-model criterion minus changepoint-model criterion; positive values favour the changepoint model. LOOCV RMSE is on the scale of the measure (log rate ratio, or DALYs per 100,000). Fold counts are out of the number of age groups (or adjacent pairs) left out in turn.'
ABBR = 'AICc, small-sample corrected Akaike information criterion; BIC, Bayesian information criterion; DALY, disability-adjusted life-year; GAM, generalized additive model; LOOCV RMSE, leave-one-out cross-validated root mean squared error.'
wb = Workbook()
wb.remove(wb.active)
# Contents.
sheet = new_sheet(wb, 'Contents', 'Additional file 2. Supplementary Tables S2–S10')
add_table(sheet, ['Table', 'Title'], [['Table S2', 'Data sources, query specifications, record counts and checksums'], ['Table S3', 'Five-model comparison under 18 alternative specifications'], ['Table S4', 'Five-model comparison with each age group removed in turn'], ['Table S5', 'Fit diagnostics for each model and curve'], ['Table S6', 'Simulation: operating characteristics of the decision rule'], ['Table S7', 'Female–male age curves under equal-year weighting, population weighting and by calendar period'], ['Table S8', 'Five-model comparison by weighting scheme, calendar period and single year'], ['Table S9', 'Opposite-limit bounds for the female–male contrast from DALY rates and from prevalence rates'], ['Table S10', 'Country-level direction of the contrast and correlations with the Socio-demographic Index']])
add_notes(sheet, ['All tables use Global Burden of Disease Study 2021 (GBD 2021) estimates. Female–male contrasts are point estimates; rates are per 100,000 population.', 'Categories: overall osteoarthritis and osteoarthritis of the hip, knee, hand and other sites. Age groups are 5-year groups from 30–34 to 90–94 years unless stated.', 'Table S1 (hormone therapy studies), the Supplementary Methods and Figures S1–S2 are in Additional file 1.'])
sheet['widths'][2] = 95
finish_sheet(sheet)
# Table S2.
sheet = new_sheet(wb, 'Table S2', 'Table S2. Data sources, query specifications, record counts and checksums')
add_part(sheet, 'Part A. Query specifications (GBD Results tool, GBD 2021 release; https://vizhub.healthdata.org/gbd-results/)')
five = 'Osteoarthritis (628), hip (1014), knee (1015), hand (1016), other (1017)'
add_table(sheet, ['Input', 'Measure (measure_id)', 'Metric (metric_id)', 'Cause (cause_id)', 'Location (location_id)', 'Age (age_id)', 'Sex (sex_id)', 'Year', 'Records'], [['Global DALYs by age and sex (age-trajectory analyses)', 'DALYs (2)', 'Number (1), Rate (3)', five, 'Global (1)', '30–34 to 90–94 years (11–20, 30, 31, 32); ≥95 years (235)', 'Male (1), Female (2)', '1990–2021', 8960], ['Global prevalence and DALYs by sex and age (overall burden, EAPC, Table 1, Figure 1)', 'Prevalence (5), DALYs (2)', 'Number (1), Rate (3); age-standardized: Rate only', five, 'Global (1)', '30–34 to ≥95 years (11–20, 30, 31, 32, 235); All ages (22); Age-standardized (27)', 'Male (1), Female (2), Both (3)', '1990–2021', 29760], ['Global DALYs, prevalence and incidence by age and sex, one file per category (prevalence-based bounds)', 'DALYs (2), Prevalence (5), Incidence (6)', 'Number (1), Rate (3)', 'One of 628, 1014, 1015, 1016, 1017 per file', 'Global (1)', '<5 to ≥95 years (1, 6–20, 30, 31, 32, 235)', 'Male (1), Female (2)', '1990–2021', 7680], ['Country-level estimates by sex, one file per category (country summaries, SDI analysis)', 'DALYs (2), Prevalence (5), Incidence (6)', 'All ages: Number (1), Rate (3); Age-standardized: Rate (3)', 'One of 628, 1014, 1015, 1016, 1017 per file', '204 countries and territories', 'All ages (22); Age-standardized (27)', 'Male (1), Female (2), Both (3)', '1990–2021', 176256], ['Country-level estimates, both sexes, overall osteoarthritis (population back-calculated as number ÷ rate)', 'DALYs (2), Prevalence (5), Incidence (6)', 'All ages: Number (1), Rate (3); Age-standardized: Rate (3)', 'Osteoarthritis (628)', '204 countries and territories', 'All ages (22); Age-standardized (27)', 'Both (3)', '1990–2021', 58752], ['Socio-demographic Index (GBD 2021 SDI table)', 'SDI', '–', '–', 'All GBD locations in the table', '–', '–', '1990–2021', 23552]], fmts={'Records': '#,##0'})
add_notes(sheet, ['The original query and export records have not been recovered. These specifications were reconstructed from the GBD identifiers and labels present in the analysed files.', 'The SDI wide-to-long conversion is documented in data/README.md. The original SDI download record has not been recovered; the official-source-to-local-file link remains unverified.', 'Records = rows in each analysed file (per file where one file per category). Any re-extraction must use the GBD 2021 release, because estimates for the same years are revised between GBD rounds.'])
add_part(sheet, 'Part B. Files analysed')
inputs = pd.read_csv(os.path.join('data', 'input_files.csv'))
values_7 = []
for r in inputs.itertuples():
    values_7.append([r.file_name, r.description, r.records, r.bytes, r.sha256])
add_table(sheet, ['File name', 'Content', 'Records', 'Size (bytes)', 'SHA-256'], values_7, fmts={'Records': '#,##0', 'Size (bytes)': '#,##0'})
add_notes(sheet, ['File names are those of the analysed files. The files themselves are not redistributed under the IHME data-use agreement; the checksums allow a re-extraction to be verified.'])
add_part(sheet, 'Part C. Data flow by analysis')
formats_8 = {}
for h in ['Records expected', 'Records observed', 'Records excluded', 'Records analysed']:
    formats_8[h] = '#,##0'
add_table(sheet, ['Analysis', 'Records expected', 'Records observed', 'Records excluded', 'Records analysed', 'Remarks'], [['Age trajectories and model comparison (DALY rates)', 4480, 4480, 320, 4160, 'Five categories × two sexes × 14 age groups × 32 years; the open-ended ≥95-year group (320 records) was not used in model fitting, leaving 13 age points per curve'], ['Overall burden and EAPC (Table 1, Figure 1)', 29760, 29760, 0, 29760, 'Prevalence and DALYs; numbers and rates'], ['Prevalence-based bounds and DALYs per prevalent case', 8320, 8320, 0, 8320, 'DALY and prevalence rates: five categories × two sexes × 13 age groups × 32 years × two measures, selected from 7,680 records per category file; records for ages under 30 years (all zero), for ≥95 years and for incidence were not used'], ['Country summaries (1990, 2000, 2010, 2021)', 8160, 8160, 0, 8160, 'Age-standardized DALY rates: 204 locations × two sexes × four years × five categories, selected from 176,256 records per category'], ['SDI correlations', 204, 204, 1, 203, 'Locations per year; Georgia excluded because the SDI table lists two locations under that name']], fmts=formats_8)
add_notes(sheet, ['Among the records used in each analysis, none was missing, duplicated, non-finite, non-positive or interval-inverted. No value was imputed and no record was removed for data-quality reasons.', 'The five category-specific age files each also contain 2,304 zero-valued records for ages under 30 years, for which GBD reports no osteoarthritis burden. These lie outside the analysed age range; this is an age-range restriction, not a data-quality exclusion.'])
add_part(sheet, 'Part D. Location names harmonized between the country-estimate and SDI files')
names = [('Bolivarian Republic of Venezuela', 'Venezuela (Bolivarian Republic of)'), ('Commonwealth of the Bahamas', 'Bahamas'), ('Czech Republic', 'Czechia'), ('Federated States of Micronesia', 'Micronesia (Federated States of)'), ('Islamic Republic of Iran', 'Iran (Islamic Republic of)'), ('Kingdom of Eswatini', 'Eswatini'), ('Plurinational State of Bolivia', 'Bolivia (Plurinational State of)'), ('Principality of Monaco', 'Monaco'), ('Republic of Cabo Verde', 'Cabo Verde'), ("Republic of Côte d'Ivoire", "Côte d'Ivoire"), ('Republic of Nauru', 'Nauru'), ('Republic of Niue', 'Niue'), ('Republic of Palau', 'Palau'), ('Republic of San Marino', 'San Marino'), ('Republic of the Gambia', 'Gambia'), ('Socialist Republic of Viet Nam', 'Viet Nam'), ('Turkey', 'Türkiye'), ('United Kingdom of Great Britain and Northern Ireland', 'United Kingdom'), ('Taiwan (Province of China)', 'Taiwan')]
values_9 = []
for x in names:
    values_9.append(list(x))
add_table(sheet, ['Name in one file', 'Harmonized name'], values_9)
finish_sheet(sheet)
g3 = pd.read_csv(out('robustness', 'model_comparison_sensitivity_settings.csv'))
SET = {'Main analysis': 'Main analysis', 'Grid: 2.5-year steps, 45-80': 'Changepoint grid: 2.5-year steps, 45–80 years', 'Grid: age-group midpoints, 42.5-82.5': 'Changepoint grid: age-group midpoints, 42.5–82.5 years', 'Grid: wider range, 40-85': 'Changepoint grid: 5-year steps, 40–85 years', 'Grid: quasi-continuous, 45-80 by 0.5': 'Changepoint grid: 0.5-year steps, 45–80 years', 'Count: changepoint K=4 (no search penalty)': 'Changepoint parameter count K = 4 (no search penalty)', 'Count: GAM = sum(edf)+1': 'GAM parameter count: sum of effective degrees of freedom + 1', 'Count: GAM = full basis k+1': 'GAM parameter count: full basis (k + 1)', 'GAM: REML instead of ML': 'GAM fitted by restricted maximum likelihood', 'GAM: basis k=4': 'GAM basis dimension k = 4', 'GAM: basis k=6': 'GAM basis dimension k = 6', 'Spline knot at 52.5': 'Natural-spline knot at 52.5 years', 'Spline knot at 72.5': 'Natural-spline knot at 72.5 years', 'Threshold: any advantage (0)': 'Information-criterion threshold 0', 'Threshold: strong advantage (6)': 'Information-criterion threshold 6', 'CV: leave two adjacent ages out': 'Cross-validation leaving out two adjacent age groups', 'Drop youngest age group (30-34)': 'Youngest age group (30–34 years) removed', 'Drop oldest age group (90-94)': 'Oldest age group (90–94 years) removed', 'Drop both end groups': 'Both end age groups removed'}
order = list(g3['analysis'].unique())
assert set(order) == set(SET) and len(order) == 19
# Table S3.
sheet = new_sheet(wb, 'Table S3', 'Table S3. Five-model comparison under 18 alternative specifications')
add_part(sheet, 'Part A. Classification and selected changepoint age, by specification and curve')
h, rows = matrix(g3, order, SET.get)
add_table(sheet, h, rows)
add_notes(sheet, [NOTE_CODE, NOTE_RULE, 'Main analysis: changepoint grid 45–80 years in 5-year steps; parameter counts K = 3 (linear), 5 (changepoint, including one search parameter), 4 (natural spline, knot at 62.5 years), 5 (cubic polynomial); GAM with thin-plate basis k = 5 fitted by maximum likelihood, parameter count from the log-likelihood; threshold 2; leave-one-out cross-validation.'])
add_part(sheet, 'Part B. Full results')
add_table(sheet, DET_H, details(g3, order, SET.get), DET_F)
add_notes(sheet, [NOTE_ADV, ABBR])
finish_sheet(sheet)
g4 = pd.read_csv(out('robustness', 'model_comparison_drop_one_age_group.csv'))
order = list(g4['analysis'].unique())
assert len(order) == 13

def drop_lab(a):
    m = float(a.split()[-1])
    return f'{int(m - 2.5)}–{int(m + 1.5)} years removed'
# Table S4.
sheet = new_sheet(wb, 'Table S4', 'Table S4. Five-model comparison with each age group removed in turn')
add_part(sheet, 'Part A. Classification and selected changepoint age, by removed age group and curve')
h, rows = matrix(g4, order, drop_lab)
add_table(sheet, h, rows)
add_notes(sheet, [NOTE_CODE, 'Each row refits all five models to the remaining 12 age groups with unchanged rules.'])
add_part(sheet, 'Part B. Full results')
add_table(sheet, DET_H, details(g4, order, drop_lab), DET_F)
add_notes(sheet, [NOTE_ADV, ABBR])
finish_sheet(sheet)
dg = pd.read_csv(out('robustness', 'fit_diagnostics.csv'))
dg['meas'] = dg['scale'].map(MEAS)

def agelab(midpoints):
    labels = []
    for value in str(midpoints).split(';'):
        midpoint = float(value)
        labels.append(f'{int(midpoint - 2.5)}–{int(midpoint + 1.5)}')
    return '; '.join(labels)
# Table S5.
sheet = new_sheet(wb, 'Table S5', 'Table S5. Fit diagnostics for each model and curve (main analysis, 13 age groups)')
values_10 = []
for c in CATS:
    for m in MORD:
        for r in dg[(dg['cause'] == c) & (dg['meas'] == m)].itertuples():
            values_10.append([CAT[r.cause], r.meas, MODEL[r.model], r.resid_sd, r.max_abs_std_resid, agelab(r.age_max_resid), r.max_leverage, agelab(r.age_max_leverage), r.max_cooks_d, agelab(r.age_max_cooks_d)])
rows = values_10
add_table(sheet, ['Category', 'Measure', 'Model', 'Residual SD', 'Largest absolute standardized residual', 'Age group of largest raw residual (years)', 'Largest leverage', 'Age groups of largest leverage (years)', "Largest Cook's distance", "Age group of largest Cook's distance (years)"], rows, {'Residual SD': '0.0000', 'Largest absolute standardized residual': '0.00', 'Largest leverage': '0.00', "Largest Cook's distance": '0.00'}, freeze=True)
add_notes(sheet, ['Residual SD is on the scale of the measure (log rate ratio, or DALYs per 100,000). Leverage for the GAM is the diagonal of its influence matrix; Cook’s distance uses the effective degrees of freedom.', 'All ages tied for the largest leverage are listed, separated by semicolons. Ties use an absolute tolerance of 1e-12 times max(1, absolute maximum leverage); this affects reporting only.', 'In every model and curve the largest Cook’s distance fell on the youngest (30–34 years) or the oldest (90–94 years) age group. Residual patterns are shown in Additional file 1: Figure S1.', ABBR])
finish_sheet(sheet)
values_11 = []
for i in (1, 2, 3, 4):
    values_11.append(pd.read_csv(out('simulation', f'simulation_batch{i}.csv')))
sim = pd.concat(values_11)
TRUTH = {'smooth': 'Smooth', 'changepoint': 'Changepoint'}
# Table S6.
sheet = new_sheet(wb, 'Table S6', 'Table S6. Simulation: operating characteristics of the decision rule')
add_part(sheet, 'Part A. All ten curve shapes pooled (2,000 simulated curves per scenario)')
pool = sim.groupby(['truth', 'noise_mult', 'rho'], as_index=False)[['reps', 'n_C', 'n_n', 'n_q']].sum()
assert (pool['reps'] == 2000).all()
chk = pd.read_csv(out('simulation', 'simulation_pooled_summary.csv'))
m = pool.merge(chk, left_on=['truth', 'noise_mult', 'rho'], right_on=['truth', 'noise_multiplier', 'ar1_rho'])
assert len(m) == 12 and np.allclose(m['n_C'] / m['reps'], m['p_changepoint_preferred'])
PH = ['Changepoint preferred (%)', 'Non-changepoint preferred (%)', 'Inconclusive (%)']
values_12 = []
for t in ['smooth', 'changepoint']:
    for r in pool[pool['truth'] == t].sort_values(['noise_mult', 'rho']).itertuples():
        values_12.append([TRUTH[r.truth], r.noise_mult, r.rho, r.reps, 100 * r.n_C / r.reps, 100 * r.n_n / r.reps, 100 * r.n_q / r.reps])
rows = values_12
formats_13 = {}
for h in PH:
    formats_13[h] = '0.0'
formats_14 = dict(formats_13)
formats_14.update({'Simulated curves': '#,##0', 'Autocorrelation of errors': '0.0'})
add_table(sheet, ['Simulated truth', 'Noise multiplier', 'Autocorrelation of errors', 'Simulated curves'] + PH, rows, formats_14)
add_part(sheet, 'Part B. By curve shape (200 simulated curves per scenario and curve)')
by = sim.groupby(['curve', 'truth', 'noise_mult', 'rho'], as_index=False).agg(reps=('reps', 'sum'), n_C=('n_C', 'sum'), n_n=('n_n', 'sum'), n_q=('n_q', 'sum'), n_loc=('n_loc', 'sum'), sigma=('sigma', 'first'), cp=('true_changepoint', 'first'), sm=('smooth_model', 'first'))
assert (by['reps'] == 200).all() and len(by) == 120
rows = []
for c in CATS:
    for sc, ml in [('ratio', MORD[0]), ('diff', MORD[1])]:
        for t in ['smooth', 'changepoint']:
            for r in by[(by['curve'] == f'{c} {sc}') & (by['truth'] == t)].sort_values(['noise_mult', 'rho']).itertuples():
                rows.append([CAT[c], ml, TRUTH[t], MODEL[r.sm] if t == 'smooth' else f'Changepoint at {r.cp:g} years', r.noise_mult, r.rho, r.sigma, 100 * r.n_C / r.reps, 100 * r.n_n / r.reps, 100 * r.n_q / r.reps, 100 * r.n_loc / r.reps if t == 'changepoint' else None])
H = ['Category', 'Measure', 'Simulated truth', 'Model used as truth', 'Noise multiplier', 'Autocorrelation of errors', 'Error SD'] + PH + ['Selected age equal to true changepoint (%)']
formats_15 = {}
for h in PH + ['Selected age equal to true changepoint (%)', 'Autocorrelation of errors']:
    formats_15[h] = '0.0'
formats_16 = dict(formats_15)
formats_16.update({'Error SD': '0.0000'})
add_table(sheet, H, rows, formats_16)
add_notes(sheet, ['For each observed curve, the fitted best smooth model (GAM or cubic polynomial) and the fitted changepoint model served as two alternative truths. Gaussian errors had the residual SD of the best-fitting model for that curve (noise multiplier 1) or twice that value (2), and were independent (autocorrelation 0) or first-order autoregressive across age groups (0.5 or 0.8).', 'The unchanged decision rule of the main analysis was applied to every simulated curve. Error SD is on the scale of the measure (log rate ratio, or DALYs per 100,000).', ABBR])
finish_sheet(sheet)
ac = pd.read_csv(out('calendar_time', 'age_curves_by_weighting_and_period.csv'))
AN = [('Main (equal year weights, 1990-2021)', 'Equal-year weights, 1990–2021 (main analysis)'), ('Population-weighted years', 'Population-weighted years, 1990–2021'), ('Period 1990-1999', '1990–1999'), ('Period 2000-2009', '2000–2009'), ('Period 2010-2021', '2010–2021')]
# Table S7.
sheet = new_sheet(wb, 'Table S7', 'Table S7. Female–male age curves under equal-year weighting, population weighting and by calendar period')
values_17 = []
for _, l in AN:
    values_17.append(f'Rate ratio: {l}')
values_18 = []
for _, l in AN:
    values_18.append(f'Rate difference: {l}')
H = ['Category', 'Age group (years)'] + values_17 + values_18
rows = []
for c in CATS:
    for a in AGES:
        x = ac[(ac['cause'] == c) & (ac['age_lab'] == a)].set_index('analysis')
        assert len(x) == 5
        values_19 = []
        for k, _ in AN:
            values_19.append(x.loc[k, 'rate_ratio'])
        values_20 = []
        for k, _ in AN:
            values_20.append(x.loc[k, 'rate_difference_per_100000'])
        rows.append([CAT[c], dash(a)] + values_19 + values_20)
formats_21 = {}
for h in H:
    if h.startswith('Rate ratio'):
        formats_21[h] = '0.000'
formats_22 = {}
for h in H:
    if h.startswith('Rate difference'):
        formats_22[h] = '0.00'
formats_23 = dict(formats_21)
formats_23.update(formats_22)
add_table(sheet, H, rows, formats_23, freeze=True)
add_notes(sheet, ['Rate ratio = exponentiated mean of annual log female-to-male DALY-rate ratios. Rate difference = mean of annual female-minus-male DALY-rate differences, per 100,000.', 'Equal-year weights give each year from 1990 to 2021 the same weight. Population weights are the combined female and male population of the age group in each year, back-calculated from GBD numbers and rates.', 'Period curves use equal-year weights within the period. The same curves are plotted in Additional file 1: Figure S2.'])
finish_sheet(sheet)
g2 = pd.read_csv(out('calendar_time', 'model_comparison_by_weighting_and_period.csv'))
sy = pd.read_csv(out('calendar_time', 'model_comparison_single_years.csv'))
formats_24 = dict(dict(AN))
formats_24.update({'Period 1990-2005': '1990–2005', 'Period 2006-2021': '2006–2021'})
PER = formats_24
order = list(g2['analysis'].unique())
assert set(order) == set(PER)
# Table S8.
sheet = new_sheet(wb, 'Table S8', 'Table S8. Five-model comparison by weighting scheme, calendar period and single year')
add_part(sheet, 'Part A. Classification and selected changepoint age, by weighting scheme or period and curve')
h, rows = matrix(g2, order, PER.get)
add_table(sheet, h, rows)
add_notes(sheet, [NOTE_CODE, NOTE_RULE])
add_part(sheet, 'Part B. Full results by weighting scheme or period')
add_table(sheet, DET_H, details(g2, order, PER.get), DET_F)
add_notes(sheet, [NOTE_ADV])
add_part(sheet, 'Part C. Classification and selected changepoint age in each single year')
yo = sorted(sy['analysis'].unique())
assert len(yo) == 32
h, rows = matrix(sy, yo, str)
h[0] = 'Year'
add_table(sheet, h, rows)
add_notes(sheet, ['Single-year curves use the female-to-male contrast of that year only. They are shown to describe how stable the classification is across years, not as independent replications: annual GBD estimates come from related models.', ABBR])
finish_sheet(sheet)
b = pd.read_csv(out('uncertainty', 'bounds_daly_vs_prevalence.csv'))
assert len(b) == 65 and list(b['age'][:13]) == AGES

def inc(lo, hi, null):
    if lo <= null <= hi:
        return 'Yes'
    return 'No'
values_25 = []
for r in b.itertuples():
    values_25.append(inc(r.daly_bound_low, r.daly_bound_high, 1) == 'Yes' and inc(r.daly_diff_bound_low, r.daly_diff_bound_high, 0) == 'Yes')
assert all(values_25), 'DALY bounds must include the null everywhere'
H = ['Category', 'Age group (years)', 'DALY rate ratio', 'DALY ratio: lower bound', 'DALY ratio: upper bound', 'DALY ratio bounds include 1', 'DALY rate difference', 'DALY difference: lower bound', 'DALY difference: upper bound', 'DALY difference bounds include 0', 'Prevalence rate ratio', 'Prevalence ratio: lower bound', 'Prevalence ratio: upper bound', 'Prevalence ratio bounds include 1', 'DALYs per prevalent case, female ÷ male', 'DALY rate: upper ÷ lower uncertainty limit', 'Prevalence rate: upper ÷ lower uncertainty limit']
values_26 = []
for c in CATS:
    for r in b[b['cause'] == c].itertuples():
        values_26.append([CAT[r.cause], dash(r.age), r.daly_rate_ratio, r.daly_bound_low, r.daly_bound_high, inc(r.daly_bound_low, r.daly_bound_high, 1), r.daly_rate_difference, r.daly_diff_bound_low, r.daly_diff_bound_high, inc(r.daly_diff_bound_low, r.daly_diff_bound_high, 0), r.prevalence_rate_ratio, r.prev_bound_low, r.prev_bound_high, inc(r.prev_bound_low, r.prev_bound_high, 1), r.dalys_per_case_female_over_male, r.daly_ui_upper_over_lower, r.prev_ui_upper_over_lower])
rows = values_26
# Table S9.
sheet = new_sheet(wb, 'Table S9', 'Table S9. Opposite-limit bounds for the female–male contrast from DALY rates and from prevalence rates')
formats_27 = {}
for h in H:
    if 'ratio' in h or 'case' in h:
        formats_27[h] = '0.000'
formats_28 = {}
for h in H:
    if 'difference' in h:
        formats_28[h] = '0.0'
formats_29 = dict(formats_27)
formats_29.update(formats_28)
formats_30 = {}
for h in H:
    if 'uncertainty limit' in h:
        formats_30[h] = '0.00'
formats_31 = dict(formats_29)
formats_31.update(formats_30)
add_table(sheet, H, rows, formats_31, freeze=True)
add_notes(sheet, ['Bounds combine the lower 95% uncertainty limit for one sex with the upper limit for the other (female lower ÷ male upper, and female upper ÷ male lower; likewise for differences), calculated in each year and averaged over 1990–2021 (ratios on the log scale). They make no assumption about the dependence between the sexes and carry no probability statement.', 'They are not confidence intervals or tests and do not measure the precision of a contrast: joint draws and the female–male covariance were unavailable. Prevalence bounds describe prevalence and do not supply the uncertainty of the DALY contrasts.', 'DALYs per prevalent case and the ratio of upper to lower uncertainty limits (mean of the female and male values) are averaged over 1990–2021. Rates are per 100,000.'])
finish_sheet(sheet)
formats_32 = {}
for c in CATS:
    values_33 = []
    for r in b[b['cause'] == c].itertuples():
        values_33.append(inc(r.prev_bound_low, r.prev_bound_high, 1) == 'No')
    formats_32[c] = int(sum(values_33))
nP = formats_32
print('Prevalence bounds excluding 1 (age groups, of 13):', nP)
cd = pd.read_csv(out('country', 'country_direction_weighted.csv'))
sd = pd.read_csv(out('country', 'sdi_correlations_bootstrap_weighted.csv'))
# Table S10.
sheet = new_sheet(wb, 'Table S10', 'Table S10. Country-level direction of the contrast and correlations with the Socio-demographic Index')
add_part(sheet, 'Part A. Direction of the female–male contrast in age-standardized DALY rates across 204 countries and territories')
H = ['Category', 'Year', 'Countries and territories', 'Female rate higher: share of countries (%)', 'Female rate higher: share of population (%)', 'Median rate ratio', 'Population-weighted median rate ratio', 'Female rate higher: share within the half with narrowest uncertainty intervals (%)', 'Uncertainty-interval width, 5th percentile', 'Uncertainty-interval width, 95th percentile']
values_34 = []
for c in CATS:
    for r in cd[cd['cause'] == c].sort_values('year').itertuples():
        values_34.append([CAT[r.cause], r.year, r.n, 100 * r.prop_female_higher, 100 * r.pop_share_female_higher, r.median_rr, r.pop_weighted_median_rr, 100 * r.prop_female_higher_narrow_ui_half, r.ui_width_p05, r.ui_width_p95])
rows = values_34
formats_35 = {}
for h in H:
    if '%' in h:
        formats_35[h] = '0.0'
formats_36 = {}
for h in H:
    if 'ratio' in h:
        formats_36[h] = '0.000'
formats_37 = dict(formats_35)
formats_37.update(formats_36)
formats_38 = {}
for h in H:
    if 'width' in h:
        formats_38[h] = '0.00'
formats_39 = dict(formats_37)
formats_39.update(formats_38)
formats_40 = dict(formats_39)
formats_40.update({'Year': '0'})
add_table(sheet, H, rows, formats_40)
add_notes(sheet, ['Rate ratio = female ÷ male age-standardized DALY rate. Population = all-age population of both sexes in that year, back-calculated from GBD numbers and rates.', 'Uncertainty-interval width = the geometric mean, over the two sexes, of upper ÷ lower 95% uncertainty limits of the age-standardized DALY rate; its narrow range shows that the intervals do not distinguish countries by data quality.'])
add_part(sheet, 'Part B. Spearman correlation between the female–male contrast and SDI (203 countries and territories)')
H = ['Category', 'Measure', 'Year', 'Spearman correlation', 'Bootstrap 95% interval: lower', 'Bootstrap 95% interval: upper', 'Interval excludes 0', 'Population-weighted correlation', 'Sign differs from unweighted', 'Interval-width-weighted correlation', 'Correlation within the half with narrowest uncertainty intervals']
rows = []
for c in CATS:
    for sc, ml in [('ratio', 'Rate ratio'), ('diff', 'Rate difference')]:
        for r in sd[(sd['cause'] == c) & (sd['scale'] == sc)].sort_values('year').itertuples():
            rows.append([CAT[c], ml, r.year, r.rho, r.ci_low, r.ci_high, 'Yes' if r.ci_low > 0 or r.ci_high < 0 else 'No', r.rho_population_weighted, 'Yes' if np.sign(r.rho) != np.sign(r.rho_population_weighted) else 'No', r.rho_interval_width_weighted, r.rho_narrow_ui_half])
formats_41 = {}
for h in H:
    if 'orrelation' in h or 'interval:' in h:
        formats_41[h] = '0.00'
formats_42 = dict(formats_41)
formats_42.update({'Year': '0'})
add_table(sheet, H, rows, formats_42)
values_43 = []
for r in rows:
    values_43.append(r[6] == 'Yes')
values_44 = []
for r in rows:
    values_44.append(r[8] == 'Yes')
print('SDI: intervals excluding 0:', sum(values_43), 'of', len(rows), '; sign changes with population weights:', sum(values_44))
add_notes(sheet, ['Contrasts are female-to-male ratios and female-minus-male differences in age-standardized DALY rates. Georgia was excluded because the SDI table lists two locations under that name.', 'Bootstrap intervals are percentile intervals from 5,000 resamples of countries; they treat country point estimates as fixed and do not include GBD estimation uncertainty or dependence between countries. Population-weighted correlations are weighted Spearman correlations with all-age population as weight.', 'Interval-width weights are the inverse squared width of the GBD uncertainty interval on the log scale; they are not inverse variances of the contrast and do not adjust for data quality. No p values are reported; these are ecological descriptions.', 'SDI, Socio-demographic Index.'])
finish_sheet(sheet)
wb.save(DEST)
values_45 = []
for w in wb.worksheets:
    values_45.append(w.title)
print('Wrote', DEST, values_45)
