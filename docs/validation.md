# Release validation, 2026-11-15

The readable-code release was checked against the original R1 repository outputs.
The original package and manuscript files were not modified.

## Runs performed

1. The 14 archived inputs matched the recorded sizes and SHA-256 values.
2. `Rscript R/07_simulation.R 4` reran all four batches: 120 scenario-curve
   combinations with 35, 65, 40 and 60 replicates (24,000 curves in total).
   The accelerated implementation first agreed with the reference implementation
   on the 30 fixed validation curves. All simulation GAM convergence checks passed.
3. `SKIP_SIMULATION=1 bash run_all.sh` ran the remaining pipeline and pooled the
   newly calculated batches. All model fits, diagnostics, bounds, bootstrap
   intervals, five PDFs and the supplementary workbook were regenerated.
4. The TIFF finalization step was also executed after adding it to the runner.
   It uses lossless LZW compression and explicit resolution tags. Figure 1 is
   8196 x 10946 pixels at 1200 dpi; Figures 2 and 3 are 5464 x 7181 at 800 dpi.
5. The final R and Python environments were recorded in `outputs/session_info.txt`.

## Numerical comparison

`tests/compare_outputs.py` compared 25 CSV files containing 33,599 cells.

- All 720 classification rows matched, including their selected changepoint ages.
- Every simulation count in all four batches matched exactly.
- All other numeric cells passed `atol=1e-10, rtol=1e-10`.
- The largest observed absolute difference was `1.0231815394945443e-12`.
- Forty diagnostic rows now list both tied maximum-leverage endpoint ages.
  Every originally reported maximum is included. This reporting change does
  not enter fitting, model comparison, cross-validation or simulation.

## Other checks

- Eight malformed-input tests rejected wrong years, location and measure,
  inverted intervals, duplicate rows, missing/non-finite values and missing columns.
- Cairo was unavailable on the validation machine. The fallback actually created
  PDF and TIFF files. A deliberately failing drawing raised an error and preserved
  the existing PDF; it did not report a successful export.
- All five generated PDFs and the changed supplementary-table views were visually
  inspected. Font rendering differs from the original Linux output; plotted
  estimates, labels and model classifications were retained.
- The supplementary workbook contains ten sheets. Table S5 lists tied ages and
  explains the tolerance; Table S2 states the SDI source-record limitation.
- The SDI preparation script reproduced all 23,552 archived location-year-value
  rows exactly after sorting. It retains duplicate location names.
- No downloaded input file, personal path, credential or local run log is included
  in the publication file set. TIFFs are generated locally and excluded from Git.

## Limits

This was a full local computational validation on archived inputs, not a new
scientific analysis or proof of independent acquisition of all inputs. The
original official SDI download record has not been recovered; the official
release-to-local-wide-table link remains unverified. No substitute SDI data were
introduced. See `data/README.md` and `DATA_TERMS.md`.

PDF and workbook metadata and floating-point tails need not be byte-identical
across environments. The original article figure styling is not a cross-platform
pixel-identity guarantee.
