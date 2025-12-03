help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with Rocoto on the NOAA RDHPCS machine Hera
]])

load("rocoto")

prepend_path("MODULEPATH","/scratch3/NAGAPE/epic/ufs-conda/modulefiles")
load("python-ufs-land-da-wflow")

