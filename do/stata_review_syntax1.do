/*******************************************************************************

stata_review_syntax - Review of Stata syntax and conventions
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

	It became a member of the United Nations in 1993, but, as a result of an 
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
//log close

