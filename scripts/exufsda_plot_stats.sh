#!/usr/bin/env bash

set -xue

#
#-----------------------------------------------------------------------
# This part replaces the role of J-job script in the NOAA NCO standards
#-----------------------------------------------------------------------
#
source ${HOMEufsda}/parm/jjob_env_setup.sh
#
#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
#
# Set the default values of plotting flags
if [ "${DO_FREE_FORECAST}" = "first" ]; then
  if [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    do_plot_stats="NO"
    do_plot_time_history="NO"
    do_plot_restart="YES"
    do_plot_fcst_out_fv3="YES"
    do_plot_fcst_out_mom6="YES"
    do_plot_fcst_out_cice="YES"
  else
    do_plot_stats="YES"
    do_plot_time_history="YES"
    do_plot_restart="NO"
    do_plot_fcst_out_fv3="NO"
    do_plot_fcst_out_mom6="NO"
    do_plot_fcst_out_cice="NO"
  fi
elif [ "${DO_FREE_FORECAST}" = "all" ]; then
  do_plot_stats="NO"
  do_plot_time_history="NO"
  do_plot_restart="YES"
  do_plot_fcst_out_fv3="YES"
  do_plot_fcst_out_mom6="YES"
  do_plot_fcst_out_cice="YES"
else
  if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    do_plot_stats="NO"
    do_plot_time_history="NO"
    do_plot_restart="YES"
    do_plot_fcst_out_fv3="YES"
    do_plot_fcst_out_mom6="YES"
    do_plot_fcst_out_cice="YES"
  else
    do_plot_stats="YES"
    do_plot_time_history="YES"
    do_plot_restart="YES"
    do_plot_fcst_out_fv3="YES"
    do_plot_fcst_out_mom6="YES"
    do_plot_fcst_out_cice="YES"
  fi
fi

DO_PLOT_STATS="${DO_PLOT_STATS:-${do_plot_stats}}"
DO_PLOT_TIME_HISTORY="${DO_PLOT_TIME_HISTORY:-${do_plot_time_history}}"
DO_PLOT_RESTART="${DO_PLOT_RESTART:-${do_plot_restart}}"
DO_PLOT_FCST_OUT_FV3="${DO_PLOT_FCST_OUT_FV3:-${do_plot_fcst_out_fv3}}"
DO_PLOT_FCST_OUT_MOM6="${DO_PLOT_FCST_OUT_MOM6:-${do_plot_fcst_out_mom6}}"
DO_PLOT_FCST_OUT_CICE="${DO_PLOT_FCST_OUT_CICE:-${do_plot_fcst_out_cice}}"

# Set other dates
NTIME=$($NDATE ${DATE_CYCLE_FREQ_HR} $PDY$cyc)

YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}

nYYYY=${NTIME:0:4}
nMM=${NTIME:4:2}
nDD=${NTIME:6:2}
nHH=${NTIME:8:2}

# Path to orography files
orog_path="${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}"
orog_fn_base="C${RES}_oro_data"

# Set variable name for snow depth
if [ "${FRAC_GRID}" = "YES" ]; then
  snowdepth_vn="snodl"
else
  snowdepth_vn="snwdph"
fi

############################################################
# Stats Plot
############################################################
if [ "${DO_PLOT_STATS}" = "YES" ]; then
  # Field Range for scatter plot: [Low,High]
  field_range_low=-200
  field_range_high=200
  # Number of bins in histogram plot
  nbins=100
  # Plot type (scatter/histogram/both)
  plottype="both"

  if [ "${OBS_GHCN_SNOW}" = "YES" ]; then
    cp -p "${COMINOUThofx}/diag.ghcn_snow_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_IMS_SNOW}" = "YES" ]; then
    cp -p "${COMINOUThofx}/diag.ims_snow_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_SFCSNO}" = "YES" ]; then
    cp -p "${COMINOUThofx}/diag.sfcsno_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_SMAP}" = "YES" ]; then
    cp -p "${COMINOUThofx}/diag.smap_soil_moisture_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_SMOPS}" = "YES" ]; then
    cp -p "${COMINOUThofx}/diag.smops_soil_moisture_${PDY}${cyc}.nc" ${DATA}
  fi

  cat > plot_hofx.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
cdate: '${YYYY}-${MM}-${DD}-${HH}'
cyc: '${cyc}'
field_range: [${field_range_low},${field_range_high}]
hofx_data_path: '${DATA_HOFX}'
nbins: ${nbins}
plottype: '${plottype}'
OBS_GHCN_SNOW: '${OBS_GHCN_SNOW}'
OBS_IMS_SNOW: '${OBS_IMS_SNOW}'
OBS_SFCSNO: '${OBS_SFCSNO}'
OBS_SMAP: '${OBS_SMAP}'
OBS_SMOPS: '${OBS_SMOPS}'
PDY: '${PDY}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
work_dir: '${DATA}'
EOF
  
  ${USHufsda}/plot_hofx_stats.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Scatter/Histogram plots failed."
  fi
  
  # Copy result files to COMINOUT
  cp -p "${DATA}/hofx_omb"* ${COMINOUTplot}
  cp -p "${DATA_HOFX}/hofx_omb_timehis"* ${COMINOUThofx}
fi

############################################################
# Time-history Plot
############################################################
if [ "${DO_PLOT_TIME_HISTORY}" = "YES" ]; then
  fn_data_anal_prefix="analysis_"
  fn_data_anal_suffix=".log"
  out_fn_base="ufsda_timehistory"

  cat > plot_timehistory.yaml <<EOF
path_data: '${LOGDIR}'
work_dir: '${DATA}'
fn_data_anal_prefix: '${fn_data_anal_prefix}'
fn_data_anal_suffix: '${fn_data_anal_suffix}'
hofx_data_path: '${DATA_HOFX}'
jedi_exe: '${JEDI_ALGORITHM}'
out_fn_base: '${out_fn_base}'
OBS_GHCN_SNOW: '${OBS_GHCN_SNOW}'
OBS_IMS_SNOW: '${OBS_IMS_SNOW}'
OBS_SFCSNO: '${OBS_SFCSNO}'
OBS_SMAP: '${OBS_SMAP}'
OBS_SMOPS: '${OBS_SMOPS}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
EOF

  ${USHufsda}/plot_analysis_timehistory.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Time-history plots failed."
  fi

  # Copy result files to COMINOUT
  cp -p ${out_fn_base}* ${COMINOUTplot}
fi

###########################################################
# Plot restart tiles
###########################################################
if [ "${DO_PLOT_RESTART}" = "YES" ]; then
  fn_data_base="${nYYYY}${nMM}${nDD}.${nHH}0000.sfc_data.tile"
  out_title_base="UFS-DA::RESTART::FV3::${nYYYY}-${nMM}-${nDD}-${nHH}::"
  out_fn_base="ufsda_out_restart_fv3_${nYYYY}${nMM}${nDD}${nHH}_"
  # zlevel_number is valid only for 3-D fields such as stc/smc/slc
  zlevel_number="1"

  cat > plot_restart.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
colorbar_option: 'fixed'
fn_data_base: '${fn_data_base}'
orog_path: '${orog_path}'
orog_fn_base: '${orog_fn_base}'
out_title_base: '${out_title_base}'
out_fn_base: '${out_fn_base}'
path_data: '${COMINOUT}/RESTART'
plot_each_tile: 'NO'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
var_list_restart:
  - ${snowdepth_vn}
  - smc
work_dir: '${DATA}'
zlevel_number: '${zlevel_number}'
EOF

  ${USHufsda}/plot_forecast_restart.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Forecast restart plots failed."
  fi

  # Copy result files to COMINOUT
  cp -p ${out_fn_base}* ${COMINOUTplot}
fi

###########################################################
# Plot forecast output tiles: FV3
###########################################################
if [ "${DO_PLOT_FCST_OUT_FV3}" = "YES" ]; then
  fn_base_prefix="${NET}.${cycle}"
  out_title_base="UFS-DA::OUT::FV3::${YYYY}-${MM}-${DD}-${HH}::"
  out_fn_base="ufsda_out_fv3_${YYYY}${MM}${DD}${HH}_"
  # zlevel_number is valid only for 3-D fields
  zlevel_number_atm="1"
  zlevel_number_sfc="1"

  cat > plot_forecast_out_fv3.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
colorbar_option: 'fixed'
FCST_HRS: ${FCST_HRS}
fn_base_prefix: '${fn_base_prefix}'
out_title_base: '${out_title_base}'
out_fn_base: '${out_fn_base}'
OUTPUT_FH: '${OUTPUT_FH}'
path_data: '${COMINOUT}'
plot_each_tile: 'NO'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
RES: ${RES}
var_list_atm:
  - tmp
var_list_sfc:
  - snod
  - soilm
work_dir: '${DATA}'
zlevel_number_atm: '${zlevel_number_atm}'
zlevel_number_sfc: '${zlevel_number_sfc}'
EOF

  ${USHufsda}/plot_forecast_out_fv3.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Forecast FV3 output plots failed."
  fi

  # Copy result files to COMINOUT
  cp -p ${out_fn_base}* ${COMINOUTplot}
fi

###########################################################
# Plot forecast output file: MOM6
###########################################################
if [ "${DO_PLOT_FCST_OUT_MOM6}" = "YES" ]; then
  fn_base_prefix="${NET}.${cycle}.ocn.f"
  fn_base_suffix=".c${RES}.nc"
  out_title_base="UFS-DA::OUT::MOM6::${YYYY}-${MM}-${DD}-${HH}::"
  out_fn_base="ufsda_out_mom6_${YYYY}${MM}${DD}${HH}_"
  # zlevel_number is valid only for 3-D fields
  zlevel_number_ocn="1"

  cat > plot_forecast_out_mom6.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
colorbar_option: 'fixed'
FCST_HRS: ${FCST_HRS}
fn_base_prefix: '${fn_base_prefix}'
fn_base_suffix: '${fn_base_suffix}'
out_title_base: '${out_title_base}'
out_fn_base: '${out_fn_base}'
path_data: '${COMINOUT}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
var_list_ocn:
  - SSH
  - SSS
  - temp
work_dir: '${DATA}'
zlevel_number_ocn: '${zlevel_number_ocn}'
EOF

  ${USHufsda}/plot_forecast_out_mom6.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Forecast MOM6 output plots failed."
  fi

  # Copy result files to COMINOUT
  cp -p ${out_fn_base}* ${COMINOUTplot}
fi

###########################################################
# Plot forecast output file: CICE
###########################################################
if [ "${DO_PLOT_FCST_OUT_CICE}" = "YES" ]; then
  fn_base_prefix="${NET}.${cycle}.ice.f"
  fn_base_suffix=".c${RES}.nc"
  out_title_base="UFS-DA::OUT::CICE::${YYYY}-${MM}-${DD}-${HH}::"
  out_fn_base="ufsda_out_cice_${YYYY}${MM}${DD}${HH}_"

  cat > plot_forecast_out_cice.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
colorbar_option: 'fixed'
FCST_HRS: ${FCST_HRS}
fn_base_prefix: '${fn_base_prefix}'
fn_base_suffix: '${fn_base_suffix}'
out_title_base: '${out_title_base}'
out_fn_base: '${out_fn_base}'
path_data: '${COMINOUT}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
RES: ${RES}
var_list_ice:
  - hi_h
  - hs_h
work_dir: '${DATA}'
EOF

  ${USHufsda}/plot_forecast_out_cice.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Forecast CICE output plots failed."
  fi

  # Copy result files to COMINOUT
  cp -p ${out_fn_base}* ${COMINOUTplot}
fi


#
#-----------------------------------------------------------------------
# J-job script ending part
#-----------------------------------------------------------------------
#
if [ -e "$pgmout" ]; then
  cat $pgmout
fi
if [ "${KEEPDATA}" = "NO" ]; then
  rm -rf ${DATA}
fi
date

