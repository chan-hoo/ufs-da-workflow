#!/usr/bin/env bash

export ECF_HOME="{{ exp_case_path }}/ecf"

# Find path to ecFlow bin directory
ecflow_bin_path=$(ecflow_start.sh -h 2>&1 \
      | awk '/^Usage:/ {
              path=$2
              sub("/ecflow_start.sh$", "", path)
              print path
            }')
if [ -z "${ecflow_bin_path}" ]; then
  echo "FATAL ERROR: ecflow_start.sh is not found. ecFlow module may not be loaded properly."
  exit 1
else
  echo "ecFlow BIN directory: ${ecflow_bin_path}"
fi

# Run ecFlow module built-in start script
${ecflow_bin_path}/ecflow_start.sh -d ${ECF_HOME}

# Load and begin the suite
ecflow_client --port ${ECF_PORT} --host ${ECF_HOST} --load ufsda.def
ecflow_client --port ${ECF_PORT} --host ${ECF_HOST} --begin cycle
