clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"

local year_restriction ""

********************************************************************************
* Creating treatment dummies from storm data in final_data
********************************************************************************
* Import Quarter-Level Disaster Data
import delimited using "$input_data/AllPDDs.csv", clear case(preserve)
rename Year year
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace

* Move 2-4 quarters to next school year
replace year = year + 1 if Quarter == 4
*drop if Quarter == 3

* Collapse to year level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year)

* Keeping necessary variables and filling out the panel
xtset fips year, yearly
tsfill, full
sort fips year

* Replace missing PropertyDmgPerCapitaADJ2018 with Zero, since not being in PDD means no disasters
replace PropertyDmgPerCapitaADJ2018 = 0 if PropertyDmgPerCapitaADJ2018 == .

* treatment variable (here you can change what the treatment variable is, the rest should remain unchanged)
rename PropertyDmgPerCapitaADJ2018 treatment_p0 

* Winzorize and/or create a treatment dummy (currently commented out) 
sum treatment_p0, d
replace treatment_p0 = 10000 if treatment_p0 > 10000 & treatment_p0 != .
*replace treatment_p0 = (treatment_p0 > 1000) & treatment_p0 != .

* Keep Relevant Time & Save File
*keep if year > 2008 & year < 2017
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
* Bringing in specific data you want to use
********************************************************************************
* Use Data with FIPS
use "$input_data/IPEDS", clear
bys unitid (institution_level): keep if _n == 1
keep unitid fips institution_level community_college
rename institution_level inst_type
tempfile fips
save `fips', replace

* Use Main Data
use "$input_data/ipeds_panel.dta", clear 

* Balance panel
xtset unitid year, yearly
tsfill, full
g ended = (total_fall_enrollment == . & l.total_fall_enrollment != .)

* Fill in FIPS
rename fips st_fips
merge m:1 unitid using `fips', update
keep if _m == 3
drop _m

* Check consistency
replace fips = county_fips if fips == .
count if fips != county_fips & !missing(fips, county_fips)
count if fips == county_fips & !missing(fips, county_fips)

drop if fips == .
*keep if fips>=1001 & inst_type!=3 // Drop < 2 Year

* Keep semi-large institutions
bys unitid: egen ave_enroll = mean(total_fall_enrollment)
*keep if ave_enroll > 100
*replace ave_enroll = ln(ave_enroll)
replace ave_enroll= 25000 if ave_enroll > 25000 & ave_enroll != .

* In State
g in_state_frac = instate_fresh_enrollment/total_fresh_enrollment
bys unitid: egen in_state_fraction = mean(in_state_frac)
drop in_state_frac

* Even Year Data
g have_data_year = (year == 2008 | year == 2010 | year == 2012 | year == 2014 | year == 2016)
order unitid fips year

* Merge Treatment Info
merge m:1 fips year using `treatment', update
drop  if _m == 2
drop _m
sort unitid year fips

* Replace Treatment with Zero if not in `treatment' data, since that implies no disasters
replace treatment_p0 = 0 if treatment_p0 == .


********************************************************************************
* Xtset
********************************************************************************
* Id
egen id = group(unitid)
xtset id year

* Difference
foreach var in "enrollment_ft" "enrollment_pt" "enrollment_undergrad" "total_fall_enrollment" "enrollment_black" "enrollment_hispanic" "enrollment_white" "enrollment_asian" "enrollment_grad" "enrollment_firstprof" {
	g d_`var' = ln(`var') - ln(l.`var')
	g l_d_`var' = ln(l.`var') - ln(l2.`var')
}

* Winsorize
foreach var in "enrollment_ft" "enrollment_pt" "enrollment_undergrad" "total_fall_enrollment" "enrollment_black" "enrollment_hispanic" "enrollment_white"  "enrollment_asian" "enrollment_grad" "enrollment_firstprof"  {
	replace d_`var' = 2 if d_`var' > 2 & d_`var' != .
	replace d_`var' = -2 if d_`var' < -2 & d_`var' != .
	replace d_`var' = -2 if ended == 1
	replace l_d_`var' = 2 if l_d_`var' > 2 & l_d_`var' != .
	replace l_d_`var' = -2 if l_d_`var' < -2 & l_d_`var' != .
	replace l_d_`var' = -2 if l.ended == 1
}

* Log Damages
*g log_percap_damages = log10(treatment_p0) - log_index
g log_percap_damages = log10(treatment_p0)

* Weights
g ave_weight = ave_enroll

preserve
drop if abs(d_enrollment_ft) > 1
*sum d_enrollment_ft
*g n_sim = rnormal(`r(mean)', `r(sd)')
*twoway (histogram d_enrollment_ft, lcolor(white) color(navy)) (kdensity n_sim), xtitle("% Change Post-Secondary Enrollment") graphregion(color(white)) ytitle(" ") legend(off)
g ave_int = round(ave_enroll)
twoway (histogram d_enrollment_ft  [fw = ave_int], lcolor(white) color(navy)), xtitle("Change Log Post-Secondary Enrollment") graphregion(color(white)) ytitle(" ") legend(off)

graph export "$output/college_enrollment/histogram.pdf", as(pdf) replace
restore

* save
save "$cleaned_data/college_enrollment/main_data.dta", replace


********************************************************************************/
* Graphs
********************************************************************************
use "$cleaned_data/college_enrollment/main_data.dta", clear

label variable log_percap_damages "Log Property Damage Per Capita"
label variable d_enrollment_ft "College Enrollment"
label variable l_d_enrollment_ft "College Enrollment (Lagged)"

* Reshape Long
use "$cleaned_data/college_enrollment/main_data.dta", clear
keep d_enrollment_ft l_d_enrollment_ft log_percap_damages treatment_p0 year ave_weight in_state_fraction
rename d_enrollment_ft d_enrollment_ft_f
rename l_d_enrollment_ft d_enrollment_ft_l
g i = _n
reshape long d_enrollment_ft, i(i) j(lagged) string
g lag = (lagged == "_l")
tempfile data
binsreg d_enrollment_ft log_percap_damages i.year  if log_percap_damages > 0 & in_state_fraction > .9 `year_restriction' [aw = ave_weight], polyreg(3) graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Log-Enrollment at School") by(lag) nbins(10) binspos(es) savedata(`data') 

use `data', clear
forvalues lag = 0/1 {
	sum dots_fit if dots_binid < 3 & lag == `lag'
	replace dots_fit = dots_fit - `r(mean)' if lag == `lag'
	replace poly_fit = poly_fit - `r(mean)' if lag == `lag'
}
twoway (scatter dots_fit dots_x if lag == 0) (line poly_fit poly_x if lag == 0, lcolor(navy)) (scatter dots_fit dots_x if lag == 1, m(T) mcolor(maroon)) (line poly_fit poly_x if lag == 1, lcolor(maroon) lpattern(dash)), graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Log-Enrollment at School") legend(lab(1 "Post-Disaster") lab(3 "Pre-Disaster") order(1 3))
graph export "$output/college_enrollment/impacts.pdf", as(pdf) replace


* Save Data
use "$cleaned_data/college_enrollment/main_data.dta", clear
binsreg d_enrollment_ft log_percap_damages i.year  if log_percap_damages > 0 & in_state_fraction > .9 `year_restriction' [aw = ave_enroll], polyreg(3) graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Log-Enrollment at School") nbins(10) binspos(es) savedata($cleaned_data/college_enrollment/binsreg) replace

* Spline
use  if log_percap_damages > 0  using "$cleaned_data/college_enrollment/main_data.dta", clear
mkspline  log0 1 log1 2 log2 3 log3  = log_percap_damages
reghdfe d_enrollment_ft log0-log3 if log_percap_damages > 0 [w = ave_enroll], vce(cluster fips) a( i.year)
predict predictions
keep predictions log_percap_damages
save $cleaned_data/college_enrollment/spline, replace


********************************************************************************
* Regressions
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

* Full Time Enrollment Regressions
reg d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction' [w = ave_enroll], vce(cluster fips )
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a( i.year)
estimates store col1
quietly estadd local county_fe "", replace 
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid)
reghdfe d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid i.year)
estimates store col2
quietly estadd local county_fe "X", replace 

* Percent Change Full Time Enrollment
reg l_d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips )
reghdfe l_d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a( i.year)
estimates store col3
quietly estadd local county_fe "", replace 
reghdfe l_d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid)
reghdfe l_d_enrollment_ft i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid i.year)
estimates store col4
quietly estadd local county_fe "X", replace 


*esttab col* using "$output/college_enrollment/coef_estimates", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe N N_clust,	label("County FE" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
esttab col* using "$output/college_enrollment/coef_estimates", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes

*esttab col* using "$output/college_enrollment/iped_estimates", replace star(* 0.10 ** 0.05 *** 0.01) scalars(N_clust) se obslast label csv
estimates clear


********************************************************************************
* Subgroups
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
label variable d_enrollment_white "College Enrollment"
label variable d_enrollment_black "College Enrollment"
label variable d_enrollment_hispanic "College Enrollment"
label variable d_enrollment_asian "College Enrollment"

label variable d_enrollment_undergrad "Undergraduate Enrollment"
label variable d_enrollment_grad "Black Graduate Enrollment"


* Full Time Enrollment Regressions
reghdfe d_enrollment_white i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid i.year)
estimates store col1
quietly estadd local race "White", replace 
quietly estadd local county_fe "X", replace 
reghdfe d_enrollment_black i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid i.year)
estimates store col2
quietly estadd local race "Black", replace 
quietly estadd local county_fe "X", replace 
reghdfe d_enrollment_hispanic i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid i.year)
estimates store col3
quietly estadd local race "Hispanic", replace 
quietly estadd local county_fe "X", replace 
reghdfe d_enrollment_asian i.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips ) a(i.unitid i.year)
estimates store col4
quietly estadd local race "Asian", replace 
quietly estadd local county_fe "X", replace 
esttab col* using "$output/college_enrollment/coef_estimates_byrace", replace nostar s(county_fe race N N_clust, fmt(0 0 0) label("Race/Ethnicity" "County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes


********************************************************************************/
* More Traditional Event Study
********************************************************************************

reghdfe d_enrollment_ft i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips)  a(i.unitid i.year)


preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4)
g category = substr(parm, 1, 1)
destring category, replace

local yscale = "yscale(range(-.06 .025))"
local ylabel = "ylabel(-.05(.025).025)"

* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment")  `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment")  `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/college_enrollment/effect_over_time.pdf", as(pdf) replace

restore


********************************************************************************/
* More Traditional Event Study
********************************************************************************

reghdfe d_enrollment_ft i.f3.disaster_category i.f2.disaster_category i.f.disaster_category i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category if in_state_fraction > .9 `year_restriction'  [w = ave_enroll], vce(cluster fips)  a(i.unitid i.year)


preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4) - 3
g category = substr(parm, 1, 1)
destring category, replace

local yscale = "yscale(range(-.06 .025))"
local ylabel = "ylabel(-.05(.025).025)"
local xlabel = "xlabel(-3(1)3)"

* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment") `ylabel' `yscale' legend(off) `xlabel' yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment") `ylabel' `yscale' legend(off) `xlabel' yline(0, lcolor(black))  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment") `ylabel' `yscale'  legend(off) `xlabel' yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years Before/After") ytitle("% Change in Enrollment") `ylabel' `yscale' legend(off) `xlabel' yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/college_enrollment/event_study.pdf", as(pdf) replace

restore


/********************************************************************************
* Summary of Enrollment
********************************************************************************
* Overall
use "$cleaned_data/college_enrollment/main_data.dta", clear
collapse (mean) d_enrollment_ft d_total_fall_enrollment (sum) log_percap_damages [w = ave_enroll], by(year)
twoway (scatter d_enrollment_ft year, c(l)) , graphregion(color(white)) xtitle("Year") ytitle("Average % Change in Fulltime Enrollment")
twoway (scatter d_total_fall_enrollment year, c(l)), graphregion(color(white)) xtitle("Year") ytitle("Average % Change in  Enrollment")
twoway (scatter log_percap_damages year, c(l)), graphregion(color(white)) xtitle("Year") ytitle("Log Per Cap Damages")

* By Institution Type
use "$cleaned_data/college_enrollment/main_data.dta", clear
collapse (mean) d_enrollment_ft [w = ave_enroll], by(year inst_type)
twoway (scatter d_enrollment_ft year if inst_type == 1, c(l)) (scatter d_enrollment_ft year if inst_type == 2, c(l)) (scatter d_enrollment_ft year if inst_type == 3, c(l)), legend(lab(1 "4-Year") lab(2 "3-Year") lab(3 "2-Year")) graphregion(color(white)) xtitle("Year") ytitle("Average % Change in Fulltime Enrollment")

********************************************************************************/


