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
if [ "${DO_FREE_FORECAST}" = "first" ]; then
  if [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    do_plot_stats="NO"
    do_plot_time_history="NO"
    do_plot_restart="YES"
  else
    do_plot_stats="YES"
    do_plot_time_history="YES"
    do_plot_restart="NO"
  fi
elif [ "${DO_FREE_FORECAST}" = "all" ]; then
  do_plot_stats="NO"
  do_plot_time_history="NO"
  do_plot_restart="YES"
else
  if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    do_plot_stats="NO"
    do_plot_time_history="NO"
    do_plot_restart="YES"
  else
    do_plot_stats="YES"
    do_plot_time_history="YES"
    do_plot_restart="YES"
  fi
fi

DO_PLOT_STATS="${DO_PLOT_STATS:-${do_plot_stats}}"
DO_PLOT_TIME_HISTORY="${DO_PLOT_TIME_HISTORY:-${do_plot_time_history}}"
DO_PLOT_RESTART="${DO_PLOT_RESTART:-${do_plot_restart}}"

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
    cp -p "${COMINhofx}/diag.ghcn_snow_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_IMS_SNOW}" = "YES" ]; then
    cp -p "${COMINhofx}/diag.ims_snow_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_SFCSNO}" = "YES" ]; then
    cp -p "${COMINhofx}/diag.sfcsno_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_SMAP}" = "YES" ]; then
    cp -p "${COMINhofx}/diag.smap_soil_moisture_${PDY}${cyc}.nc" ${DATA}
  fi
  if [ "${OBS_SMOPS}" = "YES" ]; then
    cp -p "${COMINhofx}/diag.smops_soil_moisture_${PDY}${cyc}.nc" ${DATA}
  fi

  cat > plot_hofx.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
cdate: '${YYYY}-${MM}-${DD}-${HH}'
cyc: '${cyc}'
field_range: [${field_range_low},${field_range_high}]
hofx_data_path: '${DATA_HOFX_OMB}'
nbins: ${nbins}
plottype: '${plottype}'
work_dir: '${DATA}'
OBS_GHCN_SNOW: '${OBS_GHCN_SNOW}'
OBS_IMS_SNOW: '${OBS_IMS_SNOW}'
OBS_SFCSNO: '${OBS_SFCSNO}'
OBS_SMAP: '${OBS_SMAP}'
OBS_SMOPS: '${OBS_SMOPS}'
PDY: '${PDY}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
EOF
  
  ${USHufsda}/hofx_analysis_stats.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Scatter/Histogram plots failed."
  fi
  
  # Copy result files to COMOUT
  cp -p "${DATA}/hofx_omb"* ${COMOUTplot}
  cp -p "${DATA_HOFX_OMB}/hofx_omb_timehis"* ${COMOUThofx}
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
hofx_data_path: '${DATA_HOFX_OMB}'
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

  # Copy result files to COMOUT
  cp -p ${out_fn_base}* ${COMOUTplot}
fi

###########################################################
# Plot restart tiles
###########################################################
if [ "${DO_PLOT_RESTART}" = "YES" ]; then
  fn_data_base="${nYYYY}${nMM}${nDD}.${nHH}0000.sfc_data.tile"
  out_title_base="UFS-DA::RESTART::${nYYYY}-${nMM}-${nDD}-${nHH}::"
  out_fn_base="ufsda_out_restart_${nYYYY}${nMM}${nDD}${nHH}_"
  # zlevel_number is valid only for 3-D fields such as stc/smc/slc
  zlevel_number="1"

  cat > plot_restart.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
fn_data_base: '${fn_data_base}'
orog_path: '${orog_path}'
orog_fn_base: '${orog_fn_base}'
out_title_base: '${out_title_base}'
out_fn_base: '${out_fn_base}'
path_data: '${COMIN}/RESTART'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
zlevel_number: '${zlevel_number}'
work_dir: '${DATA}'
EOF

  ${USHufsda}/plot_forecast_restart.py
  if [ $? -ne 0 ]; then
    err_exit "FATAL ERROR: Forecast restart plots failed."
  fi

  # Copy result files to COMOUT
  cp -p ${out_fn_base}* ${COMOUTplot}
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

