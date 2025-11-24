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
export envir="${envir:-test}"
export KEEPDATA="${KEEPDATA:-YES}"
export MAILCC="${MAILCC:-None}"
export MAILTO="${MAILTO:-None}"
export model_ver="${model_ver:-v0.0.0}"
export SENDCOM="${SENDCOM:-NO}"
export SENDDBN="${SENDDBN:-NO}"
export SENDECF="${SENDECF:-NO}"
export SENDWEB="${SENDWEB:-NO}"

