#!/usr/bin/env bash

set -x

# Detect path to HOME directory
PARM_DIR=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )" && pwd -P)
HOME_DIR="${PARM_DIR}/.."

# Automatically detect NOAA RDHPCS
source ${HOME_DIR}/parm/detect_platform.sh
if [ "${PLATFORM}" = "unknown" ]; then
  printf "\nFATAL ERROR: This platform (machine) is not supported.\n\n"
  exit 0
fi
printf "PLATFORM(MACHINE)=${PLATFORM}\n" >&2

# load python environment module
printf "... Load Python packages ...\n"
module use ${HOME_DIR}/modulefiles
module load wflow_${PLATFORM}
module list

