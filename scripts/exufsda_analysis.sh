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

###################################################################
# Copy sfc_data files from RESTART/WARMSTART into work directory
###################################################################
for itile in {1..6}
do
  sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
  if [ -f ${DATA_RESTART}/${sfc_fn} ]; then
    cp -p ${DATA_RESTART}/${sfc_fn} .
  elif [ -f ${WARMSTART_DIR}/${sfc_fn} ]; then
    cp -p ${WARMSTART_DIR}/${sfc_fn} .
  else
    err_exit "FATAL ERROR: Initial sfc_data files do not exist"
  fi
  # copy sfc_data file for comparison
  cp -p ${sfc_fn} "${sfc_fn}_ini"
done

############################################
# Copy obserbation files to work directory
############################################
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

############################
# Update coupler.res file
############################
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

###########################
# Copy static data files
###########################
mkdir -p ${DATA}/Data/fv3files
cp -p ${FIXufsda}/DATA_jedi/fv3files/fmsmpp.nml ${DATA}/Data/fv3files/.
cp -p ${FIXufsda}/DATA_jedi/fv3files/field_table_ufs ${DATA}/Data/fv3files/field_table
cp -p ${FIXufsda}/DATA_jedi/fv3files/akbk${NPZ}.nc4 ${DATA}/Data/fv3files/akbk.nc4

orog_path="${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}"
orog_fn_base="C${RES}_oro_data"
ln -nsf ${orog_path}/${orog_fn_base}.tile* .

# Link snow shadow level nicas data file
mkdir -p ${DATA}/berror
ln -nsf ${FIXufsda}/DATA_fix/JEDI/snow_bump_nicas_250km_shadowlevels_nicas.nc ${DATA}/berror/.

################################################
# Run JEDI Analyses
################################################
if [ "${FRAC_GRID}" = "YES" ]; then
  snowdepth_vn="snodl"
else
  snowdepth_vn="snwdph"
fi
list_jedi_types=(${list_jedi_analyses})
echo "List of JEDI analyses: ${list_jedi_types[@]}"
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

  else # letkf-oi
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
        err_exit "FATAL ERROR: letkf-oi create failed"
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
      cp -p ${PARMufsda}/jedi/fieldmetadata/fv3jedi_fieldmetadata_restart.yaml ${DATA}/Data/fv3files/.
    else
      cp -p ${PARMufsda}/jedi/fieldmetadata/fv3jedi_fieldmetadata_restart_nofrac.yaml ${DATA}/Data/fv3files/fv3jedi_fieldmetadata_restart.yaml
    fi
  elif [ "${jedi_type}" = "soil_moisture" ]; then
    cp -p ${PARMufsda}/jedi/fieldmetadata/fv3jedi_fieldmetadata_restart_soil_moisture.yaml ${DATA}/Data/fv3files/fv3jedi_fieldmetadata_restart.yaml
  fi

  ##############################
  # Copy JEDI input yaml file
  ##############################
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
    err_exit "FATAL ERROR: JEDI DA failed"
  fi

  # save intermediate sfc_data files before applying increment
  for itile in {1..6}
  do
    sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
    cp -p ${sfc_fn} "${sfc_fn}_${jedi_type}_before_inc"
  done

  ################################################
  # Apply snow increment to UFS sfc_data files
  ################################################
  if [ "${jedi_type}" = "snow" ]; then
    # Link inc file to DATA
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
    # (n=6): this is fixed, at one task per tile (with minor code change). 
    ${run_cmd} -n 6 ${EXECufsda}/$pgm >>$pgmout 2>errfile
    export err=$?; err_chk
    cp errfile errfile_apply_incr
    if [[ $err != 0 ]]; then
      err_exit "FATAL ERROR: apply snow increment failed"
    fi

    # Save intermediate sfc_data files after applying increment
    for itile in {1..6}
    do
      sfc_fn="${filedate}.sfc_data.tile${itile}.nc"
      cp -p ${sfc_fn} "${sfc_fn}_${jedi_type}_after_inc"
    done

  elif [ "${jedi_type}" = "soil_moisture" ]; then
    # Link inc file to DATA
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

    # Replace smc of sfc_data with that of JEDI output files (temporary solution)
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
      err_exit "FATAL ERROR: sfc_data var replacement failed"
    fi

    # Save intermediate sfc_data files after applying increment
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

  ############################################################
  # Comparison plot of sfc_data by JEDI increment
  ############################################################
  DO_PLOT_SFC_COMP="${DO_PLOT_SFC_COMP:-YES}"
  if [ "${DO_PLOT_SFC_COMP}" = "YES" ]; then
    fn_sfc_base="${filedate}.sfc_data.tile"
    fn_inc_base="${inc_fn_prefix}.tile"
    out_title_base="UFS-DA::SFC-DATA::${jedi_type}::${PDY}::"
    out_fn_base="ufsda_comp_sfc_${jedi_type}_${PDY}_"
    # zlevel_number is valid only for 3-D fields such as stc/smc/slc
    zlevel_number="1"

    cat > plot_comp_sfc.yaml <<EOF
work_dir: '${DATA}'
fix_dir: '${FIXufsda}'
fn_sfc_base: '${fn_sfc_base}'
fn_inc_base: '${fn_inc_base}'
jedi_exe: '${JEDI_ALGORITHM}'
jedi_type: '${jedi_type}'
orog_path: '${orog_path}'
orog_fn_base: '${orog_fn_base}'
out_title_base: '${out_title_base}'
out_fn_base: '${out_fn_base}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
snowdepth_vn: '${snowdepth_vn}'
zlevel_number: '${zlevel_number}'
EOF

    ${USHufsda}/plot_comp_sfc_data.py
    if [ $? -ne 0 ]; then
      err_exit "FATAL ERROR: sfc_data comparison plot failed"
    fi

    # Copy result file to COMINOUT
    cp -p ${out_fn_base}* ${COMINOUTplot}
  fi

  ############################################################
  # Observation File Plot
  ############################################################
  DO_PLOT_OBS="${DO_PLOT_OBS:-YES}"
  if [ "${DO_PLOT_OBS}" = "YES" ]; then
    obs_prefix="obs.${PDY}.${cycle}"
    fn_input_ghcn="${obs_prefix}.ghcn_snow.nc"
    fn_input_ims="${obs_prefix}.ims_snow.tm00.nc"
    fn_input_smap="${obs_prefix}.smap_combined.nc"
    fn_input_smops="${obs_prefix}.smops.nc"

    # Soft-link the input file to DATA
    if [ "${OBS_GHCN_SNOW}" = "YES" ]; then
      ln -nsf "${COMINOUTobs}/${fn_input_ghcn}" .
    fi
    if [ "${OBS_IMS_SNOW}" = "YES" ]; then
      ln -nsf "${COMINOUTobs}/${fn_input_ims}" .
    fi
    if [ "${OBS_SMAP}" = "YES" ]; then
      ln -nsf "${COMINOUTobs}/${fn_input_smap}" .
    fi
    if [ "${OBS_SMOPS}" = "YES" ]; then
      ln -nsf "${COMINOUTobs}/${fn_input_smops}" .
    fi

    cat > plot_obs_file.yaml << EOF
work_dir: '${DATA}'
cartopy_ne_path: '${FIXufsda}/NaturalEarth'
fn_input_ghcn: '${fn_input_ghcn}'
fn_input_ims: '${fn_input_ims}'
fn_input_smap: '${fn_input_smap}'
fn_input_smops: '${fn_input_smops}'
OBS_GHCN_SNOW: '${OBS_GHCN_SNOW}'
OBS_IMS_SNOW: '${OBS_IMS_SNOW}'
OBS_SMAP: '${OBS_SMAP}'
OBS_SMOPS: '${OBS_SMOPS}'
PDY: '${PDY}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
EOF

    ${USHufsda}/plot_obs_file.py
    if [ $? -ne 0 ]; then
      err_exit "FATAL ERROR: Observation file plot failed"
    fi
    # Copy result file to COMINOUT
    cp -p *.png ${COMINOUTplot}
  fi

done

# Copy the final sfc_data files to COMINOUT
for itile in {1..6}
do
  cp -p "${DATA}/${filedate}.sfc_data.tile${itile}.nc" ${COMINOUT}
done

if [ -d diags ]; then
  cp -p diags/* ${COMINOUThofx}
  ln -nsf ${COMINOUThofx}/*.nc ${DATA_HOFX}
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

