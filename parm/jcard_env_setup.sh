#!/usr/bin/env bash

#
#-----------------------------------------------------------------------
#
# Set the NCO standard environment variables (Table 1, pp.4)
#
#-----------------------------------------------------------------------
#
export COMROOT="${COMROOT:-${PTMP}/${envir}/com}"
export DATAROOT="${DATAROOT:-${PTMP}/${envir}/tmp}"
export DCOMROOT="${DCOMROOT:-${PTMP}/${envir}/dcom}"
export KEEPDATA="${KEEPDATA:-YES}"
export MAILCC="${MAILCC:-None}"
export MAILTO="${MAILTO:-None}"
export SENDCOM="${SENDCOM:-NO}"
export SENDDBN="${SENDDBN:-NO}"
export SENDECF="${SENDECF:-NO}"
export SENDWEB="${SENDWEB:-NO}"

export LOGDIR="${LOGDIR:-${COMROOT}/output/logs}"

