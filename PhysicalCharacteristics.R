
################### Expanded Regression Discontinuity ##########################

# Clear console.
cat("\014")

# Remove Plots
#dev.off(dev.list()["RStudioGD"]) # Apply dev.off() & dev.list()

# Remove all files from workspace - do this every time so we don't use a file archived to the workspace.
rm(list = ls())

# Change Directory
setwd("/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/")

################################## Import the packages #########################
library('ggplot2')
library('tibble')
library('tidyr')
library('dplyr')

library('collapse')

library('mgcv')
#install.packages('gratia')
library('gratia')

library('rdrobust')
library('haven')


full_data <- read_dta("input_data/StormData.dta")

ggplot(full_data %>% filter(property_damage_percap > 1, event_type == "Thunderstorm Wind") %>% mutate(property_damage_percap = ifelse((property_damage_percap > 10000), 10000, property_damage_percap)) %>% mutate(log_percap = log10(property_damage_percap)), 
       aes(x = log_percap, y = magnitude))  + geom_smooth() + theme_bw() + labs(x="Log Per Capita Property Damage", y = "Reported Wind Speed")

combined_data <- read_dta("cleaned_data/CombinedData.dta")

ggplot(combined_data %>% mutate(property_damage_percap = ifelse((property_damage_percap > 10000), 10000, property_damage_percap)) %>% mutate(log_percap = log10(property_damage_percap)) %>% filter(log_percap > 0), 
       aes(x = log_percap, y = vmax_gust_mph))  + geom_smooth() + theme_bw() +  labs(x="Log Per Capita Property Damage", y = "HURDAT Maximum Wind Speed")

