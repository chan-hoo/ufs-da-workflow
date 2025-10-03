#!/usr/bin/env python3

###################################################################### CHJ #####
## Name		: plot_forecast_out_fv3.py
## Usage	: Plot FV3 output files in forecast
## NOAA/EPIC
## History ===============================
## V000: 2025/09/24: Chan-Hoo Jeon : Preliminary version
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

    yaml_file="plot_forecast_out_fv3.yaml"
    with open(yaml_file, 'r') as f:
        yaml_data=yaml.load(f, Loader=yaml.FullLoader)
    f.close()

    cartopy_ne_path = yaml_data['cartopy_ne_path']
    FCST_HRS = yaml_data['FCST_HRS']
    fn_base_prefix = yaml_data['fn_base_prefix']
    out_title_base = yaml_data['out_title_base']
    out_fn_base = yaml_data['out_fn_base']
    OUTPUT_FH = yaml_data['OUTPUT_FH']
    path_data = yaml_data['path_data']
    plot_each_tile = yaml_data['plot_each_tile']
    PY_LOG_LEVEL = yaml_data['PY_LOG_LEVEL']
    RES = yaml_data['RES']
    var_list_atm = yaml_data['var_list_atm']
    var_list_sfc = yaml_data['var_list_sfc']
    work_dir = yaml_data['work_dir']
    zlvl_atm = yaml_data['zlevel_number_atm']
    zlvl_sfc = yaml_data['zlevel_number_sfc']

    zlvlm1_atm = int(zlvl_atm)-1
    zlvlm1_sfc = int(zlvl_sfc)-1
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

    # Make list of output hours from OUTPUT_FH
    output_fh = list(map(int, OUTPUT_FH.split()))
    if output_fh[1] == -1:
        fhr_list = list(range(0, FCST_HRS+1, output_fh[0]))
    else:
        fhr_list = output_fh
    logging.info(f''' FHR list: {fhr_list}''')

    # from 'atm' file
    logging.info(f''' ATM variable list: {var_list_atm}''')
    if var_list_atm:
        # get lon, lat
        fn_atm_base = f'''{fn_base_prefix}.atm.f000.c{RES}.tile'''
        get_geo(path_data,fn_atm_base)
        # plot output variables: atm
        for var_nm in var_list_atm:
            for ifhr in fhr_list:
                ifhr_3d = f'''{ifhr:03d}'''
                logging.info(f''' Variable: {var_nm} from "atm", fhr: {ifhr_3d}''')
                fn_atm_base = f'''{fn_base_prefix}.atm.f{ifhr_3d}.c{RES}.tile'''
                plot_data(path_data,fn_atm_base,var_nm,ifhr_3d,zlvlm1_atm,out_title_base,out_fn_base,work_dir,plot_each_tile)

    # from 'sfc' file
    logging.info(f''' SFC variable list: {var_list_sfc}''')
    if var_list_sfc:
        # get lon, lat
        fn_sfc_base = f'''{fn_base_prefix}.sfc.f000.c{RES}.tile'''
        get_geo(path_data,fn_sfc_base)
        # plot output variables: sfc
        for var_nm in var_list_sfc:
            for ifhr in fhr_list:
                ifhr_3d = f'''{ifhr:03d}'''
                logging.info(f''' Variable: {var_nm} from "sfc", fhr: {ifhr_3d}''')
                fn_sfc_base = f'''{fn_base_prefix}.sfc.f{ifhr_3d}.c{RES}.tile'''
                plot_data(path_data,fn_sfc_base,var_nm,ifhr_3d,zlvlm1_sfc,
                          out_title_base,out_fn_base,work_dir,plot_each_tile)


# geo lon/lat ======================================================= CHJ =====
def get_geo(path_data,fn_data_base):

    global glon, glat
    logging.info(f''' ===== geo data files ====================================''')
    # open the data file

    glon_all = []
    glat_all = []
    for it in range(num_tiles):
        itp=it+1
        fn_data=f'''{fn_data_base}{itp}.nc'''
        fp_data=os.path.join(path_data,fn_data)
        try: data_raw=nc.Dataset(fp_data)
        except: raise Exception('Could NOT find the file',fp_data)
        if itp == 1:
            logging.info(f''' Variables: {list(data_raw.variables)}''')
        # Extract geo data
        glon_data = np.ma.masked_invalid(data_raw.variables['grid_xt'])
        logging.info(f''' Dimension of glon(grid_xt)= {glon_data.shape}''')
        logging.info(f''' Tile{itp}, Max= {np.max(glon_data)}''')
        logging.info(f''' Tile{itp}, Min= {np.min(glon_data)}''')

        glat_data = np.ma.masked_invalid(data_raw.variables['grid_yt'])
        logging.info(f''' Dimension of glat(grid_yt)= {glat_data.shape}''')
        logging.info(f''' Tile{itp}, Max= {np.max(glat_data)}''')
        logging.info(f''' Tile{itp}, Min= {np.min(glat_data)}''')

        glon_all.append(glon_data[None,:])
        glat_all.append(glat_data[None,:])

    glon = np.vstack(glon_all)
    glat = np.vstack(glat_all)

    logging.info(f''' Dimension of glon = {glon.shape}''')
    logging.info(f''' Dimension of glon = {glat.shape}''')


# Get data from files and plot ====================================== CHJ =====
def plot_data(path_data,fn_data_base,var_nm,ifhr,zlvlm1,out_title_base,
              out_fn_base,work_dir,plot_each_tile):

    # center of map
    c_lon = -77.0369

    zlvl = zlvlm1+1

    logging.info(f''' ===== data file: '{var_nm}' ========================''')
    # open the data file
    for it in range(num_tiles):
        itp = it+1
        fn_data = f'''{fn_data_base}{itp}.nc'''
        fp_data = os.path.join(path_data,fn_data)
        try: data_raw = nc.Dataset(fp_data)
        except: raise Exception('Could NOT find the file',fp_data)
        if itp == 1:
            logging.info(f''' Variables: {list(data_raw.variables)}''')

        # Extract valid variable
        var_data = np.ma.masked_invalid(data_raw.variables[var_nm])
        ndim_var = var_data.ndim
        logging.info(f''' {var_nm}: number of dimensions = {ndim_var}''')
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

    cs_max = np.nanmax(plt_var)
    cs_min = np.nanmin(plt_var)
    logging.info(f''' cs_max = {cs_max}''')
    logging.info(f''' cs_min = {cs_min}''')

    cs_cmap = 'gist_ncar_r'
    cbar_extend = 'neither'

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
                out_title = f'''{out_title_base}{var_nm}::L{zlvl}::Tile{itp}::F{ifhr} '''
                out_fn = f'''{out_fn_base}{var_nm}_z{zlvl}_tile{itp}_f{ifhr}'''
            else:
                out_title = f'''{out_title_base}{var_nm}::Tile{itp}::F{ifhr}'''
                out_fn = f'''{out_fn_base}{var_nm}_tile{itp}_f{ifhr}'''
    
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
        out_title = f'''{out_title_base}{var_nm}::L{zlvl}::F{ifhr}::All tiles'''
        out_fn = f'''{out_fn_base}{var_nm}_z{zlvl}_alltiles_f{ifhr}'''
    else:
        out_title = f'''{out_title_base}{var_nm}::F{ifhr}::All tiles'''
        out_fn = f'''{out_fn_base}{var_nm}_alltiles_f{ifhr}'''

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
    cbar.set_label(var_nm,fontsize=6)
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

