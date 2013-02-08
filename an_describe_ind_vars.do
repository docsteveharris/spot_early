GenericSetupSteveHarris spot_early an_describe_ind_vars, logon


use ../data/working.dta, clear
include cr_preflight.do
save ../data/scratch/scratch.dta, replace


*  ============================================================
*  = Table summarising key aspects of vars for survival model =
*  ============================================================
use ../data/scratch/scratch.dta, clear

/* Timing variables */
tab visit_hour
tab visit_dow
* NOTE: 2013-01-15 - don't use visit month (unless 11-12 months data available)
* tab visit_month


/* Site level variables */
tab ccot_shift_pattern
su cmp_patients_permonth
su tails_othercc
* NOTE: 2013-01-15 - the following if associated with the outcome would suggest bias?
tab all_cc_in_cmp
su tails_all_percent
su match_quality_by_site

/* Patient level variables */
su age
tab sex
tab v_ccmds
tab v_timely
tab sepsis_dx
tab vitals1
tab rxlimits
tab icu_accept
tab icu_recommend
tab icu_accept icu_recommend
su news_score sofa_* icnarc_score, separator(9)
tab ccot_on
tab beds_none
tab full_active1

/*
Need to report on
- missingness
- min q25 q50 q75 max
- mean sd
- spike at zero
- skew kurtosis
*/

/* Now inspect the continuous vars  */
use ../data/scratch/scratch.dta, clear
local cont_vars tails_all_percent cmp_patients_permonth ///
	match_quality_by_site ///
	age news_score sofa_score icnarc_score

tempname pname
tempfile pfile
postfile `pname' str16 varname nmiss min p25 p50 p75 max mean sd skew kurt spike_0  ///
	using `pfile' , replace

foreach var of local cont_vars {
	qui su `var'
	local n = r(N)
	count if `var' == 0
	local spike_0 = r(N)
	count if `var' == .
	local nmiss = r(N)
	su `var', detail
	post `pname' ("`var'") (`nmiss') (r(min)) (r(p25)) (r(p50)) (r(p75)) ///
		(r(max)) (r(mean)) (r(sd)) (r(skewness)) (r(kurtosis)) (`spike_0')
}

postclose `pname'
use `pfile', clear
br

/* Now inspect the categorical or binary vars */
use ../data/scratch/scratch.dta, clear

/*
Main job is to look for -
- sparse categories and define the baseline for each var
- missing data
*/

local cat_vars visit_hour visit_dow ccot_shift_pattern all_cc_in_cmp ///
	v_ccmds v_timely ///
	sex sepsis_dx vitals1 rxlimits icu_accept icu_recommend ccot_on ///
	full_active1 beds_none

tempname pname
tempfile pfile
postfile `pname' str16 varname nmiss smallest_cat using `pfile' , replace

foreach var of local cat_vars {
	levelsof `var', clean local(lvls)
	qui count
	local smallest_cat = r(N)
	foreach lvl of local lvls {
		qui count if `var' == `lvl'
		if r(N) < `smallest_cat' local smallest_cat = r(N)
	}
	count if `var' == .
	local nmiss = r(N)
	post `pname' ("`var'") (`nmiss') (`smallest_cat')
}

postclose `pname'
use `pfile', clear
br

/*
Now consider correlations and co-linearity
- perhaps best visualised rather than just quoting pearson correlation co-efficents
*/

use ../data/scratch/scratch.dta, clear
running icnarc_score age
* NOTE: 2013-01-16 - so a slight increase 
egen pickone = tag(icode)
bys icode: egen icnarc_score_sbar = mean(icnarc_score)
running icnarc_score_sbar cmp_patients_permonth if pickone
/* The following should not be correlated unless there is bias */
running icnarc_score_sbar match_quality_by_site if pickone
running icnarc_score_sbar tails_all_percent if pickone





cap log close
