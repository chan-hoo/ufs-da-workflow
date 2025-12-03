help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with Rocoto on the MSU machine Hercules
]])

load("contrib")
load("rocoto")

prepend_path("MODULEPATH","/work/noaa/epic/UFS-conda/modulefiles")
load("python-ufs-land-da-wflow")
