#!/usr/bin/env python3

###################################################################### CHJ #####
## Name		: plot_forecast_restart_mom6.py
## Usage	: Plot restart output file for MOM6 in UFS DA workflow
## NOAA/EPIC
## History ===============================
## V000: 2025/09/19: Chan-Hoo Jeon : Preliminary version
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
from scipy.stats import norm
import matplotlib.pyplot as plt
import matplotlib.colors as colors
import matplotlib.ticker
import matplotlib as mpl
from matplotlib.colors import ListedColormap
from mpl_toolkits.axes_grid1 import make_axes_locatable


# Main part (will be called at the end) ============================= CHJ =====
def main():

    yaml_file = "plot_forecast_restart_mom6.yaml"
    with open(yaml_file, 'r') as f:
        yaml_data = yaml.load(f, Loader=yaml.FullLoader)
    f.close()

    cartopy_ne_path = yaml_data['cartopy_ne_path']
    colorbar_option = yaml_data['colorbar_option']
    fn_data = yaml_data['fn_data']
    out_title_base = yaml_data['out_title_base']
    out_fn_base = yaml_data['out_fn_base']
    path_data = yaml_data['path_data']
    PY_LOG_LEVEL = yaml_data['PY_LOG_LEVEL']
    var_list = yaml_data['var_list_restart']
    work_dir = yaml_data['work_dir']
    zlvl = yaml_data['zlevel_number']

    zlvlm1 = int(zlvl)-1

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

    # plot restart file
    for var_nm in var_list:
        glon,glat = get_geo(path_data,fn_data,var_nm)
        plot_data(path_data,fn_data,var_nm,glon,glat,zlvlm1,out_title_base,
                  out_fn_base,work_dir,colorbar_option)


# geo lon/lat ======================================================= CHJ =====
def get_geo(path_data,fn_data,var_nm):

    logging.info(f''' ===== geo data files ====================================''')
    # open the data file
    fp_data = os.path.join(path_data,fn_data)
    try: data_raw = nc.Dataset(fp_data)
    except: raise Exception('Could NOT find the file',fp_data)
    logging.info(f''' Variables: {list(data_raw.variables)}''')
    # Extract geo data
    # lonh/lath
    lon_h = np.ma.masked_invalid(data_raw.variables['lonh'])
    lat_h = np.ma.masked_invalid(data_raw.variables['lath'])
    # lonq/latq
    lon_q = np.ma.masked_invalid(data_raw.variables['lonq'])
    lat_q = np.ma.masked_invalid(data_raw.variables['latq'])

    data_raw.close()

    list_hh = [ "Temp", "Salt", "h", "frazil", "ave_ssh", "sfc", "MEKE", "MEKE_Kh",
                "Kd_shear", "Kv_shear", "MLD", "h_ML", "SFC_BFLX", "MDL_MLE_filtered" ]
    list_qh = [ "u", "u2", "CAu", "diffu", "ubtav" ]
    list_hq = [ "v", "v2", "CAv", "diffv", "vbtav" ]

    if var_nm in list_hh:
        glon = lon_h
        glat = lat_h
    elif var_nm in list_qh:
        glon = lon_q
        glat = lat_h
    elif var_nm in list_hq:
        glon = lon_h
        glat = lat_q
    else:
        logging.error(f''' FATAL ERROR: Variable "{var_nm}" is NOT on the variable list !!!''')
        sys.exit(1)

    logging.info(f''' Dimension of glon = {glon.shape}''')
    logging.info(f''' glon: Max = {np.nanmax(glon)} , Min = {np.nanmin(glon)}''')
    logging.info(f''' Dimension of glat = {glat.shape}''')
    logging.info(f''' glat: Max = {np.nanmax(glat)} , Min = {np.nanmin(glat)}''')

    return glon,glat


# Get data from files and plot ====================================== CHJ =====
def plot_data(path_data,fn_data,var_nm,glon,glat,zlvlm1,out_title_base,
              out_fn_base,work_dir,colorbar_option):

    # center of map
    c_lon = -77.0369

    zlvl = zlvlm1+1

    logging.info(f''' ===== data file: '{var_nm}' ========================''')
    # open the data file
    fp_data = os.path.join(path_data,fn_data)
    try: data_raw = nc.Dataset(fp_data)
    except: raise Exception('Could NOT find the file',fp_data)

    # Extract valid variable
    var_orig = data_raw.variables[var_nm]
    var_data = np.ma.masked_invalid(var_orig)
    if hasattr(var_orig, 'long_name'):
        var_nm_long = var_orig.long_name
    else:
        logging.error(f'''No long_name attribute found''')
    if hasattr(var_orig, 'units'):
        var_nm_unit = var_orig.units
    else:
        logging.error(f'''No units attribute found''')
    ndim_var = var_data.ndim
    logging.info(f''' Variable: {var_nm}: {var_nm_long}: {var_nm_unit}: number of dimensions = {ndim_var}''')
    if ndim_var == 4:
        logging.info(f''' Dimension of original data = {var_data.shape}, z-level = {zlvl}''')
        var_data_2d = var_data[:,zlvlm1,:,:]
    else:
        var_data_2d = var_data

    logging.info(f''' Dimension of data = {var_data_2d.shape}''')
    logging.info(f''' {var_nm}, Max = {np.nanmax(var_data_2d)}''')
    logging.info(f''' {var_nm}, Min = {np.nanmin(var_data_2d)}''')

    plt_var = np.squeeze(var_data_2d)
    data_raw.close()

    logging.info(f''' Dimension of data set = {plt_var.shape}''')

    cs_cmap = 'gist_ncar_r'
    cbar_extend = 'neither'
    cbar_label = f'''{var_nm}:: {var_nm_long} ({var_nm_unit})'''
    if colorbar_option == "fixed":
        if var_nm == "sfc":
            cs_cmap = 'turbo'
            cs_max = 1.5
            cs_min = -1.5
            cbar_extend = 'both'
        elif var_nm == "Salt":
            cs_cmap = 'turbo'
            cs_max = 38
            cs_min = 30
            cbar_extend = 'both'
        elif var_nm == "Temp":
            cs_cmap = 'nipy_spectral'
            cs_max = 35
            cs_min = -5
            cbar_extend = 'both'
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

    if ndim_var == 4:
        out_title = f'''{out_title_base}{var_nm}::L{zlvl}'''
        out_fn = f'''{out_fn_base}{var_nm}_z{zlvl}'''
    else:
        out_title = f'''{out_title_base}{var_nm}'''
        out_fn = f'''{out_fn_base}{var_nm}'''

    fig,ax=plt.subplots(1,1,subplot_kw=dict(projection=ccrs.Robinson(c_lon)))
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
                      edgecolor='face',facecolor=cfeature.COLORS['land'],
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

#    ax.add_feature(land)
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

