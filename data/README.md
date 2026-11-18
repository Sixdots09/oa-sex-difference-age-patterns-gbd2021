# Input data

The analysis uses 13 GBD estimate files and one prepared SDI table. They are **not distributed with this repository**: the IHME
Free-of-Charge Non-commercial User Agreement does not allow downloaded GBD files to be hosted by third parties. The 13 estimate files can be
obtained from the GBD Results tool (https://vizhub.healthdata.org/gbd-results/; registration required),
selecting the **GBD 2021** release. Estimates for the same years are revised between GBD rounds, so another release will
not reproduce the published numbers.

`input_files.csv` lists the files that were analysed, with record counts, sizes in bytes and SHA-256 checksums (the same
information as Additional file 2: Table S2, Part B).

## Where to put the files

Put the files in `data/raw/` (ignored by git), or in any other folder named by the environment variable `GBD_RAW_DIR`.
The scripts find each file through the `file_name` column of `input_files.csv`. Either give your files the names listed
there, or edit that column; the `key` column must not be changed. Then run `Rscript R/00_check_inputs.R`.

A newly downloaded file can contain the same estimates and still have a different checksum (row order, number formatting
or extra identifier columns), so a checksum difference is reported as a warning, not an error. The record checks inside
each analysis script apply in every case.

## Query specifications

The GBD 2021 query links and the SDI source link listed in Table S2 were provided in IHME's original download-notification emails. The specifications below document the GBD
identifiers and labels present in the analysed files. GBD identifiers are in parentheses. Causes: osteoarthritis (628),
osteoarthritis hip (1014), knee (1015), hand (1016), other (1017). Years: 1990–2021 in every query.

| Key(s) in `input_files.csv` | Measure | Metric | Cause | Location | Age | Sex | Records |
|---|---|---|---|---|---|---|---|
| `global_dalys_age_sex` | DALYs (2) | Number (1), Rate (3) | All five | Global (1) | 30–34 to 90–94 years (11–20, 30, 31, 32); ≥95 years (235) | Male (1), Female (2) | 8,960 |
| `global_overall_burden` | Prevalence (5), DALYs (2) | Number (1), Rate (3); age-standardized: Rate only | All five | Global (1) | 30–34 to ≥95 years (11–20, 30, 31, 32, 235); All ages (22); Age-standardized (27) | Male (1), Female (2), Both (3) | 29,760 |
| `age_sex_overall`, `age_sex_hip`, `age_sex_knee`, `age_sex_hand`, `age_sex_other` | DALYs (2), Prevalence (5), Incidence (6) | Number (1), Rate (3) | One per file | Global (1) | <5 to ≥95 years (1, 6–20, 30, 31, 32, 235) | Male (1), Female (2) | 7,680 per file |
| `country_overall`, `country_hip`, `country_knee`, `country_hand`, `country_other` | DALYs (2), Prevalence (5), Incidence (6) | All ages: Number (1), Rate (3); Age-standardized: Rate (3) | One per file | 204 countries and territories | All ages (22); Age-standardized (27) | Male (1), Female (2), Both (3) | 176,256 per file |
| `country_both_sexes_overall` | DALYs (2), Prevalence (5), Incidence (6) | All ages: Number (1), Rate (3); Age-standardized: Rate (3) | Osteoarthritis (628) | 204 countries and territories | All ages (22); Age-standardized (27) | Both (3) | 58,752 |
| `sdi` | Socio-demographic Index | – | – | All GBD locations in the SDI table | – | – | 23,552 |

Which analysis uses which file:

- `global_dalys_age_sex`: age curves and all model comparisons (scripts 01, 05);
- `global_overall_burden`: Table 1, EAPC and Figure 1 (scripts 04, 10);
- `age_sex_*`: prevalence-based bounds and DALYs per prevalent case (script 08);
- `country_*`, `country_both_sexes_overall` and `sdi`: country summaries and SDI correlations (script 09).

## Official GBD 2021 query links

Permanent links to GBD 2021 Results tool queries that retrieve the estimates (shown for overall osteoarthritis; Part F describes how the other categories and the analysed files were obtained), and to the GHDx page of the GBD 2021 Socio-demographic Index.

| Query or release page | Official link |
|---|---|
| Global age-specific estimates, both sexes (age.csv) | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/5c6a84d1ca9192130ba6f40a26d15cea |
| Global age-specific estimates by sex (age+sex.csv) | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/1ff2b8f37268f1361896b5fa61900373 |
| Global all-age and age-standardized estimates, both sexes (global.csv) | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/d4328e31b98cdf7bd65e5015e1f49f7f |
| Global all-age and age-standardized estimates by sex (sex.csv) | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/aae83a47ef9add1230138a0e942f8f3d |
| Country estimates, query 1 (also the both-sex country.csv input) | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/213322da94b0e51603de11f7dadfdef9 |
| Country estimates, query 2 | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/f17f6090ced284f8b009c6f7e5343fd3 |
| Country estimates, query 3 | https://gbd2021.healthdata.org/gbd-results?params=gbd-api-2021-permalink/6be068cc9b013ee0bd448c24da4472c5 |
| GHDx page of the GBD 2021 Socio-demographic Index (SDI), 1950–2021 | https://ghdx.healthdata.org/record/global-burden-disease-study-2021-gbd-2021-socio-demographic-index-sdi-1950%E2%80%932021 |

## Selection and preparation of the analysed inputs

Categories. Repeat the burden queries using the same options and change Cause to osteoarthritis (628), osteoarthritis hip (1014), osteoarthritis knee (1015), osteoarthritis hand (1016) or osteoarthritis other (1017).

Age-by-sex files. The age+sex query returns Female, Male and Both; only Female and Male records are retained in each category-specific age+sex file (7,680 records).

Main age-trajectory input. From the five category-specific age+sex files, retain DALYs, Number and Rate, Female and Male, and ages 30–34 through ≥95 years. Concatenate the five categories to obtain the 8,960 records of INFLECTION_CI__OA_and_4subOAs_sex_age_adjust.csv; the model-fitting exclusions are given in Part C.

Global burden and EAPC input. Combine age.csv, age+sex.csv, global.csv and sex.csv for all five categories. Retain prevalence and DALYs; ages ≥30 years, All ages and Age-standardized; Number and Rate for age-specific and all-age records; and Rate for age-standardized records. Retain Female, Male and Both as appropriate to these queries. This gives the 29,760 records of EAPC_TOTAL__sex_differeces_final_prevalece_DALYS.csv. Keep the analysis columns for measure, location, sex, age, cause, metric, year, val, lower and upper.

Country inputs. For each category, combine country queries 1–3, matching the sex and other filters to Part A, and check record keys for duplicates and completeness (176,256 records). Query 1 also supplies the overall-osteoarthritis both-sex country.csv input (58,752 records) used to derive population weights.

SDI preparation. The GBD 2021 SDI table (GHDx page in Part E) was reshaped from a wide layout (736 locations, one column per year from 1990 to 2021) to 23,552 location-year records; the conversion script is included with the analysis code.

Comparison of exports. Match records on measure, location, sex, age, cause, metric and year, then compare val, lower and upper. Applied to the category-specific files, the steps above reproduce the record keys of the analysed files, and where values could be compared they agree to within one part in 100 million (differences in stored decimal places).

## File format

GBD files are comma-separated exports of the GBD Results tool with one estimate per row. The scripts need the columns
measure, location, sex, age, cause, metric, year, val, upper and lower. Column names with or without the `_name` suffix
are accepted (`measure_name` or `measure`), and `*_id` columns are ignored.

The SDI analysis input is a long table with three columns: `location`, `year` and `SDI`.
It is prepared from a separate wide table, not a GBD Results burden query.

## SDI source and conversion

Release page: [GBD 2021 Socio-demographic Index, 1950–2021](https://ghdx.healthdata.org/record/global-burden-disease-study-2021-gbd-2021-socio-demographic-index-sdi-1950%E2%80%932021).

The archived wide file is `GBD2021_SHARED__GBD_SDI_1990-2021.csv`:

- 736 rows; columns `Location`, `1990`, ..., `2021`.
- 289,271 bytes; SHA-256 `15d51651d00dcb9f7b177c886615da2b8eff345ebf10709648d93e3895f45631`.
- The archived file is readable as GB18030. The conversion retains all location
  names, including duplicate names, and every 1990-2021 value.

Run the following on a separately obtained copy of that source file:

```bash
python3 python/prepare_sdi.py /path/to/GBD2021_SHARED__GBD_SDI_1990-2021.csv data/raw/GBD2021_OA__SDI1990-2021modified.csv gb18030
```

This writes 23,552 rows in UTF-8. Row order and encoding can differ from the
archived long file, so byte hashes can differ even when names, years and SDI
values match. The conversion was checked against all archived long-table rows.
Use `utf-8-sig` instead of `gb18030` for an equivalent UTF-8 source.

## Location names

Country-level estimates and the SDI table name 19 locations differently (for example "Czech Republic" and "Czechia").
They are matched by an explicit list in `R/09_country_sdi.R` (also given in Additional file 2: Table S2, Part D); no fuzzy
matching is used. Georgia is excluded from the SDI correlations because the SDI table lists two locations under that name.
