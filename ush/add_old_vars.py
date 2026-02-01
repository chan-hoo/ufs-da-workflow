#!/usr/bin/env python3

###################################################################### CHJ #####
## Name       : add_old_vars.py
## Usage      : Copy some variables and rename them to old variables
## NOAA/EPIC
## History ===============================
## V000: 2026/02/02: Chan-Hoo Jeon : Preliminary version
###################################################################### CHJ #####

import os
import sys
import logging
import yaml
from netCDF4 import Dataset


# Main part (will be called at the end) ============================= CHJ =====
def main():

    yaml_file = "add_old_vars.yaml"
    with open(yaml_file, 'r') as f:
        yaml_data = yaml.load(f, Loader=yaml.FullLoader)
    f.close()

    # file type: fcst_ic or restart
    file_type = yaml_data['file_type']
    num_tiles = yaml_data['num_tiles']
    PY_LOG_LEVEL = yaml_data['PY_LOG_LEVEL']
    sfc_data_fn_prefix = yaml_data['sfc_data_fn_prefix']
    sfc_data_fn_suffix = yaml_data['sfc_data_fn_suffix']
    work_dir = yaml_data['work_dir']

    # Set logging config
    log_level_str = PY_LOG_LEVEL.upper()
    try:
        log_level = getattr(logging, log_level_str)
    except AttributeError:
        log_level_str = "INFO"
        log_level = logging.INFO
        print(f''' WARNING: Invalid log level "{PY_LOG_LEVEL.upper()}", set to INFO.''')
    print(f''' Python Log Level= str: {log_level_str}, attr: {log_level}''')
    logging.basicConfig(format='%(levelname)s::%(pathname)s::L%(lineno)d::%(message)s', level=log_level)
    logging.info(f''' YAML Data: {yaml_data}''')

    for it in range(num_tiles):
        itp = it+1
        # Input file name
        sfc_data_fn = f'''{sfc_data_fn_prefix}{itp}{sfc_data_fn_suffix}'''
        # Path to input files
        sfc_data_fp = os.path.join(work_dir, sfc_data_fn)
        with Dataset(sfc_data_fp, mode="r+") as ds:
            copy_map = {
                "weasdl": ("sheleg", "sheleg"),
                "snodl": ("snwdph", "snwdph"),
                "zorli": ("zorl", "zorl")
            }
            for src_name, (dst_name, new_long_name) in copy_map.items():
                if src_name not in ds.variables:
                    raise KeyError(f"Variable '{src_name}' not found") 
                src_var = ds.variables[src_name]
                # Create destination variable if needed
                if dst_name not in ds.variables:
                    dst_var = ds.createVariable(
                        dst_name,
                        src_var.dtype,
                        src_var.dimensions,
                        fill_value=getattr(src_var, "missing_value", None)
                    )
                    # Copy all attributes
                    for attr in src_var.ncattrs():
                        dst_var.setncattr(attr, src_var.getncattr(attr))
                else:
                    dst_var = ds.variables[dst_name]
                # Copy data
                dst_var[:] = src_var[:]
                # Override long_name
                dst_var.long_name = new_long_name
    logging.info(f''' The variables have been copied successfully.''')


# Main call ========================================================= CHJ =====
if __name__=='__main__':
    main()
