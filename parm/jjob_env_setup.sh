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

# COMIN directories
export COMIN="${COMIN:-${COMROOT}/${NET}/${model_ver}/${RUN}.${PDY}}"
export COMINm1="${COMINm1:-${COMROOT}/${NET}/${model_ver}/${RUN}.${PDYm1}}"
export COMINgfs="${COMINgfs:-${FIXufsda}/DATA_gfs}"
export COMINobs=${COMINobs:-${COMIN}/obs}

# COMOUT directories
export COMOUT="${COMOUT:-${COMROOT}/${NET}/${model_ver}/${RUN}.${PDY}}"
mkdir -p ${COMOUT}
export COMOUThofx="${COMOUThofx:-${COMOUT}/hofx}"
mkdir -p ${COMOUThofx}
export COMOUTplot="${COMOUTplot:-${COMOUT}/plot}"
mkdir -p ${COMOUTplot}
export COMOUTrestart="${COMOUTrestart:-${COMOUT}/RESTART}"
mkdir -p ${COMOUTrestart}

# Create teomporary share directories
export DATA_HOFX="${DATA_HOFX:-${DATAROOT}/DATA_SHARE/hofx}"
mkdir -p ${DATA_HOFX}
export DATA_RESTART="${DATA_RESTART:-${DATAROOT}/DATA_SHARE/RESTART}"
mkdir -p ${DATA_RESTART}

# DCOMIN directories
export DCOMINghcn=${DCOMINghcn:-${FIXufsda}/DATA_ghcn}
export DCOMINsmap=${DCOMINsmap:-${FIXufsda}/DATA_smap}
export DCOMINsmops=${DCOMINsmops:-${FIXufsda}/DATA_smops}

# Output file
export pgmout="${DATA}/OUTPUT.$$"

