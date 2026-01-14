help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with ecFlow on the NCAR HPC machine Derecho
]])

load("ecflow/5.11.4")

prepend_path("MODULEPATH","/glade/work/chanhooj/UFS-DA-ENV/ss19.2/modulefiles")
load("python-ufs-land-da-wflow")
