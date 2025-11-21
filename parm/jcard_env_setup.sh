#!/usr/bin/env bash

#
#-----------------------------------------------------------------------
#
# Set the NCO standard environment variables (Table 1, pp.4)
#
#-----------------------------------------------------------------------
#
export COMROOT="${COMROOT:-${PTMP}/${envir}/com}"
export DATAROOT="${DATAROOT:-${PTMP}/${envir}/com}"

export LOGDIR="${LOGDIR:-${COMROOT}/output/logs}"

