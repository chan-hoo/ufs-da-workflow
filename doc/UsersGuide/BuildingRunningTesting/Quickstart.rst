.. _QuickStart:

*****************
Quick Start Guide
*****************

This chapter walks through the ``config.S2SWA.free-fcst.cycle.ecflow.yaml``
forecast-only case. For other applications, JEDI build options, GDAS App build
options, or Rocoto runs, see :ref:`build-ufs-da-workflow` and
:ref:`component-configuration`.

.. attention::

   These steps are designed for Level 1 systems: Ursa, Orion, Hercules,
   Gaea-C6, and Derecho. When using ecFlow on Ursa, run the ecFlow steps on
   the ``uecflow01`` node.

Run the S2SWA Free-Forecast ecFlow Case
=======================================

#. Retrieve the ``develop`` branch of the UFS DA Workflow:

   .. include:: ../../doc-snippets/clone-ufsda-sorc.rst

   .. note::

      The path to the ``ufs-da-workflow`` directory is referred to as
      ``${HOMEufsda}`` in the commands below.

#. Build the ``S2SWA`` workflow components:

   .. code-block:: console

      ./app_build.sh -a=S2SWA

   This basic build does not build JEDI-bundle or GDAS App. For experiments
   that require JEDI executables, see :ref:`optional-da-dependencies`.

#. Load the modules and Python environment for an ecFlow run:

   .. include:: ../../doc-snippets/load-workflow-env.rst

   Replace ``[workflow_manager]`` with ``ecflow``. Replace ``[machine]`` with
   ``gaeac6``, ``hercules``, ``orion``, ``ursa``, or ``derecho``.

#. Copy the sample configuration and edit it for the experiment:

   .. code-block:: console

      cd ${HOMEufsda}/parm
      cp config_samples/config.S2SWA.free-fcst.cycle.ecflow.yaml config.yaml
      vim config.yaml

   Update the parameter values as needed, especially ``ACCOUNT``.

#. Set up the case-specific experiment directory:

   .. include:: ../../doc-snippets/setup-wflow-env.rst

#. Launch the ecFlow suite:

   .. include:: ../../doc-snippets/ecflow-launch.rst

   ``[EXP_CASE_NAME]`` is set in ``config.yaml``. If the ecFlow server is
   already running, do not start it again.

#. Check the generated result and log links in the experiment directory:

   * ``com_dir``: symlink to the directory containing result files
   * ``log_dir``: symlink to the directory containing log files
   * ``tmp_dir``: symlink to the directory containing working directories

#. After the suite is complete, stop the ecFlow server:

   .. include:: ../../doc-snippets/ecflow-stop.rst
