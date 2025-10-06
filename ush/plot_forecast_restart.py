#!/usr/bin/env python3

###################################################################### CHJ #####
## Name		: plot_forecast_restart.py
## Usage	: Plot restart output file of UFS DA workflow
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

    global num_tiles

    yaml_file = "plot_restart.yaml"
    with open(yaml_file, 'r') as f:
        yaml_data = yaml.load(f, Loader=yaml.FullLoader)
    f.close()

    cartopy_ne_path = yaml_data['cartopy_ne_path']
    colorbar_option = yaml_data['colorbar_option']
    fn_data_base = yaml_data['fn_data_base']
    orog_path = yaml_data['orog_path']
    orog_fn_base = yaml_data['orog_fn_base']
    out_title_base = yaml_data['out_title_base']
    out_fn_base = yaml_data['out_fn_base']
    path_data = yaml_data['path_data']
    plot_each_tile = yaml_data['plot_each_tile']
    PY_LOG_LEVEL = yaml_data['PY_LOG_LEVEL']
    var_list = yaml_data['var_list_restart']
    work_dir = yaml_data['work_dir']
    zlvl = yaml_data['zlevel_number']

    zlvlm1 = int(zlvl)-1
    num_tiles = 6

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

    # get lon, lat from orography
    get_geo(orog_path,orog_fn_base)

    # plot restart file
    for var_nm in var_list:
        plot_data(path_data,fn_data_base,var_nm,zlvlm1,out_title_base,
                  out_fn_base,work_dir,plot_each_tile,colorbar_option)


# geo lon/lat from orography ======================================== CHJ =====
def get_geo(orog_path,orog_fn_base):

    global glon,glat
    logging.info(f''' ===== geo data files ==============================================''')

    glon_all = []
    glat_all = []
    for it in range(num_tiles):
        itp = it+1
        fn_orog = f'''{orog_fn_base}.tile{itp}.nc'''
        fp_orog = os.path.join(orog_path,fn_orog)

        try: orog = xr.open_dataset(fp_orog)
        except: raise Exception('Could NOT find the file',fp_orog)

        # Extract longitudes, and latitudes
        geolon = np.ma.masked_invalid(orog['geolon'].data)
        geolat = np.ma.masked_invalid(orog['geolat'].data)

        logging.info(f''' Dimension of glon (tile {itp}) = {geolon.shape}''')
        logging.info(f''' Tile{itp}, Max = {np.max(geolon)}''')
        logging.info(f''' Tile{itp}, Min = {np.min(geolon)}''')
        logging.info(f''' Dimension of glat (tile {itp}) = {geolat.shape}''')
        logging.info(f''' Tile{itp}, Max = {np.max(geolat)}''')
        logging.info(f''' Tile{itp}, Min = {np.min(geolat)}''')

        glon_all.append(geolon[None,:])
        glat_all.append(geolat[None,:])

        if itp == 1:
            logging.info(f''' Variables: {list(orog.variables)}''')

    glon = np.vstack(glon_all)
    glat = np.vstack(glat_all)

    logging.info(f''' Dimension of glon = {glon.shape}''')
    logging.info(f''' Dimension of glon = {glat.shape}''')


# Get sfc_data from files and plot ================================== CHJ =====
def plot_data(path_data,fn_data_base,var_nm,zlvlm1,out_title_base,out_fn_base,
              work_dir,plot_each_tile,colorbar_option):

    # center of map
    c_lon = -77.0369

    zlvl = zlvlm1+1

    logging.info(f''' ===== data file: '{var_nm}' ========================''')
    # open the data file
    for it in range(num_tiles):
        itp = it+1
        fn_data = fn_data_base+str(itp)+'.nc'
        fp_data = os.path.join(path_data,fn_data)
        try: data_raw = xr.open_dataset(fp_data)
        except: raise Exception('Could NOT find the file',fp_data)
        if itp == 1:
            logging.info(f''' Variables: {list(data_raw.variables)}''')

        # Extract valid variable
        var_orig = data_raw[var_nm]
        var_data = np.ma.masked_invalid(var_orig.values)
#        var_nm_long = var_orig.attrs.get("long_name", "No long-name attribute found")
#        var_nm_unit = var_orig.attrs.get("units", "No units attribute found")
        ndim_var = var_data.ndim
        logging.info(f''' Variable: number of dimensions = {ndim_var}''')

        if ndim_var == 4:
            logging.info(f''' Dimension of original data = {var_data.shape}, z-level = {zlvl}''')
            var_data_2d = var_data[:,zlvlm1,:,:]
        else:
            var_data_2d = var_data
 
        logging.info(f''' Dimension of data = {var_data_2d.shape}''')
        logging.info(f''' Tile{itp}, Max = {np.max(var_data_2d)}''')
        logging.info(f''' Tile{itp}, Min = {np.min(var_data_2d)}''')

        if itp == 1:
            plt_var = var_data_2d
        else:
            plt_var = np.ma.concatenate((plt_var,var_data_2d),axis=0)
        data_raw.close()

    logging.info(f''' Dimension of data set = {plt_var.shape}''')

    cs_cmap = 'gist_ncar_r'
    cbar_extend = 'neither'
    cbar_label = var_nm
    if colorbar_option == "fixed":
        if var_nm == "snodl":
            cs_max = 800.0
            cs_min = 0.0
            cbar_extend = 'max'
            cbar_label = f'''{var_nm}:: Total snow depth on land (mm)'''
        elif var_nm == "smc":
            cs_cmap = 'nipy_spectral'
            cs_max = 0.4
            cs_min = 0.0
            cbar_extend = 'max'
            cbar_label = f'''{var_nm}:: Total soil water content (m3/m3)'''
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

    # Plot each tile
    if plot_each_tile == "YES":
        for it in range(num_tiles):
            itp = it+1
            glon_tile = np.squeeze(glon[it,:,:])
            if itp == 1:
                glon_tile = (glon_tile+180)%360-180
            glat_tile = np.squeeze(glat[it,:,:])
            var_tile = np.squeeze(plt_var[it,:,:])
            c_glon = np.round(np.mean(glon_tile),decimals=2)
            c_glat = np.round(np.mean(glat_tile),decimals=2)
            logging.info(f'''c_glon, c_glat for tile{str(it+1)} = {c_glon}, {c_glat}''')
            if ndim_var == 4:
                out_title = f'''{out_title_base}{var_nm}::L{zlvl}::Tile{itp}'''
                out_fn = f'''{out_fn_base}{var_nm}_z{zlvl}_tile{itp}'''
            else:
                out_title = f'''{out_title_base}{var_nm}::Tile{itp}'''
                out_fn = f'''{out_fn_base}{var_nm}_tile{itp}'''
    
            fig,ax = plt.subplots(1,1,subplot_kw=dict(projection=ccrs.Orthographic(c_glon,c_glat)))
            ax.set_title(out_title, fontsize=6)
            # Call background plot
            back_plot(ax)
            cs=ax.pcolormesh(glon_tile,glat_tile,var_tile,cmap=cs_cmap,
                rasterized=True,vmin=cs_min,vmax=cs_max,transform=ccrs.PlateCarree())
            divider=make_axes_locatable(ax)
            ax_cb=divider.new_horizontal(size="3%",pad=0.1,axes_class=plt.Axes)
            fig.add_axes(ax_cb)
            cbar=plt.colorbar(cs,cax=ax_cb,extend=cbar_extend)
            cbar.ax.tick_params(labelsize=6)
            cbar.set_label(var_nm,fontsize=6)
            # Output figure
            ndpi=300
            out_file(work_dir,out_fn,ndpi)

    # Plot all tiles together
    if ndim_var == 4:
        out_title = f'''{out_title_base}{var_nm}::L{zlvl}::All tiles'''
        out_fn = f'''{out_fn_base}{var_nm}_z{zlvl}_alltiles'''
    else:
        out_title = f'''{out_title_base}{var_nm}::All tiles'''
        out_fn = f'''{out_fn_base}{var_nm}_alltiles'''

    fig,ax=plt.subplots(1,1,subplot_kw=dict(projection=ccrs.Robinson(c_lon)))
    ax.set_title(out_title, fontsize=6)
    # Call background plot
    back_plot(ax)
    for it in range(num_tiles):
        itp=it+1
        glon_tile=np.squeeze(glon[it,:,:])
        if itp == 1:
            glon_tile=(glon_tile+180)%360-180
        glat_tile=np.squeeze(glat[it,:,:])
        var_tile=np.squeeze(plt_var[it,:,:])
        cs=ax.pcolormesh(glon_tile,glat_tile,var_tile,cmap=cs_cmap,rasterized=True,
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

