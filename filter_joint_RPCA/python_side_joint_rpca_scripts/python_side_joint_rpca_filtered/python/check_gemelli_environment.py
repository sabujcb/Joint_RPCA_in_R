#!/usr/bin/env python3
"""Check that the Python environment contains the packages needed for Gemelli."""

from __future__ import annotations

import importlib
import platform
import sys

packages = {
    "pandas": "pandas",
    "biom-format": "biom",
    "gemelli": "gemelli",
}

print("Python executable:", sys.executable)
print("Python version:", sys.version.replace("\n", " "))
print("Platform:", platform.platform())
print()

missing = []

for display_name, module_name in packages.items():
    try:
        module = importlib.import_module(module_name)
        version = getattr(module, "__version__", "version not reported")
        print(f"OK: {display_name} ({module_name}) - {version}")
    except ImportError:
        print(f"MISSING: {display_name} ({module_name})")
        missing.append(display_name)

if missing:
    print("\nInstall missing packages in the active environment, for example:")
    print("  conda install -c conda-forge gemelli biom-format pandas")
    raise SystemExit(1)

print("\nEnvironment check passed.")
