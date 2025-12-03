help([[
This loads the modules and py environment for running the UFS-DA workflow
with Rocoto on the MSU machine Orion
]])

load("contrib")
load("ruby/3.2.3")
load("rocoto/1.3.7")

prepend_path("MODULEPATH","/work/noaa/epic/UFS-conda/modulefiles")
load("python-ufs-land-da-wflow")

