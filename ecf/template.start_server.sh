#!/usr/bin/env bash

export ECF_HOME="{{ exp_case_path }}/ecf"
export ECF_HOST=$(hostname)
export ECF_PORT=$(( $(id -u) + 1500 ))
export ECF_SUITE="{{ exp_case_name }}"

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
${ecflow_bin_path}/ecflow_start.sh -d ${ECF_HOME} -p ${ECF_PORT}

echo "ECF_HOME: ${ECF_HOME}"
echo "ECF_PORT: ${ECF_PORT}"
echo "ECF_HOST: ${ECF_HOST}"
echo "ECF_SUITE: ${ECF_SUITE}"

# Load and begin the suite
ecflow_client --delete=force yes "/${ECF_SUITE}"
ecflow_client --port="${ECF_PORT}" --host="${ECF_HOST}" --load="${ECF_HOME}/${ECF_SUITE}.def"
ecflow_client --port="${ECF_PORT}" --host="${ECF_HOST}" --begin="${ECF_SUITE}"
