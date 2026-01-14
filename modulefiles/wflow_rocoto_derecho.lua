help([[
This loads the modules and py environment necessary for running the UFS-DA workflow
with Rocoto on the NCAR HPC machine Derecho
]])

prepend_path("MODULEPATH","/glade/work/epicufsrt/contrib/derecho/modulefiles")
load("rocoto/1.3.7")

prepend_path("MODULEPATH","/glade/work/chanhooj/UFS-DA-ENV/ss19.2/modulefiles")
load("python-ufs-land-da-wflow")
