help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with Rocoto on the NOAA RDHPC machine Gaea-C6
]])

prepend_path("MODULEPATH","/ncrc/proj/epic/rocoto/modulefiles/")
load("rocoto")

prepend_path("MODULEPATH","/gpfs/f6/bil-fire8/world-shared/ufs-conda/modulefiles")
load("python-ufs-land-da-wflow")

pushenv("MKLROOT", "/opt/intel/oneapi/mkl/2023.2.0/")

