
clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"


********************************************************************************
* Urban vs Rural
********************************************************************************
* Clean County Data
use fips metro HPSA_PC using "$input_data/county_data", clear
merge 1:m fips using "$cleaned_data/seda/main_data.dta", update

* Metro
reghdfe d_all i.disaster_category [w = ave_weight] if metro == 1, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Metro Area", replace 
estimates store col1

* Non-Metro
reghdfe d_all i.disaster_category [w = ave_weight] if metro == 0, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Non-Metro Area", replace 
estimates store col2

* Clean County Data
use fips metro HPSA_PC using "$input_data/county_data", clear
merge 1:m fips using "$cleaned_data/college_enrollment/main_data.dta", update

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


* Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & metro == 1`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Metro Area", replace 
estimates store col3

* Non-Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & metro != 1`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Non-Metro Area", replace 
estimates store col4

esttab col* using "$output/Responses/MetroVsNonmetro", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe area N N_clust, label("County FE" "County Included" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************
* HPSA Primary Care
********************************************************************************
* Clean County Data
use fips metro HPSA_PC using "$input_data/county_data", clear
merge 1:m fips using "$cleaned_data/seda/main_data.dta", update

* Full HSPC
reghdfe d_all i.disaster_category [w = ave_weight] if HPSA_PC == 1, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Full HPSA County", replace 
estimates store col1

* Non-Metro
reghdfe d_all i.disaster_category [w = ave_weight] if HPSA_PC == 0, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Not Full HPSA County", replace 
estimates store col2

* Clean County Data
use fips metro HPSA_PC using "$input_data/county_data", clear
merge 1:m fips using "$cleaned_data/college_enrollment/main_data.dta", update

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


* Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & HPSA_PC == 1`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Full HPSA County", replace 
estimates store col3

* Non-Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & HPSA_PC != 1`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Not Full HPSA County", replace 
estimates store col4

esttab col* using "$output/Responses/HPSA", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe area N N_clust, label("County FE" "County Included" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
estimates clear


********************************************************************************
* Pct Uninsrued
********************************************************************************
* Clean County Data
use "$input_data/commute_uninsured", clear
collapse (mean) uninsured_pct, by(fips)
destring fips, replace
sum uninsured_pct, d
g above_median = (uninsured_pct > `r(p50)') if uninsured_pct != .
merge 1:m fips using "$cleaned_data/seda/main_data.dta", update

* Metro
reghdfe d_all i.disaster_category [w = ave_weight] if above_median == 1, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "High Uninsurance Rate", replace 
estimates store col1

* Non-Metro
reghdfe d_all i.disaster_category [w = ave_weight] if above_median == 0, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Low Uninsurance Rate", replace 
estimates store col2

* Clean County Data
use "$input_data/commute_uninsured", clear
collapse (mean) uninsured_pct, by(fips)
destring fips, replace
sum uninsured_pct, d
g above_median = (uninsured_pct > `r(p50)') if uninsured_pct != .
merge 1:m fips using "$cleaned_data/college_enrollment/main_data.dta", update

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


* Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & above_median == 1`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "High Uninsurance Rate", replace 
estimates store col3

* Non-Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & above_median == 0`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Low Uninsurance Rate", replace 
estimates store col4

esttab col* using "$output/Responses/UninsuranceRate", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe area N N_clust, label("County FE" "County Included" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************
* Commute Time
********************************************************************************
* Clean County Data
use "$input_data/commute_uninsured", clear
collapse (mean) avg_commute_time, by(fips)
destring fips, replace
sum avg_commute_time, d
g above_median = (avg_commute_time > `r(p50)') if avg_commute_time != .
merge 1:m fips using "$cleaned_data/seda/main_data.dta", update

* Metro
reghdfe d_all i.disaster_category [w = ave_weight] if above_median == 1, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "High Commute Time", replace 
estimates store col1

* Non-Metro
reghdfe d_all i.disaster_category [w = ave_weight] if above_median == 0, vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Low Commute Time", replace 
estimates store col2

* Clean County Data
use "$input_data/commute_uninsured", clear
collapse (mean) avg_commute_time, by(fips)
destring fips, replace
sum avg_commute_time, d
g above_median = (avg_commute_time > `r(p50)') if avg_commute_time != .
merge 1:m fips using "$cleaned_data/college_enrollment/main_data.dta", update

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


* Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & above_median == 1`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "High Commute Time", replace 
estimates store col3

* Non-Metro Areas
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 & above_median == 0`year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.fips i.year)
quietly estadd local county_fe "X", replace 
quietly estadd local area "Low Commute Time", replace 
estimates store col4

esttab col* using "$output/Responses/CommuteTime", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe area N N_clust, label("County FE" "County Included" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
estimates clear
