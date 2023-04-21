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
keep if year >= 1990
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace

* Replace 
replace PropertyDmgPerCapitaADJ2018 = 5000 if PropertyDmgPerCapitaADJ2018 > 5000 & PropertyDmgPerCapitaADJ2018 != .

* Collapse to year level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year)
g log_percap_damages = log10(PropertyDmgPerCapitaADJ2018)

* Categories
g disaster_category = 1 if log_percap_damages < 0 | PropertyDmgPerCapitaADJ2018 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Drop no disaster category
drop if disaster_category == 1

* Collapse 
collapse (mean) PropertyDmgPerCapitaADJ2018 (median) median_loss = PropertyDmgPerCapitaADJ2018, by(disaster_category)

* Per Student Human Capital
g postsec_loss = -166 if disaster_category == 2
replace postsec_loss = 110 if disaster_category == 3
replace postsec_loss = 1400 if disaster_category == 4
replace postsec_loss = 1950 if disaster_category == 5
g test_loss = 43 if disaster_category == 2
replace test_loss = 319 if disaster_category == 3
replace test_loss = 865 if disaster_category == 4
replace test_loss = 1288 if disaster_category == 5

g human_capital_loss = (postsec_loss*.06 + test_loss*.11)/(.06 + .11)
replace human_capital_loss = 1 if human_capital_loss < 1

* Label
label define dis_size 2 "Small Disasters" 3 "Medium Disasters"4  "Large Disasters" 5 "Very Large Disasters"
label values disaster_category dis_size 

graph bar PropertyDmgPerCapitaADJ2018 human_capital_loss, over(disaster_category) graphregion(color(white)) legend(lab(1 "Physical Capital") lab(2 "Human Capital")) ytitle("Capital Loss Per Affected Individual") 
graph export "$output/HumanVsPhysicalCapital.pdf", as(pdf) replace
