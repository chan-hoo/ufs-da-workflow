#!/usr/bin/env python3

###################################################################### CHJ #####
#
# Setting up workflow environemnt
#
###################################################################### CHJ #####

import argparse
import logging
import os
import sys
import socket
import shutil
import yaml
import math
from datetime import datetime, timedelta
from pathlib import Path

dirpath = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(dirpath, '../ush'))

from fill_jinja_template import fill_jinja_template
from uwtools.api.rocoto import realize


# Main part (will be called at the end) ============================= CHJ =====
def setup_wflow_env(machine):
# =================================================================== CHJ =====

    machine = machine.lower()
    logging.debug(f''' Machine (platform) name: {machine} ''')
    # Set directory paths
    parm_dir = os.getcwd()
    logging.info(f''' Current directory (PARMdir): {parm_dir} ''')
    home_dir = os.path.dirname(parm_dir)
    logging.info(f''' Home directory (HOMEdir): {home_dir} ''')
    exp_basedir = os.path.dirname(home_dir)
    logging.info(f''' Experimental base directory (exp_basedir): {exp_basedir} ''')

    # Check whether exec dir is empty
    exec_dir = os.path.join(home_dir, 'exec')
    exec_path = Path(exec_dir)
    fix_dir = os.path.join(home_dir, 'fix')
    fix_path = Path(fix_dir)
    if not exec_path.exists():
        logging.error(f''' exec directory "{exec_path}" does NOT exist. You might skip the build step !!!''')
        sys.exit(1)        
    else:
        visible_files = [p for p in fix_path.iterdir() if not p.name.startswith(".")]
        if not visible_files:
            logging.error(f''' fix directory "{fix_path}" is EMPTY. Please check the link in the build script !!!''')
            sys.exit(1)

    # Set default values of input parameters
    config_parm = set_default_parm()

    # Set machine-specific parameters
    machine_config = set_machine_parm(machine)

    # Merge default and machine-specific parameters
    config_parm.update(machine_config)

    # Add extra parameters
    config_parm["exp_basedir"] = exp_basedir
    config_parm["MACHINE"] = machine
    config_parm["res_p1"] = int(config_parm.get("RES")) + 1

    # Read input YAML file
    yaml_file = "config.yaml"
    try:
        with open(yaml_file, 'r') as f:
            yaml_data = yaml.safe_load(f)
        f.close()
        logging.debug(f''' Input YAML file:, {yaml_data} ''')
    except FileNotFoundError:
        logging.error(f''' FATAL ERROR: Input YAML file {yaml_file} does not exist! ''')

    for key,value in yaml_data.items():
        if key in config_parm:
            config_parm[key] = value

    # Create an experimental case directory
    if config_parm.get("EXP_CASE_NAME") is None:
        exp_case_name = f'''{config_parm.get("APP")}_{config_parm.get("RUN")}'''
        config_parm.update({'EXP_CASE_NAME': exp_case_name})
    else:
        exp_case_name = config_parm.get("EXP_CASE_NAME")

    # Path to experimenal case
    exp_case_path = os.path.join(exp_basedir, "exp_case", exp_case_name) 

    # Calculate date for the second cycle
    date_first_cycle = config_parm.get("DATE_FIRST_CYCLE")
    date_last_cycle = config_parm.get("DATE_LAST_CYCLE")
    date_cycle_freq_hr = config_parm.get("DATE_CYCLE_FREQ_HR")
    if date_first_cycle == date_last_cycle:
        date_second_cycle = None
    else:
        next_date = datetime.strptime(str(date_first_cycle), "%Y%m%d%H") + timedelta(hours=date_cycle_freq_hr)
        date_second_cycle = next_date.strftime("%Y%m%d%H")

    app = config_parm.get("APP")
    # Set model components
    if app == "S2SWA":
        atm_model = "fv3"
        ocn_model = "mom6"
        ice_model = "cice6"
        wav_model = "ww3"
    elif app == "NG-GODAS":
        atm_model = "datm"
        ocn_model = "mom6"
        ice_model = "cice6"
        wav_model = ""
    else:
        atm_model = ""
        ocn_model = ""
        ice_model = ""
        wav_model = ""

    # Set DATM domain size
    datm_data_type = config_parm.get("DATM_DATA_TYPE")
    if datm_data_type == "gfs":
        datm_nx_global = 3072
        datm_ny_global = 1536
    elif datm_data_type == "gefs":
        datm_nx_global = 1536
        datm_ny_global = 768
    elif datm_data_type == "cfsr":
        datm_nx_global = 1760
        datm_ny_global = 880

    # Calculate HPC parameter values
    atm_layout_x = config_parm.get("ATM_LAYOUT_X")
    atm_layout_y = config_parm.get("ATM_LAYOUT_Y")
    atm_io_layout_x = config_parm.get("ATM_IO_LAYOUT_X")
    atm_io_layout_y = config_parm.get("ATM_IO_LAYOUT_Y")
    max_cores_per_node = config_parm.get("MAX_CORES_PER_NODE")
    nprocs_datm = config_parm.get("NPROCS_DATM")
    nprocs_ice = config_parm.get("NPROCS_ICE")
    nprocs_ocn = config_parm.get("NPROCS_OCN")   
    nprocs_wav = config_parm.get("NPROCS_WAV")

    if app == "S2SWA":
        nprocs_forecast_med = 6*(atm_layout_x*atm_layout_y)
        nprocs_forecast_atm = nprocs_forecast_med + 6*(atm_io_layout_x*atm_io_layout_y)
        nprocs_forecast = nprocs_forecast_atm + nprocs_ocn + nprocs_ice + nprocs_wav
    elif app == "NG-GODAS":
        nprocs_forecast_atm = nprocs_datm
        nprocs_forecast_med = nprocs_forecast_atm
        nprocs_forecast = nprocs_forecast_atm + nprocs_ocn + nprocs_ice

    if nprocs_forecast <= max_cores_per_node:
        nnodes_forecast = 1
        nprocs_per_node = nprocs_forecast
    else:
        nnodes_forecast = math.ceil(nprocs_forecast/max_cores_per_node)
        nprocs_per_node = math.ceil(nprocs_forecast/nnodes_forecast)

    # Machine-specific parameters
    if machine == "gaeac6":
        native_default = '-M c6'
        partition_default = 'batch'
        queue_default = 'normal'
    elif machine == "ursa":
        native_default = None
        partition_default = 'u1-compute'
        queue_default = 'batch'
    else:
        native_default = None
        partition_default = machine
        queue_default = 'batch'

    # Slurm memory flag: some platforms do not support the memory flag in slurm
    mem_not_req = [ "gaeac6" ]
    if machine in mem_not_req:
        memory_flag = False
    else:
        memory_flag = True

    # Check lowercase/uppercase
    datm_data_type_orig = config_parm.get("DATM_DATA_TYPE")
    datm_data_type = datm_data_type_orig.lower()
    do_free_forecast_orig = config_parm.get("DO_FREE_FORECAST")
    do_free_forecast_options = ["first", "all", "none", "ctest"]
    err_msg = f''' FATAL ERROR: NOT available 'DO_FREE_FORECAST': {do_free_forecast_orig}, options = {do_free_forecast_options} !!!'''
    if isinstance(do_free_forecast_orig, bool):
        logging.error(err_msg)
        sys.exit(1)
    elif not do_free_forecast_orig.islower():
        do_free_forecast = do_free_forecast_orig.lower()
        logging.info(f''' 'DO_FREE_FORECAST: {do_free_forecast_orig}': converted to lowercase! ''')
    else:
        do_free_forecast = do_free_forecast_orig

    if do_free_forecast not in do_free_forecast_options:
        logging.error(err_msg)
        sys.exit(1)

    # Check for unsupported conditions
    obs_ghcn_snow = config_parm.get("OBS_GHCN_SNOW")
    obs_ims_snow = config_parm.get("OBS_IMS_SNOW")
    obs_sfcsno = config_parm.get("OBS_SFCSNO")
    obs_smap = config_parm.get("OBS_SMAP")
    obs_smops = config_parm.get("OBS_SMOPS")
    if obs_ghcn_snow == "YES" and obs_ims_snow == "YES":
        logging.error("FATAL ERROR: Both OBS_GHCN_SNOW and OBS_IMS_SNOW are selected, but this is not supported by JCB!!!", exc_info=True)
        sys.exit(1)
    elif obs_smap == "YES" and obs_smops == "YES":
        logging.error("FATAL ERROR: Both OBS_SMAP and OBS_SMOPS are selected, but this is not supported!!!", exc_info=True)
        sys.exit(1)

    # Set list of JEDI analyses from JEDI types and observations
    jedi_type_snow = config_parm.get("JEDI_TYPE_SNOW")
    jedi_type_soca = config_parm.get("JEDI_TYPE_SOCA")
    jedi_type_soil_moisture = config_parm.get("JEDI_TYPE_SOIL_MOISTURE")

    list_jedi_land = ""
    if jedi_type_snow == "YES":
        if not list_jedi_land:
            list_jedi_land = "snow"
        else:
            list_jedi_land = f"{list_jedi_land} snow"
    
    if jedi_type_soil_moisture == "YES":
        if not list_jedi_land:
            list_jedi_land = "soil_moisture"
        else:
            list_jedi_land = f"{list_jedi_land} soil_moisture"

    if do_free_forecast == "none":
        if jedi_type_snow == "NO" and jedi_type_soil_moisture == "NO" and jedi_type_soca == "NO":
            logging.error(f'''FATAL ERROR: All JEDI_TYPE flags are off. Please check the flags for JEDI_TYPE.''')
            sys.exit(1)

        if jedi_type_snow == "YES" and \
           (obs_ghcn_snow == "NO" and obs_ims_snow == "NO" and obs_sfcsno == "NO"):
            logging.error(f'''FATAL ERROR: JEDI_TYPE_SNOW = "YES", but all snow observation options are off !!!''')
            sys.exit(1)
        elif jedi_type_snow == "NO" and \
           (obs_ghcn_snow == "YES" or obs_ims_snow == "YES" or obs_sfcsno == "YES"):
            logging.error(f'''FATAL ERROR: JEDI_TYPE_SNOW = "NO", but snow observations are on: GHCN ({obs_ghcn_snow}), IMS (${obs_ims_snow}), SFCSNO (${obs_sfcsno}) !!!''')
            sys.exit(1)
    
        if jedi_type_soil_moisture == "YES" and (obs_smap == "NO" and obs_smops == "NO"):
            logging.error(f'''FATAL ERROR: JEDI_TYPE_SOIL_MOISTURE = "YES", but all soil moisture observation options are off !!!''')
            sys.exit(1)
        elif jedi_type_soil_moisture == "NO" and (obs_smap == "YES" or obs_smops == "YES"):
            logging.error(f'''FATAL ERROR: JEDI_TYPE_SOIL_MOISTURE = "NO", but soil moisture observations are on: SMAP ({obs_smap}) and SMOPS ({obs_smops})!!!''')
            sys.exit(1)

    # Set machine-dependent paths if not specified in config.yaml
    jedi_bin_path = config_parm.get("JEDI_BIN_PATH")
    if jedi_bin_path is None:
        jedi_bin_path = os.path.join(exp_basedir, "jedi", "build", "bin")

    jedi_iodaconv_path = config_parm.get("JEDI_IODACONV_PATH")
    jedi_py_ver = config_parm.get("JEDI_PY_VER")
    if jedi_iodaconv_path is None:
        jedi_iodaconv_path = os.path.join(jedi_bin_path, "../lib", jedi_py_ver)

    custom_jedi_config_path = config_parm.get("CUSTOM_JEDI_CONFIG_PATH")
    if custom_jedi_config_path is None:
        custom_jedi_config_path = os.path.join(fix_dir, "DATA_jedi", "custom_yaml")

    warmstart_dir = config_parm.get("WARMSTART_DIR")
    if warmstart_dir is None:
        warmstart_dir = os.path.join(fix_dir, "DATA_restart")

    # Set PTMP: PTMP/envir = OPSROOT for NOAA NCO EE2 compliance
    ptmp = config_parm.get("PTMP")
    if ptmp is None:
        ptmp = os.path.join(exp_basedir, "ptmp")

    # Set undefined parameter values
    ## MOM6
    mom6_dt_therm = config_parm.get("MOM6_DT_THERM")
    if mom6_dt_therm is None:
        dt_mom6 = config_parm.get("DT_MOM6")
        mom6_dt_therm = 2*dt_mom6
    ## OUTPUT_FH_CICE: output frequency of CICE
    output_fh = config_parm.get("OUTPUT_FH")
    output_fh_list = list(map(int, output_fh.split()))
    output_fh_cice = config_parm.get("OUTPUT_FH_CICE")
    if output_fh_cice is None:
        if output_fh_list[1] == -1:
            output_fh_cice = output_fh_list[0]
        else:
            output_fh_cice = 6
            logging.warning(f''' OUTPUT_FH_CICE is not specified in config.yaml and OUTPU_FH[1] != -1; OUTPUT_FH_CICE is set to "{output_fh_cice}" by default.''')

    ## OUTPUT_FH_MOM6: output frequency of MOM6
    output_fh_mom6 = config_parm.get("OUTPUT_FH_MOM6")
    if output_fh_mom6 is None:
        if output_fh_list[1] == -1:
            if output_fh_list[0] % 2 == 0:
                output_fh_mom6 = output_fh_list[0]
            else:
                output_fh_mom6 = 6
                logging.warning(f''' OUTPUT_FH_MOM6 is not specified in config.yaml and OUTPU_FH[0] is not an even number; OUTPUT_FH_MOM6 is set to "{output_fh_mom6}" by default.''')
        else:
            output_fh_mom6 = 6
            logging.warning(f''' OUTPUT_FH_MOM6 is not specified in config.yaml and OUTPU_FH[1] != -1; OUTPUT_FH_MOM6 is set to "{output_fh_mom6}" by default.''')
    else:
        if output_fh_mom6 % 2 != 0:
            logging.error(f''' FATAL ERROR: OUTPUT_FH_MOM6 is set to "{output_fh_mom6}" in config.yaml, but it is not an even number.''')
            sys.exit(1)

    ## OUTPUT_FH_WW3: output frequency of WW3 ("in hours"), note that this will be converted to seconds in script
    output_fh_ww3 = config_parm.get("OUTPUT_FH_WW3")
    if output_fh_ww3 is None:
        if output_fh_list[1] == -1:
            output_fh_ww3 = output_fh_list[0]
        else:
            output_fh_ww3 = 6
            logging.warning(f''' OUTPUT_FH_WW3 is not specified in config.yaml and OUTPU_FH[1] != -1; OUTPUT_FH_WW3 is set to "{output_fh_ww3} hours" by default.''')

    ## ALLCOMP_RESTART_N: output frequency of mediator (CMEPS) restart files
    restart_interval = config_parm.get("RESTART_INTERVAL")
    restart_interval_list = list(map(int, restart_interval.split()))
    allcomp_restart_n = config_parm.get("ALLCOMP_RESTART_N")
    if allcomp_restart_n is None:
        if restart_interval_list[1] == -1:
            allcomp_restart_n = restart_interval_list[0]
        else:
            allcomp_restart_n = 12
            logging.warning(f''' ALLCOMP_RESTART_N is not specified in config.yaml and RESTART_INTERVAL[1] != -1; ALLCOMP_RESTART_N is set to "{allcomp_restart_n}" by default.''')

    # Update config yaml file
    config_parm.update({
        'ALLCOMP_RESTART_N': allcomp_restart_n,
        'atm_model': atm_model,
        'CUSTOM_JEDI_CONFIG_PATH': custom_jedi_config_path,
        'date_second_cycle': date_second_cycle,
        'DATM_DATA_TYPE': datm_data_type,
        'datm_nx_global': datm_nx_global,
        'datm_ny_global': datm_ny_global,
        'DO_FREE_FORECAST': do_free_forecast,
        'exp_case_path': exp_case_path,
        'ice_model': ice_model,
        'JEDI_BIN_PATH': jedi_bin_path,
        'JEDI_IODACONV_PATH': jedi_iodaconv_path,
        'list_jedi_land': list_jedi_land,
        'memory_flag': memory_flag,
        'MOM6_DT_THERM': mom6_dt_therm,
        'native_default': native_default,
        'nnodes_forecast': nnodes_forecast,
        'nprocs_forecast': nprocs_forecast,
        'nprocs_forecast_atm': nprocs_forecast_atm,
        'nprocs_forecast_med': nprocs_forecast_med,
        'nprocs_per_node': nprocs_per_node,
        'ocn_model': ocn_model,
        'OUTPUT_FH_CICE': output_fh_cice,
        'OUTPUT_FH_MOM6': output_fh_mom6,
        'OUTPUT_FH_WW3': output_fh_ww3,
        'partition_default': partition_default,
        'PTMP': ptmp,
        'queue_default': queue_default,
        'WARMSTART_DIR': warmstart_dir,
        'wav_model': wav_model,
        })
   
    config_parm_str = yaml.dump(config_parm, sort_keys=True, default_flow_style=False)
    logging.debug(f''' FINAL configuration: {config_parm_str}''')

    if os.path.exists(exp_case_path) and os.path.isdir(exp_case_path):
        tmp_new_name = exp_case_path+"_old"
        if os.path.exists(tmp_new_name):
            shutil.rmtree(tmp_new_name)
        os.rename(exp_case_path, tmp_new_name)
        os.makedirs(exp_case_path)
    else:
        os.makedirs(exp_case_path)

    logging.info(f''' Experimental case directory {exp_case_path} has been created.''')

    # Create YAML file for Rocoto XML from template
    fn_yaml_rocoto_template = "template.rocoto_xml_file.yaml"
    fn_yaml_rocoto = "rocoto_xml_file.yaml"
    fp_yaml_rocoto_template = os.path.join(parm_dir, "templates", fn_yaml_rocoto_template)
    fp_yaml_rocoto = os.path.join(exp_case_path, fn_yaml_rocoto)
    logging.info(f''' Rocoto YAML template: {fp_yaml_rocoto_template}''')
    try:
        fill_jinja_template([
            "-u", config_parm_str,
            "-t", fp_yaml_rocoto_template,
            "-o", fp_yaml_rocoto ])
    except:
        logging.error(f''' FATAL ERROR: Call to python script fill_jinja_template.py 
              to create a '{fp_yaml_rocoto}' file from a jinja2 template failed.''')
        return False

    # Call uwtools to create Rocoto XML file
    fn_xml_rocoto = "ufsda_rocoto.xml"
    fp_xml_rocoto = os.path.join(exp_case_path, fn_xml_rocoto)
    realize(
        config = fp_yaml_rocoto,
        output_file = fp_xml_rocoto,
        )

    # Create rocoto launch file to exp_case directory
    fn_launch_template = "template.launch_rocoto_wflow.sh"
    fn_launch_script = "launch_rocoto_wflow.sh"
    fp_launch_template = os.path.join(parm_dir, "templates", fn_launch_template)
    fp_launch_script = os.path.join(exp_case_path, fn_launch_script)
    shutil.copyfile(fp_launch_template, fp_launch_script)
    with open(fp_launch_script, 'r') as file:
        fdata = file.read()
    fdata = fdata.replace('{{ parm_dir }}', parm_dir)
    fdata = fdata.replace('{{ fn_xml_rocoto }}', fn_xml_rocoto)
    fdata = fdata.replace('{{ exp_case_path }}', exp_case_path)
    with open(fp_launch_script, 'w') as file:
        file.write(fdata)
    os.chmod(fp_launch_script, 0o755)

    # Copy the automated launch script to exp_case directory
    fn_auto_launch_py = "automate_launch_script.py"
    fp_auto_script_orig = os.path.join(parm_dir, fn_auto_launch_py)
    fp_auto_script_expt = os.path.join(exp_case_path, fn_auto_launch_py)
    shutil.copyfile(fp_auto_script_orig, fp_auto_script_expt)
    os.chmod(fp_auto_script_expt, 0o755)

    # Add links to log/tmp/com directories within exp_case directory
    envir = config_parm.get("envir")
    model_ver = config_parm.get("model_ver")
    net = config_parm.get("NET")
    log_dir_src = os.path.join(ptmp, envir, "com/output/logs")
    log_dir_dst = os.path.join(exp_case_path, "log_dir")
    tmp_dir_src = os.path.join(ptmp, envir, "tmp")
    tmp_dir_dst = os.path.join(exp_case_path, "tmp_dir")
    com_dir_src = os.path.join(ptmp, envir, "com", net, model_ver)
    com_dir_dst = os.path.join(exp_case_path, "com_dir")
    os.symlink(log_dir_src, log_dir_dst)
    os.symlink(tmp_dir_src, tmp_dir_dst)
    os.symlink(com_dir_src, com_dir_dst)

    # Create coldstart txt file for the first cycle when APP = LND
    coldstart = config_parm.get("COLDSTART")
    if coldstart == "YES":
        fn_pass = f"task_skip_coldstart_{date_first_cycle}.txt"
        open(os.path.join(exp_case_path,fn_pass), 'a').close()


# Default values of configuration =================================== CHJ =====
def set_default_parm():
# =================================================================== CHJ =====

    default_config = {
        "ACCOUNT": "epic",
        "ALLCOMP_RESTART_N": None,
        "APP": "S2SWA",
        "ATM_IO_LAYOUT_X": 1,
        "ATM_IO_LAYOUT_Y": 1,
        "ATM_LAYOUT_X": 3,
        "ATM_LAYOUT_Y": 8,
        "COMINgdas": "",
        "COMINgfs": "",
        "CCPP_SUITE": "FV3_GFS_v17_coupled_p8_ugwpv1",
        "COLDSTART": "NO",
        "CUSTOM_JEDI_CONFIG_FLAG": "NO",
        "CUSTOM_JEDI_CONFIG_PATH": None,
        "CUSTOM_JEDI_CONFIG_PREFIX": "/prefix/of/custom/JEDI/config/file/name",
        "DATE_CYCLE_FREQ_HR": 24,
        "DATE_FIRST_CYCLE": 202103220600,
        "DATE_LAST_CYCLE": 202103230600,
        "DATM_DATA_TYPE": "gfs",
        "DCOMINghcn": "",
        "DCOMINobs": "",
        "DCOMINsmap": "",
        "DCOMINsmops": "",
        "DO_FREE_FORECAST": "none",
        "DT_ATMOS": 720,
        "DT_MOM6": 1800,
        "DT_RUNSEQ": 3600,
        "EXP_CASE_NAME": None,
        "envir": "test",
        "FCST_HRS": 24,
        "FHROT": 0,
        "FRAC_GRID": "YES",
        "IC_DATA_MODEL": "gfs",
        "IC_FROM_FIX_DIR": "YES",
        "JEDI_ALGORITHM": "letkf-oi",
        "JEDI_BIN_PATH": None,
        "JEDI_IODACONV_PATH": None,
        "JEDI_PY_VER": "python3.11",
        "JEDI_TYPE_SNOW": "NO",
        "JEDI_TYPE_SOIL_MOISTURE": "NO",
        "JEDI_TYPE_SOCA": "NO",
        "KEEPDATA": "YES",
        "MACHINE": "/machine/platform/name",
        "model_ver": "v1.0.0",
        "MOM6_DT_THERM": None,
        "MOM6_NIGLOBAL": 360,
        "MOM6_NJGLOBAL": 320,
        "MOM6_NK": 75,
        "NET": "ufsda",
        "NPROCS_ANALYSIS": 6,
        "NPROCS_DATM": 12,
        "NPROCS_FCST_IC": 36,
        "NPROCS_ICE": 10,
        "NPROCS_OCN": 20,
        "NPROCS_WAV": 60,
        "NPZ": 127,
        "OBS_GHCN_SNOW": "NO",
        "OBS_IMS_SNOW": "NO",
        "OBS_SFCSNO": "NO",
        "OBS_SMAP": "NO",
        "OBS_SMOPS": "NO",
        "OCN_MESH_FN": "mesh.mx100.nc",
        "OUTPUT_FH": "6 -1",
        "OUTPUT_FH_CICE": None,
        "OUTPUT_FH_MOM6": None,
        "OUTPUT_FH_WW3": None,
        "PTMP": None,
        "PY_LOG_LEVEL": "INFO",
        "RES": 96,
        "RESTART_INTERVAL": "12 -1",
        "RUN": "ufsda",
        "SMAP_RAW_WINDOW_SPAN_HALF": 5,
        "WALLTIME_FORECAST": "00:40:00",
        "WARMSTART_DIR": None,
        "WRITE_GROUPS": 1,
        "WRITE_TASKS_PER_GROUP": 6,
    }

    return default_config


# Machine-specific values of configuration ========================== CHJ =====
def set_machine_parm(machine):
# =================================================================== CHJ =====

    lowercase_machine = machine.lower()
    match lowercase_machine:
        case "gaeac6":
            MAX_CORES_PER_NODE = 192
        case "hera":
            MAX_CORES_PER_NODE = 40
        case "hercules":
            MAX_CORES_PER_NODE = 80
        case "orion":
            MAX_CORES_PER_NODE = 40
        case "ursa":
            MAX_CORES_PER_NODE = 192
        case _:
            sys.exit(f"FATAL ERROR: this machine/platform '{lowercase_machine}' is NOT supported yet !!!")

    machine_config = {
        "MAX_CORES_PER_NODE": MAX_CORES_PER_NODE,
    }

    return machine_config


# Parse arguments =================================================== CHJ =====
def parse_args(argv):
# =================================================================== CHJ =====
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Generate case-specific workflow environment.")

    parser.add_argument(
            "-p", "--platform",
            dest="MACHINE",
            help="Platform (machine) name.",
            )
    parser.add_argument(
            "-l", "--loglevel",
            dest="PY_LOG_LEVEL",
            default="INFO",
            help="Python logging option only for this script. For other scripts, set it in config.yaml",
            )

    return parser.parse_args(argv)


# Detect platform (machine) ========================================= CHJ =====
def detect_platform():
# =================================================================== CHJ =====

    if os.path.isdir("/scratch3/NAGAPE"):
        host_str = socket.gethostname()[0:3]
        if host_str == "ufe":
            machine = "ursa"
        elif host_str == "hfe":
            machine = "hera"
    elif os.path.isdir("/work/noaa"):
        machine = socket.gethostname().split('-')[0]  # orion/hercules
    elif os.path.isdir("/ncrc"):
        machine_number = socket.gethostname()[4]
        machine = f"gaeac{machine_number}"
    elif os.path.isdir("/glade"):
        machine = "derecho"
    else:
        sys.exit(f''' FATAL ERROR: Machine (platform) is not detected. Please set it with -p argument!!!''')

    logging.info(f''' Machine (platform) detected: {machine}''')

    return machine


# Main call ========================================================= CHJ =====
if __name__=='__main__':
    args = parse_args(sys.argv[1:])
    log_level_str = args.PY_LOG_LEVEL.upper()
    try:
        log_level = getattr(logging, log_level_str)
    except AttributeError:
        log_level_str = "INFO"
        log_level = logging.INFO
        print(f''' WARNING: Invalid log level "{args.PY_LOG_LEVEL.upper()}", set to INFO.''')
    print(f''' Python Log Level= str: {log_level_str}, attr: {log_level}''')
    logging.basicConfig(format='%(levelname)s::%(pathname)s::L%(lineno)d::%(message)s', level=log_level)
    MACHINE=args.MACHINE
    if MACHINE is None:
        MACHINE = detect_platform()
   
    setup_wflow_env(MACHINE)

