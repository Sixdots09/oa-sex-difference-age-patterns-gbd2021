# Reading the code

Start with `run_all.sh`. It calls each numbered script in order. Run commands
from the repository root; file paths are relative to that directory.

- `R/setup.R` reads input files and checks their columns, values and expected labels.
  `check_records()` checks rows and intervals; `check_set()` checks allowed labels.
- `R/01_main_age_curves.R` turns annual female and male rates into age curves.
- `R/engine.R` contains the shared statistical rules. `fit_all()` fits the five
  models; `adjudicate()` compares them and applies the classification thresholds.
- Scripts 02-06 use those same functions for the main and sensitivity analyses.
- Script 07 reuses matrices that depend only on age. Each simulation still fits
  the same models and uses the same rules. It checks 30 curves against the
  reference implementation before running the four batches. `mclapply()` is the
  only parallel mapping call; it assigns independent scenarios to workers.
- Scripts 08-09 calculate the bounds and country summaries.
- Scripts 10-12 draw the figures. A failed export stops the run.
- `python/12_finalize_tiffs.py` writes lossless TIFFs with explicit dpi tags.
- `python/13_supplementary_tables.py` reads the result CSV files and fills the
  supplementary workbook. Simple functions share a dictionary containing the
  current worksheet, row and column widths. It does not fit statistical models.
- The two script 14 files record R and Python package versions.

A list stores several models, scenarios or tables. A data frame stores rows
and columns. In R, `do.call(rbind, rows)` joins a list of row tables. In Python,
`itertuples()` visits a data frame one row at a time. Statistical packages and
plotting libraries remain necessary; the rewrite changes code organization,
not their mathematical definitions.
