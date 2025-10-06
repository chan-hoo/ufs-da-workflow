#!/usr/bin/env python3

###################################################################### CHJ #####
## Name		: plot_forecast_out_cice.py
## Usage	: Plot CICE output files in forecast
## NOAA/EPIC
## History ===============================
## V000: 2025/10/03: Chan-Hoo Jeon : Preliminary version
###################################################################### CHJ #####

import os, sys
import logging
import yaml
import numpy as np
import netCDF4 as nc
import cartopy
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import xarray as xr
import matplotlib.pyplot as plt
import matplotlib.colors as colors
import matplotlib.ticker
import matplotlib as mpl
from matplotlib.colors import ListedColormap
from mpl_toolkits.axes_grid1 import make_axes_locatable


# Main part (will be called at the end) ============================= CHJ =====
def main():

    yaml_file="plot_forecast_out_cice.yaml"
    with open(yaml_file, 'r') as f:
        yaml_data=yaml.load(f, Loader=yaml.FullLoader)
    f.close()

    cartopy_ne_path = yaml_data['cartopy_ne_path']
    colorbar_option = yaml_data['colorbar_option']
    FCST_HRS = yaml_data['FCST_HRS']
    fn_base_prefix = yaml_data['fn_base_prefix']
    out_title_base = yaml_data['out_title_base']
    out_fn_base = yaml_data['out_fn_base']
    OUTPUT_FH_CICE = yaml_data['OUTPUT_FH_CICE']
    path_data = yaml_data['path_data']
    PY_LOG_LEVEL = yaml_data['PY_LOG_LEVEL']
    RES = yaml_data['RES']
    var_list_ice = yaml_data['var_list_ice']
    work_dir = yaml_data['work_dir']

    # Set logging config
    log_level_str = PY_LOG_LEVEL.upper()
    try:
        log_level = getattr(logging, log_level_str)
    except AttributeError:
        log_level_str = "INFO"
        log_level = logging.INFO
        print(f''' WARNING: Invalid log level "{PY_LOG_LEVEL.upper()}", set to INFO.''')
    print(f''' Python Log Level = str: {log_level_str}, attr: {log_level}''')
    logging.basicConfig(format='%(levelname)s::%(pathname)s::L%(lineno)d::%(message)s', level=log_level)

    logging.info(f''' YAML Data: {yaml_data}''')

    # Set the path to Natural Earth dataset
    cartopy.config['data_dir'] = cartopy_ne_path

    # Make list of output hours from OUTPUT_FH_CICE
    fhr_1st = int(OUTPUT_FH_CICE)
    fhr_list = list(range(fhr_1st, int(FCST_HRS)+1, int(OUTPUT_FH_CICE)))
    logging.info(f''' FHR list: {fhr_list}''')

    # from 'ice' file
    logging.info(f''' ICE variable list: {var_list_ice}''')
    if var_list_ice:
        for var_nm in var_list_ice:
            # get lon, lat
            fn_ice = f'''{fn_base_prefix}.ice.f{fhr_1st:03d}.c{RES}.nc'''
            glon,glat = get_geo(path_data,fn_ice,var_nm)
            for ifhr in fhr_list:
                ifhr_3d = f'''{ifhr:03d}'''
                logging.info(f''' Variable: {var_nm} from "ice", fhr: {ifhr_3d}''')
                fn_ice = f'''{fn_base_prefix}.ice.f{ifhr_3d}.c{RES}.nc'''
                plot_data(path_data,fn_ice,var_nm,glon,glat,ifhr_3d,
                          out_title_base,out_fn_base,work_dir,colorbar_option)


# geo lon/lat ======================================================= CHJ =====
def get_geo(path_data,fn_data,var_nm):

    logging.info(f''' ===== geo data files ====================================''')
    # open the data file
    fp_data=os.path.join(path_data,fn_data)
    try: data_raw=nc.Dataset(fp_data)
    except: raise Exception('Could NOT find the file',fp_data)
    logging.info(f''' Variables: {list(data_raw.variables)}''')
    # Extract geo data
    # lon/lat at T-grid center points
    geolon_t = np.ma.masked_invalid(data_raw.variables['TLON'])
    geolat_t = np.ma.masked_invalid(data_raw.variables['TLAT'])
    # lon/lat at U-grid center plints
    geolon_u = np.ma.masked_invalid(data_raw.variables['ULON'])
    geolat_u = np.ma.masked_invalid(data_raw.variables['ULAT'])
    # lon/lat at N-grid center points
    geolon_n = np.ma.masked_invalid(data_raw.variables['NLON'])
    geolat_n = np.ma.masked_invalid(data_raw.variables['NLAT'])
    # lon/lat at E-grid center points
    geolon_e = np.ma.masked_invalid(data_raw.variables['ELON'])
    geolat_e = np.ma.masked_invalid(data_raw.variables['ELAT'])

    list_t = [ "hi_h", "hs_h", "Tsfc_h", "aice_h", "uatm_h", "vatm_h", "scie_h",
               "fswdn_h", "flwdn_h", "snow_ai_h", "rain_ai_h", "sst_h", "sss_h",
               "uocn_h", "vocn_h", "frzmlt_h", "scale_factor", "fswint_ai_h", 
               "fswabs_ai_h", "albsni_h", "alvdr_h", "alidr_h", "alvdf_h",
               "alidf_h", "flat_ai_h", "fsens_ai_h", "flwup_ai_h", "evap_ai_h",
               "Tair_h", "Tref_h", "Qref_h", "congel_h", "frazil_h", "snoice_h",
               "dsnow_h", "meltt_h", "metls_h", "meltb_h", "meltl_h", "fresh_ai_h",
               "fsalt_ai_h", "fbot_h", "fhocn_ai_h", "fswthru_ai_h", "divu_h",
               "shear_h", "dvidtt_h", "dvidtd_h", "daidtt_h", "daidtd_h",
               "mlt_onset_h", "frz_onset_h", "ice_present_h", "fsurf_ai_h", 
               "fcondtop_ai_h", "apond_ai_h", "ipond_ai_h", "apeff_ai_h" ]
               
    list_u = [ "uvel_h", "vvel_h", "strairx_h", "strairy_h", "strocnx_h", "strocny_h" ]

    if var_nm in list_t:
        glon = geolon_t
        glat = geolat_t
    elif var_nm in list_u:
        glon = geolon_u
        glat = geolat_u
    else:
        logging.error(f''' FATAL ERROR: Variable "{var_nm}" is NOT on the variable list !!!''')
        sys.exit(1)

    logging.info(f''' Dimension of glon = {glon.shape}''')
    logging.info(f''' glon: Max = {np.nanmax(glon)} , Min = {np.nanmin(glon)}''')
    logging.info(f''' Dimension of glat = {glat.shape}''')
    logging.info(f''' glat: Max = {np.nanmax(glat)} , Min = {np.nanmin(glat)}''')

    return glon,glat


# Get data from files and plot ====================================== CHJ =====
def plot_data(path_data,fn_data,var_nm,glon,glat,ifhr,out_title_base,
              out_fn_base,work_dir,colorbar_option):

    logging.info(f''' ===== data file: '{var_nm}' ========================''')
    # open the data file
    fp_data = os.path.join(path_data,fn_data)
    try: data_raw = xr.open_dataset(fp_data)
    except: raise Exception('Could NOT find the file',fp_data)

    # Extract valid variable
    var_orig = data_raw[var_nm]
    var_data = np.ma.masked_invalid(var_orig.values)
    var_nm_long = var_orig.attrs.get("long_name", "No long-name attribute found")
    var_nm_unit = var_orig.attrs.get("units", "No units attribute found")
    ndim_var = var_data.ndim
    logging.info(f''' Variable: {var_nm}: {var_nm_long}: {var_nm_unit}: number of dimensions = {ndim_var}''')
    logging.info(f''' Dimension of data = {var_data.shape}''')
    logging.info(f''' {var_nm}, Max = {np.nanmax(var_data)}''')
    logging.info(f''' {var_nm}, Min = {np.nanmin(var_data)}''')

    plt_var = np.squeeze(var_data)
    data_raw.close()
    logging.info(f''' Dimension of data set = {plt_var.shape}''')

    cs_cmap = 'gist_ncar_r'
    cbar_extend = 'neither'
    cbar_label = f'''{var_nm}:: {var_nm_long} ({var_nm_unit})'''
    if colorbar_option == "fixed":
        if var_nm == "hi_h":
            cs_max = 3.5
            cs_min = 0.0
            cbar_extend = 'max'
        elif var_nm == "hs_h":
            cs_max = 0.5
            cs_min = 0.0
            cbar_extend = 'max'
        else:
            cs_max = np.nanmax(plt_var)
            cs_min = np.nanmin(plt_var)
    else:
        cs_max = np.nanmax(plt_var)
        cs_min = np.nanmin(plt_var)
    logging.info(f''' colorbar_option = {colorbar_option}''')
    logging.info(f''' cs_max = {cs_max}''')
    logging.info(f''' cs_min = {cs_min}''')
    logging.info(f''' colorbar_extend = {cbar_extend}''')

    out_title = f'''{out_title_base}{var_nm}::F{ifhr}'''
    out_fn = f'''{out_fn_base}{var_nm}_f{ifhr}'''

    fig,ax=plt.subplots(1,1,subplot_kw=dict(projection=ccrs.NorthPolarStereo()))
    ax.set_extent([-180, 180, 50, 90], ccrs.PlateCarree())
    ax.set_title(out_title, fontsize=6)
    # Call background plot
    back_plot(ax)
    cs=ax.pcolormesh(glon,glat,plt_var,cmap=cs_cmap,rasterized=True,
       vmin=cs_min,vmax=cs_max,transform=ccrs.PlateCarree())
    divider=make_axes_locatable(ax)
    ax_cb=divider.new_horizontal(size="3%",pad=0.1,axes_class=plt.Axes)
    fig.add_axes(ax_cb)
    cbar=plt.colorbar(cs,cax=ax_cb,extend=cbar_extend)
    cbar.ax.tick_params(labelsize=6)
    cbar.set_label(cbar_label,fontsize=6)

    # Output figure
    ndpi = 300
    out_file(work_dir,out_fn,ndpi)


# Background plot ==================================================== CHJ =====
def back_plot(ax):
    # Resolution of background natural earth data ('50m' or '110m')
    back_res = '50m'

    fline_wd = 0.5  # line width
    falpha = 0.7 # transparency

    # natural_earth
    land = cfeature.NaturalEarthFeature('physical','land',back_res,
                      edgecolor='face',facecolor='lightgray',
                      alpha=falpha)
    lakes = cfeature.NaturalEarthFeature('physical','lakes',back_res,
                      edgecolor='blue',facecolor='none',
                      linewidth=fline_wd,alpha=falpha)
    coastline = cfeature.NaturalEarthFeature('physical','coastline',
                      back_res,edgecolor='black',facecolor='none',
                      linewidth=fline_wd,alpha=falpha)
    states = cfeature.NaturalEarthFeature('cultural','admin_1_states_provinces',
                      back_res,edgecolor='green',facecolor='none',
                      linewidth=fline_wd,linestyle=':',alpha=falpha)
    borders = cfeature.NaturalEarthFeature('cultural','admin_0_countries',
                      back_res,edgecolor='red',facecolor='none',
                      linewidth=fline_wd,alpha=falpha)

    ax.add_feature(land)
#    ax.add_feature(lakes)
#    ax.add_feature(states)
#    ax.add_feature(borders)
    ax.add_feature(coastline)


# Output file ======================================================= CHJ =====
def out_file(work_dir,out_file,ndpi):
    # Output figure
    fp_out = os.path.join(work_dir,out_file)
    plt.savefig(fp_out+'.png',dpi=ndpi,bbox_inches='tight')
    plt.close('all')


# Main call ========================================================= CHJ =====
if __name__=='__main__':
    main()

