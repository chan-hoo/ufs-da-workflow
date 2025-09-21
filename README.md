# ufs-da-workflow
UFS DA (Data Assimilation) Workflow

## Quick Start Guide

1. Clone the `develop` branch of the authoritative repository:
```
git clone -b develop --recursive https://github.com/ufs-community/ufs-da-workflow
```

2. Move to the `sorc` directory:
```
cd ufs-da-workflow/sorc
```

3. Run the build script:
- Workflow components: YES, JEDI-bundle: NO
```
./app_build.sh
```

- Workflow components: YES, JEDI-bundle: YES
```
./app_build.sh --jedi=on
```

- Workflow components: NO, JEDI-bundle: YES
```
./app_build.sh --jedi=only
```

4. Load the python environment to set up the workflow:
```
cd ..
module use wflow_[machine] 
```
where `[machine]` is `gaeac6`, `hera`, `hercules`, `orion`, or `ursa`.

5. Copy the sample configuration and modify it as needed:
```
cp config_samples/config.S2SWA.free-fcst.coldstart.yaml config.yaml
vim config.yaml
```
Change the parameter values such as `ACCOUNT` as needed.

6. Set up the workflow in the case-specific experiment directory:
```
./setup_wflow_env.py
```

7 Move to the experimental case directory:
```
cd ../../exp_case/[EXP_CASE_NAME]
```
where `EXP_CASE_NAME` is specified in the configuration file `config.yaml`.

8. Launchh the workflow tasks:
```
./automate_launch_script.py -i [time interval in seconds]
```
where the default value of `[time interval in seconds]` is 10. This means that the launch script `launch_rocoto_wflow.sh` is submitted every 10 seconds.
