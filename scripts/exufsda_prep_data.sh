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

# Set date and time
YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}

PTIME=$($NDATE -${DATE_CYCLE_FREQ_HR} $PDY$cyc)
YYYYp=${PTIME:0:4}
MMp=${PTIME:4:2}
DDp=${PTIME:6:2}
HHp=${PTIME:8:2}
PDYcm1=${PTIME:0:8}
COMINOUTcm1="${COMROOT}/${NET}/${model_ver}/${RUN}.${PDYcm1}"

#
#####################################################################
# JCB: JEDI configuration
#####################################################################
#

if [ "${CUSTOM_JEDI_CONFIG_FLAG}" = "NO" ]; then
  cycle_freq_hr_half=$(( DATE_CYCLE_FREQ_HR / 2 ))
  date_hf=$($NDATE -${cycle_freq_hr_half} $PDY$cyc)
  yyyy_hf=${date_hf:0:4}
  mm_hf=${date_hf:4:2}
  dd_hf=${date_hf:6:2}
  hh_hf=${date_hf:8:2}
  
  # JCB parameters
  driver_do_posterior_observer="false"
  driver_do_test_prints="false"
  driver_save_posterior_ensemble="false"
  driver_save_posterior_mean_increment="true"
  driver_update_obs_config_with_geometry_info="false"
  final_diagnostics_departures="anlmob"
  inflation_mult="1.0"
  inflation_rtpp="0.0"
  inflation_rtps="0.0"
  local_ensemble_da_solver="${JEDI_ALGORITHM^^}"
  land_background_time_fv3="${YYYY}${MM}${DD}.${HH}0000"
  land_background_time_iso="${YYYY}-${MM}-${DD}T${HH}:00:00Z"
  land_fv3jedi_files_path="Data/fv3files"
  land_window_begin="${yyyy_hf}-${mm_hf}-${dd_hf}T${hh_hf}:00:00Z"
  land_window_length="PT${DATE_CYCLE_FREQ_HR}H"
  
  # Algorithm-specific values
  if [ "${JEDI_ALGORITHM}" = "letkf-oi" ]; then
    jedi_algorithm_mod="local_ensemble_da"
    local_ensemble_da_solver="Deterministic LETKF"
  else
    jedi_algorithm_mod="${JEDI_ALGORITHM}"
  fi
  
  # Variable name of snow depth
  if [ "${FRAC_GRID}" = "YES" ]; then
    snowdepth_vn="snodl"
  else
    snowdepth_vn="snwdph"
  fi
   
  # Run JCB to create JEDI input yaml files
  list_jedi_types=(${list_jedi_analyses})
  echo "List of JEDI analyses: ${list_jedi_types[@]}"
  for jedi_type in "${list_jedi_types[@]}"; do
    echo "JEDI analysis for ${jedi_type}"
    if [ "${jedi_type}" = "snow" ]; then
      driver_save_posterior_mean="false"
      inc_fn_prefix="snowinc" 
    elif [ "${jedi_type}" = "soil_moisture" ]; then
      driver_save_posterior_mean="true"
      inc_fn_prefix="smcinc"
    fi
  
    # update jcb-base yaml file
    settings="\
    'FIXufsda': ${FIXufsda}
    'JEDI_ALGORITHM': ${JEDI_ALGORITHM}
    'jedi_algorithm_mod': ${jedi_algorithm_mod}
    'PARMufsda': ${PARMufsda}
    'RES': ${RES}
    'driver_do_posterior_observer': ${driver_do_posterior_observer}
    'driver_do_test_prints': ${driver_do_test_prints}
    'driver_save_posterior_ensemble': ${driver_save_posterior_ensemble}
    'driver_save_posterior_mean': ${driver_save_posterior_mean}
    'driver_save_posterior_mean_increment': ${driver_save_posterior_mean_increment}
    'driver_update_obs_config_with_geometry_info': ${driver_update_obs_config_with_geometry_info}
    'final_diagnostics_departures': ${final_diagnostics_departures}
    'inc_fn_prefix': ${inc_fn_prefix}
    'inflation_mult': ${inflation_mult}
    'inflation_rtpp': ${inflation_rtpp}
    'inflation_rtps': ${inflation_rtps}
    'jedi_type': ${jedi_type}
    'local_ensemble_da_solver': ${local_ensemble_da_solver}
    'land_window_begin': !!str ${land_window_begin}
    'land_window_length': ${land_window_length}
    'land_final_inc_file_path': ./
    'land_fv3jedi_files_path': ${land_fv3jedi_files_path}
    'land_layout_x': 1
    'land_layout_y': 1
    'land_npx_anl': ${res_p1}
    'land_npy_anl': ${res_p1}
    'land_npz_anl': ${NPZ}
    'land_npx_ges': ${res_p1}
    'land_npy_ges': ${res_p1}
    'land_npz_ges': ${NPZ}
    'land_background_path': bkg
    'land_background_time_fv3': !!str ${land_background_time_fv3}
    'land_background_time_iso': !!str ${land_background_time_iso}
    'land_bump_data_dir': berror
    'land_obsdatain_path': obs
    'land_obsdatain_prefix': "obs.${PDY}.${cycle}."
    'land_obsdataout_path': diags
    'land_obsdataout_prefix': "diag."
    'land_obsdataout_suffix': "_${PDY}${cyc}.nc"
    'land_orog_files_path': "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}"
    'snowdepth_vn': ${snowdepth_vn}
    'OBS_GHCN_SNOW': '${OBS_GHCN_SNOW}'
    'OBS_IMS_SNOW': '${OBS_IMS_SNOW}'
    'OBS_SFCSNO': '${OBS_SFCSNO}'
    'OBS_SMAP': '${OBS_SMAP}'
    'OBS_SMOPS': '${OBS_SMOPS}'
  " # End of settings variable
  
    template_fp="${PARMufsda}/jedi/jcb-base_land.yaml.j2"
    jcb_base_fn="jcb-base_${jedi_type}.yaml"
    jcb_base_fp="${DATA}/${jcb_base_fn}"
    jcb_out_fn="jedi_${JEDI_ALGORITHM}_${jedi_type}_${PDY}${cyc}.yaml"
    ${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${template_fp}" -o "${jcb_base_fp}"
      
    ${USHufsda}/jcb_setup.py -i "${jcb_base_fn}" -o "${jcb_out_fn}" -a "${JEDI_ALGORITHM}" -t "${jedi_type}" -g "${FRAC_GRID}" -l "${PY_LOG_LEVEL}"
      
    if [ $? -ne 0 ]; then
      err_exit "Generation of JEDI YAML file for ${jedi_type} by JCB failed !!!"
    fi
    cp -p ${jcb_out_fn} ${COMINOUT}
  done
else
  list_jedi_types=(${list_jedi_analyses})
  echo "List of JEDI analyses: ${list_jedi_types[@]}"
  for jedi_type in "${list_jedi_types[@]}"; do
    jcb_out_fn="jedi_${JEDI_ALGORITHM}_${jedi_type}_${PDY}${cyc}.yaml"
    cp -p "${CUSTOM_JEDI_CONFIG_PATH}/${CUSTOM_JEDI_CONFIG_PREFIX}_${PDY}${cyc}.yaml" "${COMINOUT}/${jcb_out_fn}"
  done
fi
echo "================ JCB COMPLETED !!! ==========================="
#
#####################################################################
# Observation Data Files
#####################################################################
#
if [ "${COLDSTART}" != "YES" ] || [ "${PDY}${cyc}" != "${DATE_FIRST_CYCLE:0:10}" ]; then
  obs_out_fn_ghcn=""
  obs_out_fn_ims=""
  obs_out_fn_smap=""
  # GHCN snow depth data
  if [ "${OBS_GHCN_SNOW}" = "YES" ]; then
    # GHCN are time-stamped at 18. If assimilating at 00, need to use previous day's obs, 
    # so that obs are within DA window.
    obs_fn="ghcn_snwd_ioda_${YYYYp}${MMp}${DDp}${HHp}.nc"
    obs_dp="${DCOMINobs}/ghcn/${YYYY}"
    obs_fp="${obs_dp}/${obs_fn}"
    obs_out_fn_ghcn="obs.${PDY}.${cycle}.ghcn_snow.nc"
  
    # Check if obs is available
    if [ -f "${obs_fp}" ]; then
      echo "GHCN observation file: ${obs_fp}"
      cp -p "${obs_fp}" "${obs_out_fn_ghcn}"
      cp -p "${obs_fp}" "${COMINOUTobs}/${obs_out_fn_ghcn}"
    elif [ -f "${obs_dp}/${obs_out_fn_ghcn}" ]; then
      echo "GHCN observation file: ${obs_dp}/${obs_out_fn_ghcn}"
      cp -p "${obs_dp}/${obs_out_fn_ghcn}" .
      cp -p "${obs_dp}/${obs_out_fn_ghcn}" "${COMINOUTobs}/${obs_out_fn_ghcn}"
    else
      input_ghcn_file="${DCOMINghcn}/${YYYYp}.csv"
      if [ ! -f "${input_ghcn_file}" ]; then
        echo "GHCN raw data path: ${DCOMINghcn}"
        echo "GHCN raw data file: ${YYYYp}.csv"
        err_exit "GHCN raw data file does not exist in designated path !!!"
      fi
      ghcn_station_file="${DCOMINghcn}/ghcnd-stations.txt"
  
      ${USHufsda}/ghcn_snod2ioda.py -i ${input_ghcn_file} -o ${obs_fn} -f ${ghcn_station_file} -d ${YYYYp}${MMp}${DDp}${HHp} -m maskout
      if [ $? -ne 0 ]; then
        err_exit "Generation of GHCN obs file failed !!!"
      fi
      cp -p "${obs_fn}" "${COMINOUTobs}/${obs_out_fn_ghcn}"
    fi
  fi

  # IMS snow data
  if [ "${OBS_IMS_SNOW}" = "YES" ]; then  
    # Check if pre-generated IMS obs file exists
    obs_fn="obs.${PDY}.${cycle}.ims_snow.tm00.nc"
    obs_dp="${DCOMINobs}/IMS/${PDY}"
    obs_fp="${obs_dp}/${obs_fn}"
    obs_out_fn_ims=${obs_fn}

    # Check if obs is available
    if [ -f "${obs_fp}" ]; then
      cp -p "${obs_fp}" .
      cp -p "${obs_fp}" "${COMINOUTobs}/${obs_out_fn_ims}"
    else
      # Set up input namelist for calcfIMS
      julian_day=$(date -d "${YYYY}-${MM}-${DD}" +%j)
      jdate="${YYYY}${julian_day}"
      orog_fn_base="C${RES}_oro_data"
      if [ "${PDY}${cyc}" -lt "20141203" ]; then
        imsversion="1.2"
      else
        imsversion="1.3"
      fi
      imsres="4km"

      if [ "${FRAC_GRID}" = "YES" ]; then
        frac_grid=".true."
      else
        frac_grid=".false."
      fi

cat > fims.nml << EOF
&fIMS_nml
  idim = ${RES}, 
  jdim = ${RES},
  jdate = "${jdate}",
  otype = "${orog_fn_base}",
  yyyymmddhh = "${YYYY}${MM}${DD}.${HH}",
  lsm = 2,
  imsformat = 1,
  imsres = "${imsres}",
  imsversion = "${imsversion}",
  frac_grid = ${frac_grid},
  fcst_path = "${DATA}/",
  IMS_obs_path = "${DATA}/",
  IMS_ind_path = "${DATA}/"
/
EOF

      # Copy IMS raw ascii file
      ims_asc_fn="ims${jdate}_${imsres}_v${imsversion}.asc"
      if [ "${IC_DATA_MODEL}" = "gfs" ] || [ "${IC_DATA_MODEL}" = "GFS" ]; then
        fn_data_prefix="gfs"
        dcom_path="${COMINgfs}"
      elif [ "${IC_DATA_MODEL}" = "gdas" ] || [ "${IC_DATA_MODEL}" = "GDAS" ]; then
        fn_data_prefix="gdas"
        dcom_path="${COMINgdas}"
      fi
      # Since JEDI is supposed to run at 18H, cyc is fixed to 18
      input_data_dir="${dcom_path}/${fn_data_prefix}.${PDY}/18/atmos"
      cp -p "${input_data_dir}/${fn_data_prefix}.t18z.imssnow${RES}.asc" "${DATA}/${ims_asc_fn}"
      # Soft-link mapping file
      ln -nsf "${FIXufsda}/DATA_ims/IMS4km_to_FV3_mapping.C${RES}_oro_data.nc" .

      # Copy sfc_data files into work directory
      for itile in {1..6}
      do
        sfc_m0="${YYYY}${MM}${DD}.${HH}0000.sfc_data.tile${itile}.nc"
        if [ -f ${DATA_RESTART}/${sfc_m0} ]; then
          ln -nsf ${DATA_RESTART}/${sfc_m0} ${DATA}
        elif [ -f ${WARMSTART_DIR}/${sfc_m0} ]; then
          ln -nsf ${WARMSTART_DIR}/${sfc_m0} ${DATA}
        else
          err_exit "sfc_data files do not exist"
        fi
      done
  
      # Run calcfIMS.exe
      export pgm="calcfIMS.exe"
      . prep_step
      ${EXECufsda}/$pgm >>$pgmout 2>errfile
      export err=$?; err_chk
      cp errfile errfile_calcfIMS
      if [[ $err != 0 ]]; then
        err_exit "calcfIMS failed"
      fi

      # Convert to IODA format
      fims_out_fn="IMSscf.${PDY}.C${RES}_oro_data.nc"
      ${USHufsda}/imsfv3_scf2ioda.py -i ${fims_out_fn} -o ${obs_out_fn_ims}
      if [ $? -ne 0 ]; then
        err_exit "Generation of IMS obs file failed !!!"
      fi
      cp -p ${obs_out_fn_ims} "${COMINOUTobs}/${obs_out_fn_ims}"
    fi
  fi

  # SFCSNO data
  if [ "${OBS_SFCSNO}" = "YES" ]; then
    sfcsno_fn_suffix="sfcsno.tm00.bufr_d"
    cp -p "${COMINgdas}/${PDY}/gdas.${cycle}.${sfcsno_fn_suffix}" "${COMINOUTobs}/obs.${PDY}.${cycle}.${sfcsno_fn_suffix}"
  fi

  # SMAP data
  if [ "${OBS_SMAP}" = "YES" ]; then
    obs_fn="obs.${PDY}.${cycle}.smap_combined.nc"
    obs_dp="${DCOMINobs}/SMAP/${YYYY}${MM}"
    obs_fp="${obs_dp}/${obs_fn}"
    obs_out_fn_smap="${obs_fn}"

    # Check if obs is available
    if [ -f "${obs_fp}" ]; then
      echo "SMAP observation file: ${obs_fp}"
      cp -p "${obs_fp}" "${obs_out_fn_smap}"
      cp -p "${obs_fp}" "${COMINOUTobs}/${obs_out_fn_smap}"
    else
      # Create smap_raw_data directory
      smap_raw_dir="${DATA}/smap_raw_data"
      fn_smap_prefix="SMAP_L2_SM_P_E"
      fn_smap_suffix=".h5"
      mkdir -p ${smap_raw_dir}

      # Specify time window for SMAP raw data (default: +-5 hours -> total 11 hours)
      SMAP_RAW_WINDOW_SPAN_HALF="${SMAP_RAW_WINDOW_SPAN_HALF:-0}"

      # IODA-converting
      if [ "${SMAP_RAW_WINDOW_SPAN_HALF}" -eq 0 ]; then
        ihr_smap_raw_dir="${DCOMINsmap}/${PDY}"

        found=false
        for file in "${ihr_smap_raw_dir}"/*; do
          filename=$(basename "${file}")
          if [ -f "${file}" ] && [[ "${filename}" == ${fn_smap_prefix}*"${PDY}T${cyc}"*${fn_smap_suffix} ]]; then
            ln -nsf "${file}" ${smap_raw_dir}
            echo "SMAP raw data file for ${PDY}${cyc} found in ${ihr_smap_raw_dir}."
	    smap_ioda_in_fn=${filename}
            found=true
	    break
          fi
        done  
        if ! $found; then
          err_exit "No matching file for ${PDY}${cyc} found in ${ihr_smap_raw_dir}!"
        fi
	# Run ioda converting script
        ${USHufsda}/smap_ssm2ioda.py -i "${smap_raw_dir}/${smap_ioda_in_fn}" -o ${obs_out_fn_smap} --maskMissing
        if [ $? -ne 0 ]; then
          err_exit "Generation of SMAP obs file failed !!!"
        fi
      else
        hftime_smap=$($NDATE -${SMAP_RAW_WINDOW_SPAN_HALF} $PDY$cyc)
        pdy_hf=${hftime_smap:0:8}
  
        # soft-link SMAP raw data files into smap_raw_data directory
        for ihr in $(seq -${SMAP_RAW_WINDOW_SPAN_HALF} ${SMAP_RAW_WINDOW_SPAN_HALF}); do
          ihr_date=$($NDATE $ihr $PDY$cyc)
          ihr_pdy=${ihr_date:0:8}
          ihr_cyc=${ihr_date:8:2}
          ihr_smap_raw_dir="${DCOMINsmap}/${ihr_pdy}"
  
          found=false
          for file in "${ihr_smap_raw_dir}"/*; do
            filename=$(basename "${file}")
            if [ -f "${file}" ] && [[ "${filename}" == ${fn_smap_prefix}*"${ihr_pdy}T${ihr_cyc}"*${fn_smap_suffix} ]]; then
              ln -nsf "${file}" ${smap_raw_dir}
              echo "SMAP raw data file for ${ihr_date} found in ${ihr_smap_raw_dir}."
              found=true
            fi
          done        
          if ! $found; then
            err_exit "No matching file for ${ihr_date} found in ${ihr_smap_raw_dir}!"
          fi
        done
  
        # Create input yaml file
        cat > smap_ioda_concat.yaml << EOF
fn_smap_prefix: '${fn_smap_prefix}'
fn_smap_suffix: '${fn_smap_suffix}'
obs_out_fn_smap: '${obs_out_fn_smap}'
pdy_hf: '${pdy_hf}'
smap_raw_dir: '${smap_raw_dir}'
work_dir: '${DATA}'
PDY: '${PDY}'
cyc: '${cyc}'
PY_LOG_LEVEL: '${PY_LOG_LEVEL}'
USHufsda: '${USHufsda}'
EOF

        # Run the ioda converting script for SMAP and concatenate the netcdf files
        ${USHufsda}/smap_ioda_concat_files.py
        if [ $? -ne 0 ]; then
          err_exit "Generation of SMAP_ioda obs file failed !!!"
        fi
      fi
      cp -p "${obs_out_fn_smap}" "${COMINOUTobs}/${obs_out_fn_smap}"
    fi
  fi

  # SMOPS data
  if [ "${OBS_SMOPS}" = "YES" ]; then
    obs_fn="obs.${PDY}.${cycle}.smops.nc"
    obs_dp="${DCOMINobs}/SMOPS/${YYYY}${MM}"
    obs_fp="${obs_dp}/${obs_fn}"
    obs_out_fn_smops="${obs_fn}"

    # Check if obs is available
    if [ -f "${obs_fp}" ]; then
      echo "SMOPS observation file: ${obs_fp}"
      cp -p "${obs_fp}" "${obs_out_fn_smops}"
      cp -p "${obs_fp}" "${COMINOUTobs}/${obs_out_fn_smops}"
    else
      # Soft-link SMOPS raw data file to DATA directory
      fn_smops_prefix="SMOPS-CDR_v2r0_s${PDY}"
      fn_smops_raw=$(ls "${DCOMINsmops}/${fn_smops_prefix}"*)
      smops_ioda_in_fn="${fn_smops_prefix}.nc"
      if [ -n "${fn_smops_raw}" ]; then
        ln -nsf ${fn_smops_raw} ${smops_ioda_in_fn}
      else
        err_exit "SMOPS raw data file does not exist in ${DCOMINsmops} !!!"
      fi

      # Run ioda converting script
      ${USHufsda}/smops_ssm2ioda.py -i ${smops_ioda_in_fn} -o ${obs_out_fn_smops}
      if [ $? -ne 0 ]; then
        err_exit "Generation of SMOPS obs file failed !!!"
      fi
      cp -p "${obs_out_fn_smops}" "${COMINOUTobs}/${obs_out_fn_smops}"
    fi
  fi
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

