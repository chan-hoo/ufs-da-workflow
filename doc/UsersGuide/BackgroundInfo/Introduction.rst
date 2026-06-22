.. _Intro:

****************
Introduction
****************

Unified Forecast System (UFS)
=============================

The UFS is a community-based, coupled, comprehensive Earth modeling system. It
includes :ufs:`multiple applications <applications>` that support different
forecast durations and spatial domains. NOAA's operational model suite for
numerical weather prediction (:term:`NWP`) is transitioning to the UFS from
many different modeling systems.
The UFS is designed to enable research, development, and contribution
opportunities within the broader :term:`Weather Enterprise` (including
government, industry, and academia). For more information about the UFS, visit
the :ufs:`UFS Portal <>`.

UFS DA Workflow
===============

The UFS Data Assimilation (DA) Workflow provides a configurable framework for
running :term:`data assimilation` experiments with the :term:`UFS` Weather
Model and the Joint Effort for Data assimilation Integration (:term:`JEDI`)
system. It connects model forecasts,
observations, analysis applications, and workflow management tools so users can
prepare data, generate forecast backgrounds, run JEDI-based analyses, and cycle
updated model states through subsequent forecasts.

The workflow is designed to support data assimilation across several UFS
applications. These applications range from an atmosphere-only
configuration to coupled Earth system configurations that include ocean, sea
ice, wave, aerosol/chemistry, and land components. Supported application
configurations include:

* ``S2SWA``: atmosphere (FV3+CCPP), ocean (MOM6), sea ice (CICE), waves
  (WW3), and aerosol/chemistry (GOCART)
* ``S2SWAL``: ``S2SWA`` plus land (Noah-MP)
* ``NG-GODAS``: data atmosphere (DATM), ocean (MOM6), and sea ice (CICE)
* ``ATML``: atmosphere (FV3+CCPP) and land (Noah-MP)
* ``ATM``: stand-alone atmosphere (FV3+CCPP)

By providing common configuration files, task scripts, and experiment templates,
the UFS DA Workflow helps users build reproducible DA experiments while
preserving flexibility for different model components, observation types,
analysis methods, and computing platforms.

User Support and Documentation
==============================

Questions
---------

The UFS DA Workflow's `GitHub Discussions forum <https://github.com/ufs-community/ufs-da-workflow/discussions>`_
provides online support for UFS users and developers to post questions and
exchange information. When users encounter difficulties running the UFS DA
Workflow, this is the place to post. Users can expect an initial response within
two business days.

When posting a question, users are encouraged to provide the following
information:

* The platform or system being used (e.g., Ursa, Orion, Derecho, Hercules,
  GaeaC6)
* The version of the ufs-da-workflow being used (e.g., ``develop``,
  ``release/public-v1.0.0``). To determine this, users can run ``git branch``;
  the name of the branch with an asterisk (``*``) in front of it is the name of
  the branch or tag they are working on. Note that the ufs-da-workflow version
  and the documentation version should match, or users will run into
  difficulties.
* Stage of the application when the issue appeared (i.e., build/compilation,
  configuration, or forecast run)
* Contents of relevant configuration files
* Full error message (preferably in text form rather than a screenshot)
* Current shell (e.g., bash, csh) and modules loaded
* Compiler + MPI combination being used
* Run directory and code directory, if available on supported platforms
