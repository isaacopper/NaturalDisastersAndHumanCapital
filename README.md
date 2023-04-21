# NaturalDisastersAndHumanCapital
This repository includes the code for the paper "The effect of natural disasters on human capital in the United States." The precise order of the files does not matter too much, although the files seda.do, netmig.do, ipeds_year_differences.do, edfacts_years_differences.do all create data that is used as input to the files that are listed after those.

# Included Files
## Describing the Disasters
* DisasterCounts.do --> Couts the number natural disasters in the United States over time and by type of disaster
* MappingDisasters.py --> Maps the locations of disasters

## Estimating Component Effects
* seda.do --> Cleans/estiamtes the effect on student test scores
* netmig.do --> Cleans/estiamtes the effect on netmigration
* ipeds_year_differences.do --> Cleans/estiamtes the effect on post-secondary attendance
* edfacts_year_differences.do --> Cleans/estiamtes the effect on high school graduation rates
* LogRegressions.do --> Estimates the relationship between log disaster size and the four human capital components (e.g., produces Extended Data Table 1 in the paper)
* EffectGraphs.R --> Non-parametrically estimates the relationship between log disaster size and the human capital components (e.g., produces Figure 3a/b in the paper)

## Aggregating the Results
* BarChart.do --> Combines the results into a top-line number and graphs it via a bar chart (e.g., produces Figure 4 in the paper)

## Robustness, Heterogeneity, and Responses to Reviewers
* Robustness.do --> Various checks of how robust the results are.
* PhysicalCharacteristics.R --> How does property damage relate to physical characteristics of the disasters?
* Heterogeneity.do --> How to the results vary by characteristics of the counties?
