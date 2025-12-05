help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with ecFlow on the NOAA RDHPC machine Ursa
]])

prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.2/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")
load("stack-oneapi/2024.2.1")
load("stack-intel-oneapi-mpi/2021.13")
load("ecflow")

prepend_path("MODULEPATH","/scratch3/NAGAPE/epic/ufs-conda/modulefiles")
load("python-ufs-land-da-wflow")

