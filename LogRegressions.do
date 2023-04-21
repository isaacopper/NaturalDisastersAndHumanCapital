clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"

set scheme s2color 



********************************************************************************
* Log Regressions, in order
********************************************************************************
* Net Migration
use  "$cleaned_data/migration/main_data.dta", clear
label variable netmig_rate "Net Migration Rate"
label variable l_netmig_rate "Net Migration Rate (Lagged)"
label variable log_percap_damages "Log Property Damage Per Capita"

areg netmig_rate log_percap_damages if log_percap_damages > 0 [w = ave_weight], a(year) vce(cluster fips)
estimates store col1

areg l_netmig_rate log_percap_damages if log_percap_damages > 0 [w = ave_weight], a(year) vce(cluster fips)
estimates store l_col1


* Test Scores
use "$cleaned_data/seda/main_data.dta", clear
label variable d_all "Change in Ave. Test Scores"
label variable l_d_all "Change in Ave. Test Scores (Lagged)"

areg d_all log_percap_damages if log_percap_damages > 0 [w = ave_weight], a(year) vce(cluster fips)
estimates store col2

areg l_d_all log_percap_damages if log_percap_damages > 0 [w = ave_weight], a(year) vce(cluster fips)
estimates store l_col2

* HS Graduation
use "$cleaned_data/graduation/main_data.dta", clear
label variable d_grad_rate "Change in HS Graduation Rates"
label variable l_d_grad_rate "Change in HS Graduation Rates (Lagged)"
label variable log_percap_damages "Log Property Damage Per Capita"
label variable f_d_grad_rate "Change in Graduation Rates (Lead)"

areg d_grad_rate log_percap_damages if log_percap_damages > 0 [w = ave_enroll], a(year) vce(cluster fips)
estimates store col3

areg f_d_grad_rate log_percap_damages if log_percap_damages > 0 [w = ave_enroll], a(year) vce(cluster fips)
estimates store col4

areg l_d_grad_rate log_percap_damages if log_percap_damages > 0 [w = ave_enroll], a(year) vce(cluster fips)
estimates store l_col3

* Post-Secondary Enrollment
use "$cleaned_data/college_enrollment/main_data.dta", clear

label variable log_percap_damages "Log Property Damage Per Capita"
label variable d_enrollment_ft "Change in College Enrollment"
label variable l_d_enrollment_ft "Change in College Enrollment (Lagged)"

areg d_enrollment_ft log_percap_damages if log_percap_damages > 0 & in_state_fraction > .9 [w = ave_weight], a(year) vce(cluster fips)
estimates store col5

areg l_d_enrollment_ft log_percap_damages if log_percap_damages > 0 & in_state_fraction > .9 [w = ave_weight], a(year) vce(cluster fips)
estimates store l_col5


********************************************************************************
* Output
********************************************************************************

esttab col* using "$output/log_regression", replace nostar s(N N_clust, fmt(0 0 0) label("Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes

esttab l_col* using "$output/log_regression_lagged", replace nostar s(N N_clust, fmt(0 0 0) label("Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear
