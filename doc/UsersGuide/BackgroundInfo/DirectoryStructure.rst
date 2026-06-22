.. _directory-structure:

Directory Structure
===================

The :term:`UFS` DA Workflow follows the vertical directory structure and
environment variable conventions used by :term:`NCEP` Central Operations
(:term:`NCO`) :term:`WCOSS` Implementation Standards. The workflow keeps those
conventions while allowing large working and output files to reside under a
configurable ``PTMP`` location on NOAA :term:`HPC` systems.

.. _nco-standard-variables:

NCO Standard Variables
----------------------

The UFS DA Workflow follows the NCO-style environment variable conventions
described in the
:nco:`NCO Implementation Standards document <ImplementationStandards.v11.0.0.pdf>`.
Within this repository, ``parm/jcard_env_setup.sh`` sets defaults for the
generated :term:`job cards <job card>`, and ``parm/jjob_env_setup.sh`` derives
the task-specific paths and cycle variables used by the workflow scripts.

.. _workflow-layer-structure:

Workflow Layer Structure
------------------------

The UFS DA Workflow follows the NCO job-layer pattern without maintaining a
separate task wrapper script for every task. Instead, generated job cards source
common setup scripts that set task directories and shared environment variables.

Each task job card is created in the experiment case directory when the setup
script builds the case. The job card sources ``parm/jcard_env_setup.sh`` and
``parm/jjob_env_setup.sh`` and then calls the task's
:term:`ex-script <ex-scripts>` in ``${HOMEufsda}/scripts``. Utility Python and
shell scripts called by the ex-scripts are stored in ``${HOMEufsda}/ush``.

.. figure:: https://raw.githubusercontent.com/wiki/ufs-community/ufs-da-workflow/UserGuideImages/ufsDAworkflowstructure.png
   :alt: Structure of the UFS DA Workflow
   :align: center

   Structure of the UFS DA Workflow

.. _workflow-vertical-directory-structure:

Workflow Vertical Directory Structure
-------------------------------------

The ``ufs-da-workflow`` repository uses the following directory structure.

.. note::

   Some files and directories are omitted for concision and clarity.

.. code-block:: console

   ufs-da-workflow
   ├── doc
   │     └── UsersGuide
   ├── ecf
   │     ├── include
   │     ├── template.*.sh
   │     └── stop_server.sh
   ├── fix
   ├── modulefiles
   │     ├── tasks
   │     │     ├── common
   │     │     └── <machine>
   │     ├── ufs_common.lua
   │     ├── ufsda_<platform>.intel.lua
   │     └── wflow_<workflow_manager>_<platform>.lua
   ├── parm
   │     ├── config_default
   │     ├── config_samples
   │     ├── templates
   │     │     ├── template.*
   │     │     └── task_env
   │     ├── automate_launch_script.py
   │     ├── detect_platform.sh
   │     ├── jcard_env_setup.sh
   │     ├── jjob_env_setup.sh
   │     └── setup_wflow_env.py
   ├── scripts
   │     └── exufsda_*.sh
   ├── sorc
   │     ├── CMakeLists.txt
   │     ├── UFS_UTILS.fd
   │     ├── UFS_UTILS_nofrac.fd
   │     ├── apply_incr.fd
   │     ├── calcfIMS.fd
   │     ├── app_build.sh
   │     ├── jcb-algorithms
   │     ├── jcb-gdas
   │     ├── jedi-bundle
   │     ├── tile2tile_converter.fd
   │     └── ufs_model.fd
   ├── ush
   │     ├── fill_jinja_template.py
   │     ├── jcb_setup.py
   │     ├── plot_*.py
   │     └── *_ioda*.py
   ├── versions
   │     └── run.ver_<platform>
   ├── .gitmodules
   └── README.md

On WCOSS, operational products must set ``OPSROOT`` to
``/lfs/{FS}/ops/{envir}``. If ``PTMP`` is set to ``/lfs/{FS}/ops``, the UFS DA
Workflow directory structure aligns with the NCO implementation standards while
still allowing platforms to place large files on the correct disk space.

The UFS DA Workflow also adds ``DATA_SHARE`` under ``tmp``. This directory
holds intermediate files that should not be stored in the ``COM`` directory.

For comparison, the NCO implementation standards use the following vertical
directory structure:

.. code-block:: console

   [envir] ([OPSROOT])
   ├── com ([COMROOT])
   │     ├── [NET]
   │     │     └── [model_ver]
   │     │           └── [RUN.PDY] ([COMIN]/[COMOUT])
   │     └── output
   │           └── logs
   ├── dcom ([DCOMROOT])
   ├── tmp ([DATAROOT])
   │     └── [jobid] ([DATA])
   └── packages ([PACKAGEROOT])
         └── model.vX.Y.Z ([HOMEmodel])
               ├── doc
               ├── ecf
               ├── exec ([EXECmodel])
               ├── fix
               ├── jobs
               ├── modulefiles
               ├── parm ([PARMmodel])
               ├── scripts
               ├── sorc
               ├── ush ([USHmodel])
               └── versions

.. _fix-directory-structure:

Static Data Directory
---------------------

Static data, or :term:`FIX` files, are too large to store directly in the GitHub
repository. Instead, these files are kept in centralized locations on supported
HPC systems. During installation, ``sorc/app_build.sh`` creates symbolic links
from those centralized locations into the workflow ``fix`` directory.

To use custom static data, remove the relevant symbolic link in ``fix`` and
link or move the custom data to the ``fix`` directory.
