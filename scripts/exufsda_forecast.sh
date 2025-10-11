#!/usr/bin/env bash

set -xue

ulimit -s unlimited; ulimit -a;
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
export I_MPI_EXTRA_FILESYSTEM=ON
export FI_MLX_INJECT_LIMIT=0


machines_srun=( "gaeac6" "hera" "hercules" "orion" "ursa" )
if [[ ${machines_srun[@]} =~ "${MACHINE}" ]]; then
  run_cmd="srun"
else
  run_cmd=`which mpiexec`
fi

NTIME=$($NDATE ${DATE_CYCLE_FREQ_HR} $PDY$cyc)
PTIME=$($NDATE -${DATE_CYCLE_FREQ_HR} $PDY$cyc)

YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}
nYYYY=${NTIME:0:4}
nMM=${NTIME:4:2}
nDD=${NTIME:6:2}
nHH=${NTIME:8:2}
PDYcm1=${PTIME:0:8}
COMINOUTcm1="${COMINOUTcm1:-${COMROOT}/${NET}/${model_ver}/${RUN}.${PDYcm1}}"

HHsec=$(( HH * 3600 ))
HHsec_5d=$(printf "%05d" "${HHsec}")
nHHsec=$(( nHH * 3600 ))
nHHsec_5d=$(printf "%05d" "${nHHsec}")

filedate=${PDY}.${cyc}0000

#############################
# Input/output directories
#############################
mkdir -p INPUT
mkdir -p RESTART

#####################
# Model components
#####################
if [ "${APP}" = "S2SWA" ]; then
  atm_model="fv3"
  ocn_model="mom6"
  ice_model="cice6"
  wav_model="ww3"
elif [ "${APP}" = "NG-GODAS" ]; then
  atm_model="datm"
  ocn_model="mom6"
  ice_model="cice6"
  wav_model=""
else
  atm_model=""
  ocn_model=""
  ice_model=""
  wav_model=""
fi

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

  # ufs.configure
  allcomp_read_restart=".false."
  allcomp_start_type="startup"

  # ice_in
  ice_runtype="initial"
  ice_use_restart_time=".false."
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
  allcomp_read_restart=".true."
  allcomp_start_type="continue"

  # ice_in
  ice_runtype="continue"
  ice_use_restart_time=".true."
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
if [ "${APP}" = "S2SWA" ]; then
  fn_template="template.${APP}.input.nml.${CCPP_SUITE}"
elif [ "${APP}" = "NG-GODAS" ]; then
  fn_template="template.${APP}.input.nml"
fi
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
fp_template="${PARMufsda}/templates/${fn_template}"
fn_namelist="input.nml"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

######################
# Set ufs.configure
######################
nprocs_atm_m1=$(( nprocs_forecast_atm - 1 ))
nprocs_med_m1=$(( nprocs_forecast_med - 1 ))
nprocs_atm_ocn=$(( nprocs_forecast_atm + OCN_NPROCS ))
nprocs_atm_ocn_m1=$(( nprocs_atm_ocn - 1 ))
nprocs_atm_ocn_ice=$(( nprocs_atm_ocn + ICE_DOMAIN_NPROCS ))
nprocs_atm_ocn_ice_m1=$(( nprocs_atm_ocn_ice - 1 ))
nprocs_forecast_m1=$(( nprocs_forecast - 1 ))

settings="\
  'APP': ${APP}
  'DT_ATMOS': ${DT_ATMOS}
  'DT_RUNSEQ': ${DT_RUNSEQ}
  'ALLCOMP_RESTART_N': ${ALLCOMP_RESTART_N}
  'allcomp_read_restart': ${allcomp_read_restart}
  'allcomp_start_type': ${allcomp_start_type}
  'allcomp_stop_n': ${FCST_HRS}
  'atm_mesh_atm': mesh.datm.3072x1536.nc
  'atm_model': ${atm_model}
  'atm_stop_n': ${FCST_HRS}
  'atm_petlist_bounds_n1': 0
  'atm_petlist_bounds_n2': ${nprocs_atm_m1}
  'ice_mesh_ice': mesh.mx100.nc
  'ice_model': ${ice_model}
  'ice_petlist_bounds_n1': ${nprocs_atm_ocn}
  'ice_petlist_bounds_n2': ${nprocs_atm_ocn_ice_m1}
  'ice_stop_n': ${FCST_HRS}
  'med_petlist_bounds_n1': 0
  'med_petlist_bounds_n2': ${nprocs_med_m1}
  'ocn_mesh_ocn': mesh.mx100.nc
  'ocn_model': ${ocn_model}
  'ocn_petlist_bounds_n1': ${nprocs_forecast_atm}
  'ocn_petlist_bounds_n2': ${nprocs_atm_ocn_m1}
  'wav_mesh_wav': mesh.global_270k.nc
  'wav_model': ${wav_model}
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
  'FHROT': ${FHROT}
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
  'OUTPUT_FH_MOM6': ${OUTPUT_FH_MOM6}
  'RES': ${RES}
" # End of settings variable
fp_template="${PARMufsda}/templates/template.${APP}.diag_table"
fn_namelist="diag_table"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"


###############
# FV3 files
###############
if [ "${atm_model}" = "fv3" ]; then
  # FV3 global fix files
  ln -nsf ${FIXufsda}/DATA_fix/FV3/Global/* .

  # FV3 tiled fix files
  sfc_fns=( "facsf" "maximum_snow_albedo" "slope_type" "snowfree_albedo" "soil_color" \
            "soil_type" "substrate_temperature" "vegetation_greenness" "vegetation_type" )
  for ifn in "${sfc_fns[@]}" ; do
    for itile in {1..6};
    do
      ifp="${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}.${ifn}.tile${itile}.nc"
      if [ -e "${ifp}" ]; then
        ln -nsf ${ifp} .
      else
        err_exit "Symlink failed: ${ifp} does not exist."
      fi
    done
  done

  # INPUT directory
  cd ${DATA}/INPUT
  ## Grid/orography/mosaic files
  for itile in {1..6}
  do
    ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_oro_data.tile${itile}.nc" oro_data.tile${itile}.nc
    ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_grid.tile${itile}.nc" .
    ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_oro_data_ls.tile${itile}.nc" oro_data_ls.tile${itile}.nc
    ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_oro_data_ss.tile${itile}.nc" oro_data_ss.tile${itile}.nc
  done
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_mosaic.nc" .
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_grid_spec.nc" grid_spec.nc
  
  ## IC (initial condition) files for cold start
  if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${IC_FROM_FIX_DIR}" = "YES" ]; then
      data_dir="${FIXufsda}/DATA_ics/${PDY}/${cyc}"
    else
      data_dir="${COMINOUT}"
    fi
    ln -nsf "${data_dir}/gfs_ctrl.nc" .
    for itile in {1..6}
    do
      ln -nsf "${data_dir}/gfs_data.tile${itile}.nc" .
      ln -nsf "${data_dir}/sfc_data.tile${itile}.nc" .
    done
  fi
  
  ## Copy restart files
  if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
      data_dir="${WARMSTART_DIR}"
    else
      data_dir="${COMINOUTcm1}/RESTART"
    fi
  
    ### Tiled files
    rst_fns=( "ca_data" "fv_core.res" "fv_srf_wnd.res" "fv_tracer.res" "phy_data" )
    for ifn in "${rst_fns[@]}" ; do
      for itile in {1..6};
      do
        r_fp="${data_dir}/${filedate}.${ifn}.tile${itile}.nc"
        if [ -e "${r_fp}" ]; then
          ln -nsf "${r_fp}" "${ifn}.tile${itile}.nc"
        else
          err_exit "Symlink failed: ${r_fp} file does not exist."
        fi
      done
    done
  
    ### Single files (time format: YYYYMMDD.HH0000)
    r_fp="${data_dir}/${filedate}.fv_core.res.nc"
    if [ -e "${r_fp}" ]; then
      ln -nsf "${r_fp}" "fv_core.res.nc"
    else
      err_exit "Symlink failed: ${r_fp} file does not exist."
    fi
  
    ### Files updated by ANALYSIS (JEDI)
    if [ "${DO_FREE_FORECAST}" = "none" ]; then
      data_dir="${COMINOUT}"
    else
      if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
        data_dir="${WARMSTART_DIR}"
      else
        data_dir="${COMINOUTcm1}/RESTART"
      fi
    fi
    for itile in {1..6};
    do
      r_fp="${data_dir}/${filedate}.sfc_data.tile${itile}.nc"
      if [ -e "${r_fp}" ]; then
        ln -nsf "${r_fp}" "sfc_data.tile${itile}.nc"
      else
        err_exit "Symlink failed: ${r_fp} file does not exist."
      fi
    done
  
    ### create coupler.res file
    settings="\
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
  cd ${DATA}
fi

###############
# MOM6 files
###############
if [ "${ocn_model}" = "mom6" ]; then
  # output directory
  mkdir -p MOM6_OUTPUT

  # INPUT directory
  cd ${DATA}/INPUT
  ocn_fns=( "atmos_mosaic_tile1Xland_mosaic_tile1.nc" "atmos_mosaic_tile1Xocean_mosaic_tile1.nc" \
            "hycom1_75_800m.nc" "interpolate_zgrid_40L.nc" "KH_background_2d.nc" "land_mask.nc" \
  	  "land_mosaic_tile1Xocean_mosaic_tile1.nc" "layer_coord.nc" \
  	  "MOM_channels_SPEAR" "ocean_hgrid.nc" "ocean_mask.nc" "ocean_mosaic.nc" \
  	  "seawifs_1998-2006_smoothed_2X.nc" "tidal_amplitude.nc" \
  	  "topog.nc" "ufs.topo_edits_011818.nc" "vgrid_75_2m.nc" )
  for ifn in "${ocn_fns[@]}" ; do
    ifp="${FIXufsda}/DATA_fix/MOM6/${ifn}"
    if [ -e "${ifp}" ]; then
      ln -nsf ${ifp} .
    else
      err_exit "Symlink failed: ${ifp} does not exist."
    fi
  done
  
  ## MOM6 input namelist files
  cp -p "${PARMufsda}/templates/template.${APP}.MOM_input" MOM_input
  cp -p "${PARMufsda}/templates/template.${APP}.MOM_override" MOM_override

  ## IC (initial condition) files for cold start
  if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${IC_FROM_FIX_DIR}" = "YES" ]; then
      data_dir="${FIXufsda}/DATA_ics/${PDY}/${cyc}"
    else
      data_dir="${COMINOUT}"
    fi
    ln -nsf "${data_dir}/MOM6_IC_TS.nc" .
  fi

  ## restart files
  if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
      data_dir="${WARMSTART_DIR}"
    else
      data_dir="${COMINOUTcm1}/RESTART"
    fi
    r_fp="${data_dir}/${filedate}.MOM.res.nc"
    if [ -e "${r_fp}" ]; then
      ln -nsf "${r_fp}" "MOM.res.nc"
    else
      err_exit "Symlink failed: ${r_fp} file does not exist."
    fi
  fi
  cd ${DATA}
fi

###############
# CICE files
###############
if [ "${ice_model}" = "cice6" ]; then
  # set ice_in
  settings="\
  'yyyymmdd': !!str ${PDY}
  'yyyy': !!str ${YYYY}
  'yyyy_last': !!str ${nYYYY}
  'yyyy_align': !!str ${YYYY}
  'mm': !!str ${MM}
  'dd': !!str ${DD}
  'hh_sec': !!str ${HHsec_5d}
  'DT_ATMOS': ${DT_ATMOS}
  'ICE_DOMAIN_NPROCS': ${ICE_DOMAIN_NPROCS}
  'ice_runtype': ${ice_runtype}
  'ice_use_restart_time': ${ice_use_restart_time}
  'OUTPUT_FH_CICE': ${OUTPUT_FH_CICE}
" # End of settings variable
  fp_template="${PARMufsda}/templates/template.ice_in"
  fn_namelist="ice_in"
  ${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

  # fix files
  ice_fns=( "grid_cice_NEMS_mx100.nc" "kmtu_cice_NEMS_mx100.nc" "mesh.mx100.nc" )
  for ifn in "${ice_fns[@]}" ; do
    ifp="${FIXufsda}/DATA_fix/CICE/${ifn}"
    if [ -e "${ifp}" ]; then
      ln -nsf ${ifp} .
    else
      err_exit "Symlink failed: ${ifp} does not exist."
    fi
  done

  # CICE histoy directory
  mkdir -p history

  # IC (initial condition) files for cold start
  if [ "${COLDSTART}" = "YES" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${IC_FROM_FIX_DIR}" = "YES" ]; then
      data_dir="${FIXufsda}/DATA_ics/${PDY}/${cyc}"
    else
      data_dir="${COMINOUT}"
    fi
    ln -nsf "${data_dir}/cice_model.res.nc" .
  fi

  # CMEPS restart and pointer files
  if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
      data_dir="${WARMSTART_DIR}"
    else
      data_dir="${COMINOUTcm1}/RESTART"
    fi
    r_fn="iced.${YYYY}-${MM}-${DD}-${HHsec_5d}.nc"
    r_fp="${data_dir}/${r_fn}"
    if [ -e "${r_fp}" ]; then
      ln -nsf "${r_fp}" "RESTART/${r_fn}"
      ls -1 "./RESTART/${r_fn}">ice.restart_file
    else
      err_exit "Symlink failed: ${r_fp} file does not exist."
    fi
  fi
fi

##############
# WW3 files
##############
if [ "${wav_model}" = "ww3" ]; then
  # set ww3_shel.nml
  output_fh_ww3_sec=$(( OUTPUT_FH_WW3 * 3600 ))
  settings="\
  'output_fh_ww3_sec': ${output_fh_ww3_sec}
" # End of settings variable
  fp_template="${PARMufsda}/templates/template.${APP}.ww3_shel.nml"
  fn_namelist="ww3_shel.nml"
  ${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

  # fix files	
  wav_fns=( "mod_def.ww3" "ww3_points.list" "mesh.global_270k.nc" )
  for ifn in "${wav_fns[@]}" ; do
    ifp="${FIXufsda}/DATA_fix/WW3/${ifn}"
    if [ -e "${ifp}" ]; then
      ln -nsf ${ifp} .
    else
      err_exit "Symlink failed: ${ifp} does not exist."
    fi
  done
  # CMEPS restart files
  if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
    if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
      data_dir="${WARMSTART_DIR}"
    else
      data_dir="${COMINOUTcm1}"
    fi
    r_fn="ufs.cpld.ww3.r.${YYYY}-${MM}-${DD}-${HHsec_5d}.nc"
    r_fp="${data_dir}/${r_fn}"
    if [ -e "${r_fp}" ]; then
      ln -nsf "${r_fp}" .
    else
      err_exit "Symlink failed: ${r_fp} file does not exist."
    fi
  fi
fi

##############
# CMEPS files
##############
if [ "${COLDSTART}" = "NO" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
  if [ "${COLDSTART}" = "NO" ] && [ "${PDY}${cyc}" = "${DATE_FIRST_CYCLE:0:10}" ]; then
    data_dir="${WARMSTART_DIR}"
  else
    data_dir="${COMINOUTcm1}/RESTART"
  fi
  # Restart from RESTART and pointer files
  r_fn="ufs.cpld.cpl.r.${YYYY}-${MM}-${DD}-${HHsec_5d}.nc"
  r_fp="${data_dir}/${r_fn}"
  if [ -e "${r_fp}" ]; then
    ln -nsf "${r_fp}" .
    ls -1 "${r_fn}">rpointer.cpl
  else
    err_exit "Symlink failed: ${r_fp} file does not exist."
  fi
fi

##########################
# Run ufs-weather-model
##########################
app_lower=$(echo ${APP} | tr '[A-Z]' '[a-z]')
export pgm="ufs_model_${app_lower}"
. prep_step
${run_cmd} --label -n ${nprocs_forecast} ${EXECufsda}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk
cp errfile errfile_ufs_model
if [[ $err != 0 ]]; then
  err_exit "ufs_model failed"
fi

##################################
# Copy output files to COMINOUT
##################################
########
# FV3
########
if [ "${atm_model}" = "fv3" ]; then
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
      cp -p "${DATA}/atmf${ihr_3d}.tile${itile}.nc" "${COMINOUT}/${NET}.${cycle}.atm.f${ihr_3d}.c${RES}.tile${itile}.nc"
      cp -p "${DATA}/sfcf${ihr_3d}.tile${itile}.nc" "${COMINOUT}/${NET}.${cycle}.sfc.f${ihr_3d}.c${RES}.tile${itile}.nc"
    done
  done
fi

#########
# MOM6
#########
if [ "${ocn_model}" = "mom6" ]; then
  # time-averaged => output time line is different
  cp -rp "${DATA}/MOM6_OUTPUT" ${COMINOUT}
  out_start_mom6=$(( OUTPUT_FH_MOM6 / 2 ))
  list_out_fh_mom6=$(seq ${out_start_mom6} ${OUTPUT_FH_MOM6} ${FCST_HRS})
  for ihr in ${list_out_fh_mom6}
  do
    idate=$($NDATE ${ihr} $PDY$cyc)
    iyyyy=${idate:0:4}
    imm=${idate:4:2}
    idd=${idate:6:2}
    ihh=${idate:8:2}
    ihr_3d=$(printf "%03d" "${ihr}")
    cp -p "${DATA}/MOM6_OUTPUT/ocn_${iyyyy}_${imm}_${idd}_${ihh}.nc" "${COMINOUT}/${NET}.${cycle}.ocn.f${ihr_3d}.c${RES}.nc"
  done
fi

#########
# CICE
#########
if [ "${ice_model}" = "cice6" ]; then
  # time-averaged if hist_avg = true in ice_in
  # output frequency: output time is not based on forecast hours but based on wall-clock hour
  cp -rp "${DATA}/history" ${COMINOUT}
  output_fh_cice_2d=$(printf "%02d" "${OUTPUT_FH_CICE}")
  fdate_fcst=$($NDATE ${FCST_HRS} ${PDY}${cyc})
  idate="${PDY}00"
  ihr="0"
  icnt="0"
  while [ "${idate}" -le "${fdate_fcst}" ]; do
    if (( "${idate}" > "${PDY}${cyc}" )); then
      iyyyy=${idate:0:4}
      imm=${idate:4:2}
      idd=${idate:6:2}
      ihh=${idate:8:2}
      ihh_nz="${ihh#0}"
      if (( "${icnt}" == 0 )); then
        ihr0=$(( cyc - ihh_nz ))
        ihr=$(( ihr + ihr0 ))
        icnt=$(( icnt + 1 ))
      fi
      ihh_sec=$(( ihh_nz * 3600 ))
      ihh_sec_5d=$(printf "%05d" "${ihh_sec}")
      ihr=$(( ihr + OUTPUT_FH_CICE ))
      ihr_3d=$(printf "%03d" "${ihr}")
      cp -p "${DATA}/history/iceh_${output_fh_cice_2d}h.${iyyyy}-${imm}-${idd}-${ihh_sec_5d}.nc" "${COMINOUT}/${NET}.${cycle}.ice.f${ihr_3d}.c${RES}.nc"
    fi
    idate=$($NDATE ${OUTPUT_FH_CICE} ${idate})
  done
fi

########
# WW3
########
if [ "${wav_model}" = "ww3" ]; then
  cp -p *.out_grd.ww3 ${COMINOUT}
  cp -p *.out_pnt.ww3.nc ${COMINOUT}
  cp -p out.pnt_wght.ww3.nc ${COMINOUT}
  list_out_fh_ww3=$(seq ${OUTPUT_FH_WW3} ${OUTPUT_FH_WW3} ${FCST_HRS})
  for ihr in ${list_out_fh_ww3}
  do
    idate=$($NDATE ${ihr} $PDY$cyc)
    ipdy=${idate:0:8}
    ihh=${idate:8:2}
    ihr_3d=$(printf "%03d" "${ihr}")
    cp -p "${DATA}/${ipdy}.${ihh}0000.out_pnt.ww3.nc" "${COMINOUT}/${NET}.${cycle}.wav.f${ihr_3d}.c${RES}.nc"
  done
  cp -p ufs.cpld.ww3.r.* ${COMINOUT}
fi

# RESTART directory
cp -p ${DATA}/RESTART/* ${COMINOUTrestart}

# Set sfc_data to DATA_RESTART to trigger ANALYSIS task in next cycle
if [ "${DO_FREE_FORECAST}" = "first" ]; then
  ln -nsf ${COMINOUTrestart}/*.sfc_data.tile*.nc ${DATA_RESTART}
else
  for itile in {1..6};
  do
    ln -nsf "${COMINOUTrestart}/${nYYYY}${nMM}${nDD}.${nHH}0000.sfc_data.tile${itile}.nc" ${DATA_RESTART}/.
  done
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

