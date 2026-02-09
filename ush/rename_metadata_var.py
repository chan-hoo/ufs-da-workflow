#!/usr/bin/env python3

###################################################################### CHJ #####
## Name		  : rename_metadata_var.py
## Usage	  : Rename variable of MetaData in NetCDF
##            : rename_metadata_var.py -i input -o output -v old_var -n new_var
## NOAA/EPIC
## History ===============================
## V000: 2026/02/09: Chan-Hoo Jeon : Preliminary version
###################################################################### CHJ #####

import argparse
from netCDF4 import Dataset
import sys


def copy_variable(src_var, dst_grp, out_name):
    """
    Copy a NetCDF variable, handling _FillValue correctly.
    """

    # _FillValue MUST be set at creation time
    fill_value = None
    if "_FillValue" in src_var.ncattrs():
        fill_value = src_var.getncattr("_FillValue")

    dst_var = dst_grp.createVariable(
        out_name,
        src_var.datatype,
        src_var.dimensions,
        fill_value=fill_value
    )

    # Copy variable attributes EXCEPT _FillValue
    for attr in src_var.ncattrs():
        if attr == "_FillValue":
            continue
        dst_var.setncattr(attr, src_var.getncattr(attr))

    # Copy data
    dst_var[:] = src_var[:]

    return dst_var


def copy_group(src_grp, dst_grp, old_name=None, new_name=None):
    """
    Recursively copy a NetCDF group.
    Optionally rename one variable.
    """

    # Copy group attributes
    for attr in src_grp.ncattrs():
        dst_grp.setncattr(attr, src_grp.getncattr(attr))

    # Copy dimensions
    for dname, dim in src_grp.dimensions.items():
        dst_grp.createDimension(
            dname,
            None if dim.isunlimited() else len(dim)
        )

    # Copy variables
    for vname, var in src_grp.variables.items():

        out_name = new_name if (old_name and vname == old_name) else vname

        if out_name in dst_grp.variables:
            raise RuntimeError(
                f"Variable '{out_name}' already exists in destination group"
            )

        copy_variable(var, dst_grp, out_name)

    # Recurse into subgroups
    for gname, subgrp in src_grp.groups.items():
        dst_subgrp = dst_grp.createGroup(gname)
        copy_group(subgrp, dst_subgrp, old_name, new_name)


def rename_metadata_var_copy(src_file, dst_file, old_name, new_name):
    """
    Safely rename a variable in the MetaData group by copying the file.
    """

    with Dataset(src_file, "r") as src, Dataset(dst_file, "w") as dst:

        # Copy global attributes
        for attr in src.ncattrs():
            dst.setncattr(attr, src.getncattr(attr))

        # Copy root dimensions
        for dname, dim in src.dimensions.items():
            dst.createDimension(
                dname,
                None if dim.isunlimited() else len(dim)
            )

        # Copy root variables
        for vname, var in src.variables.items():
            copy_variable(var, dst, vname)

        # Copy groups
        for gname, grp in src.groups.items():

            dst_grp = dst.createGroup(gname)

            if gname == "MetaData":
                if old_name not in grp.variables:
                    raise KeyError(
                        f"Variable '{old_name}' not found in MetaData group"
                    )
                if new_name in grp.variables:
                    raise KeyError(
                        f"Variable '{new_name}' already exists in MetaData group"
                    )

                copy_group(grp, dst_grp, old_name, new_name)
            else:
                copy_group(grp, dst_grp)


def main():
    parser = argparse.ArgumentParser(
        description="Safely rename a variable in MetaData by copying NetCDF file"
    )
    parser.add_argument(
        "-i", "--input", required=True,
        help="Input NetCDF file (read-only)"
    )
    parser.add_argument(
        "-o", "--output", required=True,
        help="Output NetCDF file"
    )
    parser.add_argument(
        "-v", "--var", required=True,
        help="Existing MetaData variable name"
    )
    parser.add_argument(
        "-n", "--new", required=True,
        help="New variable name"
    )

    args = parser.parse_args()

    try:
        rename_metadata_var_copy(
            args.input,
            args.output,
            args.var,
            args.new
        )
    except Exception as e:
        print(f"FATAL ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    print(
        "Renamed MetaData variable by copy:\n"
        f"  {args.var} -> {args.new}\n"
        f"  {args.input}  ->  {args.output}"
    )


# Main call ========================================================= CHJ =====
if __name__=='__main__':
    main()
