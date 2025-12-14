help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with ecFlow on the NOAA RDHPC machine Gaea-C6
]])

prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.2/envs/ue-intel-2023.2.0/install/modulefiles/Core")
load("stack-intel/2023.2.0")
--load("cray-mpich/8.1.30")

prepend_path("MODULEPATH", "/ncrc/proj/epic/spack-stack/c6/spack-stack-1.9.2/envs/ue-intel-2023.2.0/install/modulefiles/gcc/12.3.0")
load("ecflow/5.11.4")

prepend_path("MODULEPATH","/gpfs/f6/bil-fire8/world-shared/ufs-conda/modulefiles")
load("python-ufs-land-da-wflow")

pushenv("MKLROOT", "/opt/intel/oneapi/mkl/2023.2.0/")

