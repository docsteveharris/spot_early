*  ============================================================================
*  = Model the site, patient and timing components that affect early survival =
*  ============================================================================

/*
TODO: 2013-01-22 -
- build a basic cox model
- refit with robust standard errors
- build a piecewise exponential model to estimate the underlying hazard
- build a model with shared frailty
- estimate the shared variance
*/

clear all
estimates drop _all
* Set-up the survival data
include cr_survival.do
* Working with 28 day survival
/*
NOTE: 2013-01-22 - lose some patients because resolution in days
 and die on or before day of visit
*/
stset
save ../data/working_survival.dta, replace

*  ===============================
*  = Examine the baseline hazard =
*  ===============================

local inspect_baseline 1
if `inspect_baseline' == 1 {
	use ../data/working_survival, clear
	stset dt1, id(id) origin(dt0) failure(dead) exit(time dt0+28)
	stsplit tsplit, every(1)
	gen risktime = _t - _t0

	* NOTE: 2012-10-04 - comment out code below and run collapsed version instead as quicker
	* glm _d ibn.tsplit, family(poisson) lnoffset(risktime) nocons eform
	* NOTE: 2012-10-04 - copy and paste stata table this into datagraph for quick inspection

	save ../data/scratch/scratch.dta, replace

	use ../data/scratch/scratch, clear
	collapse (min) _t0 (max) _t (count) n = _d (sum) risktime _d, by(tsplit)
	glm _d ibn.tsplit, family(poisson) lnoffset(risktime) nocons eform
	gen baseline_hazard = _d/n
	tw line baseline_hazard tsplit
	graph rename baseline_hazard, replace

}

estimates drop _all
use ../data/working_survival, clear

stcox, estimate
est store cox_base
estimates stats *
predict h_cox, basehc

streg , dist(exponential)
est store exp_base
estimates stats *
predict h_exp, hazard

streg , dist(weibull)
est store wb_base
estimates stats *
predict h_wb, hazard

streg , dist(gompertz)
est store gom_base
estimates stats *
predict h_gom, hazard

sort _t
tw ///
	(line h_cox _t, c(l)) ///
	(line h_exp _t, c(l)) ///
	(line h_wb _t, c(l)) ///
	(line h_gom _t, c(l)) 


* Looks like an exponentially decreasing hazard

*  ==============================================
*  = Now fit a cox model - univariate initially =
*  ==============================================

/*
Site level vars
- ccot
- ccot_shift_pattern
- hes_overnight
- hes_emergx
- cmp_beds_max
- match_quality_by_site
- count_patients_q5

Timing vars
- ccot_on
- ccot_shift_start
- beds_none
- full_active1

- out_of_hours
- weekend

Patient level vars
- age
- male

Severity factors (one or a limited combination of)
- sepsis_b
- sepsis2001
- news_risk
- news_score
- icnarc_score
- sofa_score

*/


use ../data/working_survival, clear
tempfile working_parm temp1
save `working_parm', replace
local first_run  1
local vars ///
	ccot ///
	ccot_shift_pattern ///
	hes_overnight ///
	hes_emergx ///
	cmp_beds_max ///
	match_quality_by_site ///
	count_patients_q5 ///
	ccot_on ///
	ccot_shift_start ///
	full_active1 ///
	beds_none ///
	out_of_hours ///
	weekend ///
	age ///
	male ///
	sepsis_severity ///
	news_risk ///
	news_score ///
	sofa_score ///
	icnarc_score ///


global catname univariate
foreach var of local vars {
	use `working_parm', clear
	// specify variables as needed
	if "`var'" == "ccot_shift_pattern" local var ib3.ccot_shift_pattern
	if "`var'" == "count_patients_q5" local var i.count_patients_q5
	if "`var'" == "sepsis_severity" local var i.sepsis_severity
	if "`var'" == "news_risk" local var ib1.news_risk

	qui stcox `var'
	tempfile temp1
	qui parmest , ///
		eform ///
		label list(parm label estimate min* max* p) ///
		format(estimate min* max* %8.3f p %8.3f) ///
		idstr("$catname") ///
		saving(`temp1', replace)
	if `first_run' {
		use `temp1', clear
		save ../data/model_ward_survival.dta, replace
	}
	else {
		use ../data/model_ward_survival.dta, clear
		append using `temp1'
		save ../data/model_ward_survival.dta, replace
	}
	local first_run 0
}

use ../data/model_ward_survival.dta, replace
br parm estimate min95 max95 p



use ../data/working_survival, clear
tempfile working_parm temp1
save `working_parm', replace
local ivars1 ///
	ib3.ccot_shift_pattern ///
	hes_overnight ///
	hes_emergx ///
	cmp_beds_max ///
	match_quality_by_site ///
	i.count_patients_q5 ///
	ccot_on ///
	ccot_shift_start ///
	beds_none ///
	out_of_hours ///
	weekend ///
	age ///
	male ///


forvalues i = 1/3 {
	use `working_parm', clear

	// specify variables as needed
	if `i' == 1 {
		local ivars2 sepsis_b news_risk
		global catname multi_news_risk
	}
	if `i' == 2 {
		local ivars2 sepsis_b icnarc_score icnarc_miss10
		global catname multi_icnarc
	}
	if `i' == 3 {
		local ivars2 sepsis_severity
		global catname multi_sepsis
	}

	local ivars `ivars1' `ivars2'
	qui stcox `ivars'
	tempfile temp1
	qui parmest , ///
		eform ///
		label list(parm label estimate min* max* p) ///
		format(estimate min* max* %8.3f p %8.3f) ///
		idstr("$catname") ///
		saving(`temp1', replace)

	use ../data/model_ward_survival.dta, clear
	append using `temp1'
	save ../data/model_ward_survival.dta, replace
}


use ../data/model_ward_survival.dta, replace
gen varname = parm
replace varname = substr(parm,strpos(parm,".") + 1,.) if strpos(parm,".") != 0
tempvar reverse_parm
gen `reverse_parm' = reverse(parm)
gen varlevel = substr(`reverse_parm',strpos(`reverse_parm',".") + 1,.)  ///
	if strpos(`reverse_parm',".") != 0
replace varlevel = reverse(varlevel)
gsort varname varlevel -idstr
br varname varlevel idstr estimate min95 max95 p

*  ===========
*  = SCRATCH=
*  ===========

use ../data/working_survival, clear
/*
CHANGED: 2013-01-22 - following vars should be entered into the model?
- count_patients_q5
- hes_overnight
- hes_emergx
*/

local ivars1 ///
	ib3.ccot_shift_pattern ///
	cmp_beds_max ///
	ccot_on ///
	ccot_shift_start ///
	out_of_hours ///
	weekend ///
	age ///
	male 

global ivars `ivars1'

stcox $ivars beds_none i.icnarc_q10 icnarc_miss10, shared(icode)
stcox $ivars beds_none i.icnarc_q10 icnarc_miss10
stcox $ivars beds_none i.icnarc_q10 icnarc_miss10, vce(cluster icode)

stcox $ivars beds_none icnarc_score icnarc_miss10
stcox $ivars beds_none icnarc_score icnarc_miss10, vce(cluster icode)
stcox $ivars beds_none icnarc_score icnarc_miss10, shared(icode)

stcox $ivars beds_none##c.icnarc_score icnarc_miss10
stcox $ivars beds_none icnarc_score icnarc_miss10, vce(cluster icode)
stcox $ivars beds_none icnarc_score icnarc_miss10, shared(icode)
