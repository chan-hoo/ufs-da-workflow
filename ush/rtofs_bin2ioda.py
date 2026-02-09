#!/usr/bin/env python3
"""
Read RTOFS unformatted Fortran binary profile observations and write
IODA-V3 NetCDF output.

Includes MOM6 vertical thinning using layer depths (layerz.txt).

Assumptions:
- Fortran file uses big-endian 4-byte record markers (header_dtype=">u4")
- Arrays and record ordering match ocn_obs.f output structure.
- DTG record is fixed-length 12-character strings (YYYYMMDDHHMM) for each profile.
"""

import argparse
from datetime import datetime
import numpy as np
from scipy.io import FortranFile
import os
import sys

jedi_bundle_gdas = os.environ.get('JEDI_BUNDLE_GDAS')
if jedi_bundle_gdas == "gdas":
    jedi_gdas_pyioda_path = os.environ.get('JEDI_GDAS_PYIODA_PATH')
    sys.path.append(jedi_gdas_pyioda_path)

jedi_iodaconv_path = os.environ.get('JEDI_IODACONV_PATH')
sys.path.append(jedi_iodaconv_path)
print(f'''sys.path: {sys.path}''')

import pyiodaconv.ioda_conv_engines as iconv
from pyiodaconv.orddicts import DefaultOrderedDict


# -------------------------------------------------------------------
# IODA metadata definitions
# -------------------------------------------------------------------

locationKeyListpfl = [
    ("latitude", "float"),
    ("longitude", "float"),
    ("depth", "float"),
    ("dateTime", "long"),
]

GlobalAttrs = {
    "odb_version": 1,
}

VarDims = {
    " ": ["nlocs"],
}


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

def read_layerz(file_path: str) -> np.ndarray:
    """Read MOM6 vertical layer depths from comma-separated text file."""
    with open(file_path, "r") as f:
        text = f.read()

    layerz = np.array(
        [float(x) for x in text.split(",") if x.strip()],
        dtype=np.float32,
    )
    print(f"Loaded MOM6 layers: {len(layerz)} levels")
    return layerz


def vertical_thin_profile(depths: np.ndarray, layerz: np.ndarray, start_index: int = 0):
    """
    Vertical thinning based on MOM6 depths.

    Keeps:
      - surface level (0)
      - levels matching MOM6 depth intervals
      - bottom level (mm)

    Mimics ocn_obs.f thinning logic.
    """
    mm = len(depths) - 1
    if mm <= 0:
        return [0]

    selected = [0]
    ma = start_index

    for z in range(len(layerz)):
        if layerz[z] >= depths[mm]:
            break

        for m in range(ma, mm):
            if depths[m] <= layerz[z] <= depths[m + 1]:
                selected.append(m)
                ma = m + 1
                break

    selected.append(mm)
    return sorted(set(selected))


def decode_dtg_record_as_strings(fh: FortranFile, n_obs: int) -> np.ndarray:
    """
    Read DTG record as raw bytes, then decode as fixed-length 12-byte strings.

    Expected total bytes = n_obs * 12.
    """
    raw = fh.read_record("u1").tobytes()
    nbytes = len(raw)

    print(f"DTG record bytes: {nbytes}")

    expected = n_obs * 12
    if nbytes != expected:
        raise ValueError(
            f"DTG record length mismatch: got {nbytes}, expected {expected} (= {n_obs}*12). "
            "File read order may be misaligned."
        )

    ob_dtg = np.array(
        [raw[i * 12:(i + 1) * 12].decode("ascii", errors="ignore").strip()
         for i in range(n_obs)],
        dtype="U12",
    )
    print(f"Parsed dtg count: {len(ob_dtg)}")
    return ob_dtg


def parse_dtg_yyyymmddhhmm(dtg: str) -> datetime:
    """Parse YYYYMMDDHHMM -> datetime, with basic validation."""
    if len(dtg) < 12 or not dtg[:12].isdigit():
        raise ValueError(f"Bad dtg string: '{dtg}'")
    return datetime(
        int(dtg[0:4]),
        int(dtg[4:6]),
        int(dtg[6:8]),
        int(dtg[8:10]),
        int(dtg[10:12]),
    )


# -------------------------------------------------------------------
# Profile reader
# -------------------------------------------------------------------

class ProfileObs:
    """Container for RTOFS binary profile observations."""

    def __init__(self, filename: str, varname: str, layerz_file: str):
        self.filename = filename
        self.varname = varname
        self.layerz = read_layerz(layerz_file)

        # Nested dict for iconv.ExtractObsData
        self.data = DefaultOrderedDict(lambda: DefaultOrderedDict(dict))

        # Standard fill values
        self.floatFill = np.float32(9.96921e36)
        self.intFill = np.int32(-2147483647)

        self._read_binary()

    def _read_binary(self):
        """Read RTOFS binary profiles."""
        print(f"\nOpening binary file: {self.filename}")

        try:
            fh = FortranFile(self.filename, mode="r", header_dtype=">u4")
        except IOError:
            raise IOError(f"ERROR: file not found: {self.filename}")

        # Header info
        n_obs, n_lvl, n_vrsn = fh.read_ints(">i4")
        print(f"Number of profiles : {n_obs}")
        print(f"Max levels/profile : {n_lvl}")
        print(f"File version       : {n_vrsn}")

        if n_obs <= 0:
            print("No observations found.")
            fh.close()
            return

        # Profile-level metadata
        ob_btm = fh.read_reals(">f4")   # not used, but read to keep alignment
        ob_lat = fh.read_reals(">f4")
        ob_lon = fh.read_reals(">f4")

        ob_ls = fh.read_ints(">i4")     # not used, but read to keep alignment
        ob_lt = fh.read_ints(">i4")     # not used, but read to keep alignment

        ob_sal_typ = fh.read_ints(">i4")  # not used
        ob_sal_qc  = fh.read_reals(">f4")
        ob_tmp_typ = fh.read_ints(">i4")  # not used
        ob_tmp_qc  = fh.read_reals(">f4")

        # Profile arrays (per profile records)
        ob_lvl = []
        ob_sal = []
        ob_sal_err = []
        ob_tmp = []
        ob_tmp_err = []

        for _ in range(n_obs):
            ob_lvl.append(fh.read_reals(">f4"))

            ob_sal.append(fh.read_reals(">f4"))
            ob_sal_err.append(fh.read_reals(">f4"))
            fh.read_reals(">f4")  # sal_prb

            ob_tmp.append(fh.read_reals(">f4"))
            ob_tmp_err.append(fh.read_reals(">f4"))
            fh.read_reals(">f4")  # tmp_prb

            fh.read_reals(">f4")  # clm_sal
            fh.read_reals(">f4")  # cssd
            fh.read_reals(">f4")  # clm_tmp
            fh.read_reals(">f4")  # ctsd
            fh.read_reals(">f4")  # flag

        # Date-time group strings
        ob_dtg = decode_dtg_record_as_strings(fh, n_obs)

        fh.close()

        # -----------------------------------------------------------
        # Convert to IODA obs structure
        # -----------------------------------------------------------
        valKey = (self.varname, iconv.OvalName())
        errKey = (self.varname, iconv.OerrName())
        qcKey  = (self.varname, iconv.OqcName())

        for n in range(n_obs):
            lat0 = float(ob_lat[n])
            lon0 = float(ob_lon[n])

            # Parse DTG for this profile
            sa = parse_dtg_yyyymmddhhmm(ob_dtg[n])

            depths = ob_lvl[n]
            keep_levels = vertical_thin_profile(depths, self.layerz)

            # Profile qc is scalar per profile in this file
            if self.varname == "waterTemperature":
                prof_qc = int(ob_tmp_qc[n])
                prof_val = ob_tmp[n]
                prof_err = ob_tmp_err[n]
            else:  # salinity
                prof_qc = int(ob_sal_qc[n])
                prof_val = ob_sal[n]
                prof_err = ob_sal_err[n]

            for k in keep_levels:
                depth = float(depths[k])

                val = float(prof_val[k])
                err = float(prof_err[k])
                qc  = prof_qc

                locKey = (lat0, lon0, depth, int(sa.timestamp()))
                self.data[locKey][valKey] = val
                self.data[locKey][errKey] = err
                self.data[locKey][qcKey]  = qc

        print(f"Total thinned obs written: {len(self.data)}")


# -------------------------------------------------------------------
# Main driver
# -------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convert RTOFS binary profiles into IODA-V3 NetCDF"
    )

    parser.add_argument("-i", "--input", required=True,
                        help="Input RTOFS binary file")
    parser.add_argument("-v", "--varname", required=True,
                        choices=["waterTemperature", "salinity"],
                        help="Variable name")
    parser.add_argument("-o", "--output", required=True,
                        help="Output IODA-V3 NetCDF file")
    parser.add_argument("--layerz", default="layerz.txt",
                        help="MOM6 layer depth file (default: layerz.txt)")

    args = parser.parse_args()

    obs = ProfileObs(args.input, args.varname, args.layerz)

    # Extract for IODA
    ObsVars, Location = iconv.ExtractObsData(obs.data, locationKeyListpfl)

    DimDict = {"Location": Location}
    writer = iconv.IodaWriter(args.output, locationKeyListpfl, DimDict)

    # Variable attributes
    VarAttrs = DefaultOrderedDict(lambda: DefaultOrderedDict(dict))
    VarAttrs[("depthBelowWaterSurface", "MetaData")]["units"] = "m"
    VarAttrs[("dateTime", "MetaData")]["units"] = "seconds since 1970-01-01T00:00:00Z"

    # (Optional) add units if known:
    # VarAttrs[(args.varname, "ObsValue")]["units"] = "K"  # or "degree_Celsius"

    writer.BuildIoda(ObsVars, VarDims, VarAttrs, GlobalAttrs)

    print("\nIODA-V3 file written successfully:")
    print(f"  {args.output}\n")


if __name__ == "__main__":
    main()

