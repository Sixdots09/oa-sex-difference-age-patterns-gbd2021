# Append the Python environment to the run record.
import platform
from importlib.metadata import version

with open("outputs/session_info.txt", "a", encoding="utf-8") as record:
    record.write("\nPython " + platform.python_version() + "\n")
    for package in ["pandas", "numpy", "openpyxl", "Pillow"]:
        record.write(package + " " + version(package) + "\n")
print("Wrote outputs/session_info.txt")
