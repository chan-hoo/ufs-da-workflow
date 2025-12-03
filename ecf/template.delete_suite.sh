#!/usr/bin/env bash

export ECF_SUITE="{{ exp_case_name }}"

ecflow_client --suspend "/${ECF_SUITE}"
ecflow_client --kill "/${ECF_SUITE}"
sleep 10
ecflow_client --delete=force yes "/${ECF_SUITE}"
