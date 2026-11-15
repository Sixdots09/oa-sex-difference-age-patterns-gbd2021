# Compare result CSV files with a separate reference outputs folder.
# Usage: python3 tests/compare_outputs.py /path/to/reference/outputs
import csv
import math
from pathlib import Path
import sys

if len(sys.argv) != 2:
    sys.exit("Provide a reference outputs directory.")
reference_root = Path(sys.argv[1])
current_root = Path("outputs")
reference_files = sorted(reference_root.rglob("*.csv"))
if len(reference_files) != 25:
    sys.exit("Expected 25 reference CSV files.")
failures = []
maximum_difference = 0.0
compared_cells = 0
changed_tie_cells = 0
exact_columns = ["boundary", "exact", "within5", "n_folds", "reps", "n_C", "n_n", "n_q",
                 "n_loc", "n_C_loc", "true_changepoint", "simulated_curves",
                 "constant_ratio_best_age", "candidate_changepoint_age"]
for reference_path in reference_files:
    relative_path = reference_path.relative_to(reference_root)
    current_path = current_root / relative_path
    with reference_path.open(encoding="utf-8", newline="") as source:
        reference_reader = csv.DictReader(source)
        reference_columns = reference_reader.fieldnames
        reference_rows = list(reference_reader)
    with current_path.open(encoding="utf-8", newline="") as source:
        current_reader = csv.DictReader(source)
        current_columns = current_reader.fieldnames
        current_rows = list(current_reader)
    if reference_columns != current_columns or len(reference_rows) != len(current_rows):
        failures.append(str(relative_path) + ": columns or row count differ")
        continue
    for index in range(len(reference_rows)):
        for column in reference_columns:
            previous = reference_rows[index][column]
            current = current_rows[index][column]
            compared_cells += 1
            if column == "age_max_leverage":
                previous_ages = []
                current_ages = []
                for value in previous.split(";"):
                    previous_ages.append(float(value))
                for value in current.split(";"):
                    current_ages.append(float(value))
                if not set(previous_ages).issubset(set(current_ages)):
                    failures.append(f"{relative_path}, row {index + 1}: old leverage maximum missing")
                if previous_ages != current_ages:
                    changed_tie_cells += 1
                continue
            if previous == current:
                continue
            try:
                old_number = float(previous)
                new_number = float(current)
            except ValueError:
                failures.append(f"{relative_path}, row {index + 1}, {column}: text differs")
                continue
            difference = abs(old_number - new_number)
            maximum_difference = max(maximum_difference, difference)
            same = math.isclose(old_number, new_number, rel_tol=1e-10, abs_tol=1e-10)
            if column in exact_columns:
                same = old_number == new_number
            if not same:
                failures.append(f"{relative_path}, row {index + 1}, {column}: values differ")
print("Compared", len(reference_files), "CSV files and", compared_cells, "cells.")
print("Maximum absolute numerical difference:", maximum_difference)
print("Leverage cells expanded to include tied ages:", changed_tie_cells)
if failures:
    for failure in failures:
        print(failure)
    sys.exit(1)
print("PASS: classifications, selected ages and simulation counts unchanged.")
print("Other numbers agree within atol=1e-10 and rtol=1e-10.")
