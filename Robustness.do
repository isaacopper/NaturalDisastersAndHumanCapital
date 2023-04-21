
clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"


********************************************************************************
* Control for Lagged Values
********************************************************************************
* Add Covariates to SEDA
use "$input_data/covariate_data.dta", clear
destring fips, replace
drop index median_home_price_2021
tempfile covariate_data
save `covariate_data', replace
use "$cleaned_data/seda/main_data.dta", clear
merge m:1 fips year using `covariate_data', update
keep if _m == 3
drop _m
xtset id year

* Regressions
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "None", replace 
estimates store col1

* Control for Pre-Trends
reghdfe d_all i.disaster_category l.d_all [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Baseline Trends", replace 
estimates store col2

* Control for Lagged Unemployment
reghdfe d_all i.disaster_category l.unemprate [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Unemployment Rate", replace 
estimates store col3

* Control for Lagged Construction 
reghdfe d_all i.disaster_category l.construction_pct [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Construction Workforce", replace 
estimates store col4

esttab col* using "$output/Responses/BaselineControlsSEDA", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe controls N N_clust, label("County FE" "Additional Controls" "Observations" "Number of Clusters")) drop(L.d_all L.unemprate L.construction_pct) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
*estimates clear

* Add Covariates to IPEDS
use "$input_data/covariate_data.dta", clear
destring fips, replace
drop index median_home_price_2021
tempfile covariate_data
save `covariate_data', replace
use "$cleaned_data/college_enrollment/main_data.dta", clear
merge m:1 fips year using `covariate_data', update
keep if _m == 3
drop _m


* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Label Variables & Values
lab define disaster_category 0 "No Disaster" 1 "No Disaster" 2 "Small Disaster" 3 "Medium Disaster" 4 "Large Disaster" 5 "Very Large Disaster"
lab val disaster_category disaster_category
label variable d_enrollment_ft "College Enrollment"

xtset id year


* Full Time Enrollment Regressions
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "None", replace 
estimates store col5

* Control for Pre-Trends
reghdfe d_enrollment_ft i.disaster_category l.d_enrollment_ft if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Baseline Trends", replace 
estimates store col6

* Control for Lagged Unemployment
reghdfe d_enrollment_ft i.disaster_category l.unemprate if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Unemployment Rate", replace 
estimates store col7

* Control for Lagged Construction 
reghdfe d_enrollment_ft i.disaster_category l.construction_pct if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Construction Workforce", replace 
estimates store col8

esttab col5 col6 col7 col8 using "$output/Responses/BaselineControlsIPEDS", replace nostar s(county_fe controls N N_clust, label("County FE" "Additional Controls" "Observations" "Number of Clusters")) drop(L.d_enrollment_ft L.unemprate L.construction_pct) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
*estimates clear
esttab col* using "$output/Responses/BaselineControls", replace nostar s(county_fe controls N N_clust, fmt(0 0 0) label("County FE" "Additional Controls" "Observations" "Number of Clusters")) drop(L.d_all L.unemprate L.construction_pct L.d_enrollment_ft) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************
* College 
********************************************************************************

use "$cleaned_data/college_enrollment/main_data.dta", clear

* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Label Variables & Values
lab define disaster_category 0 "No Disaster" 1 "No Disaster" 2 "Small Disaster" 3 "Medium Disaster" 4 "Large Disaster" 5 "Very Large Disaster"
lab val disaster_category disaster_category
label variable d_enrollment_ft "College Enrollment"
label variable l_d_enrollment_ft "\begin{tabular}{@{}c@{}} College Enrollment \\ (Lagged)\end{tabular}"

* Public vs Private
bys unitid (year): egen inst_aff = mean(inst_affiliation)
bys unitid (year): egen inst_level = mean(institution_level)

* Main Effects
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "All Schools"
estimates store col1

* Public 2 years
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & (inst_aff == 1 & inst_level == 2) `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "Public Two-Year"
estimates store col2

* Community Colleges
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & community_college == 1 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "Community Colleges"
estimates store col3

esttab col* using "$output/Responses/CollegeTypes", replace nostar s(county_fe sample N N_clust, fmt(0 0 0) label("County FE" "Institution Type" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear


/*
* Full Time Enrollment Regressions
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
estimates store col1

* Full Time Enrollment Regressions
reghdfe d_enrollment_ft i.disaster_category l.d_enrollment_ft if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
estimates store col2


********************************************************************************
* Community Colleges vs. Non-Community College 
********************************************************************************
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & community_college == 1 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
estimates store col1

reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & community_college == 0 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
estimates store col2

* Public vs Private
bys unitid (year): egen inst_aff = mean(inst_affiliation)
bys unitid (year): egen inst_level = mean(institution_level)
* Public 2 years
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & (inst_aff == 1 & inst_level == 2) `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
* Public 4 years
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & (inst_aff == 1 & inst_level == 4) `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & (inst_aff != 1 & inst_level == 4) `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)

quietly estadd local county_fe "X", replace 
estimates store col3

* Public Two years
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & (inst_aff == 1 & inst_type == 2) `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)

* Private 4 year
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9  & (inst_aff == 3 | inst_aff == 4) & inst_type == 1 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
*/



********************************************************************************
* Spillovers
********************************************************************************

use "$cleaned_data/college_enrollment/main_data.dta", clear

* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Label Variables & Values
lab define disaster_category 0 "No Disaster" 1 "No Disaster" 2 "Small Disaster" 3 "Medium Disaster" 4 "Large Disaster" 5 "Very Large Disaster"
lab val disaster_category disaster_category
label variable d_enrollment_ft "College Enrollment"
label variable l_d_enrollment_ft "\begin{tabular}{@{}c@{}} College Enrollment \\ (Lagged)\end{tabular}"

* State Measures
g small = (disaster_category == 2) if disaster_category != .
g medium = (disaster_category == 3) if disaster_category != .
g large = (disaster_category == 4) if disaster_category != .
g very_large = (disaster_category == 5) if disaster_category != .
g large_disasters = (disaster_category == 4 | disaster_category == 5)
foreach var of varlist small medium large very_large large_disasters {
	bys st_fips year: egen st_`var' = mean(`var')	
}

* Labels
label variable st_large_disasters "Fraction with Significant Disaster"
label variable st_small "Fraction with Small Disaster"
label variable st_medium "Fraction with Medium Disaster"
label variable st_large "Fraction with Large Disaster"
label variable st_very_large "Fraction with Very Large Disaster"

*bys st_fips year: egen mean_prop_damage = mean(treatment_p0)
*g ln_mean_prop_damage = log10(mean_prop_damage)
*replace ln_mean_prop_damage = 0 if ln_mean_prop_damage < 0 | mean_prop_damage == 0

reghdfe d_enrollment_ft i.disaster_category st_large_disasters if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "All Institutions", replace 
estimates store col1

reghdfe d_enrollment_ft i.disaster_category st_small st_medium st_large st_very_large if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "All Institutions", replace 
estimates store col2

reghdfe d_enrollment_ft st_large_disasters if in_state_fraction > .9 & disaster_category < 4`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "Unaffected Institutions", replace 
estimates store col3

reghdfe d_enrollment_ft st_small st_medium st_large st_very_large if in_state_fraction > .9 & disaster_category < 4 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local sample "Unaffected Institutions", replace 
estimates store col4


esttab col* using "$output/Responses/Spillovers", replace nostar s(county_fe sample N N_clust, fmt(0 0 0) label("County FE" "Institutions Included" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear


********************************************************************************
* Autocorrelation 
********************************************************************************

use "$cleaned_data/college_enrollment/main_data.dta", clear

* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

xtset id year

* Define large/very large disaster
g large_disaster = (log_percap_damages > 2 & log_percap_damages != .)

* Check that definition is right
tab disaster_category large_disaster, m

* Autocorrelation
g l_large = l.large_disaster
g l_disaster_cat = l.disaster_category

tab large_disaster l_large
tab l_disaster_cat disaster_category

* Regressions
use "$cleaned_data/seda/main_data.dta", clear


* Baseline
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "None", replace 
estimates store col1

* Control for last years disaster
reghdfe d_all i.disaster_category l.i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Lagged Disasters", replace 
estimates store col2

use "$cleaned_data/college_enrollment/main_data.dta", clear

* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Label Variables & Values
lab define disaster_category 0 "No Disaster" 1 "No Disaster" 2 "Small Disaster" 3 "Medium Disaster" 4 "Large Disaster" 5 "Very Large Disaster"
lab val disaster_category disaster_category
label variable d_enrollment_ft "College Enrollment"

xtset id year


* Full Time Enrollment Regressions
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "None", replace 
estimates store col3

* Control for Earlier Disasters
reghdfe d_enrollment_ft i.disaster_category l.i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local controls "Lagged Disasters", replace 
estimates store col4

esttab col* using "$output/Responses/LaggedDisasters", replace nostar s(county_fe controls N N_clust, fmt(0 0 0) label("County FE" "Additional Controls" "Observations" "Number of Clusters")) drop(2L.disaster_category 3L.disaster_category 4L.disaster_category 5L.disaster_category) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear


********************************************************************************
* Lagged Controls 
********************************************************************************


* Regressions
use "$cleaned_data/seda/main_data.dta", clear

g mn_all2 = mn_all^2
g mn_all3 = mn_all^3


* Baseline
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local outcome_measure "Year-to-Year Change", replace 
estimates store col1

* Control for last years disaster
reghdfe d_all i.disaster_category l.mn_all [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local outcome_measure "Linear Growth Model", replace 
*estimates store col2

* Control for last years disaster
reghdfe d_all i.disaster_category l.mn_all l.mn_all2 l.mn_all3 [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local outcome_measure "Cubic Growth Model", replace 
estimates store col3


use "$cleaned_data/college_enrollment/main_data.dta", clear

* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Label Variables & Values
lab define disaster_category 0 "No Disaster" 1 "No Disaster" 2 "Small Disaster" 3 "Medium Disaster" 4 "Large Disaster" 5 "Very Large Disaster"
lab val disaster_category disaster_category
label variable d_enrollment_ft "College Enrollment"

* Lagged enrollment
g ln_enrollment = ln(enrollment_ft)
g ln_enrollment2 = ln_enrollment^2
g ln_enrollment3 = ln_enrollment^3

xtset id year

* Main Regression
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local outcome_measure "Year-to-Year Change", replace 
estimates store col4

* Control flexibly for lagged enrollment
reghdfe d_enrollment_ft i.disaster_category l.ln_enrollment if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local outcome_measure "Linear Growth Model", replace 
*estimates store col5

* Control flexibly for lagged enrollment
reghdfe d_enrollment_ft i.disaster_category l.ln_enrollment l.ln_enrollment2 l.ln_enrollment3 if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local outcome_measure "Cubic Growth Model", replace 
estimates store col6

esttab col* using "$output/Responses/GrowthModels", replace nostar s(county_fe outcome_measure N N_clust, fmt(0 0 0) label("County FE" "Outcome" "Observations" "Number of Clusters")) drop(L.mn_all L.mn_all2 L.mn_all3 L.ln_enrollment L.ln_enrollment2 L.ln_enrollment3) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************
* Aggregate
********************************************************************************
* Regressions
use "$cleaned_data/seda/main_data.dta", clear

* Baseline
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local unit "School Grade", replace 
estimates store col1

* Collapse
collapse (mean) d_all disaster_category (rawsum) ave_weight [w = ave_weight], by(fips year)
lab val disaster_category disaster_category
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local unit "County", replace 
estimates store col2


use "$cleaned_data/college_enrollment/main_data.dta", clear

* Disaster Category
*g disaster_category = 0 if treatment_p0 == 0
g disaster_category = 1 if log_percap_damages < 0 | treatment_p0 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Label Variables & Values
lab define disaster_category 0 "No Disaster" 1 "No Disaster" 2 "Small Disaster" 3 "Medium Disaster" 4 "Large Disaster" 5 "Very Large Disaster"
lab val disaster_category disaster_category
label variable d_enrollment_ft "College Enrollment"

reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local unit "School Grade", replace 
estimates store col3

* Collapse
keep if in_state_fraction > .9
collapse (mean) d_enrollment_ft disaster_category (rawsum) ave_enroll [w = ave_enroll], by(fips year)
lab val disaster_category disaster_category
reghdfe d_enrollment_ft i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local unit "County", replace 
estimates store col4

esttab col* using "$output/Responses/CountyAggregates", replace nostart s(county_fe unit N N_clust, fmt(0 0 0) label("County FE" "Unit of Observation" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear
