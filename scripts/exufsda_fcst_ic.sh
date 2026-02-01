#!/usr/bin/env bash

set -xue

ulimit -s unlimited; ulimit -a;

# Set OpenMP variables.
export KMP_AFFINITY="scatter"
export OMP_NUM_THREADS="1"
export OMP_STACKSIZE="1024m"

YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}

if [ "${PDY}${cyc}" -ge "2021032100" ]; then
  data_format="netcdf"
else
  data_format="nemsio"
fi

if [ "${IC_DATA_MODEL}" = "gfs" ] || [ "${IC_DATA_MODEL}" = "GFS" ]; then
  fn_data_prefix="gfs"
  dcom_path="${COMINgfs}"
elif [ "${IC_DATA_MODEL}" = "gdas" ] || [ "${IC_DATA_MODEL}" = "GDAS" ]; then
  fn_data_prefix="gdas"
  dcom_path="${COMINgdas}"
fi
data_dir_input_grid="${dcom_path}/${fn_data_prefix}.${PDY}/${cyc}/atmos"

if [ "${data_format}" = "nemsio" ]; then
  input_type="gaussian_nemsio"
  fn_atm_data="${fn_data_prefix}.${cycle}.atmanl.nemsio"
  fn_sfc_data="${fn_data_prefix}.${cycle}.sfcanl.nemsio"
elif [ "${data_format}" = "netcdf" ]; then
  input_type="gaussian_netcdf"
  fn_atm_data="${fn_data_prefix}.${cycle}.atmanl.nc"
  fn_sfc_data="${fn_data_prefix}.${cycle}.sfcanl.nc"
fi

# Check whether input files exist
fp_atm="${data_dir_input_grid}/${fn_atm_data}"
if [ ! -e "${fp_atm}" ]; then
  err_exit "Input file ${fp_atm} does not exist."
fi
fp_sfc="${data_dir_input_grid}/${fn_sfc_data}"
if [ ! -e "${fp_sfc}" ]; then
  err_exit "Input file ${fp_sfc} does not exist."
fi

mkdir -p fix_sfc
sfc_fns=( "facsf" "maximum_snow_albedo" "slope_type" "snowfree_albedo" "soil_color" \
          "soil_type" "substrate_temperature" "vegetation_greenness" "vegetation_type" )
for ifn in "${sfc_fns[@]}" ; do
  for itile in {1..6}
  do
    ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}.${OCN_MESH_RES}.${ifn}.tile${itile}.nc" "fix_sfc/C${RES}.${ifn}.tile${itile}.nc"
  done
done

mkdir -p fix_oro
ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_mosaic.nc" fix_oro/.
for itile in {1..6}
do
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}_grid.tile${itile}.nc" fix_oro/.
  ln -nsf "${FIXufsda}/DATA_fix/FV3/Tiled/C${RES}/C${RES}.${OCN_MESH_RES}_oro_data.tile${itile}.nc" fix_oro/C${RES}_oro_data.tile${itile}.nc
done

settings="
 'mosaic_file_target_grid': ${DATA}/fix_oro/C${RES}_mosaic.nc
 'fix_dir_target_grid': ${DATA}/fix_sfc
 'orog_dir_target_grid': ${DATA}/fix_oro
 'sfc_files_input_grid': ${fn_sfc_data}
 'atm_files_input_grid': ${fn_atm_data}
 'data_dir_input_grid': ${data_dir_input_grid}
 'vcoord_file_target_grid': ${FIXufsda}/DATA_fix/FV3/Global/global_hyblev.l128.txt
 'cycle_mon': ${MM}
 'cycle_day': ${DD}
 'cycle_hour': ${HH}
 'input_type': ${input_type}
 'RES': ${RES}
"

fp_template="${PARMufsda}/templates/template.chgres_cube"
fn_namelist="fort.41"
${USHufsda}/fill_jinja_template.py -u "${settings}" -t "${fp_template}" -o "${fn_namelist}"

#
#-----------------------------------------------------------------------
#
# Run chgres_cube.
#
#-----------------------------------------------------------------------
#
export pgm="chgres_cube"

. prep_step
${RUN_CMD} -n ${NPROCS_FCST_IC} ${EXECufsda}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk

# Copy final output files to COMINOUT
cp -p ${DATA}/gfs_ctrl.nc ${COMINOUT}
for itile in {1..6}
do
  cp -p ${DATA}/out.atm.tile${itile}.nc ${COMINOUT}/gfs_data.tile${itile}.nc
  cp -p ${DATA}/out.sfc.tile${itile}.nc ${COMINOUT}/sfc_data.tile${itile}.nc
done

