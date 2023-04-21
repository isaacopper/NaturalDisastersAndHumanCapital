clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"

********************************************************************************
* EdFacts Graduation Data
********************************************************************************
* Loop Over Data
forvalues yr = 2010/2017 {
	import delimited $input_data/schools_edfacts_grad_rates_`yr'.csv, clear
	
	* Missing
	foreach var of varlist grad_rate_low grad_rate_high grad_rate_midpt {
		replace `var' = . if `var' < 0
	}
	
	* They were measuring the year in the fall of the year, rather than the spring
	replace year = year + 1
	
	* Tempsave
	tempfile data`yr'
	save `data`yr''
}

* Append them all together
use `data2010', clear
forvalues yr = 2011/2017 {
	append using `data`yr''
}

* Save
tempfile grad_data
save `grad_data', replace

* Bring in Fips
import delimited $input_data/schools_ccd_directory.csv, clear
keep year ncessch ncessch_num enrollment county_code
keep if year > 2010
merge 1:m ncessch year using `grad_data', update
drop _m
rename fips st_fips
bys ncessch: egen fips = mode(county_code)

* Save
save $cleaned_data/graduation/EdFactsGraduation, replace


********************************************************************************/
* Creating treatment dummies from storm data in final_data
********************************************************************************
* Import Quarter-Level Data
import delimited using "input_data/AllPDDs.csv", clear case(preserve)
rename Year year
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace

* Move 2-4 quarters to next school year
replace year = year + 1 if Quarter > 1

* Ignore disasters that occur outside of school year
drop if Quarter == 2

* Collapse to year level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year)

* Rename treatment variable (here you can change what the treatment variable is, the rest should remain unchanged)
rename PropertyDmgPerCapitaADJ2018 treatment_p0 

* Winzorize 
	*--> Only matters for log-regression, since others are indicators
replace treatment_p0 = 10000 if treatment_p0 > 10000 & treatment_p0 != .

* Focus only on relatively recent disasters
	*--> Just makes reshaping later easier
keep if year > 2000

* Save File
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
* Bringing in EdFacts
********************************************************************************
use "$cleaned_data/graduation/EdFactsGraduation.dta", clear

* State
g st = floor(fips/1000)

* For now, keep only measures with everyone 
keep if race == 99 & lep == 99 & homeless == 99 & disability == 99 & econ_disadvantaged == 99 & foster_care == 99
isid ncessch year

* Weights
replace enrollment = . if enrollment < 0
bys ncessch: egen ave_enroll = mean(enrollment)
replace ave_enroll = ln(ave_enroll)
replace ave_enroll = 0 if ave_enroll < 0
*sum ave_enroll, d
*replace ave_enroll = `r(p99)' if ave_enroll > `r(p99)' & ave_enroll != .

* Id
xtset ncessch year

*g d_grad_rate = ln(grad_rate_midpt) - ln(l.grad_rate_midpt)
*g l_d_grad_rate = ln(l.grad_rate_midpt) - ln(l2.grad_rate_midpt)
g d_grad_rate = grad_rate_midpt - l.grad_rate_midpt
g l_d_grad_rate = l.grad_rate_midpt - l2.grad_rate_midpt

* Future
forvalues i = 1/3 {
	g f`i' = f`i'.grad_rate_midpt
}
egen ave_g_rate = rowmean(grad_rate_midpt f1)
g d_ave = ln(ave_g_rate) - ln(l.grad_rate_midpt)
*g f_d_grad_rate = ln(f.grad_rate_midpt) - ln(l.grad_rate_midpt)
g f_d_grad_rate = f.grad_rate_midpt - l.grad_rate_midpt


* Windsorize
foreach var of varlist d_grad_rate l_d_grad_rate f_d_grad_rate {
	replace `var' = 50 if `var' > 50 & `var' != .
	replace `var' = -50 if `var' < -50 & `var' != .
}

tempfile main_data
save `main_data', replace

********************************************************************************
* Merge to Treatment Data
********************************************************************************
* Keep list of IDs
use `main_data', clear
bys fips ncessch_num: keep if _n == 1
keep fips ncessch_num

* Merge IDs to Treatment Data
joinby fips using `treatment', unmatched(master)
drop _m fips

* Replace year if never hit by a disaster to balance
replace year = 2018 if year == .
isid ncessch_num year

* Balance panel to account for no-disaster periods
xtset ncessch_num year
tsfill, full
sort ncessch_num year

* Replace Treatment with Zero if not in `treatment' data, since that implies no disasters
replace treatment_p0 = 0 if treatment_p0 == .

* Log Damages
*g log_percap_damages = log10(treatment_p0) - log_index
g log_percap_damages = log10(treatment_p0)

* Merge back SEDA data
merge 1:1 ncessch_num year using `main_data', update replace
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
label variable d_grad_rate "HS Graduation Rate"
label variable l_d_grad_rate "\begin{tabular}{@{}c@{}} HS Graduation Rate \\ (Lagged)\end{tabular}"
label variable log_percap_damages "Log Property Damage Per Capita"

label variable f_d_grad_rate "\begin{tabular}{@{}c@{}} HS Graduation Rate \\ (Lead)\end{tabular}"

* Save
save "$cleaned_data/graduation/main_data.dta", replace


********************************************************************************
* Graphs
********************************************************************************
use "$cleaned_data/graduation/main_data.dta", clear

* Histogram
preserve
g ave_int = round(exp(ave_enroll))
drop if abs(d_grad_rate) > 25
*twoway (histogram d_grad_rate, lcolor(white) color(navy)) (kdensity d_grad_rate, bw(1)), xtitle("Change in Counties' HS Graduation Rates") graphregion(color(white)) ytitle(" ") legend(off)
twoway (histogram d_grad_rate [fw = ave_int], lcolor(white) color(navy) disc w(1)) , xtitle("Change in HS Graduation Rates") graphregion(color(white)) ytitle(" ") legend(off)
graph export "$output/graduation/histogram.pdf", as(pdf) replace
restore

use "$cleaned_data/graduation/main_data.dta", clear
keep d_grad_rate l_d_grad_rate f_d_grad_rate log_percap_damages year ave_enroll
rename d_grad_rate d_grad_rate_c
rename l_d_grad_rate d_grad_rate_l
rename f_d_grad_rate d_grad_rate_f
g i = _n
reshape long d_grad_rate, i(i) j(lagged) string
tempfile data
encode lagged, g(lag)
binsreg d_grad_rate log_percap_damages i.year  if log_percap_damages > 0 [aw = ave_enroll], polyreg(1)  by(lag) nbins(10) binspos(es) savedata(`data') 

use `data', clear
forvalues lag = 1/3 {
	sum dots_fit if dots_binid < 3 & lag == `lag'
	replace dots_fit = dots_fit - `r(mean)' if lag == `lag'
	replace poly_fit = poly_fit - `r(mean)' if lag == `lag'
}
twoway (scatter dots_fit dots_x if lag == 1) (line poly_fit poly_x if lag == 1, lcolor(navy)) (scatter dots_fit dots_x if lag == 3, m(T) mcolor(maroon)) (line poly_fit poly_x if lag == 3, lcolor(maroon) lpattern(dash)) (scatter dots_fit dots_x if lag == 2, m(D) mcolor(forest_green)) (line poly_fit poly_x if lag == 2, lcolor(forest_green) lpattern(longdash)), graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Log-Enrollment at School") legend(lab(1 "Post-Disaster") lab(3 "Pre-Disaster") lab(5 "Two Years Post-Disaster") order(1 3 5))
graph export "$output/graduation/impacts.pdf", as(pdf) replace


*use "$cleaned_data/graduation/main_data.dta", clear
*binsreg f_d_grad_rate log_percap_damages i.year if log_percap_damages > 0 [aw = ave_enroll], polyreg(3) nbins(10) binspos(es) savedata($cleaned_data/graduation/binsreg) 

********************************************************************************
* Regressions
********************************************************************************
use "$cleaned_data/graduation/main_data.dta", clear

* Full Time Enrollment Regressions
reg d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips)
reghdfe d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a( i.year)
estimates store col1
quietly estadd local county_fe "", replace 
reghdfe d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.ncessch)
reghdfe d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.ncessch i.year)
estimates store col2
quietly estadd local county_fe "X", replace 

* Percent Change Full Time Enrollment
reg l_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips)
reghdfe l_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a( i.year)
estimates store col3
quietly estadd local county_fe "", replace 
reghdfe l_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.ncessch)
reghdfe l_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.ncessch i.year)
estimates store col4
quietly estadd local county_fe "X", replace 

* Percent Change Full Time Enrollment
reg f_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips)
reghdfe f_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a( i.year)
estimates store col5
quietly estadd local county_fe "", replace 
reghdfe f_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.ncessch)
reghdfe f_d_grad_rate i.disaster_category [w = ave_enroll], vce(cluster fips) a(i.ncessch i.year)
estimates store col6
quietly estadd local county_fe "X", replace 


*esttab col* using "$output/graduation/coef_estimates", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe N N_clust,	label("County FE" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
esttab col* using "$output/graduation/coef_estimates", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************/
* Dynamic Effects
********************************************************************************

reghdfe d_grad_rate  i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category [w = ave_enroll], vce(cluster fips)  a(i.ncessch i.year)

preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4)
g category = substr(parm, 1, 1)
destring category, replace


* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5) legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5)legend(off) xlabel(0(1)3) yline(0, lcolor(black) )  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5) legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5) legend(off) xlabel(0(1)3) yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/graduation/effect_over_time.pdf", as(pdf) replace

restore


********************************************************************************/
* Event Study
********************************************************************************

reghdfe d_grad_rate i.f3.disaster_category i.f2.disaster_category i.f.disaster_category i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category [w = ave_enroll], vce(cluster fips)  a(i.ncessch i.year)

preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4) - 3
g category = substr(parm, 1, 1)
destring category, replace


* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5) legend(off) xlabel(-3(1)3) yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5)legend(off) xlabel(-3(1)3) yline(0, lcolor(black) )  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5) legend(off) xlabel(-3(1)3) yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Graduation Rates") ylabel(-1.5(.5)1.5) legend(off) xlabel(-3(1)3) yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/graduation/event_study.pdf", as(pdf) replace

restore
