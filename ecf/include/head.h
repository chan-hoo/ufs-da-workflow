date
export PS4='+ $SECONDS + '
set -xue

# Variables needed for communication with ecFlow
export ECF_NAME=%ECF_NAME%
export ECF_HOST=%ECF_LOGHOST%
export ECF_PORT=%ECF_PORT%
export ECF_PASS=%ECF_PASS%
export ECF_TRYNO=%ECF_TRYNO%
export ECF_RID=${ECF_RID:-${PBS_JOBID:-$(hostname -s).$$}}
export ECF_JOB=%ECF_JOB%
export ECF_JOBOUT=%ECF_JOBOUT%
export ecflow_ver=%ecflow_ver%

# Tell ecFlow we have started
ecflow_client --init=$$

# Define error handler
ERROR() {
  set +ex
  if [ "$1" -eq 0 ]; then
     msg="Killed by signal (likely via qdel)"
  else
     msg="Killed by signal $1"
  fi
  ecflow_client --abort="$msg"
  echo $msg
  trap $1; exit $1
}
# Trap all error and exit signals
trap 'ERROR $?' ERR EXIT
