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

#export MPI_TYPE_DEPTH=20
export OMP_STACKSIZE=512M
export KMP_AFFINITY=scatter
export OMP_NUM_THREADS=1
#export ESMF_RUNTIME_COMPLIANCECHECK=OFF:depth=4
#export PSM_RANKS_PER_CONTEXT=4
#export PSM_SHAREDCONTEXTS=1
export ESMF_RUNTIME_PROFILE=ON
export ESMF_RUNTIME_PROFILE_OUTPUT="SUMMARY"


machines_srun=( "gaeac6" "hera" "hercules" "orion" "ursa" )
if [[ ${machines_srun[@]} =~ "${MACHINE}" ]]; then
  run_cmd="srun"
else
  run_cmd=`which mpiexec`
fi

NTIME=$($NDATE ${DATE_CYCLE_FREQ_HR} $PDY$cyc)

YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}
nYYYY=${NTIME:0:4}
nMM=${NTIME:4:2}
nDD=${NTIME:6:2}
nHH=${NTIME:8:2}

HHsec=$(( HH * 3600 ))
HHsec_5d=$(printf "%05d" "${HHsec}")
nHHsec=$(( nHH * 3600 ))
nHHsec_5d=$(printf "%05d" "${nHHsec}")

filedate=${PDY}.${cyc}0000

########################################
# cold/warm-start dependent variables
########################################

if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
  # input.nml
  external_ic=".true."
  ignore_rst_cksum=".true."
  make_nh=".true."
  mom_input_filename="n"
  mountain=".false."
  na_init="1"
  nggps_ic=".true."
  nstf_name="2,0,0,0,0"
  warm_start=".false."
#############################################
# CHECK: in other cases, nstf_name: 2,1,0,0,0 for coldstart, but in regression test 
#        'cpld_control_gfsv17_intel' of ufs-weather-model, it is set to 2,0,0,0,0
#############################################

  # ufs.configure
  allcomp_restart_n="3"
  allcomp_start_type="startup"

  # model_configure
  fhrot="0"

  # ice_in
  ice_runtype="initial"
  ice_use_restart_time=".false."
  ice_diagfreq="120"
  ice_histfreq_n="0, 0, 6, 120, 1"
else
  # input.nml
  external_ic=".false."
  ignore_rst_cksum=".true."
  make_nh=".false."
  mom_input_filename="r"
  mountain=".true."
  na_init="0"
  nggps_ic=".false."
  nstf_name="2,0,0,0,0"
  warm_start=".true."

  # ufs.configure
  allcomp_restart_n="12"
  allcomp_start_type="continue"

  # model_configure
  fhrot="12"

  # ice_in
  ice_runtype="continue"
  ice_use_restart_time=".true."
  ice_diagfreq="60"
  ice_histfreq_n="0, 0, 6, 0, 0"
fi

#####################################
# Copy app-independent input files
#####################################
# field_table
cp -p "${PARMufsda}/templates/template.${APP}.field_table" field_table
# fd_ufs.yaml
cp -p "${PARMufsda}/templates/template.${APP}.fd_ufs.yaml" fd_ufs.yaml
# data_table
cp -p "${PARMufsda}/templates/template.${APP}.data_table" data_table

##################
# Set input.nml
##################
settings="\
  'ATM_IO_LAYOUT_X': ${ATM_IO_LAYOUT_X}
  'ATM_IO_LAYOUT_Y': ${ATM_IO_LAYOUT_Y}
  'ATM_LAYOUT_X': ${ATM_LAYOUT_X}
  'ATM_LAYOUT_Y': ${ATM_LAYOUT_Y}
  'CCPP_SUITE': ${CCPP_SUITE}
  'external_ic': '${external_ic}'
  'ignore_rst_cksum': '${ignore_rst_cksum}'
  'make_nh': '${make_nh}'
  'mom_input_filename': ${mom_input_filename}
  'mountain': '${mountain}'
  'na_init': ${na_init}
  'nggps_ic': '${nggps_ic}'
  'nstf_name': '${nstf_name}'
  'NPZ': ${NPZ}
  'res_p1': ${res_p1}
  'warm_start': '${warm_start}'
" # End of settings variable

fp_template="${PARMufsda}/templates/template.${APP}.input.nml.${CCPP_SUITE}"
fn_namelist="input.nml"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

######################
# Set ufs.configure
######################
atm_model="fv3"
nprocs_atm_m1=$(( nprocs_forecast_atm - 1 ))
nprocs_med_m1=$(( nprocs_forecast_med - 1 ))
nprocs_atm_ocn=$(( nprocs_forecast_atm + OCN_NPROCS ))
nprocs_atm_ocn_m1=$(( nprocs_atm_ocn - 1 ))
nprocs_atm_ocn_ice=$(( nprocs_atm_ocn + ICE_DOMAIN_NPROCS ))
nprocs_atm_ocn_ice_m1=$(( nprocs_atm_ocn_ice - 1 ))
nprocs_forecast_m1=$(( nprocs_forecast - 1 ))

settings="\
  'DT_ATMOS': ${DT_ATMOS}
  'DT_RUNSEQ': ${DT_RUNSEQ}
  'allcomp_restart_n': ${allcomp_restart_n}
  'allcomp_start_type': ${allcomp_start_type}
  'allcomp_stop_n': ${FCST_HRS}
  'atm_model': ${atm_model}
  'atm_petlist_bounds_n1': 0
  'atm_petlist_bounds_n2': ${nprocs_atm_m1}
  'ice_petlist_bounds_n1': ${nprocs_atm_ocn}
  'ice_petlist_bounds_n2': ${nprocs_atm_ocn_ice_m1}
  'med_petlist_bounds_n1': 0
  'med_petlist_bounds_n2': ${nprocs_med_m1}
  'ocn_petlist_bounds_n1': ${nprocs_forecast_atm}
  'ocn_petlist_bounds_n2': ${nprocs_atm_ocn_m1}
  'wav_petlist_bounds_n1': ${nprocs_atm_ocn_ice}
  'wav_petlist_bounds_n2': ${nprocs_forecast_m1}
" # End of settings variable

fp_template="${PARMufsda}/templates/template.ufs.configure"
fn_namelist="ufs.configure"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

########################
# Set model_configure
########################
settings="\
  'yyyy': !!str ${YYYY}
  'mm': !!str ${MM}
  'dd': !!str ${DD}
  'hh': !!str ${HH}
  'APP': ${APP}
  'DT_ATMOS': ${DT_ATMOS}
  'FCST_HRS': ${FCST_HRS}
  'fhrot': ${fhrot}
  'OUTPUT_FH': ${OUTPUT_FH}
  'RESTART_INTERVAL': ${RESTART_INTERVAL}
  'WRITE_GROUPS': ${WRITE_GROUPS}
  'WRITE_TASKS_PER_GROUP': ${WRITE_TASKS_PER_GROUP}
" # End of settings variable

fp_template="${PARMufsda}/templates/template.model_configure"
fn_namelist="model_configure"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

###################
# set diag table
###################
settings="\
  'yyyymmdd': !!str ${PDY}
  'yyyy': !!str ${YYYY}
  'mm': !!str ${MM}
  'dd': !!str ${DD}
  'hh': !!str ${cyc}
  'RES': ${RES}
" # End of settings variable

fp_template="${PARMufsda}/templates/template.${APP}.diag_table"
fn_namelist="diag_table"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

###############
# set ice_in
###############
settings="\
  'yyyymmdd': !!str ${PDY}
  'yyyy': !!str ${YYYY}
  'yyyy_last': !!str ${nYYYY}
  'yyyy_align': !!str ${YYYY}
  'mm': !!str ${MM}
  'dd': !!str ${DD}
  'hh_sec': !!str ${HHsec}
  'DT_ATMOS': ${DT_ATMOS}
  'ICE_DOMAIN_NPROCS': ${ICE_DOMAIN_NPROCS}
  'ice_runtype': ${ice_runtype}
  'ice_use_restart_time': ${ice_use_restart_time}
  'ice_diagfreq': ${ice_diagfreq}
  'ice_histfreq_n': '${ice_histfreq_n}'
" # End of settings variable

fp_template="${PARMufsda}/templates/template.${APP}.ice_in"
fn_namelist="ice_in"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

#####################
# set ww3_shel.nml
#####################
cp -p ${PARMufsda}/templates/template.${APP}.ww3_shel.nml ww3_shel.nml

#########################################
# Soft-link or copy FIX (static) files
#########################################
# FV3 global fix files
ln -nsf ${FIXufsda}/DATA_fix/FV3/Global/* .

# FV3 tiled fix files
sfc_fns=( "facsf" "maximum_snow_albedo" "slope_type" "snowfree_albedo" "soil_color" \
          "soil_type" "substrate_temperature" "vegetation_greenness" "vegetation_type" )
for ifn in "${sfc_fns[@]}" ; do
  for itile in {1..6};
  do
    ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}.${ifn}.tile${itile}.nc" .
  done
done

# CICE files
ice_fns=( "grid_cice_NEMS_mx100.nc" "kmtu_cice_NEMS_mx100.nc" "mesh.xm100.nc" )
for ifn in "${ice_fns[@]}" ; do
  ln -nsf "${FIXufsda}/DATA_fix/CICE/${ifn}" .
done

# WW3 files
wav_fns=( "mod_def.ww3" "ww3_points.list" "mesh.global_270k.nc" )
for ifn in "${wav_fns[@]}" ; do
  ln -nsf "${FIXufsda}/DATA_fix/WW3/${ifn}" .
done

##########################
# MOM6 output directory
##########################
mkdir -p MOM6_OUTPUT

################################
# Set up RESTART directory
################################
mkdir -p RESTART

if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
  # Set path to directory where restart files exist
  if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    data_dir="${WARMSTART_DIR}"
  else
    data_dir="${COMINm1}/RESTART"
  fi      
  # CMEPS restart and pointer files
  r_fn="ufs.cpld.cpl.r.${YYYY}-${MM}-${DD}-${HHsec_5d}.nc"
  if [ -f "${data_dir}/${r_fn}" ]; then
    ln -nsf "${data_dir}/${r_fn}" RESTART/.
  else
    err_exit "${data_dir}/${r_fn} file does not exist."
  fi
  ls -1 "./RESTART/${r_fn}">rpointer.cpl

  # NoahMP restart files
  if [ "${DO_FREE_FORECAST}" = "YES" ]; then
    for itile in {1..6}
    do
      ln -nsf "${WARMSTART_DIR}/ufs_land_restart.${YYYY}-${MM}-${DD}_${HH}-00-00.tile${itile}.nc" RESTART/ufs.cpld.lnd.out.${YYYY}-${MM}-${DD}-${HHsec_5d}.tile${itile}.nc
    done
  else
    for itile in {1..6}
    do
      ln -nsf "${COMIN}/ufs_land_restart.anal.${YYYY}-${MM}-${DD}_${HH}-00-00.tile${itile}.nc" RESTART/ufs.cpld.lnd.out.${YYYY}-${MM}-${DD}-${HHsec_5d}.tile${itile}.nc
    done
  fi
fi

#############################
# Set up INPUT directory
#############################
mkdir -p INPUT
cd INPUT

# Grid/orography/mosaic files
for itile in {1..6}
do
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_oro_data.tile${itile}.nc" oro_data.tile${itile}.nc
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_grid.tile${itile}.nc" .
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_oro_data_ls.tile${itile}.nc" oro_data_ls.tile${itile}.nc
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_oro_data_ss.tile${itile}.nc" oro_data_ss.tile${itile}.nc
done
ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_mosaic.nc" .
ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_grid_spec.nc" grid_spec.nc

# MOM6 input data files
ocn_fns=( "atmos_mosaic_tile1Xland_mosiaic_tile1.nc" "atmos_mosaic_tile1Xocean_mosaic_tile1.nc" \
          "hycom1_75_800m.nc" "interpolate_zgrid_40L.nc" "KH_background_2d.nc" "land_mask.nc" \
	  "land_mosaic_tile1Xocean_mosaic_tile1.nc" "layer_coord.nc" "MOM6_IC_TS.nc" \
	  "MOM_channels_SPEAR" "ocean_hgrid.nc" "ocean_mask.nc" "ocean_mosaic.nc" \
	  "seawifs_1998-2006_smoothed_2X.nc" "tidal_amplitude.nc" "topog.nc" \
	  "ufs.topo_edits_011818.nc" "vgrid_75_2m.nc" )
for ifn in "${ocn_fns[@]}" ; do
  ln -nsf "${FIXufsda}/DATA_fix/MOM6/${ifn}" .
done

# MOM6 input namelist files
cp -p "${PARMufsda}/templates/template.${APP}.MOM_input" MOM_input
cp -p "${PARMufsda}/templates/template.${APP}.MOM_override" MOM_override

# GFS IC (initial condition) files for cold start
if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
  if [ "${IC_FROM_FIX_DIR}" = "YES" ]; then
    data_dir="${FIXufsda}/DATA_ics/${PDY}/${cyc}"
  else
    data_dir="${COMIN}"
  fi
  ln -nsf "${data_dir}/gfs_ctrl.nc" .
  for itile in {1..6}
  do
    ln -nsf "${data_dir}/gfs_data.tile${itile}.nc" .
    ln -nsf "${data_dir}/sfc_data.tile${itile}.nc" .
  done
fi

# Copy restart files
if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
  # Set path to directory where restart files exist
  if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    data_dir="${WARMSTART_DIR}"
  else
    data_dir="${COMINm1}/RESTART"
  fi

  rst_fns=( "ca_data" "fv_core.res" "fv_srf_wnd.res" "fv_tracer.res" "phy_data" )
  for ifn in "${rst_fns[@]}" ; do
    for itile in {1..6};
    do
      r_fp="${data_dir}/${filedate}.${ifn}.tile${itile}.nc"
      if [ -f "${r_fp}" ]; then
        ln -nsf "${r_fp}" "${ifn}.tile${itile}.nc"
      else
        err_exit "${r_fp} file does not exist."
      fi
    done
    if [ "${ifn}" = "fv_core.res" ]; then
      r_fp="${data_dir}/${filedate}.${ifn}.nc"
      if [ -f "${r_fp}" ]; then
        ln -nsf "${r_fp}" "${ifn}.nc"
      else
        err_exit "${r_fp} file does not exist."
      fi
    fi
  done
  # link sfc_data from COMIN because they were upated by JEDI Analysis task
  if [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
    data_dir="${COMIN}"
  fi
  for itile in {1..6};
  do
    r_fp="${data_dir}/${filedate}.sfc_data.tile${itile}.nc"
    if [ -f "${r_fp}" ]; then
      ln -nsf "${r_fp}" "sfc_data.tile${itile}.nc"
    else
      err_exit "${r_fp} file does not exist."
    fi
  done

  # update coupler.res file
  settings="\
  'coupler_calendar': ${COUPLER_CALENDAR}
  'yyyp': !!str ${YYYY}
  'mp': !!str ${MM}
  'dp': !!str ${DD}
  'hp': !!str ${HH}
  'yyyy': !!str ${YYYY}
  'mm': !!str ${MM}
  'dd': !!str ${DD}
  'hh': !!str ${HH}
" # End of settings variable

  fp_template="${PARMufsda}/templates/template.coupler.res"
  fn_namelist="coupler.res"
  ${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"
fi
cd -

# Run ufs-weather-model
export pgm="ufs_model"
. prep_step
${run_cmd} --label -n ${nprocs_forecast} ${EXECufsda}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk
cp errfile errfile_ufs_model
if [[ $err != 0 ]]; then
  err_exit "ufs_model failed"
fi

############################
# copy model ouput to COM
############################
# Copy and link output file to restart for next cycle
if [ "${FCST_HRS}" -gt "${DATE_CYCLE_FREQ_HR}" ]; then
  num_set=$(( FCST_HRS / DATE_CYCLE_FREQ_HR ))
  for iset in $( seq 1 $num_set )
  do
    iset_hr=$(( DATE_CYCLE_FREQ_HR * iset ))
    iset_cdate=$($NDATE ${iset_hr} $PDY$cyc)
    iYYYY=${iset_cdate:0:4}
    iMM=${iset_cdate:4:2}
    iDD=${iset_cdate:6:2}
    iHH=${iset_cdate:8:2}
    iHHsec=$(( iHH * 3600 )) 
    iHHsec_5d=$(printf "%05d" "${iHHsec}")
    for itile in {1..6}
    do
      cp -p "${DATA}/ufs.cpld.lnd.out.${iYYYY}-${iMM}-${iDD}-${iHHsec_5d}.tile${itile}.nc" "${COMOUT}/RESTART/ufs_land_restart.${iYYYY}-${iMM}-${iDD}_${iHH}-00-00.tile${itile}.nc"
      ln -nsf "${COMOUT}/RESTART/ufs_land_restart.${iYYYY}-${iMM}-${iDD}_${iHH}-00-00.tile${itile}.nc" ${DATA_RESTART}/.
    done
  done
else
  for itile in {1..6}
  do
    cp -p "${DATA}/ufs.cpld.lnd.out.${nYYYY}-${nMM}-${nDD}-${nHHsec_5d}.tile${itile}.nc" "${COMOUT}/RESTART/ufs_land_restart.${nYYYY}-${nMM}-${nDD}_${nHH}-00-00.tile${itile}.nc"
    ln -nsf "${COMOUT}/RESTART/ufs_land_restart.${nYYYY}-${nMM}-${nDD}_${nHH}-00-00.tile${itile}.nc" ${DATA_RESTART}/.
  done
fi

# Move output to COMOUT
read -ra out_fh <<< "${OUTPUT_FH}"
out_fh1="${out_fh[0]}"
out_fh2="${out_fh[1]}"
if [ "${out_fh2}" = "-1" ]; then
  list_out_fh=$(seq 0 ${out_fh1} ${FCST_HRS})
else
  list_out_fh=${OUTPUT_FH}
fi
for ihr in ${list_out_fh}
do
  ihr_3d=$(printf "%03d" "${ihr}")
  for itile in {1..6}
  do
    cp -p "${DATA}/atmf${ihr_3d}.tile${itile}.nc" "${COMOUT}/${NET}.${cycle}.atm.f${ihr_3d}.c${RES}.tile${itile}.nc"
    cp -p "${DATA}/sfcf${ihr_3d}.tile${itile}.nc" "${COMOUT}/${NET}.${cycle}.sfc.f${ihr_3d}.c${RES}.tile${itile}.nc"
  done
done
# RESTART directory
cp -p "${DATA}/RESTART/${nYYYY}${nMM}${nDD}.${nHH}0000.coupler.res" ${COMOUT}/RESTART/.
cp -p "${DATA}/RESTART/${nYYYY}${nMM}${nDD}.${nHH}0000.fv_core.res.nc" ${COMOUT}/RESTART/.

rst_fns=( "ca_data" "fv_core.res" "fv_srf_wnd.res" "fv_tracer.res" "phy_data" "sfc_data" )
for ifn in "${rst_fns[@]}" ; do
  for itile in {1..6};
  do
    cp -p "${DATA}/RESTART/${nYYYY}${nMM}${nDD}.${nHH}0000.${ifn}.tile${itile}.nc" ${COMOUT}/RESTART/.
  done
done
# Set sfc_data to DATA_RESTART to trigger ANALYSIS task in next cycle
for itile in {1..6};
do
  cp -p "${COMOUT}/RESTART/${nYYYY}${nMM}${nDD}.${nHH}0000.sfc_data.tile${itile}.nc" ${DATA_RESTART}/.
done

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

