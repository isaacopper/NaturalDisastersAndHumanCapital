clear all
set more off

cd "/Users/iopper/Documents/ResearchProjects/NaturalDisastersAndHumanCapital/"

global input_data "input_data"
global cleaned_data "cleaned_data"
global output "output"


set scheme s2color 
********************************************************************************
* Creating treatment dummies from storm data in final_data
********************************************************************************
* Import Quarter-Level Disaster Data
import delimited using "$input_data/AllPDDs.csv", clear case(preserve)
rename Year year
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace

* Move 2-4 quarters to next school year since SY2007 runs from Fall 2006 to Spring 2007
replace year = year + 1 if Quarter > 1

* Ignore disasters that occur outside of school year
keep if Quarter == 1 | Quarter == 4 

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
use fips median_home_price_2021 labor_force using "$input_data/covariate_data.dta", clear
destring fips, replace

* One obs per county
bys fips (year): keep if _n == 1

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
* Clean SEDA data
********************************************************************************
* Import SEDA Outcome Data
use "$input_data/seda_county_long_cs_v30.dta", clear
drop fips
destring countyid, gen(fips)
order grade subject fips year, first
drop countyid countyname stateabb

* Create State
g st = floor(fips/1000)

* Save as main data
tempfile main_data
save `main_data', replace

* Bring in covariates
use "$input_data/seda_cov_county_long_v30.dta", clear
drop fips
rename countyid fips

* Merge & keep if have both
merge 1:m fips year grade using `main_data', update
keep if _m == 3
drop _m
sort grade subject fips year

* Create Average Weights of Racial Groups
sort fips 
foreach racial_group in "wht" "hsp" "blk" "asn" "ind" {
	by fips: egen ave_per`racial_group' = mean(per`racial_group')
}

* Id
egen id = group(fips grade subject)
xtset id year

* Log Test Takers
g log_totgyb_all = log(totgyb_all)

* Calculate Differences
foreach group in "all" "wht" "hsp" "asn" "blk" "ecd" {
	g d_`group' = mn_`group' - l.mn_`group'
	g l_d_`group' = l.mn_`group' - l2.mn_`group'
}
foreach group in "totenrl" "perblk" "perhsp" "perwht" "perasn" "perecd" "unempall" {
	g d_`group' = `group' - l.`group'
}
foreach group in "totgyb_ecd" "totgyb_all" "log_totgyb_all" {
	g d_`group' = `group' - l.`group'
}


* Calculate differences using fixed weights
	*--> If group is missing d_`racial_group', give them a weight of zero and upweight other groups
g d_all_fixedweights = 0
g sum_d_weights = 0
foreach racial_group in "wht" "hsp" "blk" "asn" {
	replace d_all_fixedweights = d_all_fixedweights + d_`racial_group'*ave_per`racial_group' if d_`racial_group' != .
	replace sum_d_weights = sum_d_weights + ave_per`racial_group' if d_`racial_group' != .
}
replace d_all_fixedweights = d_all_fixedweights/sum_d_weights
replace d_all_fixedweights = . if sum_d_weights < .75


* Calculate Difference in Demographics


* Weights as inverse of the standard error, averaged over the whole sample
g inv_sd = 1/mn_all_se
bys fips: egen ave_weight = mean(inv_sd)

* Resave as main data
save `main_data', replace


********************************************************************************
* Merge to Treatment Data
********************************************************************************
* Keep list of IDs
use `main_data', clear
bys id: keep if _n == 1
keep id fips

* Merge IDs to Treatment Data
joinby fips using `treatment', unmatched(master)
drop _m fips

* Replace year if never hit by a disaster to balance
replace year = 2018 if year == .
isid id year

* Balance panel to account for no-disaster periods
xtset id year
tsfill, full
sort id year

* Replace Treatment with Zero if not in `treatment' data, since that implies no disasters
replace treatment_p0 = 0 if treatment_p0 == .

* Log Damages
*g log_percap_damages = log10(treatment_p0) - log_index
g log_percap_damages = log10(treatment_p0)

* Merge back SEDA data
merge 1:1 id year using `main_data', update replace
drop _m

* Keep (relatively) recent years
keep if year > 2000

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
label variable d_all "Avg. Test Scores"
label variable l_d_all "\begin{tabular}{@{}c@{}} Avg. Test Scores \\ (Lagged)\end{tabular}"
label variable log_percap_damages "Log Property Damage Per Capita"



* Save
save "$cleaned_data/seda/main_data.dta", replace


********************************************************************************/
* Graphs
********************************************************************************

* Histogram
use "$cleaned_data/seda/main_data.dta", clear
preserve
keep if abs(d_all) < 0.75
g ave_int = round(ave_weight)
twoway (histogram d_all [fw = ave_int], lcolor(white) color(navy)), xtitle("Change in Counties' Average Test Scores") graphregion(color(white)) ytitle(" ") legend(off)
graph export "$output/seda/histogram.pdf", as(pdf) replace
restore

* Log Per Cap
use "$cleaned_data/seda/main_data.dta", clear
keep d_all log_percap_damages ave_weight l_d_all year
rename d_all d_all_f
rename l_d_all d_all_l
g i = _n
reshape long d_all, i(i) j(lagged) string
g lag = (lagged == "_l")
label define lag 0 "Post-Disaster" 1 "Pre-Disaster"
label values lag lag
tempfile data
binsreg d_all log_percap_damages  if log_percap_damages > 0 [aw = ave_weight], polyreg(1) graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Percentage Change in Enrollment at School") by(lag) nbins(10) binspos(es) savedata(`data')

use `data', clear
forvalues lag = 0/1 {
	sum dots_fit if dots_binid < 3 & lag == `lag'
	replace dots_fit = dots_fit - `r(mean)' if lag == `lag'
	replace poly_fit = poly_fit - `r(mean)' if lag == `lag'
}
twoway (scatter dots_fit dots_x if lag == 0) (line poly_fit poly_x if lag == 0, lcolor(navy)) (scatter dots_fit dots_x if lag == 1, m(T) mcolor(maroon)) (line poly_fit poly_x if lag == 1, lcolor(maroon) lpattern(dash)), graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Average Test Scores") legend(lab(1 "Post-Disaster") lab(3 "Pre-Disaster") order(1 3))
graph export "$output/seda/impacts.pdf", as(pdf) replace

* Cubic 
use "$cleaned_data/seda/main_data.dta", clear
binsreg d_all log_percap_damages  if log_percap_damages > 0 [aw = ave_weight], polyreg(3) graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Average Test Scores") nbins(10) binspos(es) savedata($cleaned_data/seda/binsreg) replace
use "$cleaned_data/seda/binsreg", clear
sum dots_fit if dots_binid < 3 
replace dots_fit = dots_fit - `r(mean)'
replace poly_fit = poly_fit - `r(mean)'
twoway (scatter dots_fit dots_x) (line poly_fit poly_x, lcolor(navy)), graphregion(color(white)) xtitle("Log Per Capita Property Damage") ytitle("Change in Average Test Scores") legend(off)
graph export "$output/seda/impacts_cubic.pdf", as(pdf) replace


* Spline
use  if log_percap_damages > 0 & log_percap_damages != . using "$cleaned_data/seda/main_data.dta", clear
mkspline  log0 1 log1 2 log2 3 log3  = log_percap_damages
reghdfe d_all log0-log3 if log_percap_damages > 0 [w = ave_weight], vce(cluster fips) a( i.year)
predict predictions
keep predictions log_percap_damages
save $cleaned_data/seda/spline, replace

********************************************************************************
* Regressions 
********************************************************************************
use "$cleaned_data/seda/main_data.dta", clear

* Regressions
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
estimates store col1
quietly estadd local county_fe "", replace 
parmest, saving("$output/seda/coef_estimates", replace)
reghdfe l_d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
quietly estadd local county_fe "", replace  
estimates store col2
tempfile parmest
parmest, saving(`parmest')
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
estimates store col3
reghdfe l_d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
estimates store col4

*esttab col1 col3 col2 col4 using "$output/seda/coef_estimates", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe N N_clust,	label("County FE" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
esttab col1 col3 col2 col4 using "$output/seda/coef_estimates", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************
* Regressions (Counts)
********************************************************************************
use "$cleaned_data/seda/main_data.dta", clear

* Regressions
reghdfe d_log_totgyb_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
estimates store col1
quietly estadd local county_fe "", replace 
reghdfe l.d_log_totgyb_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
quietly estadd local county_fe "", replace  
estimates store col2
tempfile parmest
parmest, saving(`parmest')
reghdfe d_log_totgyb_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
estimates store col3
reghdfe l.d_log_totgyb_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
quietly estadd local county_fe "X", replace 
estimates store col4

*esttab col1 col3 col2 col4 using "$output/seda/coef_estimates_counts", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe N N_clust,	label("County FE" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes
esttab col1 col3 col2 col4 using "$output/seda/coef_estimates_counts", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes

estimates clear

********************************************************************************
* Regressions 
********************************************************************************
use "$cleaned_data/seda/main_data.dta", clear

* Regressions
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
estimates store col0
quietly estadd local county_fe "", replace 
reghdfe d_all i.disaster_category [w = ave_weight] if abs(d_log_totgyb_all) < .25, vce(cluster fips) a(year)
estimates store col1
quietly estadd local county_fe "", replace 
reghdfe d_all i.disaster_category [w = ave_weight] if abs(d_log_totgyb_all) < .1, vce(cluster fips) a(year)
estimates store col2
quietly estadd local county_fe "", replace 
reghdfe d_all i.disaster_category [w = ave_weight] if abs(d_log_totgyb_all) < .05, vce(cluster fips) a(year)
estimates store col3
quietly estadd local county_fe "", replace 
reghdfe d_all i.disaster_category [w = ave_weight] if abs(d_log_totgyb_all) < .01, vce(cluster fips) a(year)
estimates store col4
quietly estadd local county_fe "", replace 
reghdfe d_all i.disaster_category [w = ave_weight] if abs(d_log_totgyb_all) < .005, vce(cluster fips) a(year)
estimates store col5
quietly estadd local county_fe "", replace 

*esttab col0 col1 col3 col2 col4 col5 using "$output/seda/coef_estimates_small_N_change", replace star(* 0.10 ** 0.05 *** 0.01) s(county_fe N N_clust,	label("County FE" "Observations" "Number of Clusters")) se obslast label nobaselevels noconstant tex nonotes

esttab col0 col1 col3 col2 col4 col5 using "$output/seda/coef_estimates_small_N_change", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes
estimates clear

********************************************************************************
* Regressions to Check for Compositional Changes
********************************************************************************
label variable d_all_fixedweights "Change in Avg. Test Scores"
label variable d_ecd "Change in Avg. Test Scores"

* Baseline
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
estimates store col1
quietly estadd local county_fe "", replace 
quietly estadd local spec "Baseline", replace 
reghdfe d_all i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
estimates store col2
quietly estadd local county_fe "X", replace 
quietly estadd local spec "Baseline", replace 

* Idea: Fix the weight on the different racial groups; 
* Compositional changes could still occur within groups, 
* but seems unlikely to find compositional changes within groups and not across groups
reghdfe d_all_fixedweights i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
estimates store col3
quietly estadd local county_fe "", replace 
quietly estadd local spec "Fixed Race/Ethnicity Weights", replace 
reghdfe d_all_fixedweights i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
estimates store col4
quietly estadd local county_fe "X", replace 
quietly estadd local spec "Fixed Race/Ethnicity Weights", replace 


* Idea: Same as above, but there is also potentially selection of people who don't move becoming 
* classified as ECD. However, that would likely bias the effects up and so this could be a conservative estimate of the
* individual effects.
reghdfe d_ecd i.disaster_category [w = ave_weight], vce(cluster fips) a(year)
estimates store col5 
quietly estadd local county_fe "", replace 
quietly estadd local spec "Economically Disadvantaged", replace 
reghdfe d_ecd i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
estimates store col6
quietly estadd local county_fe "X", replace 
quietly estadd local spec "Economically Disadvantaged", replace 

esttab col3 col4 col5 col6 using "$output/seda/composition_changes", replace nostar s(county_fe N N_clust, fmt(0 0 0) label("County FE" "Observations" "Number of Clusters")) cells(b(fmt(3)) se(fmt(3) par) p(fmt(3) par([ ])) .) obslast label nobaselevels noconstant tex nonotes

*esttab col* using "$output/seda/composition_changes", replace star(* 0.10 ** 0.05 *** 0.01) scalars(N_clust) se obslast label csv
estimates clear

* Demographics
reghdfe d_perwht i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
reghdfe d_perblk i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
reghdfe d_perhsp i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
reghdfe d_perasn i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)
reghdfe d_totenrl i.disaster_category [w = ave_weight], vce(cluster fips) a(year fips)

********************************************************************************/
* Traditional Event Study
********************************************************************************
xtset id year

reghdfe d_all i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category [w = ave_weight], vce(cluster fips) a(year)

preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4)
g category = substr(parm, 1, 1)
destring category, replace

local yscale = "yscale(range(-.0375 .025))"
local ylabel = "ylabel(-.025(.025).025)"

* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Test Standard Deviations") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Test Standard Deviations") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Test Standard Deviations") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years After Disaster") ytitle("Change in Test Standard Deviations") `yscale' `ylabel' legend(off) xlabel(0(1)3) yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/seda/effect_over_time.pdf", replace

restore


********************************************************************************/
* Traditional Event Study
********************************************************************************
xtset id year

reghdfe d_all i.f3.disaster_category i.f2.disaster_category i.f.disaster_category i.disaster_category i.l.disaster_category i.l2.disaster_category i.l3.disaster_category [w = ave_weight], vce(cluster fips) a(year)

preserve
parmest, norestore

* Set up Data
g lead_lag = floor((_n - 1)/4) - 3
g category = substr(parm, 1, 1)
destring category, replace

local yscale = "yscale(range(-.0375 .025))"
local ylabel = "ylabel(-.025(.025).025)"
local xlabel = "xlabel(-3(1)3)"

* Graphs
twoway (scatter estimate lead_lag if category == 2) (rcap max95 min95 lead_lag if category == 2, lcolor(navy) lpattern(dash)) ///
, title("Small Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Test Standard Deviations") `ylabel' `yscale' `xlabel' legend(off) yline(0, lcolor(black))  name(cat2, replace)

twoway (scatter estimate lead_lag if category == 3) (rcap max95 min95 lead_lag if category == 3, lcolor(navy) lpattern(dash)) ///
, title("Medium Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Test Standard Deviations") `ylabel' `yscale' `xlabel' legend(off) yline(0, lcolor(black))  name(cat3, replace)

twoway (scatter estimate lead_lag if category == 4) (rcap max95 min95 lead_lag if category == 4, lcolor(navy) lpattern(dash)) ///
, title("Large Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Test Standard Deviations") `ylabel' `yscale' `xlabel' legend(off) yline(0, lcolor(black))  name(cat4, replace)

twoway (scatter estimate lead_lag if category == 5) (rcap max95 min95 lead_lag if category == 5, lcolor(navy) lpattern(dash)) ///
, title("Very Large Disasters") graphregion(color(white)) xtitle("Years Before/After Disaster") ytitle("Change in Test Standard Deviations") `ylabel' `yscale' `xlabel' legend(off) yline(0, lcolor(black)) name(cat5, replace)
graph combine cat2 cat3 cat4 cat5, graphregion(color(white))
graph export "$output/seda/event_study.pdf", replace

restore

