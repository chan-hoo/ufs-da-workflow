#!/usr/bin/env python3

import argparse
from scipy.io import FortranFile
import netCDF4 as nc
from datetime import datetime, timedelta
import numpy as np
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

from warnings import filterwarnings
filterwarnings(action='ignore', category=DeprecationWarning, message='`np.bool` is a deprecated alias')

vName = [
    "waterTemperature",
    "salinity"]

locationKeyList = [
    ("latitude", "float"),
    ("longitude", "float"),
    ("dateTime", "string"),
]

locationKeyListpfl = [
    ("latitude", "float"),
    ("longitude", "float"),
    ("depthBelowWaterSurface", "float"),
    ("dateTime", "long")
]

GlobalAttrs = {
    'odb_version': 1,
}
##GlobalAttrs = {}

DimDict = { }

VarDims = {
	" ": ['nlocs']
}

class profile(object):

    def __init__(self, filename, varname, date):

        self.filename = filename
        self.varname = varname
        self.date = date

        # --- add these ---
        self.VarAttrs = DefaultOrderedDict(lambda: DefaultOrderedDict(dict))
        self.floatDefFillVal = np.float32(9.96921e36)   # netCDF float fill
        self.intDefFillVal   = np.int32(-2147483647)    # int fill
        # ---------------
       
        self._rd_prof()
        return

    def _rd_prof(self):
        '''
        Read the profile data
        Based on subroutine rd_prof in ocn_obs.f
        '''

        try:
            fh = FortranFile(self.filename, mode='r', header_dtype='>u4')
        except IOError:
            raise IOError('%s file not found!' % self.filename)
        except Exception:
            raise Exception('Unknown error opening %s' % self.filename)

        # data is the dictionary with data structure as in ocn_obs.f
        data = {}

        data['n_obs'], data['n_lvl'], data['n_vrsn'] = fh.read_ints('>i4')

        print('    number profiles: %d' % data['n_obs'])
        print('  max number levels: %d' % data['n_lvl'])
        print('file version number: %d' % data['n_vrsn'])

        if data['n_obs'] <= 0:
            print('No profile observations to process from %s' % self.filename)
            return

        data['ob_btm'] = fh.read_reals('>f4')
        data['ob_lat'] = fh.read_reals('>f4')
        data['ob_lon'] = fh.read_reals('>f4')
        data['ob_ls'] = fh.read_ints('>i4')
        data['ob_lt'] = fh.read_ints('>i4')
        data['ob_sal_typ'] = fh.read_reals('>i4')
        data['ob_sal_qc'] = fh.read_reals('>f4')
        data['ob_tmp_typ'] = fh.read_reals('>i4')
        data['ob_tmp_qc'] = fh.read_reals('>f4')

        data['ob_lvl'] = []
        data['ob_sal'] = []
        data['ob_sal_err'] = []
        data['ob_sal_prb'] = []
        data['ob_tmp'] = []
        data['ob_tmp_err'] = []
        data['ob_tmp_prb'] = []
        data['ob_cssd'] = []
        data['ob_ctsd'] = []
        data['ob_flg'] = []

        for n in range(data['n_obs']):
            data['ob_lvl'].append(fh.read_reals('>f4'))
            data['ob_sal'].append(fh.read_reals('>f4'))
            data['ob_sal_err'].append(fh.read_reals('>f4'))
            data['ob_sal_prb'].append(fh.read_reals('>f4'))
            data['ob_tmp'].append(fh.read_reals('>f4'))
            data['ob_tmp_err'].append(fh.read_reals('>f4'))
            data['ob_tmp_prb'].append(fh.read_reals('>f4'))
            data['ob_clm_sal'] = fh.read_reals('>f4')
            data['ob_cssd'].append(fh.read_reals('>f4'))
            data['ob_clm_tmp'] = fh.read_reals('>f4')
            data['ob_ctsd'].append(fh.read_reals('>f4'))
            data['ob_flg'].append(fh.read_reals('>f4'))

        data['ob_dtg'] = fh.read_record('>S12').astype('U12')
        data['ob_rct'] = fh.read_reals('>f4')

        fh.close()

        # keep binary-read content separately
        self.profinfo = data

        # make sure self.data is the obs container (nested)
        if not hasattr(self, "data") or not isinstance(self.data, DefaultOrderedDict):
            self.data = DefaultOrderedDict(lambda: DefaultOrderedDict(dict))

        # Finished all binary reading

        # Start writing
        varName = self.varname
        self.VarAttrs[varName, iconv.OvalName()]['_FillValue'] = self.floatDefFillVal
        self.VarAttrs[varName, iconv.OerrName()]['_FillValue'] = self.floatDefFillVal
        self.VarAttrs[varName, iconv.OqcName()]['_FillValue'] = self.intDefFillVal

        dates = []

        valKey = self.varname, iconv.OvalName()
        errKey = self.varname, iconv.OerrName()
        qcKey = self.varname, iconv.OqcName()
        if ( self.varname == 'waterTemperature' or  self.varname == 'salinity'):
            sws_valKey = 'salinity', iconv.OvalName()
            sws_errKey = 'salinity', iconv.OerrName()
            sws_qcKey = 'salinity', iconv.OqcName()

        for n in range(data['n_obs']):
            lat0 = data['ob_lat'][n]
            lon0 = data['ob_lon'][n]

            dtg = data['ob_dtg'][n]
            sa = datetime(
                int(dtg[0:4]),
                int(dtg[4:6]),
                int(dtg[6:8]),
                int(dtg[8:10]),
                int(dtg[10:12])
            )

            nlev = len(data['ob_lvl'][n])

            for k in range(nlev):
                depth = data['ob_lvl'][n][k]

                if self.varname == 'waterTemperature':
                    val = data['ob_tmp'][n][k]
                    err = data['ob_tmp_err'][n][k]
                    qc  = data['ob_tmp_qc'][n]

                elif self.varname == 'salinity':
                    val = data['ob_sal'][n][k]
                    err = data['ob_sal_err'][n][k]
                    qc  = data['ob_sal_qc'][n]

                else:
                    continue

                locKey = (
                    lat0,
                    lon0,
                    depth,
                    int(sa.timestamp())
                )

                self.data[locKey][valKey] = val
                self.data[locKey][errKey] = err
                self.data[locKey][qcKey]  = qc

        print("Total obs written:", len(self.data))
        return

def main():

    # get command line arguments
    parser = argparse.ArgumentParser(
        description=(
            'read RTOFS obs ascii file'
            'write IODA V3 netCDF file')
    )

    required = parser.add_argument_group(title='required arguments')
    required.add_argument(
        '-i', '--input',
        help="RTOFS obs ascii input file",
        type=str, required=True)
    required.add_argument(
        '-v', '--varname',
        help="IODA V3 variable name, e.g., sea_surface_Temperature",
        type=str, required=True)
    parser.add_argument(
        '-d', '--date', help='file date', metavar='YYYYMMDDHH',
        type=str, required=True)
    required.add_argument(
        '-o', '--output',
        help="IODA V3 output file",
        type=str, required=True)
    args = parser.parse_args()

    
    # Read in profile data in binary format
    obs = profile(args.input, args.varname, args.date)

    # write them out
    if (args.varname == 'waterTemperature' or args.varname == 'salinity'):
       ObsVars, Location = iconv.ExtractObsData(obs.data, locationKeyListpfl)
    else:
       ObsVars, Location = iconv.ExtractObsData(obs.data, locationKeyList)

    DimDict = {'Location': Location}
    if (args.varname == 'waterTemperature' or args.varname == 'salinity'):
       writer = iconv.IodaWriter(args.output, locationKeyListpfl, DimDict)
    else:
       writer = iconv.IodaWriter(args.output, locationKeyList, DimDict)

    VarAttrs = DefaultOrderedDict(lambda: DefaultOrderedDict(dict))
    VarAttrs[('depthBelowWaterSurface', 'MetaData')]['units'] = 'm'
    VarAttrs[('dateTime', 'MetaData')]['units'] = 'seconds since 1970-01-01T00:00:00Z'
    VarAttrs[('waterTemperature', 'ObsValue')]['_FillValue'] = -32767
    VarAttrs[('salinity', 'ObsValue')]['_FillValue'] = -32767
    
    writer.BuildIoda(ObsVars, VarDims, VarAttrs, GlobalAttrs)

if __name__ == '__main__':
    main()


