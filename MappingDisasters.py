#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Sep 21 10:11:06 2021

@author: iopper
"""

# Import Geopandas
import geopandas as geo
import pandas as pd
import matplotlib.pyplot as plt

# Set Path
path = '/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/'

###############################################################################
# Legend Labels
###############################################################################
# Function to Replace Legend
def replace_legend_items(legend, mapping):
    for txt in legend.texts:
        for k,v in mapping.items():
            if txt.get_text() == str(k):
                txt.set_text(v)

# Dictionary Mapping Default Labels to Preferred Labels
legend_dict = {'0.0':'0', '1.0':'1', '2.0':'2', '3.0':'3', '4.0':'4+'}

###############################################################################
# Import Data
###############################################################################
# Import Shape File
all_counties = geo.read_file('/'.join([path,'input_data', 'cb_2018_us_county_20m','cb_2018_us_county_20m.shp']))
all_counties = all_counties.astype({'STATEFP':'int32', 'GEOID':'int64'})

# Keep CONUS Only for mapping
not_conus_fips = [2, 60, 66, 72, 15 ]
all_conus_counties = all_counties.loc[~all_counties['STATEFP'].isin(not_conus_fips)]

# Import Disasters
all_disasters = pd.read_csv('/'.join([path,'cleaned_data', 'DisasterCounts.csv']))
#all_disasters['GEOID'] = pd.to_numeric(all_disasters['County FIPS'].str.slice(start = 1, stop = 6), errors='coerce')

###############################################################################
# Restrict to disaster size category, merge, and plot
###############################################################################
for cat in [2, 3, 4, 5]:
    # Combine the Two Data Sets
    combined = all_conus_counties.merge(all_disasters.loc[all_disasters['disaster_category'] == cat], left_on='GEOID', right_on='fips', how = 'outer')
    
    # Replace Zeros with Missings
    combined['number_of_disasters'] = combined['number_of_disasters'].fillna(0)
    
    # Plot
    f, ax = plt.subplots(1, figsize=(16, 9))
    combined.plot(column='number_of_disasters', categorical=True, cmap='OrRd', linewidth=0.2, ax=ax, edgecolor='black', legend=True, legend_kwds={'title': 'Number of Disasters in County from 1990-2018:', 'loc': 'lower left', 'ncol':5})
    ax.set_axis_off()
    replace_legend_items(ax.get_legend(), legend_dict)
    plt.savefig('/'.join([path,'output', 'DisasterFigs', 'DisaterMap' + str(cat) + '.pdf']), format='pdf')
