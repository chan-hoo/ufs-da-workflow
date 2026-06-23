.. _build-ufs-da-workflow:

Building and Testing the UFS DA Workflow
========================================

This chapter describes how to build the UFS DA Workflow and verify related
components. It is organized by task: build the workflow, add optional DA
dependencies, run tests, and review an optional global-workflow example.

.. _build-workflow:

Build the UFS DA Workflow
-------------------------

Clone the Repository
^^^^^^^^^^^^^^^^^^^^

Retrieve the default ``develop`` branch from the
``ufs-community/ufs-da-workflow`` repository:

.. code-block:: console

   git clone --recursive https://github.com/ufs-community/ufs-da-workflow
   cd ufs-da-workflow

The path to the ``ufs-da-workflow`` directory is referred to as
``${HOMEufsda}`` in this documentation.

The workflow checkout contains the subrepositories, scripts, configuration files, and
build support files. Some directories, such as ``exec`` and ``lib64``, are
created by the build process.

.. list-table:: UFS DA Workflow directories
   :header-rows: 1
   :widths: 25 75

   * - Directory or file
     - Description
   * - ``doc``
     - Documentation source for the user's guide
   * - ``ecf``
     - ecFlow scripts
   * - ``fix``
     - Fix fields, tables, and other static input data
   * - ``modulefiles``
     - Machine-specific module files used to build and run the workflow
   * - ``parm``
     - Parameter files, templates, default configuration files, and sample
       configuration files
   * - ``scripts``
     - Ex-scripts, or main workflow scripts
   * - ``sorc``
     - Build-related scripts and external components
   * - ``ush``
     - Utility scripts called from ex-scripts
   * - ``versions``
     - Module version control files
   * - ``exec``
     - Workflow executables, created by the build process
   * - ``lib64``
     - Dynamic libraries, created by the build process

The workflow commonly sits beside generated or optional directories such as
``exp_case``, ``ptmp``, ``jedi``, and ``GDASApp``.

.. _build-workflow-components:

Build Workflow Components
^^^^^^^^^^^^^^^^^^^^^^^^^

The main build interface is ``sorc/app_build.sh``. To build workflow
components:

.. code-block:: console

   cd ${HOMEufsda}/sorc
   ./app_build.sh -a=[APP]

Replace ``[APP]`` with ``S2SWA``, ``S2SWAL``, ``NG-GODAS``, ``ATML``, or
``ATM``. If the application is not specified, the build script defaults to
``S2SWA``.

The basic build creates the selected UFS Weather Model executable, UFS utilities,
DA utility executables when applicable, and FIX links. It does not build JEDI;
use an existing JEDI installation or one of the optional JEDI build modes below.

When the build process completes, executables are installed in
``${HOMEufsda}/exec``. The UFS Weather Model executable is renamed with the
application suffix, for example ``ufs_model_s2swa``.

.. note::

   ``apply_incr.exe`` and ``calcfIMS.exe`` are used for snow DA and are not
   installed for ``APP=NG-GODAS``.

Build Script Options
^^^^^^^^^^^^^^^^^^^^

The most common ``app_build.sh`` options are listed below. Run
``./app_build.sh -h`` for the script's full usage message.

.. list-table:: Common ``app_build.sh`` options
   :header-rows: 1
   :widths: 20 55 25

   * - Option
     - Description
     - Example
   * - ``-h``, ``--help``
     - Shows the help guide
     - ``./app_build.sh -h``
   * - ``-p``, ``--platform``
     - Specifies the platform. If omitted, ``parm/detect_platform.sh`` is used
       to detect supported Tier-1 platforms
     - ``./app_build.sh -p=ursa``
   * - ``-c``, ``--compiler``
     - Specifies the compiler
     - ``./app_build.sh -c=intel``
   * - ``-a``, ``--app``
     - Specifies the weather model application
     - ``./app_build.sh -a=S2SWA``
   * - ``--remove``
     - Removes existing build products and updates submodules
     - ``./app_build.sh --remove``
   * - ``--clean``
     - Runs ``make clean`` in the build directory
     - ``./app_build.sh --clean``
   * - ``--build``
     - Builds executables and libraries in ``sorc/build`` without moving them
       to ``exec`` and ``lib64``
     - ``./app_build.sh --build``
   * - ``--move``
     - Moves pre-compiled executables and libraries from the build directory to
       ``exec`` and ``lib64``
     - ``./app_build.sh --move``
   * - ``--da-utils-only``
     - Builds DA utilities only
     - ``./app_build.sh --da-utils-only``
   * - ``--fix-only``
     - Creates or refreshes symbolic links to static FIX files without
       rebuilding
     - ``./app_build.sh --fix-only``
   * - ``--jedi``
     - Selects the JEDI build option: ``off``, ``bundle``, ``gdas``,
       ``bundle-only``, or ``gdas-only``
     - ``./app_build.sh --jedi=bundle``

When ``sorc/build`` already exists, the script prompts for an interactive
choice:

.. list-table:: Interactive build options
   :header-rows: 1
   :widths: 20 80

   * - Option
     - Description
   * - ``R`` or ``r``
     - Remove the existing build directory and continue
   * - ``C`` or ``c``
     - Continue building in the existing build directory
   * - ``Q`` or ``q``
     - Quit the build process

Installed Executables
^^^^^^^^^^^^^^^^^^^^^

The following executables are installed in ``${HOMEufsda}/exec`` when their
source components are included in the selected build.

.. list-table:: Workflow executables
   :header-rows: 1
   :widths: 25 50 25

   * - Name
     - Description
     - Source component
   * - ``ufs_model_[app]``
     - UFS Weather Model executable for the selected application.
     - ``ufs_model.fd``
   * - ``chgres_cube``
     - Creates cold-start initial condition files for the atmospheric model.
     - ``UFS_UTILS.fd``
   * - ``cpld_gridgen``
     - Creates static and initial condition files for coupled configurations
       such as ``S2SWA`` and ``S2SWAL``.
     - ``UFS_UTILS.fd``
   * - ``oiprep``
     - Creates warm-start files for ocean and ice from component restart files.
     - ``UFS_UTILS.fd``
   * - ``orog_gsl``
     - Creates GSL gravity wave drag fields required by the orographic drag
       suite.
     - ``UFS_UTILS.fd``
   * - ``apply_incr.exe``
     - Applies JEDI increments to ``sfc_data`` files.
     - ``apply_incr.fd``
   * - ``calcfIMS.exe``
     - Creates IMS NetCDF files from ASCII data files.
     - ``calcfIMS.fd``

.. _optional-da-dependencies:

Build Optional DA Dependencies
------------------------------

The basic ``./app_build.sh -a=[APP]`` command does not build JEDI. Use this
section only for experiments that run JEDI-based DA and need ``app_build.sh`` to
build the required JEDI executables. If you already have JEDI executables
installed, skip to :ref:`use-separately-installed-jedi`.

JEDI-bundle with ``app_build.sh``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Build JEDI-bundle when ``JEDI_BUNDLE_GDAS`` is set to ``bundle`` and the
experiment will use the default JEDI path, ``../jedi/build/bin``. The
JEDI-bundle synced with the GDAS App can be built through ``app_build.sh``:

.. code-block:: console

   # Workflow components and JEDI-bundle
   ./app_build.sh -a=[APP] --jedi=bundle

   # JEDI-bundle only
   ./app_build.sh --jedi=bundle-only

The script copies ``sorc/jedi-bundle`` to ``../jedi`` relative to the workflow
checkout and installs it in ``../jedi/build`` by default.

GDAS App with ``app_build.sh``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Build the GDAS App when ``JEDI_BUNDLE_GDAS`` is set to ``gdas`` and the
experiment will use the default JEDI path, ``../GDASApp/build/bin``. The GDAS
App can also be built through ``app_build.sh``:

.. code-block:: console

   # Workflow components and GDAS App
   ./app_build.sh -a=[APP] --jedi=gdas

   # GDAS App only
   ./app_build.sh --jedi=gdas-only

By default, the GDAS App is installed in ``../GDASApp`` relative to the
workflow checkout.

.. include:: ../../doc-snippets/gdas-derecho-note.rst

.. _use-separately-installed-jedi:

Use Separately Installed JEDI
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you use separately installed JEDI executables, set the paths in the workflow
configuration file after creating it from a sample in the workflow checkout's
``parm`` directory:

.. note::

   The ``parm/config_samples`` directory provides many configuration examples
   that users can choose from, using names such as
   ``config_samples/config.[APP].[case_name].yaml``.

.. code-block:: yaml

   JEDI_BIN_PATH: /path/to/bin/directory/of/your/JEDI/
   JEDI_IODACONV_PATH: /path/to/python/directory/of/your/ioda_converter/

Manual Installation of JEDI-bundle
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Skip this section if JEDI-bundle is already built. The automated build script is
preferred, but the JEDI-bundle can also be built manually. In the commands below,
``${HOMEjedi}`` refers to the parent directory where JEDI-bundle is or will be
installed; replace it with the actual path on your system.

#. Create and enter a parent directory:

   .. code-block:: console

      mkdir -p ${HOMEjedi}
      cd ${HOMEjedi}

#. Clone the ``sync_gdas`` branch:

   .. code-block:: console

      git clone -b sync_gdas https://github.com/NOAA-EPIC/jedi-bundle

#. Reset loaded modules and enter the clone:

   .. code-block:: console

      cd jedi-bundle
      module purge

   .. attention::

      On Gaea-C6, use ``module reset`` instead of ``module purge``.

#. Load the machine module and Git LFS:

   .. code-block:: console

      module use modulefiles/
      module load [machine].intel
      module load git-lfs

   Replace ``[machine]`` with ``gaeac6``, ``hercules``, ``orion``, ``ursa``, or
   ``derecho``.

#. Configure and build:

   .. code-block:: console

      cd ..
      mkdir -p build
      cd build
      ecbuild ${HOMEjedi}/jedi-bundle
      make -j4

#. Check that Git LFS data files were retrieved correctly:

   .. code-block:: console

      cd ${HOMEjedi}/jedi-bundle/soca/test/Data
      file godas_sst_bgerr.nc

   If this reports ``ASCII`` instead of a NetCDF file, Git LFS was not active
   when the data was retrieved.

Manual Installation of GDAS App
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. note::

   Skip this section if the GDAS App was already built with ``app_build.sh``.
   The automated build script is preferred, but the GDAS App can also be built
   manually.

#. Move to the parent directory of the workflow checkout:

   .. code-block:: console

      cd ${HOMEufsda}/..

   The workflow assumes by default that ``GDASApp`` is installed beside
   ``ufs-da-workflow``. Users can override this assumption by adding the path
   to ``GDASApp`` in ``config.yaml``, after creating ``config.yaml`` from a
   sample such as ``config_samples/config.[APP].[case_name].yaml``.

#. Clone GDAS App:

   .. code-block:: console

      git clone --recursive https://github.com/NOAA-EMC/GDASApp.git

#. Build GDAS App:

   .. code-block:: console

      cd GDASApp
      module load git-lfs
      ./build.sh -f -a -d -t [machine] > build.log 2>&1 &

   Replace ``[machine]`` with ``gaeac6``, ``hercules``, ``orion``, or
   ``ursa``.

.. include:: ../../doc-snippets/gdas-derecho-note.rst

.. _build-and-component-tests:

Run Build and Component Tests
-----------------------------

C-test of JEDI-bundle
^^^^^^^^^^^^^^^^^^^^^

#. Get interactive access on the target platform. Examples:

   .. code-block:: console

      # Gaea-C6
      salloc -A epic -t 0:30:00 -M c6 -p batch -N 1

      # Hercules / Orion
      salloc -A epic -t 0:30:00 -q debug --nodes=1

      # Ursa
      salloc -A epic -t 30 -p u1-compute -N 1

      # Derecho
      qinteractive -A nral0032 -l walltime=00:30:00

#. Load the JEDI-bundle environment:

   .. code-block:: console

      cd ${HOMEjedi}/jedi-bundle
      module purge
      module use modulefiles/
      module load [machine].intel

   Replace ``[machine]`` with ``gaeac6``, ``hercules``, ``orion``, ``ursa``, or
   ``derecho``.

   .. note::

      On Gaea-C6, use ``module reset`` instead of ``module purge``.

#. Move to the build directory and list available C-tests:

   .. code-block:: console

      cd ${HOMEjedi}/build
      ctest -N

#. Run tests. For example:

   .. code-block:: console

      ctest -R test_soca

   Use ``ctest -N`` to list available tests, and use ``ctest -N -V`` to inspect
   test properties such as dependencies. To run ``test_soca_3dvar`` alone,
   first run its prerequisite cases:

   .. code-block:: console

      ctest -R test_soca_gridgen
      ctest -R test_soca_setcorscales
      ctest -R test_soca_parameters_diffusion
      ctest -R test_soca_3dvar

#. Check the C-test log:

   .. code-block:: console

      cd ${HOMEjedi}/build/Testing/Temporary
      vim LastTest.log

#. Inspect test inputs, outputs, and working directories as needed:

   .. code-block:: console

      cd ${HOMEjedi}/build/soca/test/test_workdir/[case_name]

#. Cancel the interactive allocation when finished:

   .. code-block:: console

      # On Slurm systems (e.g, Ursa, Hercules, Orion, Gaea-C6):
      squeue -u [user_id]
      scancel [JOBID]

      # Or, on PBS systems:
      qstat -u [user_id]
      qdel [JOBID]

.. _ufs-weather-model-regression-tests:

UFS Weather Model Regression Tests
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#. Create a custom regression test configuration:

   .. code-block:: console

      cd /path/to/ufs-weather-model/tests
      vim my_rt.conf

   Replace ``/path/to/ufs-weather-model`` with the path to your UFS Weather
   Model checkout.

#. Copy the ``COMPILE`` and ``RUN`` lines for the cases of interest from
   ``rt.conf`` into ``my_rt.conf``. For example:

   .. code-block:: text

      COMPILE | s2swa_32bit | intel | -DAPP=S2SWA -D32BIT=ON -DCCPP_SUITES=FV3_GFS_v17_coupled_p8_ugwpv1 | | fv3 |

      RUN | cpld_control_gfsv17 | - noaacloud | baseline |
      RUN | cpld_restart_gfsv17 | - noaacloud | | cpld_control_gfsv17

#. Set machine-specific directories in ``rt.sh``:

   .. code-block:: console

      vim rt.sh

   Set ``dprefix``, ``STMP``, and ``PTMP`` to the intended parent directory.

#. Run the regression test:

   .. code-block:: console

      ./rt.sh -a epic -kl my_rt.conf >& my_rt.out &

   .. note::

      When running multiple tests, add ``-e`` to submit through ecFlow or ``-r``
      to submit through Rocoto.

.. list-table:: Selected ``rt.sh`` flags
   :header-rows: 1
   :widths: 15 85

   * - Flag
     - Description
   * - ``-c``
     - Create new baseline results
   * - ``-e``
     - Use ecFlow workflow manager
   * - ``-h``
     - Display help
   * - ``-k``
     - Keep run directory
   * - ``-l``
     - Run tests listed in a file
   * - ``-m``
     - Compare against new baseline results
   * - ``-n``
     - Run a single named test
   * - ``-r``
     - Use Rocoto workflow manager

After the test starts, inspect the case directory. The ``{dprefix}`` value is
set in ``rt.sh``, and the regression-test driver prints the ``rt_[test_id]``
directory name when the run starts:

.. code-block:: console

   cd {dprefix}/[user_id]/FV3_RT/rt_[test_id]

The example produces directories for the executable build, the control run, and
the restart run. To modify inputs and rerun a case:

.. code-block:: console

   cd cpld_control_gfsv17_intel
   # Modify input files as needed
   sbatch job_card

.. _related-global-workflow-example:

Related Global Workflow Example
-------------------------------

This example is not necessary for building or running the UFS DA Workflow. It is
included only for users who want to compare UFS DA Workflow behavior with
global-workflow cases.

#. Create test directories:

   .. code-block:: console

      mkdir global_workflow_test
      cd global_workflow_test
      mkdir HOMEDIR
      mkdir STMP

#. Clone global-workflow:

   .. code-block:: console

      module load git-lfs
      git clone --recursive https://github.com/NOAA-EMC/global-workflow
      cd global-workflow

#. Build global-workflow components:

   .. code-block:: console

      cd sorc
      ./build_all.sh -A [account] -c gfs gsi gdas

   ``[account]`` is the project account name on NOAA RDHPCS machines. The
   ``-A [account] -c`` options build on compute nodes. To build on the login
   node, omit those options.

#. Link workflow files and enter the setup directory:

   .. code-block:: console

      ./link_workflow.sh
      cd ../dev/workflow

#. Update the host YAML file, such as ``hosts/ursa.yaml``, with the desired
   ``HOMEDIR``, ``STMP``, ``PTMP``, and ``DO_ARCHCOM`` values.

#. Generate a sample workflow:

   .. code-block:: console

      ./generate_workflows.sh -A [account] -y [sample_case] -t test /path/to/global_workflow_test/test_case

   Sample cases are listed in
   ``global-workflow/dev/ci/gitlab-ci-hosts.yml``.

#. Move to the experiment directory:

   .. code-block:: console

      cd /path/to/global_workflow_test/test_case/EXPDIR/[sample_case]_test

   To preserve working directories, set ``KEEPDATA`` in ``config.base``:

   .. code-block:: console

      export KEEPDATA="YES"

#. Load Rocoto if needed, then run and monitor the workflow using ``rocotorun`` and ``rocotostat`` respectively:

   .. code-block:: console

      rocotorun -w [sample_case]_test.xml -d [sample_case]_test.db
      rocotostat -w [sample_case]_test.xml -d [sample_case]_test.db

Output files are written under the configured ``COMROOT``. After generating the
sample workflow, inspect the generated experiment configuration in
``EXPDIR/[sample_case]_test`` to confirm the resolved ``COMROOT`` and ``STMP``
values. Log files are under ``COMROOT/[sample_case]_test/logs``, and temporary
run directories are under the configured ``STMP`` path.
