prepend_path("MODULEPATH", os.getenv("modulepath_spack_stack"))
load(pathJoin("stack-oneapi", stack_intel_ver))
load(pathJoin("prod_util", prod_util_ver))

load("ecflow/5.11.4")

prepend_path("MODULEPATH", os.getenv("modulepath_pymodule"))
load("python-ufs-land-da-wflow")
