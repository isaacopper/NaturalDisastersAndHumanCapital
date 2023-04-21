clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"


********************************************************************************/
* Creating treatment dummies from storm data in final_data
********************************************************************************
* Import Quarter-Level Data
import delimited using "input_data/AllPDDs.csv", clear case(preserve)
rename Year year
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace

* Collapse to year level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year)

* Rename treatment variable (here you can change what the treatment variable is, the rest should remain unchanged)
rename PropertyDmgPerCapitaADJ2018 treatment_p0 

* Winzorize 
	*--> Only matters for log-regression, since others are indicators
replace treatment_p0 = 10000 if treatment_p0 > 10000 & treatment_p0 != .

* Focus only on relatively recent disasters
	*--> Just makes reshaping later easier
keep if year > 1985

* Save
tempfile treatment
save `treatment'


********************************************************************************
* Add capital cost
********************************************************************************
* Use median home prices
use fips median_home_price_2021 using "$input_data/covariate_data.dta", clear
destring fips, replace

* One obs per county
bys fips: keep if _n == 1

* Normalization 
sum median_home_price_2021
g index = median_home_price_2021/`r(mean)'
g log_index = log10(index)
tempfile capital_cost
save `capital_cost'

use if fips != . using `treatment', clear
merge m:1 fips using `capital_cost',
keep if _m == 1 | _m == 3
drop _m

* Save File
tempfile treatment
save `treatment'

********************************************************************************
* Clean Migration Data
********************************************************************************
use "$input_data/county_panel.dta", clear


* Per 100,000
replace outmig_total_n1 = 100000*outmig_total_n1/acs_pop_total
replace outmig_total_n2 = 100000*outmig_total_n2/acs_pop_total
replace outmig_total_agi = 100000000*outmig_total_agi/acs_pop_total
replace inmig_total_n1 = 100000*inmig_total_n1/acs_pop_total
replace inmig_total_n2 = 100000*inmig_total_n2/acs_pop_total
replace inmig_total_agi = 100000000*inmig_total_agi/acs_pop_total

foreach v of varlist school_en* {
	replace `v' = 100000*`v'/acs_pop_total
}

* AGI per outmig
g agi_per_outmig = outmig_total_agi/outmig_total_n1
g agi_per_inmig = inmig_total_agi/inmig_total_n1

* Id
xtset fips year

* Migration Rates
	* --> In levels not changes since "migration" is itself a change in population
g inmig_rate = f.inmig_total_n1
g outmig_rate = f.outmig_total_n1
g netmig_rate = f.inmig_total_n1 - f.outmig_total_n1
g l_outmig_rate = l.outmig_total_n1
g l_netmig_rate = l.inmig_total_n1 - l.outmig_total_n1
g l_inmig_rate = l.inmig_total_n1
g d_agi_per_outmig = f.agi_per_outmig - l.agi_per_outmig
g d_agi_per_inmig = f.agi_per_inmig - l.agi_per_inmig

* Winsorize
foreach var of varlist netmig_rate l_netmig_rate {
	replace `var' = 10000 if `var' > 10000 & `var' != .
	replace `var' = -10000 if `var' < -10000 & `var' != .
}

* Weights
bys fips: egen ave_weight = mean(acs_pop_total)
replace ave_weight = ln(ave_weight)
*replace ave_weight = 5000 if ave_weight > 5000 & ave_enroll != .

* Resave as main data
tempfile main_data
save `main_data', replace

********************************************************************************
* Merge to Treatment Data
********************************************************************************
* Keep list of IDs
use `main_data', clear
bys fips: keep if _n == 1
keep fips

* Merge IDs to Treatment Data
joinby fips using `treatment', unmatched(master)
drop _m

* Replace year if never hit by a disaster to balance
replace year = 2018 if year == .
isid fips year

* Balance panel to account for no-disaster periods
xtset fips year
tsfill, full
sort fips year

* Replace Treatment with Zero if not in `treatment' data, since that implies no disasters
replace treatment_p0 = 0 if treatment_p0 == .

* Log Damages
*g log_percap_damages = log10(treatment_p0) - log_index
g log_percap_damages = log10(treatment_p0)


* Merge back migration data
merge 1:1 fips year using `main_data', update replace
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
label variable netmig_rate "Net Migration Rate"
label variable l_netmig_rate "\begin{tabular}{@{}c@{}} Net Migration Rate \\ (Lagged)\end{tabular}"
label variable log_percap_damages "Log Property Damage Per Capita"
label variable outmig_rate "Out Migration Rate"
label variable inmig_rate "In Migration Rate"
label variable l_outmig_rate "\begin{tabular}{@{}c@{}} Out Migration Rate \\ (Lagged)\end{tabular}"
label variable l_inmig_rate "\begin{tabular}{@{}c@{}} In Migration Rate \\ (Lagged)\end{tabular}"
label variable d_agi_per_outmig "AGI per Out-Migration Household"
label variable d_agi_per_inmig "AGI per In-Migration Household"



* Save
save "$cleaned_data/migration/main_data.dta", replace


********************************************************************************
* Graphs
********************************************************************************
use  "$cleaned_data/migration/main_data.dta", clear

* Histogram
preserve
drop if abs(netmig_rate) > 2500
g ave_int = round(ave_weight)
twoway (histogram netmig_rate [fw = ave_int], lcolor(white) color(navy)), xtitle("Counties' Net Migration Rates") graphregion(color(white)) ytitle(" ") legend(off)
graph export "$output/migration/histogram.pdf", as(pdf) replace
restore

* Reshape Long
use  "$cleaned_data/migration/main_data.dta", clear
keep netmig_rate l_netmig_rate log_percap_damages year ave_weight
rename netmig_rate netmig_rate_f
rename l_netmig_rate netmig_rate_l
g i = _n
reshape long netmig_rate, i(i) j(lagged) string
g lag = (lagged == "_l")
label define lag 0 "Post-Disaster" 1 "Pre-Disaster"
label values lag lag
tempfile data
binsreg netmig_rate log_percap_damages i.year  if log_percap_damages > 0 [aw = ave_weight], polyreg(3) graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Net Migration Rate Per 100,000 People") by(lag) legend(lab(1 "Post-Disater") lab(2 "Pre-Disaster Change")) nbins(10)  binspos(es) savedata(`data')

use `data', clear
forvalues lag = 0/1 {
	sum dots_fit if dots_binid < 3 & lag == `lag'
	replace dots_fit = dots_fit - `r(mean)' if lag == `lag'
	replace poly_fit = poly_fit - `r(mean)' if lag == `lag'
}
twoway (scatter dots_fit dots_x if lag == 0) (line poly_fit poly_x if lag == 0, lcolor(navy)) (scatter dots_fit dots_x if lag == 1, m(T) mcolor(maroon)) (line poly_fit poly_x if lag == 1, lcolor(maroon) lpattern(dash)), graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Net Migration Rate Per 100,000 Peopl") legend(lab(1 "Post-Disaster") lab(3 "Pre-Disaster") order(1 3))
graph export "$output/migration/impacts.pdf", as(pdf) replace

* Re-Do to Save Results
use  "$cleaned_data/migration/main_data.dta", clear
binsreg netmig_rate log_percap_damages i.year  if log_percap_damages > 0 [aw = ave_weight], polyreg(3) graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Net Migration Rate Per 100,000 People") nbins(10)  binspos(es) savedata($cleaned_data/migration/binsreg) replace


* Spline
use  if log_percap_damages > 0  using "$cleaned_data/migration/main_data.dta", clear
mkspline  log0 1 log1 2 log2 3 log3  = log_percap_damages
reghdfe netmig_rate log0-log3 if log_percap_damages > 0 [w = ave_weight], vce(cluster fips) a( i.year)
predict predictions
keep predictions log_percap_damages
save $cleaned_data/migration/spline, replace

********************************************************************************
* Regressions
********************************************************************************
use "$cleaned_data/migration/main_data.dta", clear

* Netmig Regressions 
reg netmig_rate i.disaster_category  [w = ave_weight], vce(cluster fips)
reghdfe netmig_rate i.disaster_category  [w = ave_weight], vce(cluster fips) a( i.year)
estimates store col1
quietly estadd local county_fe "", replace 
reghdfe netmig_rate i.disaster_category  [w = ave_weight], vce(cluster fips) a(i.fips)
reghdfe netmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col2
quietly estadd local county_fe "X", replace 

* Netmig Regressions
reg l_netmig_rate i.disaster_category [w = ave_weight], vce(cluster fips)
reghdfe l_netmig_rate i.disaster_category  [w = ave_weight], vce(cluster fips) a( i.year)
estimates store col3
quietly estadd local county_fe "", replace 
reghdfe l_netmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips)
reghdfe l_netmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col4
quietly estadd local county_fe "X", replace 

esttab col* using "$output/migration/coef_estimates", replace nostar s(county_fe N N_clust, fmt(0 0 0)	label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
*esttab col* using "$output/migration/coef_estimates", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe N N_clust,	label("County FE" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
estimates clear

* In vs Out-Mig
reghdfe outmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col1
quietly estadd local county_fe "X", replace 
reghdfe inmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col2
quietly estadd local county_fe "X", replace 
reghdfe l_outmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col3
quietly estadd local county_fe "X", replace 
reghdfe l_inmig_rate i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col4
quietly estadd local county_fe "X", replace 
esttab col* using "$output/migration/in_vs_outmig", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear

* Any Changes in AGI
reghdfe d_agi_per_outmig i.disaster_category [w = ave_weight], vce(cluster fips) a(i.year)
estimates store col1
quietly estadd local county_fe "", replace 
reghdfe d_agi_per_outmig i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col2
quietly estadd local county_fe "X", replace 
reghdfe d_agi_per_inmig i.disaster_category [w = ave_weight], vce(cluster fips) a(i.year)
estimates store col3
quietly estadd local county_fe "", replace 
reghdfe d_agi_per_inmig i.disaster_category [w = ave_weight], vce(cluster fips) a(i.fips i.year)
estimates store col4
quietly estadd local county_fe "X", replace 
esttab col* using "$output/migration/agi_per_mover", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear




********************************************************************************/
* More Traditional Event Study
********************************************************************************

reghdfe netmig_rate i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category [w = ave_weight], vce(cluster fips)  a(i.fips i.year)


preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4)
g category = substr(parm, 1, 1)
destring category, replace

local yscale = "yscale(range(-75 50))"
local ylabel = "ylabel(-50(50)50)"

* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/migration/effect_over_time.pdf", as(pdf) replace

restore


********************************************************************************/
* Traditional Event Study
********************************************************************************

reghdfe netmig_rate i.f3.disaster_category i.f2.disaster_category i.f.disaster_category i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category [w = ave_weight], vce(cluster fips)  a(i.fips i.year)


preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4) - 3
g category = substr(parm, 1, 1)
destring category, replace

local xscale = "xlabel(-3(1)3)"
local yscale = "yscale(range(-75 50))"
local ylabel = "ylabel(-50(50)50)"


* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) `xscale' yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years Before/AfterNet-Migration") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) `xscale' yline(0, lcolor(black))  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years Before/AfterNet-Migration") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) `xscale' yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years Before/AfterNet-Migration") ytitle("Net-Migration Rate") `yscale' `ylabel' legend(off) `xscale' yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/migration/event_study.pdf", as(pdf) replace

restore
