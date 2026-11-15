# Convert an archived SDI wide table to the long analysis format.
# Usage: python3 python/prepare_sdi.py input.csv output.csv [encoding]
import csv
import os
import sys

if len(sys.argv) not in [3, 4]:
    sys.exit("Usage: prepare_sdi.py input.csv output.csv [encoding]")
source_path = sys.argv[1]
output_path = sys.argv[2]
encoding = "utf-8-sig"
if len(sys.argv) == 4:
    encoding = sys.argv[3]
if os.path.abspath(source_path) == os.path.abspath(output_path):
    sys.exit("Input and output must be different files.")

with open(source_path, encoding=encoding, newline="") as source:
    reader = csv.DictReader(source)
    required_columns = ["Location"]
    for year in range(1990, 2022):
        required_columns.append(str(year))
    if reader.fieldnames != required_columns:
        sys.exit("Expected Location and 32 year columns, 1990 through 2021.")
    locations = list(reader)
if len(locations) != 736:
    sys.exit("The archived source has 736 rows; verify a different source before use.")

rows = []
for year in range(1990, 2022):
    for location in locations:
        value = location[str(year)]
        if not 0 < float(value) <= 1:
            sys.exit("Invalid SDI value.")
        rows.append([location["Location"], year, value])
parent = os.path.dirname(os.path.abspath(output_path))
os.makedirs(parent, exist_ok=True)
with open(output_path, "w", encoding="utf-8", newline="") as output:
    writer = csv.writer(output)
    writer.writerow(["location", "year", "SDI"])
    writer.writerows(rows)
print("Wrote", len(rows), "rows. Duplicate location names are retained.")
