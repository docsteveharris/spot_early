*  =============================
*  = Generate propensity score =
*  =============================
/*
NOTE: 2013-02-23 - you may want to convert this to a cr_ file or
just save the estimates and replay them in the cr file

*/
/*
### Notes on using psmatch2
___________________________
- where a 1:1 match is requested several matches may be possible for each case but only the first one according to the current sort order of the file will be selected.  Therefore make sure you set a seed and then randomly sort the data so that you can reproduce your work.
- non-replacement is recommended when selecting matches but this option does not work for Mahalanobis matching in psmatch2.  You must implement this yourself
- pstest: compares covariares balance before and after matching
- psgraph: compares propensity score histogram by treatment status

### Notes on using imbalance
____________________________
- calculates the covariate imbalance statistics d_x and d_xm developed by Haviland see pp 172 [@Guo:2009vr]
*/

GenericSetupSteveHarris spot_early an_model_propensity, logon

local clean_run 1
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
}
use ../data/working_postflight.dta, clear

*  =====================
*  = Prepare the model =
*  =====================
/*
NOTE: 2013-02-23 - approach to specifying propensity model
- do not include instruments, favour vars assoc with outcome over vars assoc with Rx
- hence check assoc with outcome at each stage
- use logistic models for simplicity
- avoid icufree-days as this is not normally distributed even though linear


dependent var is early4
	- however it would be good to check different times (and consider recoomend and decide)
independent vars
site level
	hes_overnight
	hes_emergx
	patients_perhesadmx
	ccot_shift_pattern
unit level
	cmp_beds_max
timing level
	out_of_hours
	weekend
	bed_none
patient level
	age_c
	male
	periarrest
	sepsis_dx
	v_ccmds
	icnarc0_c
vars that might be too tightly correlated with outcome
	icu_recoomend
	icu_accept

*/

// univariate inspection
tab dead28
tab early4

foreach var in early4 dead28 {
	local plot 1
	// site vars
	tabstat `var', by(hes_overnight_k) s(n mean sd ) format(%9.3g)
	running `var' hes_overnight
	graph rename plot_`var'_`plot', replace
	local ++plot
	tab `var' hes_overnight_k, col chi
	// assoc with outcome and exposure but v weak on running

	tabstat `var', by(hes_emergx_k) s(n mean sd ) format(%9.3g)
	running `var' hes_emergx
	graph rename plot_`var'_`plot', replace
	local ++plot
	tabstat `var', by(hes_emergx_k) s(n mean sd ) format(%9.3g)
	tab `var' hes_emergx_k, col chi
	// assoc with outcome and exposure but v weak on running

	cap drop patients_perhesadmx_k
	egen patients_perhesadmx_k = cut(patients_perhesadmx), at(0, 0.5, 1,100) label
	tabstat `var', by(patients_perhesadmx_k) s(n mean sd ) format(%9.3g)
	running `var' patients_perhesadmx, ci
	graph rename plot_`var'_`plot', replace
	local ++plot

	tabstat `var', by(ccot_shift_pattern) s(n mean sd ) format(%9.3g)
	tab `var' ccot_shift_pattern, col chi
	// associated by chi but not v impressive

	// include all though hes_overnight doesn't look very impressive
	// include as categorical

	// unit vars
	tabstat `var', by(cmp_beds_peradmx_k) s(n mean sd ) format(%9.3g)
	running `var' cmp_beds_perhesadmx, ci
	graph rename plot_`var'_`plot', replace
	local ++plot
	tab `var' cmp_beds_peradmx_k, col chi
	// again not v impressive in outcome model



	// patient level
	tabstat `var', by(age_k) s(n mean sd ) format(%9.3g)
	running `var' age, ci
	graph rename plot_`var'_`plot', replace
	local ++plot
	// enter as categorical
	// assoc with outcome +++ but weakly with exposure

	tabstat `var', by(male) s(n mean sd ) format(%9.3g)
	tabstat `var', by(periarrest) s(n mean sd ) format(%9.3g)
	tabstat `var', by(sepsis_dx) s(n mean sd ) format(%9.3g)
	tabstat `var', by(v_ccmds) s(n mean sd ) format(%9.3g)
	// probably best to collapse into binary?
	tabstat `var', by(icnarc_q5) s(n mean sd ) format(%9.3g)

	// timing
	tabstat `var', by(weekend) s(n mean sd ) format(%9.3g)
	tabstat `var', by(out_of_hours) s(n mean sd ) format(%9.3g)
	// weakly assoc with outcome
	tabstat `var', by(bed_pressure) s(n mean sd ) format(%9.3g)
	// do not use in propensity model as this is not a confounder

	// decision and recoomend
	tabstat `var', by(icu_recommend) s(n mean sd ) format(%9.3g)
	tabstat `var', by(icu_accept) s(n mean sd ) format(%9.3g)

}

// TODO: 2013-02-23 - check that the propensity score works is available to all patients

global prvars ///
	i.hes_overnight_k ///
	i.hes_emergx_k ///
	i.patients_perhesadmx_k ///
	ib3.ccot_shift_pattern ///
	i.cmp_beds_peradmx_k ///
	weekend ///
	out_of_hours ///
	ib2.age_k ///
	male ///
	periarrest ///
	i.sepsis_dx ///
	i.v_ccmds ///
	i.icnarc_q10 ///
	i.v_ccmds 

// check vars in full *outcome* model
logistic dead28 $prvars
est store dead28
logistic early4 $prvars
est store prscore1

global prvars ///
	i.hes_overnight_k ///
	i.hes_emergx_k ///
	i.patients_perhesadmx_k ///
	ib3.ccot_shift_pattern ///
	i.cmp_beds_peradmx_k ///
	weekend ///
	out_of_hours ///
	ib2.age_k ///
	male ///
	periarrest ///
	i.sepsis_dx ///
	i.v_ccmds ///
	i.icnarc_q10 ///
	i.v_ccmds 

logistic early4 $prvars icu_recommend icu_accept
est store prscore2

forvalues i = 1/2 {
	est restore prscore`i'
	cap drop prscore`i'
	predict prscore`i', xb
	replace prscore`i' = invlogit(prscore`i')
	label var prscore`i' "Propensity score `i'"
}

// quick 'play'
logistic dead28 early4 prscore1
logistic dead28 early4 prscore2

gen prscore2_odds = logit(prscore2)
logistic dead28 early4 prscore2_odds

gen wt = .
replace wt = 1 / prscore2 if early4 == 1
replace wt = 1 / (1 - prscore2) if early4 == 0
logistic dead28 early4 [pweight=wt]





*  ===================================
*  = Produce the common overlap plot =
*  ===================================
hist prscore1 ///
	, ///
	by(early4, ///
		ixaxes col(1)) ///
	s(0) w(0.025) percent ///
	xscale(noextend) ///
	xlab(0(0.25)1, format(%9.1f)) ///
	yscale(noextend) ///
	ylab(0(10)50, format(%9.0gc) nogrid)

graph rename hist_propensity, replace
graph export ../outputs/figures/hist_propensity.pdf, ///
	name(hist_propensity) ///
	replace

tabstat prscore, by(early4) s(n mean sd min q max) format(%9.3g)

save ../data/working_propensity_all.dta, replace


cap log off