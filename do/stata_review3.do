/*******************************************************************************

stata_review - Review of Stata commands
Michael Wooley
Econ 326

DON'T FORGOT TO RUN THE LOG FILE!
DON'T FORGOT TO RUN THE LOG FILE!
DON'T FORGOT TO RUN THE LOG FILE!
DON'T FORGOT TO RUN THE LOG FILE!
DON'T FORGOT TO RUN THE LOG FILE!
DON'T FORGOT TO RUN THE LOG FILE!

*******************************************************************************/

**** SETUP ****

* Clear all variables, figures, etc. from memory
clear all
* Avoid the annoying "more" message
set more off

* Set up locals
* 	Working Directory
local wk_dir C:\Users\Michael\Dropbox\teaching\ECON326\Recitations\Recitation1\stata_review
*	Log File Name
local log_name log\syntax_review_log

* Set Working Directory
cd `wk_dir'

/* Start up log file
	Options:
		replace ~ if the log file already exists, replace it with the new output
		text    ~ Log file in '.log' format rather than '.smcl'. Readily opened
					in text editors without need for Stata
		Alternative options? Look at help file: help log
*/


//log using `log_name', replace text

**** DATA CLEANING & SHOVELING ****

* Open the base dataset
use data/raw/lifeexp-eur&asia, replace
* Inspect it: (Bad labels, data types, no labels, missing data)
describe
browse
misstable summarize
* Correct Errors in Labeling
label var region Region
label var country Country

* Append dataset for Americas - add ROWS
* Peak into appending dataset to check for problems
* Preserve current data for later
preserve
* Now using new data
use data/raw/lifeexp-america, clear
* Run same checks on this data as last
describe
browse
misstable summarize
* Restore previous data
restore
* Append
append using data/raw/lifeexp-america

* Merge dataset on per capita income - add COLUMNS
* Peak into merging dataset to check for problems, identify merging variables
* Preserve again
preserve
use data/raw/gnppc, clear
describe
browse
misstable summarize
* Can match on country name but need variables to be the same
rename Country country
* Save as NEW dataset in 'data/int'
save data/int/gnppc_for_merge, replace
* Restore data
restore
* Now do the actual merge!
* Still a bit hazy on the "sort" rationale. Just do it if you get an error...
sort country
* Let's preserve the data in case something goes wrong on merge
preserve
* Merge
merge 1:1 country using data/int/gnppc_for_merge 

* What countries were left out?
list region country _merge if _merge != 3
/* 
Appears that Macedonia and Macedonia FYR are actually the same country?

Yes, from Wikipedia entry for "Republic of Macedonia"
 (https://en.wikipedia.org/wiki/Republic_of_Macedonia)

	It became a member of the United Nations in 1993," but, as a result of an 
	ongoing dispute with Greece over the use of the name "Macedonia", was 
	admitted under the provisional description the former Yugoslav Republic 
	of Macedonia[10][11] (sometimes unofficially abbreviated as FYROM and 
	FYR Macedonia), a term that is also used by international organizations 
	such as the European Union,[12] the Council of Europe[13] and NATO.[14]
*/ 

* Amend gnppc_for_merge data
use data/int/gnppc_for_merge, clear
* Change a single name
replace country = "Macedonia FYR" if country == "Macedonia"
* Save
save data/int/gnppc_for_merge, replace

* Restore back life expectations data
restore
* Merge again
* Merge
merge 1:1 country using data/int/gnppc_for_merge 

* What countries were left out?
li region country _merge if _merge != 3
* Check on Macedonia:
li region country _merge if country == "Macedonia FYR"

* Data is ready for analysis. Save it to 'data/fin' 
save data/fin/lifeexp_main, replace

**** DESCRIPTIVE STATISTICS ****

* Not strictly necessary but useful if copy to separate do file later
use data/fin/lifeexp_main, clear

* Basic Summary Stats - All variables by default
su
* Select variables - safewater and variables with "p" in name
su safewater *p*
* Detailed stats
su gnppc, detail
* Save median GNP for later
local gnp_med = `r(p50)'
* Stats by region
bysort region: su lexp
* Stats for subsets meeting logical condition: If GNP above/below median.
su lexp popgrowth if gnppc < `gnp_med'
su lexp popgrowth if gnppc >= `gnp_med'

**** CORRELATIONS AND REGRESSIONS ****

* Pearson Correlation Coefficients - corr and pwcorr differ in treatment of 
*	missing data.
* NOTICE: these are different!
corr pop* lexp gnppc safewater
pwcorr pop* lexp gnppc safewater, obs 
* Restrict pwcorr to sample of countries with full data to get back corr
pwcorr pop* lexp gnppc safewater ///
	if popgrowth != . & lexp != . & gnppc != . & safewater != . , obs
* pwcorr can also display p-values for null hypothesis H0: CORR != 0
pwcorr  lexp gnppc safewater, sig

* Basic OLS regression
reg popgrowth lexp gnppc
* With "robust" SEs
reg popgrowth lexp gnppc, r
* Add region dummies - note difference between dummies and factor numbers
xi: reg popgrowth lexp gnppc i.region, r

* Easy/intuitive coefficient interpretations? Not as easy as logged versions:
gen log_gnppc = log(gnppc) 
label var log_gnppc "log(GNP per capita)"
gen log_lexp = log(lexp)
label var log_lexp "log(Life expectancy at birth)"

* Now get elasticity interpretation:
xi: reg popgrowth log_* i.region, r

* Look at effects of being above/below cutoffs...
gen gnppc_above_med = 0
replace gnppc_above_med = 1 if gnppc > `gnp_med'

* Compare:
reg popgrowth log_g*, r
reg popgrowth gnppc_above_med, r

**** Graphs ****

* Bring in PWT
import excel data/raw/pwt90.xlsx, sheet("Data") firstrow clear
* Run the labels
do do/pwt_label

* Add in continent codes for later - many to one merge
preserve
import delimited data\raw\country_continents.csv, clear 
drop countrycode
rename alpha3 countrycode
save data/int/country_continents, replace
restore
merge m:1 countrycode using data/int/country_continents
keep if _merge == 3
drop _merge

* Set up panel
* Need the country variable to be a factor variable
encode country, gen(country_fac)
* Displays variable in terms of underlying label/string
tab country_fac
* But under the hood it is actually a number! Uncomment and run (throws error)
/*
count if country_fac == "Turkmenistan"
count if country == "Turkmenistan"
*/

* Now set panel
xtset country_fac year

* Make average growth rates
* For purposes of comparison, let's drop all years < 1970
keep if year >= 1970
* For ease of analysis, let's just keep those variables that we'll be needing
keep year country* rgdpe pop *region*
* Make log income per capita - Notice that rgdpe and pop both in millions
gen log_gdp_pc = log(rgdpe / pop)
label var log_gdp_pc "Log GDP per capita - log(rgdpe / pop)"
* Now make a growth rate using the lag operator
gen d_gdp_pc = D.log_gdp_pc
label var d_gdp_pc "Growth GDP per capita - D.log_gdp_pc"
* Make mean growth rates using egen and bysort
bysort country: egen mean_d_gdp_pc = mean(d_gdp_pc)
* Make a percent by multiplying by 100
replace mean_d_gdp_pc  = mean_d_gdp_pc * 100
label var mean_d_gdp_pc "Mean Growth - GDP per capita (%), 1970-2014"
* Should do spot check to make sure correct
order country mean_d_gdp_pc
//browse

* How do we get the first year's GDP?
* reshape! long -> wide
* What do we need?
keep log_gdp_pc mean_d_gdp_pc country* year *region*
reshape wide log_gdp_pc, i(country) j(year)
* Really only need to keep the log_gdp_pc from 1970 - Make a new variable
gen init_log_gdp_pc = log_gdp_pc1970
label var init_log_gdp_pc "Log GDP per capita, 1970"
* Drop all others
drop log_gdp_pc*

* Make the plot
scatter mean_d_gdp_pc init_log_gdp_pc
twoway scatter mean_d_gdp_pc init_log_gdp_pc, ///
	title("Initial GDP and Subsequent Growth, 1970-2014") ///
	mlabel(countrycode) mlabp(0) m(i) mlabs(1.45)
* Fit a line
twoway (lfitci mean_d_gdp_pc init_log_gdp_pc) ///
	(scatter mean_d_gdp_pc init_log_gdp_pc, ///
	title("Initial GDP and Subsequent Growth, 1970-2014") ///
	mlabel(countrycode) mlabp(0) m(i) mlabs(1.45) ///
	legend(off))
* What about separate plots by continent?
twoway scatter mean_d_gdp_pc init_log_gdp_pc, ///
	mlabel(countrycode) mlabp(0) m(i)  mlabs(1.45) ///
	by(region)
* One plot with color by subregion?
separate mean_d_gdp_pc, by(region)
twoway scatter mean_d_gdp_pc* init_log_gdp_pc, ///
	title("Initial GDP and Subsequent Growth, 1970-2014") ///
	legend(off) m(i) ///
	ytitle("Mean Growth - GDP per capita (%), 1970-2014")




/*
TO BE ADDED:

Syntax info.
graphs
Reshape

*/


**** HELP ****
*help local

*do do/sample_do.do


* https://geocenter.github.io/StataTraining/portfolio/01_resource/

* Close log file
scatter mean_d_gdp_pc init_log_gdp_pc
graph export "figures/test_fig.png"
twoway (scatter mean_d_gdp_pc init_log_gdp_pc if init_log_gdp_pc <= log(30000), ///
	mlabel(countrycode) mlabp(0) m(i) mlabs(1.65)) || ///
	(scatter mean_d_gdp_pc init_log_gdp_pc if init_log_gdp_pc > log(30000), ///
	mlabel(countrycode) mlabp(0) m(i) mlabs(1.65) ///
	legend(off) ///
	title("Initial GDP and Subsequent Growth, 1970-2014") ///
	)
graph export figures/split_gdp.png, replace
twoway scatter mean_d_gdp_pc init_log_gdp_pc  if init_log_gdp_pc <= log(30000), ///
	title("Initial GDP and Subsequent Growth, 1970-2014") ///
	mlabel(countrycode) mlabp(0) m(i) mlabs(1.45)
graph export figures/non_oil_alpha.png, replace
// What about separate plots by continent?
twoway scatter mean_d_gdp_pc init_log_gdp_pc, ///s
	mlabel(countrycode) mlabp(0) m(i)  mlabs(1.45) ///
	by(region)
graph export figures/by_continent_sep.png, replace
// One plot with color by subregion?
separate mean_d_gdp_pc, by(region)
twoway scatter mean_d_gdp_pc* init_log_gdp_pc, ///
	title("Initial GDP and Subsequent Growth, 1970-2014") ///
	legend(off) m(i) ///
	ytitle("Mean Growth - GDP per capita (%), 1970-2014")
graph export figures/by_continent_tog.png, replace

