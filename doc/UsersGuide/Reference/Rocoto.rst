.. _rocoto:

Rocoto Introductory Information
===============================

Rocoto is one of the workflow managers supported by the UFS DA Workflow. When
``WORKFLOW_MANAGER`` is set to ``rocoto`` in ``config.yaml``, the experimental
case directory is set up to run workflow tasks with the Rocoto workflow manager.
See the `Rocoto documentation <https://noaa-gsl.github.io/rocoto/>`_ for
additional command usage and workflow-manager details.

In the examples below, ``${HOMEufsda}`` refers to the full path of the cloned
``ufs-da-workflow`` repository.

.. _rocoto-select:

Select Rocoto
-------------

Load the workflow environment:

.. code-block:: console

   cd ${HOMEufsda}
   module use modulefiles
   module load wflow_[workflow_manager]_[machine]

Replace ``[workflow_manager]`` with ``rocoto`` and replace ``[machine]`` with
``gaeac6``, ``hercules``, ``orion``, ``ursa``, or ``derecho``.

In ``config.yaml``, set:

.. code-block:: yaml

   parm:
     WORKFLOW_MANAGER: rocoto

Based on the ``WORKFLOW_MANAGER`` parameter in the configuration file, a Rocoto
XML file is generated in the experiment directory.

.. _rocoto-automated-launch:

Automated Launch
----------------

Move to the generated experiment directory:

.. include:: ../../doc-snippets/rocoto-expdir.rst

Run the automation script:

.. include:: ../../doc-snippets/rocoto-auto-launch.rst

The automation script runs ``launch_rocoto_wflow.sh`` every 10 seconds by
default. To use a 30-second interval:

.. include:: ../../doc-snippets/rocoto-auto-interval.rst

or:

.. code-block:: console

   ./automate_launch_script.py --interval 30

The script prints status information to the terminal, for example:

.. code-block:: text

   Using log file: log.rocoto_launch
   Running ./launch_rocoto_wflow.sh ...
    Cycles: 0 out of 2 completed.
    Detected wflow_status = IN PROGRESS
    Waiting 10 seconds before next run...

Press ``Ctrl+C`` to stop the automation loop. To resume the loop, run
``./automate_launch_script.py`` again from the experiment directory.

.. _rocoto-manual-helper-launch:

Manual Launch With the Helper Script
------------------------------------

Users can run the launch helper directly:

.. include:: ../../doc-snippets/rocoto-expdir.rst

.. include:: ../../doc-snippets/rocoto-helper-launch.rst

Run ``launch_rocoto_wflow.sh`` sequentially until all workflow tasks complete.
The script calls ``rocotorun``, checks ``rocotostat`` output, writes
``log.rocoto_launch``, and reports whether the workflow is still in progress,
has succeeded, or has failed.

.. _rocoto-manual-commands:

Manual Launch With Rocoto Commands
----------------------------------

If needed, load Rocoto directly for the target platform:

.. list-table:: Rocoto module commands
   :header-rows: 1
   :widths: 20 80

   * - Platform
     - Commands
   * - Ursa
     - ``module load rocoto``
   * - Orion
     - ``module load contrib``; ``module load rocoto``
   * - Hercules
     - ``module load contrib``; ``module load rocoto``
   * - Gaea-C6
     - ``module use /ncrc/proj/epic/rocoto/modulefiles/``;
       ``module load rocoto``
   * - Derecho
     - ``module use /glade/work/epicufsrt/contrib/derecho/modulefiles``;
       ``module load rocoto/1.3.7``

Launch the workflow manually:

.. include:: ../../doc-snippets/rocoto-expdir.rst

Replace ``[EXP_CASE_NAME]`` with the experiment case name set in
``config.yaml``.

.. code-block:: console

   rocotorun -w [EXP_CASE_NAME].xml -d [EXP_CASE_NAME].db -v 10

Check task status:

.. code-block:: console

   rocotostat -w [EXP_CASE_NAME].xml -d [EXP_CASE_NAME].db -v 10

.. _rocoto-restart-dead-task:

Restart a DEAD Task
-------------------

When a task fails, ``rocotostat`` may report it in the ``DEAD`` state:

.. code-block:: text

   CYCLE          TASK      JOBID     STATE      EXIT STATUS TRIES DURATION
   ========================================================================
   200001030000   analysis  16805206  SUCCEEDED  0           1     69.0
   200001030000   forecast  16805240  DEAD        5           1     -

After resolving the underlying issue, rewind the failed task:

.. code-block:: console

   rocotorewind -w [EXP_CASE_NAME].xml -d [EXP_CASE_NAME].db -c 200001030000 -t forecast

The cycle supplied with ``-c`` must include minutes in ``YYYYMMDDHHmm`` format.
To rewind multiple tasks:

.. code-block:: console

   rocotorewind -w [EXP_CASE_NAME].xml -d [EXP_CASE_NAME].db -c 200001030000 -t 'analysis,forecast'

Submit the rewound task again:

.. code-block:: console

   rocotoboot -w [EXP_CASE_NAME].xml -d [EXP_CASE_NAME].db -c 200001030000 -t forecast

.. _rocoto-command-flags:

Useful Rocoto Command Flags
---------------------------

.. list-table:: Common Rocoto flags
   :header-rows: 1
   :widths: 20 80

   * - Flag
     - Description
   * - ``-w``
     - Path to the Rocoto workflow XML file.
   * - ``-d``
     - Path to the Rocoto workflow database file.
   * - ``-v``
     - Run Rocoto in verbose mode at the specified level.
   * - ``-c``
     - Cycle or cycle list. Values may be a single cycle, comma-separated
       cycles, a cycle range, or ``all``.
   * - ``-t``
     - Task or comma-separated task list.
