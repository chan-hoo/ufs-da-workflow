#!/usr/bin/env bash

date
export PS4='+ $SECONDS + '
#
#-----------------------------------------------------------------------
#
# Set the NCO standard environment variables (Table 1, pp.4)
#
#-----------------------------------------------------------------------
#
export USHufsda="${HOMEufsda}/ush"
export EXECufsda="${HOMEufsda}/exec"
export PARMufsda="${HOMEufsda}/parm"
export FIXufsda="${HOMEufsda}/fix"
export SCRIPTSufsda="${HOMEufsda}/scripts"
#
#-----------------------------------------------------------------------
#
# Define job and jobid by default for rocoto
#
#-----------------------------------------------------------------------
#
WORKFLOW_MANAGER="${WORKFLOW_MANAGER:-rocoto}"
if [ "${WORKFLOW_MANAGER}" = "rocoto" ]; then
  if [ "${SCHED}" = "slurm" ]; then
    job=${SLURM_JOB_NAME}
    pid=${SLURM_JOB_ID}
  elif [ "${SCHED}" = "pbspro" ]; then
    job=${PBS_JOBNAME}
    pid=${PBS_JOBID}
  else
    job="task"
    pid=$$
  fi
  jobid="${job}.${PDY}${cyc}.${pid}"
fi
#
#-----------------------------------------------------------------------
#
# Create a temp working directory (DATA) and cd into it.
#
#-----------------------------------------------------------------------
#
export DATA="${DATA:-${DATAROOT}/${jobid}}"
mkdir -p $DATA
cd $DATA
#
#-----------------------------------------------------------------------
#
# Define NCO environment variables and set COM type definitions.
#
#-----------------------------------------------------------------------
#
export NET="${NET:-ufsda}"
export RUN="${RUN:-ufsda}"

# Run setpdy to initialize PDYm and PDYp variables
export cycle="${cycle:-t${cyc}z}"
setpdy.sh
. ./PDY

[[ "$WORKFLOW_MANAGER" = "rocoto" ]] && export COMROOT=$COMROOT

###################################
# COM directories (input/output)
###################################
export COMINOUT="${COMINOUT:-${COMROOT}/${NET}/${model_ver}/${RUN}.${PDY}}"
export COMINOUTm1="${COMINOUTm1:-${COMROOT}/${NET}/${model_ver}/${RUN}.${PDYm1}}"
export COMINOUThofx="${COMINOUThofx:-${COMINOUT}/hofx}"
export COMINOUTobs="${COMINOUTobs:-${COMINOUT}/obs}"
export COMINOUTplot="${COMINOUTplot:-${COMINOUT}/plot}"
export COMINOUTrestart="${COMINOUTrestart:-${COMINOUT}/RESTART}"
mkdir -p ${COMINOUT}
mkdir -p ${COMINOUThofx}
mkdir -p ${COMINOUTobs}
mkdir -p ${COMINOUTplot}
mkdir -p ${COMINOUTrestart}

##################################################################
# Data directories (model output: COMINmodel, data: DCOMINdata)
##################################################################
# Path to GDAS output files
export COMINgdas="${COMINgdas:-${FIXufsda}/DATA_gdas}"
# Path to GFS output files
export COMINgfs="${COMINgfs:-${FIXufsda}/DATA_gfs}"
# Path to pre-processed observation data files
export DCOMINobs="${DCOMINobs:-${FIXufsda}/DATA_obs}"
# Path to GHCN raw data files
export DCOMINghcn="${DCOMINghcn:-${FIXufsda}/DATA_ghcn}"
# Path to SMAP raw data files
export DCOMINsmap="${DCOMINsmap:-${FIXufsda}/DATA_smap}"
# Path to SMOPS raw data files
export DCOMINsmops="${DCOMINsmops:-${FIXufsda}/DATA_smops}"

########################################
# Create teomporary share directories
########################################
export DATA_HOFX="${DATA_HOFX:-${DATAROOT}/DATA_SHARE/hofx}"
export DATA_RESTART="${DATA_RESTART:-${DATAROOT}/DATA_SHARE/RESTART}"
mkdir -p ${DATA_HOFX}
mkdir -p ${DATA_RESTART}

#####################
# Task output file
#####################
export pgmout="${DATA}/OUTPUT.$$"

