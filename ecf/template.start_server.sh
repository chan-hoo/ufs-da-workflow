#!/usr/bin/env bash

export ECF_HOME="{{ ecf_home_path }}"
export ECF_PORT={{ ecf_port_num }}

ecflow_server --port $ECF_PORT --host localhost --daemon
sleep 1

# Load and begin the suite
ecflow_client --port $ECF_PORT --host localhost --load defs/ufsda.def
ecflow_client --port $ECF_PORT --host localhost --begin cycle
