help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with ecFlow on the NOAA RDHPCS machine Hera
]])

load("contrib")
load("ecflow/5.11.4")

prepend_path("MODULEPATH","/scratch3/NAGAPE/epic/ufs-conda/modulefiles")
load("python-ufs-land-da-wflow")

