.. _component-configuration:

Component Configuration
========================

The UFS DA Workflow supports several forecast model application configurations.
Each application enables a different set of UFS Weather Model components.

.. _component-configuration-s2swa:

Coupling: ATM/OCN/ICE/WAV/CHM (APP=S2SWA)
----------------------------------------------

* Coupling option used for GFS and GEFS. GOCART is excluded in the GFS
  configuration.

.. list-table:: Component configuration of S2SWA in UFS Weather Model
   :header-rows: 1
   :widths: 20 15 65

   * - Model component
     - Coupling
     - Description
   * - FMS
     - ON
     - Flexible Modeling System
   * - FV3
     - ON
     - Dynamical core of atmospheric model developed by NOAA GFDL
   * - MPAS
     - OFF
     - Dynamical core of atmospheric model by Los Alamos Lab and NCAR
   * - AQM
     - OFF
     - Air quality model (CMAQ)
   * - GOCART
     - ON
     - NASA Goddard Chemistry Aerosol Radiation and Transport model
   * - MOM6
     - ON
     - Ocean model developed by NOAA GFDL
   * - HYCOM
     - OFF
     - Ocean model developed by U.S. Navy
   * - CICE6
     - ON
     - Sea ice model
   * - LM4
     - OFF
     - Land model developed by NOAA GFDL
   * - WW3
     - ON
     - Wave model (WaveWatch III)
   * - STOCH_PHYS
     - ON
     - Physics component of atmospheric model
   * - CDEPS
     - ON
     - Community Data models for Earth Predictive Systems
   * - CMEPS
     - ON
     - Community Mediator for Earth Prediction Systems
   * - NOAHMP
     - OFF
     - Land surface model
   * - FIRE_BEHAVIOR
     - OFF
     - Fire behavior model

.. _component-configuration-s2swal:

Coupling: ATM/OCN/ICE/WAV/CHM/LND (APP=S2SWAL)
--------------------------------------------------

* Fully coupled configuration.

.. list-table:: Component configuration of S2SWAL in UFS Weather Model
   :header-rows: 1
   :widths: 20 15 65

   * - Model component
     - Coupling
     - Description
   * - FMS
     - ON
     - Flexible Modeling System
   * - FV3
     - ON
     - Dynamical core of atmospheric model developed by NOAA GFDL
   * - MPAS
     - OFF
     - Dynamical core of atmospheric model by Los Alamos Lab and NCAR
   * - AQM
     - OFF
     - Air quality model (CMAQ)
   * - GOCART
     - ON
     - NASA Goddard Chemistry Aerosol Radiation and Transport model
   * - MOM6
     - ON
     - Ocean model developed by NOAA GFDL
   * - HYCOM
     - OFF
     - Ocean model developed by U.S. Navy
   * - CICE6
     - ON
     - Sea ice model
   * - LM4
     - OFF
     - Land model developed by NOAA GFDL
   * - WW3
     - ON
     - Wave model (WaveWatch III)
   * - STOCH_PHYS
     - ON
     - Physics component of atmospheric model
   * - CDEPS
     - ON
     - Community Data models for Earth Predictive Systems
   * - CMEPS
     - ON
     - Community Mediator for Earth Prediction Systems
   * - NOAHMP
     - ON
     - Land surface model
   * - FIRE_BEHAVIOR
     - OFF
     - Fire behavior model

.. _component-configuration-ng-godas:

Coupling: DATM/OCN/ICE (APP=NG-GODAS)
-----------------------------------------

* Coupling option used for NOAA/CPC global modeling.
* Next Generation Global Ocean Data Assimilation System (NG-GODAS).

.. list-table:: Component configuration of NG-GODAS in UFS Weather Model
   :header-rows: 1
   :widths: 20 15 65

   * - Model component
     - Coupling
     - Description
   * - FMS
     - ON
     - Flexible Modeling System
   * - FV3
     - OFF
     - Dynamical core of atmospheric model developed by NOAA GFDL
   * - MPAS
     - OFF
     - Dynamical core of atmospheric model by Los Alamos Lab and NCAR
   * - AQM
     - OFF
     - Air quality model (CMAQ)
   * - GOCART
     - OFF
     - NASA Goddard Chemistry Aerosol Radiation and Transport model
   * - MOM6
     - ON
     - Ocean model developed by NOAA GFDL
   * - HYCOM
     - OFF
     - Ocean model developed by U.S. Navy
   * - CICE6
     - ON
     - Sea ice model
   * - LM4
     - OFF
     - Land model developed by NOAA GFDL
   * - WW3
     - OFF
     - Wave model (WaveWatch III)
   * - STOCH_PHYS
     - ON
     - Physics component of atmospheric model
   * - CDEPS
     - ON
     - Community Data models for Earth Predictive Systems
   * - CMEPS
     - ON
     - Community Mediator for Earth Prediction Systems
   * - NOAHMP
     - OFF
     - Land surface model
   * - FIRE_BEHAVIOR
     - OFF
     - Fire behavior model

.. _component-configuration-atml:

Coupling: ATM/LND (APP=ATML)
--------------------------------

* Coupling option to support the land-DA working group using Noah-MP.

.. list-table:: Component configuration of ATML in UFS Weather Model
   :header-rows: 1
   :widths: 20 15 65

   * - Model component
     - Coupling
     - Description
   * - FMS
     - ON
     - Flexible Modeling System
   * - FV3
     - ON
     - Dynamical core of atmospheric model developed by NOAA GFDL
   * - MPAS
     - OFF
     - Dynamical core of atmospheric model by Los Alamos Lab and NCAR
   * - AQM
     - OFF
     - Air quality model (CMAQ)
   * - GOCART
     - OFF
     - NASA Goddard Chemistry Aerosol Radiation and Transport model
   * - MOM6
     - OFF
     - Ocean model developed by NOAA GFDL
   * - HYCOM
     - OFF
     - Ocean model developed by U.S. Navy
   * - CICE6
     - OFF
     - Sea ice model
   * - LM4
     - OFF
     - Land model developed by NOAA GFDL
   * - WW3
     - OFF
     - Wave model (WaveWatch III)
   * - STOCH_PHYS
     - ON
     - Physics component of atmospheric model
   * - CDEPS
     - OFF
     - Community Data models for Earth Predictive Systems
   * - CMEPS
     - ON
     - Community Mediator for Earth Prediction Systems
   * - NOAHMP
     - ON
     - Land surface model
   * - FIRE_BEHAVIOR
     - OFF
     - Fire behavior model

.. _component-configuration-atm:

Non-coupling: ATM (APP=ATM)
-------------------------------

* Atmospheric model (FV3+CCPP) stand-alone.

.. list-table:: Component configuration of ATM in UFS Weather Model
   :header-rows: 1
   :widths: 20 15 65

   * - Model component
     - Coupling
     - Description
   * - FMS
     - ON
     - Flexible Modeling System
   * - FV3
     - ON
     - Dynamical core of atmospheric model developed by NOAA GFDL
   * - MPAS
     - OFF
     - Dynamical core of atmospheric model by Los Alamos Lab and NCAR
   * - AQM
     - OFF
     - Air quality model (CMAQ)
   * - GOCART
     - OFF
     - NASA Goddard Chemistry Aerosol Radiation and Transport model
   * - MOM6
     - OFF
     - Ocean model developed by NOAA GFDL
   * - HYCOM
     - OFF
     - Ocean model developed by U.S. Navy
   * - CICE6
     - OFF
     - Sea ice model
   * - LM4
     - OFF
     - Land model developed by NOAA GFDL
   * - WW3
     - OFF
     - Wave model (WaveWatch III)
   * - STOCH_PHYS
     - ON
     - Physics component of atmospheric model
   * - CDEPS
     - OFF
     - Community Data models for Earth Predictive Systems
   * - CMEPS
     - OFF
     - Community Mediator for Earth Prediction Systems
   * - NOAHMP
     - OFF
     - Land surface model
   * - FIRE_BEHAVIOR
     - OFF
     - Fire behavior model
