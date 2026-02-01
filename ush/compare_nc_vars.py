#!/usr/bin/env python3

###################################################################### CHJ #####
## Name       : compare_nc_vars.py
## Usage      : Compare two variables in a NetCDF file
## NOAA/EPIC
## History ===============================
## V000: 2026/02/02: Chan-Hoo Jeon : Preliminary version
###################################################################### CHJ #####

import sys
from netCDF4 import Dataset
import numpy as np

def usage():
    print("Usage: compare_nc_vars.py <netcdf_file> <var1> <var2> <tile_number>")
    sys.exit(1)

if len(sys.argv) != 5:
    usage()

ncfile = sys.argv[1]
var1_name = sys.argv[2]
var2_name = sys.argv[3]
tile_num = sys.argv[4]

with Dataset(ncfile, "r") as ds:
    if var1_name not in ds.variables:
        raise KeyError(f'''FATAL ERROR: Variable '{var1_name}' not found''')
    if var2_name not in ds.variables:
        raise KeyError(f'''FATAL ERROR: Variable '{var2_name}' not found''')

    v1 = ds.variables[var1_name]
    v2 = ds.variables[var2_name]

    # Metadata checks
    if v1.shape != v2.shape:
        raise ValueError("Shapes differ")
    if v1.dtype != v2.dtype:
        raise ValueError("Data types differ")
    if v1.dimensions != v2.dimensions:
        raise ValueError("Dimensions differ")

    # Load data
    a = v1[:]
    b = v2[:]

    # Handle missing values
    mv1 = getattr(v1, "missing_value", None)
    mv2 = getattr(v2, "missing_value", None)

    if mv1 is not None:
        a = np.where(a == mv1, np.nan, a)
    if mv2 is not None:
        b = np.where(b == mv2, np.nan, b)

    # Bit-to-bit comparison
    identical = np.array_equal(a, b, equal_nan=True)

    if identical:
        print(f'''PASS:: Tile {tile_num}: {var1_name} and {var2_name} are bit-to-bit identical''')
        sys.exit(0)
    else:
        print(f'''FATAL ERROR:: Tile {tile_num}: {var1_name} and {var2_name} differ''')

        # Diagnostics
        diff = np.where(a != b)
        n = diff[0].size
        print(f"Number of differing points: {n}")
        if n > 0:
            idx = tuple(d[0] for d in diff)
            print("First difference index:", idx)
            print("Values:", a[idx], b[idx])

        sys.exit(2)
