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

# Set other dates
YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}
PTIME=$($NDATE -${DATE_CYCLE_FREQ_HR} $PDY$cyc)
YYYYp=${PTIME:0:4}
MMp=${PTIME:4:2}
DDp=${PTIME:6:2}
HHp=${PTIME:8:2}

filedate=${YYYY}${MM}${DD}.${HH}0000

machines_srun=( "gaeac6" "hera" "hercules" "orion" "ursa" )
if [[ ${machines_srun[@]} =~ "${MACHINE}" ]]; then
  run_cmd="srun"
else
  run_cmd=`which mpiexec`
fi

# Global parameters
orog_path="${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}"
orog_fn_base="C${RES}_oro_data"
fn_ice_data=""
fn_ice_incr=""
fn_ocn_data=""
fn_ocn_incr=""
fn_sfc_data=""
fn_sfc_incr=""
if [ "${FRAC_GRID}" = "YES" ]; then
  snowdepth_vn="snodl"
else
  snowdepth_vn="snwdph"
fi

###################################
# C-test of JEDI model component
###################################
if [ "${DO_FREE_FORECAST}" = "ctest" ]; then
  #########
  # SOCA
  #########
  if [ "${JEDI_TYPE_SOCA}" = "YES" ]; then
    ## Path to data set
    path_soca_data="${JEDI_BIN_PATH}/../../jedi-bundle/soca/test"
    mkdir -p data_output
    mkdir -p testoutput
    mkdir -p data_generated

    ## Symlink data/input directories
    ln -nsf "${path_soca_data}/Data" "data_static"
    ln -nsf "${path_soca_data}/testinput" .
    ln -nsf "${path_soca_data}/testref" .

    ## Symlink data files for gridgen
    ln -nsf "data_static/workdir/diag_table" .
    ln -nsf "data_static/workdir/field_table" .

    ##################################################################
    ## Run "JEDI_ALGORITHM" and its pre-requisite tasks in sequence
    ##################################################################
    ## Set list of tasks and executable name for jedi algorithm
    if [ "${JEDI_ALGORITHM}" = "3dvar" ]; then
      list_soca_tasks=("gridgen" "setcorscales" "parameters_diffusion" "${JEDI_ALGORITHM}")
      jedi_exe_soca_fn="soca_var.x"
    elif [ "${JEDI_ALGORITHM}" = "3dvarfgat_pseudo" ]; then
      list_soca_tasks=("gridgen" "setcorscales" "parameters_diffusion" \
	               "forecast_mom6" "${JEDI_ALGORITHM}")
      jedi_exe_soca_fn="soca_var.x"
    else
      list_soca_tasks=("${JEDI_ALGORITHM}")
      jedi_exe_soca_fn="soca_${JEDI_ALGORITHM}.x"
    fi
    for isoca in "${list_soca_tasks[@]}"; do
      ### JEDI input yaml file
      jedi_nml_fn="${isoca}.yml"
      cp -p "${path_soca_data}/testinput/${jedi_nml_fn}" .
 
      ### Run JEDI executable
      if [ "${isoca}" = "forecast_mom6" ]; then
        export BIN_DIR="${JEDI_BIN_PATH}"
        export MPIEXE="${run_cmd}"
        # To avoid file replacement
        [[ -e "input.nml" ]] && rm input.nml
        py_exe_path="${JEDI_BIN_PATH}/../../jedi-bundle/soca/test"
        ${py_exe_path}/mom6solo.py ${jedi_nml_fn}
        if [ $? -ne 0 ]; then
          err_exit "SOCA c-test FORECAST_MOM6 failed"
        fi
        [[ -e "input.nml" ]] && rm input.nml
      else
        if [ "${isoca}" = "${JEDI_ALGORITHM}" ]; then
          jedi_exe_fn="${jedi_exe_soca_fn}"
        elif [ "${isoca}" = "parameters_diffusion" ]; then
          jedi_exe_fn="soca_error_covariance_toolbox.x"
        else
          jedi_exe_fn="soca_${isoca}.x"
        fi
        export pgm="${jedi_exe_fn}"
        . prep_step
        ${run_cmd} -n ${NPROCS_ANALYSIS} ${JEDI_BIN_PATH}/$pgm ${jedi_nml_fn} >>$pgmout 2>errfile
        export err=$?; err_chk
        cp errfile errfile_ctest_${isoca}
        if [[ $err != 0 ]]; then
          err_exit "JEDI SOCA C-test for ${isoca} failed"
        fi
      fi

      ### Copy output files
      mkdir -p "data_generated/${isoca}"
      cp -p data_output/* "data_generated/${isoca}"
      
      echo "========== SOCA task ${isoca} completed !!! =========="
    done

  fi

  # Copy observation files to COMINOUT
  cp -p data_static/obs/sst.nc "${COMINOUTobs}/obs.${PDY}.${cycle}.sst.nc"
  cp -p data_static/obs/sss.nc "${COMINOUTobs}/obs.${PDY}.${cycle}.sss.nc"
  cp -p data_static/obs/adt.nc "${COMINOUTobs}/obs.${PDY}.${cycle}.adt.nc"
  cp -p data_static/obs/prof.nc "${COMINOUTobs}/obs.${PDY}.${cycle}.prof.nc"
  cp -p data_static/obs/icec.nc "${COMINOUTobs}/obs.${PDY}.${cycle}.icec.nc"

  # Copy output to COMINOUT
  cp -rp data_generated/* ${COMINOUT}
  cp -p data_output/* ${COMINOUT}

  # Copy H(x) output to COMINOUT
  cp -p data_output/sst.nc "${COMINOUThofx}/diag.SeaSurfaceTemp_${PDY}${cyc}.nc"
  cp -p data_output/sss.nc "${COMINOUThofx}/diag.SeaSurfaceSalinity_${PDY}${cyc}.nc"
  cp -p data_output/adt.nc "${COMINOUThofx}/diag.ADT_${PDY}${cyc}.nc"
  cp -p data_output/prof_T.nc "${COMINOUThofx}/diag.InsituTemperature_${PDY}${cyc}.nc"
  cp -p data_output/prof_S.nc "${COMINOUThofx}/diag.InsituSalinity_${PDY}${cyc}.nc"

  # Set and symlink output/increment file names for plotting
  bkg_file_dir="data_static/72x35x25/restarts"
  anl_file_dir="data_output"

  fn_ocn_data="MOM.res.nc"
  fn_ocn_incr="MOM.incr.res.nc"
  if [ "${JEDI_ALGORITHM}" = "3dvarfgat_pseudo" ]; then
    fn_ocn_data_after="ocn.${JEDI_ALGORITHM}.an.${YYYY}-${MM}-${DD}T12:00:00Z.nc"
    fn_ocn_incr_orig="ocn.cor_rh.incr.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
  else
    fn_ocn_data_after="ocn.${JEDI_ALGORITHM}.an.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
    fn_ocn_incr_orig="ocn.${JEDI_ALGORITHM}.iter1.incr.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
  fi
  ln -nsf "${bkg_file_dir}/${fn_ocn_data}" "${fn_ocn_data}_soca_ctest_before_inc"
  ln -nsf "${anl_file_dir}/${fn_ocn_data_after}" "${fn_ocn_data}_soca_ctest_after_inc"
  ln -nsf "${anl_file_dir}/${fn_ocn_incr_orig}" ${fn_ocn_incr}

  if [ "${JEDI_ALGORITHM}" = "3dvar" ]; then
    cp -p data_output/sst_coolskin.nc "${COMINOUThofx}/diag.CoolSkin_${PDY}${cyc}.nc"
    cp -p data_output/icec.nc "${COMINOUThofx}/diag.SeaIceFraction_${PDY}${cyc}.nc"

    fn_sfc_data="sfc.res.nc"
    fn_sfc_incr="sfc.incr.res.nc"
    fn_sfc_data_after="sfc.${JEDI_ALGORITHM}.an.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
    fn_sfc_incr_orig="sfc.${JEDI_ALGORITHM}.iter1.incr.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
    fn_ice_data="cice.res.nc"
    fn_ice_incr="cice.incr.res.nc"
    fn_ice_data_after="ice.${JEDI_ALGORITHM}.an.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
    fn_ice_incr_orig="ice.${JEDI_ALGORITHM}.iter1.incr.${YYYY}-${MM}-${DD}T${HH}:00:00Z.nc"
    ln -nsf "${bkg_file_dir}/${fn_sfc_data}" "${fn_sfc_data}_soca_ctest_before_inc"
    ln -nsf "${anl_file_dir}/${fn_sfc_data_after}" "${fn_sfc_data}_soca_ctest_after_inc"
    ln -nsf "${anl_file_dir}/${fn_sfc_incr_orig}" ${fn_sfc_incr}
    ln -nsf "${bkg_file_dir}/${fn_ice_data}" "${fn_ice_data}_soca_ctest_before_inc"
    ln -nsf "${anl_file_dir}/${fn_ice_data_after}" "${fn_ice_data}_soca_ctest_after_inc"
    ln -nsf "${anl_file_dir}/${fn_ice_incr_orig}" ${fn_ice_incr}
  fi
fi

##################
# SOCA analysis
##################
if [ "${JEDI_TYPE_SOCA}" = "YES" ] && [ "${DO_FREE_FORECAST}" != "ctest" ]; then

    if [ "${JEDI_ALGORITHM}" = "3dvar" ]; then
      # Set JEDI executable
      jedi_exe_fn="soca_var.x"
    fi

    # JEDI field metadata file
    fn_fmeta_template="fv3jedi_fieldmetadata_soca.yaml"
    fn_fmeta="fv3jedi_fieldmetadata.yaml"
    cp -p "${PARMufsda}/jedi/fieldmetadata/${fn_fmeta_template}" ${fn_fmeta}

    # Copy JEDI input yaml file
    jedi_nml_fn="jedi_${JEDI_ALGORITHM}_soca_${PDY}${cyc}.yaml"
    if [ "${CUSTOM_JEDI_CONFIG_FLAG}" = "YES" ]; then
      cp -p "${CUSTOM_JEDI_CONFIG_PATH}/${CUSTOM_JEDI_CONFIG_PREFIX}_${PDY}${cyc}.yaml" ${jedi_nml_fn}
    else
      cp -p "${COMINOUT}/${jedi_nml_fn}" .
    fi

    # Run JEDI executable
    export pgm="${jedi_exe_fn}"
    . prep_step
    ${run_cmd} -n ${NPROCS_ANALYSIS} ${JEDI_BIN_PATH}/$pgm ${jedi_nml_fn} >>$pgmout 2>errfile
    export err=$?; err_chk
    cp errfile errfile_fv3jedi_x
    if [[ $err != 0 ]]; then
      err_exit "JEDI DA failed"
    fi

fi

##################################
# Snow / Soil-moisture analysis
##################################
if [ -n "${list_jedi_land}" ] && [ "${DO_FREE_FORECAST}" != "ctest" ]; then
  # Copy sfc_data files from RESTART/WARMSTART into work directory
  for itile in {1..6}
  do
    sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
    if [ -f ${DATA_RESTART}/${sfc_fn} ]; then
      cp -p ${DATA_RESTART}/${sfc_fn} .
    elif [ -f ${WARMSTART_DIR}/${sfc_fn} ]; then
      cp -p ${WARMSTART_DIR}/${sfc_fn} .
    else
      err_exit "Initial sfc_data files do not exist"
    fi
    ## copy sfc_data file for comparison
    cp -p ${sfc_fn} "${sfc_fn}_ini"
  done
  
  # Copy obserbation files to work directory
  mkdir -p ${DATA}/obs
  obs_prefix="obs.${PDY}.${cycle}"
  if [ "${OBS_GHCN_SNOW}" = "YES" ]; then
    ln -nsf "${COMINOUTobs}/${obs_prefix}.ghcn_snow.nc" "${DATA}/obs"
  fi
  if [ "${OBS_IMS_SNOW}" = "YES" ]; then
    ln -nsf "${COMINOUTobs}/${obs_prefix}.ims_snow.tm00.nc" "${DATA}/obs"
  fi
  if [ "${OBS_SFCSNO}" = "YES" ]; then
    ln -nsf "${COMINOUTobs}/${obs_prefix}.sfcsno.tm00.bufr_d" "${DATA}/obs"
    ln -nsf "${PARMufsda}/jedi/bufr_sfcsno_mapping.yaml" "${DATA}/obs"
  fi
  if [ "${OBS_SMAP}" = "YES" ]; then
    ln -nsf "${COMINOUTobs}/${obs_prefix}.smap_combined.nc" "${DATA}/obs"
  fi
  if [ "${OBS_SMOPS}" = "YES" ]; then
    ln -nsf "${COMINOUTobs}/${obs_prefix}.smops.nc" "${DATA}/obs"
  fi
  
  # Update coupler.res file
  settings="\
  'yyyp': !!str ${YYYYp}
  'mp': !!str ${MMp}
  'dp': !!str ${DDp}
  'hp': !!str ${HHp}
  'yyyy': !!str ${YYYY}
  'mm': !!str ${MM}
  'dd': !!str ${DD}
  'hh': !!str ${HH}
" # End of settings variable

  fp_template="${PARMufsda}/templates/template.coupler.res"
  fn_namelist="${DATA}/${filedate}.coupler.res"
  ${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"
  
  # Copy static data files
  mkdir -p ${DATA}/Data/fv3files
  cp -p ${FIXufsda}/DATA_jedi/fv3files/fmsmpp.nml ${DATA}/Data/fv3files/.
  cp -p ${FIXufsda}/DATA_jedi/fv3files/field_table_ufs ${DATA}/Data/fv3files/field_table
  cp -p ${FIXufsda}/DATA_jedi/fv3files/akbk${NPZ}.nc4 ${DATA}/Data/fv3files/akbk.nc4
  
  ln -nsf ${orog_path}/${orog_fn_base}.tile* .
  
  # Link snow shadow level nicas data file
  mkdir -p ${DATA}/berror
  ln -nsf ${FIXufsda}/DATA_fix/JEDI/snow_bump_nicas_250km_shadowlevels_nicas.nc ${DATA}/berror/.
  
  # Run JEDI Analyses
  list_jedi_types=(${list_jedi_land})
  echo "List of JEDI analyses for land: ${list_jedi_types[@]}"
  for jedi_type in "${list_jedi_types[@]}"; do
    echo "JEDI analysis for ${jedi_type}"
    # Intermediate/Output directories
    dir_list=("${DATA}/diags" "${DATA}/anl" "${DATA}/bkg" "${DATA}/test")
    for dir in "${dir_list[@]}"; do
      if [ -d "${dir}" ]; then
        echo "Removing existing directory: $dir"
        rm -rf $dir
      fi
      echo "Creating directory: $dir"
      mkdir -p $dir
    done
  
    # Set up background
    if [ "${JEDI_ALGORITHM}" = "3dvar" ]; then
      for itile in {1..6}
      do
        sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
        sfc_bkg_fn="${filedate}.sfc_data.tile${itile}.nc"
        cp -p ${sfc_fn} "${DATA}/bkg/${sfc_bkg_fn}"
        ln -nsf "${orog_path}/${orog_fn_base}.tile${itile}.nc" "${DATA}/bkg/."
      done
      cp -p ${filedate}.coupler.res ${DATA}/bkg
  
      # Set JEDI executable
      jedi_exe_fn="fv3jedi_var.x"
  
    elif [ "${JEDI_ALGORITHM}" = "letkf-oi" ]; then
      if [ "${jedi_type}" = "snow" ]; then
        for ens in {1..2}
        do
          mkdir -p $DATA/mem${ens}
          cp -p ${filedate}.sfc_data.tile*.nc ${DATA}/mem${ens}
          cp -p ${filedate}.coupler.res ${DATA}/mem${ens}
          ln -nsf ${orog_path}/${orog_fn_base}.tile*.nc ${DATA}/mem${ens}
        done
  
        ${USHufsda}/letkf_create_ens.py $filedate $snowdepth_vn 30
        if [[ $? != 0 ]]; then
          err_exit "letkf-oi create failed"
        fi
      else
        ln -nsf ${orog_path}/${orog_fn_base}.tile*.nc ${DATA}
      fi
      # Set JEDI executable
      jedi_exe_fn="fv3jedi_letkf.x"
    fi
  
    # JEDI field metadata file
    if [ "${jedi_type}" = "snow" ]; then
      if [ "${FRAC_GRID}" = "YES" ]; then
        fn_fmeta_template="fv3jedi_fieldmetadata_restart_${jedi_type}.yaml"
      else
        fn_fmeta_template="fv3jedi_fieldmetadata_restart_${jedi_type}_nofrac.yaml"
      fi
    elif [ "${jedi_type}" = "soil_moisture" ]; then
      fn_fmeta_template="fv3jedi_fieldmetadata_restart_${jedi_type}.yaml"
    fi
    fn_fmeta="fv3jedi_fieldmetadata_restart.yaml"
    cp -p "${PARMufsda}/jedi/fieldmetadata/${fn_fmeta_template}" ${fn_fmeta}
  
    # Copy JEDI input yaml file
    jedi_nml_fn="jedi_${JEDI_ALGORITHM}_${jedi_type}_${PDY}${cyc}.yaml"
    if [ "${CUSTOM_JEDI_CONFIG_FLAG}" = "YES" ]; then
      cp -p "${CUSTOM_JEDI_CONFIG_PATH}/${CUSTOM_JEDI_CONFIG_PREFIX}_${PDY}${cyc}.yaml" ${jedi_nml_fn}
    else
      cp -p "${COMINOUT}/${jedi_nml_fn}" .
    fi
  
    export pgm="${jedi_exe_fn}"
    . prep_step
    ${run_cmd} -n ${NPROCS_ANALYSIS} ${JEDI_BIN_PATH}/$pgm ${jedi_nml_fn} >>$pgmout 2>errfile
    export err=$?; err_chk
    cp errfile errfile_fv3jedi_x
    if [[ $err != 0 ]]; then
      err_exit "JEDI DA failed"
    fi
  
    # save intermediate sfc_data files before applying increment
    for itile in {1..6}
    do
      sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
      cp -p ${sfc_fn} "${sfc_fn}_${jedi_type}_before_inc"
    done
  
    # Apply snow increment to UFS sfc_data files
    if [ "${jedi_type}" = "snow" ]; then
      ## Link inc file to DATA
      if [ "${JEDI_ALGORITHM}" = "3dvar" ]; then
        inc_fp_prefix="${DATA}/anl/snowinc.${filedate}.sfc_data"
      elif [ "${JEDI_ALGORITHM}" = "letkf-oi" ]; then
        inc_fp_prefix="${DATA}/${filedate}.snowinc.sfc_data"
      fi
      inc_fn_prefix="snowinc.${filedate}.sfc_data"
      for itile in {1..6}
      do
        cp -p "${inc_fp_prefix}.tile${itile}.nc" "${DATA}/${inc_fn_prefix}.tile${itile}.nc"
      done
  
      if [ "${FRAC_GRID}" = "YES" ]; then
        frac_grid=".true."
      else
        frac_grid=".false."
      fi
  
      cat << EOF > apply_incr_nml
&noahmp_snow
 date_str = "${YYYY}${MM}${DD}",
 hour_str = "${HH}",
 res = ${RES},
 frac_grid = ${frac_grid},
 rst_path = "${DATA}",
 inc_path = "${DATA}",
 orog_path = "${orog_path}",
 otype = "${orog_fn_base}"
/
EOF

      export pgm="apply_incr.exe"
      . prep_step
      ## (n=6): this is fixed, at one task per tile (with minor code change). 
      ${run_cmd} -n 6 ${EXECufsda}/$pgm >>$pgmout 2>errfile
      export err=$?; err_chk
      cp errfile errfile_apply_incr
      if [[ $err != 0 ]]; then
        err_exit "apply snow increment failed"
      fi
  
      ## Save intermediate sfc_data files after applying increment
      for itile in {1..6}
      do
        sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
        cp -p ${sfc_fn} "${sfc_fn}_${jedi_type}_after_inc"
      done
  
    elif [ "${jedi_type}" = "soil_moisture" ]; then
      ## Link inc file to DATA
      if [ "${JEDI_ALGORITHM}" = "3dvar" ]; then
        inc_fp_prefix="${DATA}/anl/smcinc.${filedate}.sfc_data"
      elif [ "${JEDI_ALGORITHM}" = "letkf-oi" ]; then
        inc_fp_prefix="${DATA}/${filedate}.smcinc.sfc_data"
      fi
      inc_fn_prefix="smcinc.${filedate}.sfc_data"
      for itile in {1..6}
      do
        cp -p "${inc_fp_prefix}.tile${itile}.nc" "${DATA}/${inc_fn_prefix}.tile${itile}.nc"
      done
  
      ## Replace smc of sfc_data with that of JEDI output files (temporary solution)
      fn_data_base="${filedate}.sfc_data.tile"
      sfc_data_fn_suffix=".nc_${jedi_type}_before_inc"
      jedi_out_fn_prefix="jedi_smc."
      jedi_out_fn_suffix=".nc"
      new_sfc_data_fn_suffix=".nc_${jedi_type}_replaced"
      cat > sfc_replace_var.yaml << EOF
work_dir: '${DATA}'
fn_data_base: '${fn_data_base}'
sfc_data_fn_suffix: '${sfc_data_fn_suffix}'
jedi_out_fn_prefix: '${jedi_out_fn_prefix}'
jedi_out_fn_suffix: '${jedi_out_fn_suffix}'
new_sfc_data_fn_suffix: '${new_sfc_data_fn_suffix}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
EOF

      ${USHufsda}/sfc_data_replace_var.py
      if [ $? -ne 0 ]; then
        err_exit "sfc_data var replacement failed"
      fi
  
      ## Save intermediate sfc_data files after applying increment
      for itile in {1..6}
      do
        sfc_fn="${fn_data_base}${itile}.nc"
        cp -p "${fn_data_base}${itile}${new_sfc_data_fn_suffix}" ${sfc_fn}
        cp -p ${sfc_fn} "${fn_data_base}${itile}.nc_${jedi_type}_after_inc"
      done
  
    fi
  
    # Copy the increment files to COMINOUT
    for itile in {1..6}
    do
      cp -p "${DATA}/${inc_fn_prefix}.tile${itile}.nc" ${COMINOUT}
    done  
  done
  
  ## Copy the final sfc_data files to COMINOUT
  for itile in {1..6}
  do
    cp -p "${DATA}/${filedate}.sfc_data.tile${itile}.nc" ${COMINOUT}
  done
  
  if [ -d diags ]; then
    cp -p diags/* ${COMINOUThofx}
    ln -nsf ${COMINOUThofx}/*.nc ${DATA_HOFX}
  fi

  ## Set file names for plotting
  fn_sfc_data="${filedate}.sfc_data.tile"
  fn_sfc_incr="${inc_fn_prefix}.tile"
fi

###############################################################
# Comparison plot of background and output by JEDI increment
###############################################################
DO_PLOT_COMP_JEDI_INCR="${DO_PLOT_COMP_JEDI_INCR:-YES}"
if [ "${DO_PLOT_COMP_JEDI_INCR}" = "YES" ]; then
  out_fn_base_prefix="ufsda_comp_"
  # zlevel_number is valid only for 3-D fields such as stc/smc/slc
  zlevel_number="1"

  cat > plot_analysis_comp_increment.yaml <<EOF
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
DO_FREE_FORECAST: '${DO_FREE_FORECAST}'
fn_ice_data: '${fn_ice_data}'
fn_ice_incr: '${fn_ice_incr}'
fn_ocn_data: '${fn_ocn_data}'
fn_ocn_incr: '${fn_ocn_incr}'
fn_sfc_data: '${fn_sfc_data}'
fn_sfc_incr: '${fn_sfc_incr}'
JEDI_ALGORITHM: '${JEDI_ALGORITHM}'
JEDI_TYPE_SNOW: '${JEDI_TYPE_SNOW}'
JEDI_TYPE_SOCA: '${JEDI_TYPE_SOCA}'
JEDI_TYPE_SOIL_MOISTURE: '${JEDI_TYPE_SOIL_MOISTURE}'
orog_path: '${orog_path}'
orog_fn_base: '${orog_fn_base}'
out_fn_base_prefix: '${out_fn_base_prefix}'
PDY: '${PDY}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
snowdepth_vn: '${snowdepth_vn}'
work_dir: '${DATA}'
zlevel_number: '${zlevel_number}'
EOF

  ${USHufsda}/plot_analysis_comp_increment.py
  if [ $? -ne 0 ]; then
    err_exit "JEDI increment comparison plot failed"
  fi

  # Copy result file to COMINOUT
  cp -p ${out_fn_base_prefix}* ${COMINOUTplot}
fi


##########################################################################
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
