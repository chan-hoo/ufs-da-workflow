help([[
This loads the modules and py environment for running the UFS-DA workflow
with ecFlow on the MSU machine Orion
]])

prepend_path("MODULEPATH", "/apps/contrib/spack-stack/spack-stack-1.9.2/envs/ue-oneapi-2024.1.0/install/modulefiles/Core")
load("stack-oneapi/2024.2.1")
load("stack-intel-oneapi-mpi/2021.13")
load("ecflow/5.11.4")

prepend_path("MODULEPATH","/work/noaa/epic/UFS-conda/modulefiles")
load("python-ufs-land-da-wflow")

