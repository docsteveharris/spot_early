*  ==========================
*  = Regression diagnostics =
*  ==========================

GenericSetupSteveHarris spot_early an_model_ward_survival, logon

/*
Consider the following issues
- parameterisation of continous covariates
	- linktest
*/


*  ===================
*  = Model variables =
*  ===================
local patient_vars age_c sex_b sepsis_b delayed_referral icnarc0_c
local timing_vars out_of_hours weekend beds_none
local site_vars ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c

*  ===============================================
*  = Model variables assembled into single macro =
*  ===============================================
local all_vars age_c sex_b sepsis_b delayed_referral icnarc0_c ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c


local clean_run 1
if `clean_run' == 1 {
	include cr_survival.do
	// NOTE: 2013-01-29 - cr_survival.do stsets @ 28 days by default
}

*  ==================================
*  = Check for time-varying effects =
*  ==================================

/*
NOTE: 2013-02-01 - notes on outcome of running this by hand
Time varying effects
- age: no
- severity: yes
- delayed referral: no
- beds_none

*/
use ../data/working_survival.dta, clear
stsplit tb, at(3 14 28)
label var tb "Time blocks"
list site id _t _t0 _st _d tb in 1/10

stcox age_c sex_b sepsis_b delayed_referral icnarc0_c ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///
	, ///
	nolog
est store full

* Proportional hazards assumption - inspect which variables violate this
estat phtest, detail
* NOTE: 2013-02-03 - clear violation of PH hazards for severity
* nice way to plot this is as per Royston
predict sca*, scaledsch
rename sca5 ssresidual
running ssresidual _t if _d == 1, gen(ssresidual_bar) gense(ssresidual_se) nodraw
gen ssresidual_est = exp(ssresidual_bar)
gen ssresidual_min95 = exp(ssresidual_bar - 1.96*ssresidual_se)
gen ssresidual_max95 = exp(ssresidual_bar + 1.96*ssresidual_se)
local beta = exp(_b[icnarc0_c])
tw ///
	(rarea ssresidual_max95 ssresidual_min95 _t, sort pstyle(ci)) ///
	(line ssresidual_est _t, sort clpattern(solid)) ///
	(function y = `beta', lpattern(shortdash) range(_t)) ///
	, ///
	ylabel(, nogrid) ///
	yscale(noextend) ///
	ytitle("Exponentiated scaled Schoenfeld residual") ///
	xlabel(0(7)28) ///
	xscale(noextend) ///
	xtitle("Days following assessment") ///
	legend(off) ///
	ttext(`beta' 28 "Estimated (time-constant) hazard ratio" ///
		, placement(nw) justification(right) size(small) ///
		margin(small) ///
		)
graph rename survival_icnarc0_ssresidual, replace
graph export ../outputs/figures/survival_icnarc0_ssresidual.pdf, replace




stcox age_c sex_b sepsis_b delayed_referral icnarc0_c ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///
	i.tb#c.age_c ///
	, ///
	nolog

est store tb1
est stats full tb1
lrtest full tb1

stcox age_c sex_b sepsis_b delayed_referral icnarc0_c ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///
	i.tb#c.icnarc0 ///
	, ///
	nolog

est store tb2
est stats full tb2
lrtest full tb2

stcox age_c sex_b sepsis_b delayed_referral icnarc0_c ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///
	i.tb#delayed_referral ///
	, ///
	nolog

est store tb3
est stats full tb3
lrtest full tb3

stcox age_c sex_b sepsis_b delayed_referral icnarc0_c ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///
	i.tb#sex_b ///
	, ///
	nolog

est store tb4
est stats full tb4
lrtest full tb4
est table full tb1 tb2 tb3 tb4, b(%9.3f) p(%9.4f) eform stats(aic bic)

