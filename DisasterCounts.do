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

* Collapse to year level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year)
g log_percap_damages = log10(PropertyDmgPerCapitaADJ2018)

* Categories
g disaster_category = 1 if log_percap_damages < 0 | PropertyDmgPerCapitaADJ2018 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Counts
collapse (count) number_of_disasters = log_percap, by(fips disaster_category)
replace number_of_disasters = 4 if number_of_disasters > 4 & number_of_disasters < .

* Export
export delimited using "$cleaned_data/DisasterCounts.csv", replace

* Count
g st_fips = floor(fips/1000)
drop if st_fips == 2 | st_fips == 60 | st_fips == 72 | st_fips == 15
keep if disaster_category == 4 | disaster_category == 5
egen tag = tag(fips)
tab tag


********************************************************************************
* Disasters by Size over Year
********************************************************************************
* Import Quarter-Level Disaster Data
import delimited using "$input_data/AllPDDs.csv", clear case(preserve)
rename Year year
keep if year >= 1990
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace


* Collapse to year level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year)
g log_percap_damages = log10(PropertyDmgPerCapitaADJ2018)

* Categories
g disaster_category = 1 if log_percap_damages < 0 | PropertyDmgPerCapitaADJ2018 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Collapse
collapse (count) number_per_year = log_percap_damages, by(year disaster_category)

* Reshape
reshape wide number_per_year, i(year) j(disaster_category)
g n2 = number_per_year2
g n3 = n2 + number_per_year3
g n4 = n3 + number_per_year4
g n5 = n4 + number_per_year5

* Graph
twoway (bar number_per_year2 year, color("0 63 92")) (rbar number_per_year2 n3 year, color("122 81 149")) (rbar n3 n4 year, color("239 86 117")) (rbar n4 n5 year, color("255 166 0")), legend(lab(1 "Small Disasters") lab(2 "Medium Disasters") lab(3 "Large Disasters") lab(4 "Very Large Disasters")) graphregion(color(white)) ytitle("Number of County-Disasters in Year") xtitle("Year")
graph export "$output/DisasterFigs/DisastersByYear.pdf", as(pdf) replace


********************************************************************************
* Disasters by Size over Category
********************************************************************************
import delimited using "$input_data/AllPDDs.csv", clear case(preserve)
rename Year year
keep if year >= 1990
g fips = substr(CountyFIPS, 2, 5)
destring fips, replace

* Collapse to year/Hazard level
collapse (sum) PropertyDmgPerCapitaADJ2018, by(fips year Hazard)
g log_percap_damages = log10(PropertyDmgPerCapitaADJ2018)

* Categories
g disaster_category = 1 if log_percap_damages < 0 | PropertyDmgPerCapitaADJ2018 == 0
replace disaster_category = 2 if log_percap_damages < 1 & log_percap_damages > 0
replace disaster_category = 3 if log_percap_damages < 2 & log_percap_damages > 1
replace disaster_category = 4 if log_percap_damages < log10(500) & log_percap_damages > 2
replace disaster_category = 5 if log_percap_damages > log10(500) & log_percap_damages != .

* Replace Others
g hazard = Hazard
foreach category in "Avalanche" "Coastal" "Drought" "Earthquake" "Fog" "Heat" "Landslide" "Lightning" "Tsunami/Seiche" "Volcano" "Wildfire" {
	replace hazard = "Other" if hazard == "`category'"
}


* Collapse
collapse (count) number_per_year = log_percap_damages, by(hazard disaster_category)

encode hazard, g(haz)
tab hazard haz

drop hazard

reshape wide number_per_year, i(disaster_category) j(haz)

drop if disaster_category == 1

label define dis_size 2 "Small Disasters" 3 "Medium Disasters"4  "Large Disasters" 5 "Very Large Disasters"
label values disaster_category dis_size 

graph bar number_per_year1-number_per_year3 number_per_year5-number_per_year8 number_per_year4, over(disaster_category) stack graphregion(color(white)) legend(lab(1 "Flooding") lab(2 "Hail") lab(3 "Hurricane/Tropical Storm") lab(4 "Severe Strom/Thunder Storm") lab(5 "Tornado") lab(6 "Wind") lab(7 "Winter Weather") lab(8 "Other") ) percent ytitle("Percent")
graph export "$output/DisasterFigs/DisastersByCategory.pdf", as(pdf) replace

