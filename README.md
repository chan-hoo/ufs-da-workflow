# ufs-da-workflow
UFS DA (Data Assimilation) Workflow
- Available coupling configurations:
 1. S2SWA: ATM (FV3+CCPP) + OCN (MOM6) + ICE (CICE) + WAV (WW3)
 2. NG-GODAS: ATM (DATM) + OCN (MOM6) + ICE (CICE)

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
./app_build.sh -a=[APP]
```
where `[APP]` is `S2SWA` or `NG-GODAS`.

- Workflow components: YES, JEDI-bundle: YES
```
./app_build.sh -a=[APP] --jedi=on
```

- Workflow components: NO, JEDI-bundle: YES
```
./app_build.sh --jedi=only
```

4. Load the python environment to set up the workflow:
```
cd ..
module use modulefiles
module load wflow_[workflow_manager]_[machine] 
```
where `[workflow_manager]` is `rocoto` or `ecflow`, and `[machine]` is `gaeac6`, `hera`, `hercules`, `orion`, or `ursa`.

5. Copy a sample configuration and modify it as needed:
```
cd parm
cp config_samples/config.[sample_case].yaml config.yaml
vim config.yaml
```
Change the parameter values such as `ACCOUNT` as needed.

6. Set up the workflow in the case-specific experiment directory:
```
./setup_wflow_env.py
```

7. Move to the experimental case directory:
```
cd ../../exp_case/[EXP_CASE_NAME]
```
where `[EXP_CASE_NAME]` is specified in the configuration file `config.yaml`.

8. Launch the workflow tasks:
```
./automate_launch_script.py -i [time interval in seconds]
```
where the default value of `[time interval in seconds]` is 30. This means that the launch script `launch_rocoto_wflow.sh` is submitted every 30 seconds.

9. Check the result and log files:
- `com_dir`: symlink to the directory containing the result files
- `log_dir`: symlink to the directory containing the log files
- `tmp_dir`: symlink to the directory containing the working directories
