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
	cmp_beds_max : switch to smallunit
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


- all above in single level (ignoring correlation of site level vars)
- then repeat in
	- random effects
	- fixed effects (site)

*/

// univariate inspection
tab dead28
tab early4

local premodel_checks = 0
if `premodel_checks' == 1{

	// check for collinearity
	collin hes_overnight ///
		hes_emergx ///
		patients_perhesadmx ///
		cmp_beds_perhesadmx ///
		ccot_shift_pattern ///
		age ///
		male ///
		sepsis_dx ///
		periarrest ///
		v_ccmds ///
		icnarc0 ///
		weekend ///
		out_of_hours ///
		bed_pressure ///
		icu_recommend ///
		icu_accept

	// NOTE: 2013-02-28 - no good evidence of collinearity

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

		// CHANGED: 2013-03-03 - move this to earlier in the file to avoid running all checks
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
		tabstat `var', by(small_unit) s(n mean sd ) format(%9.3g)
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
		tabstat `var', by(sepsis1_b) s(n mean sd ) format(%9.3g)
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
}

// TODO: 2013-02-23 - check that the propensity score works is available to all patients

estimates drop _all

// CHANGED: 2013-03-29 - moved variable definitions to preflight

logistic early4 $prvars_c
// check model fit with continuous: nearly linear so keep this way?
cap drop rstandard*

logistic early4 $prvars_k
predict rstandard1, rstandard
running rstandard1 age
graph rename age1, replace
running rstandard1 icnarc0
graph rename icnarc0_1, replace
logistic early4 $prvars_c if time2icu != .
predict rstandard2, rstandard
running rstandard2 icnarc0
graph rename icnarc0_2, replace
graph combine icnarc0_1 icnarc0_2
running rstandard2 age
graph rename age2, replace
graph combine age1 age2

logistic dead28 $prvars_k
est store dead28_k
logistic early4 $prvars_k
est store prscore1_k

logistic early4 $prvars_k
est store prscore1_k
logistic early4 $prvars_c
est store prscore1_c

estimates stats prscore1_k prscore1_c
// not much difference: stay with the continuous version

*  ============================================
*  = RUN AND SAVE THE FINAL PROPENSITY MODELS =
*  ============================================
use ../data/working_postflight.dta, clear
est drop _all

* NOTE: 2013-03-29 - global variable definitions prvars_* moved to preflight

// models with instrument for interest only
// full patient level only model incl instrument
logistic early4 $prvars_patient beds_none
est store log_cc0
// full patient and site level model incl instrument
logistic early4 $prvars_patient beds_none $prvars_site $prvars_timing
est store log_cc1

// NOTE: 2013-03-05 - excluding the instrument from now on

// Candidate model 1:
// Kitchen sink @ patient level *without* cc_recommend
logistic early4 $prvars_patient $prvars_site $prvars_timing
est store pm_lvl1_cc0
estimates title: Propensity model - 1 level - w/o recommend
estimates save ../data/estimates/pm_lvl1_cc0.ster, replace

// Candidate model 2:
// Kitchen sink @ patient level *with* cc_recommend
logistic early4 $prvars_patient $prvars_site $prvars_timing cc_recommend
est store pm_lvl1_cc1
estimates title: Propensity model - 1 level - incl recommend
estimates save ../data/estimates/pm_lvl1_cc1.ster, replace

// Now switch to 2 level models
xtset site
xtsum age male periarrest sepsis1_b v_ccmds icnarc0
xtsum weekend out_of_hours
xtsum small_unit hes_overnight hes_emergx patients_perhesadmx ccot_shift_pattern
// NOTE: 2013-03-05 - bizzare structe to patients_perhesadmx: should only have betw variance

// Compare random effects and fixed effects
xtlogit early4 $prvars_patient $prvars_timing, fe
est store xt0fe
// use xtmelogit for post-estimation features in random effects form
xtmelogit early4 $prvars_patient $prvars_site $prvars_timing || site:
est store xt0re

xtlogit early4 $prvars_patient $prvars_timing cc_recommend, fe
est store xt1fe
// use xtmelogit for post-estimation features in random effects form
xtmelogit early4 $prvars_patient $prvars_site $prvars_timing cc_recommend || site:
est store xt1re

est table log_cc0 pm_lvl1_cc0 xt0re xt0fe , ///
	b(%9.2fc) eform star ///
	newpanel stats(N ll chi2 aic bic)
est table log_cc1 pm_lvl1_cc1 xt1re xt1fe, ///
	b(%9.2fc) eform star ///
	newpanel stats(N ll chi2 aic bic)

// Candidate model 3:
// 2 level random effects
// Kitchen sink @ site_level *without* cc_recommend
est restore xt0re
est store pm_lvl2_cc0
estimates title: Propensity model - 2 level - w/o recommend
estimates save ../data/estimates/pm_lvl2_cc0.ster, replace

// Candidate model 4:
// 2 level random effects
// Kitchen sink @ site_level *with* cc_recommend
est restore xt1re
est store pm_lvl2_cc1
estimates title: Propensity model - 2 level - incl recommend
estimates save ../data/estimates/pm_lvl2_cc1.ster, replace

// Candidate model 5:
// Kitchen sink @ patient and timing + dummy for site *without* cc_recommend
logistic early4 $prvars_patient $prvars_site $prvars_timing ib(freq).site
est store pm_lvl2f_cc0
estimates title: Propensity model - 2 level fixed - w/o recommend
estimates save ../data/estimates/pm_lvl2f_cc0.ster, replace

// Candidate model 6:
// Kitchen sink @ patient and timing + dummy for site *with* cc_recommend
logistic early4 $prvars_patient $prvars_site $prvars_timing ib(freq).site cc_recommend
est store pm_lvl2f_cc1
estimates title: Propensity model - 2 level fixed - incl recommend
estimates save ../data/estimates/pm_lvl2f_cc1.ster, replace

// now you have the saved estimation results ready to use

*  =====================================================
*  = Save your propensity predictions to the data file =
*  =====================================================
// do this here and now so it easy to pull in to R files

use ../data/working_postflight.dta, clear
// now bring in your saved estimates
local models ///
		pm_lvl1_cc0 ///
		pm_lvl1_cc1 ///
		pm_lvl2_cc0 ///
		pm_lvl2_cc1 ///
		pm_lvl2f_cc0 ///
		pm_lvl2f_cc1
foreach model of local models {
	estimates use ../data/estimates/`model'.ster
	// NOTE: 2013-03-05 - seems OK wrt to esample but not 100% sure this is robust
	// see the code inserted for the RE model below
	est store `model'
	di "`=e(estimates_title)' e(esample) is `=e(N)' patients"
	if e(cmd) == "logistic" {
		cap drop `model'_yhat
		predict `model'_yhat, xb
		cap drop `model'_prob
		predict `model'_prob, pr
	}
	else {
		// leave this here ... but you are not planning on using FE models for prediction?
		//if e(cmd2) == "xtlogit" {
		//	cap drop `model'_yhat
		//	predict `model'_yhat, xb
		//	// Pr(early4 | one positve outcome in the group)
		//	cap drop `model'_prob
		//	predict `model'_prob, pc1
		//}
		if e(cmd) == "xtmelogit" {
			// set the sample up again
			estimates esample: `=e(datasignaturevars)', replace
			count if e(sample)
			// hand calculate the linear predictor incl fixed and random effects
			cap drop `model'_yhat
			tempvar xb reffects
			predict `xb', xb
			predict `reffects', reffects
			gen `model'_yhat = `xb' + `reffects'
			// Predicted mean: uses fixed and random effects
			cap drop `model'_prob
			predict `model'_prob, mu
		}
	}
}
cap drop _yhat _prob
su *_yhat *_prob
sort id
save ../data/working_propensity_all.dta, replace

use ../data/working_propensity_all, clear
cap drop __*
*  ===================================================
*  = Run a 2 - level model and generate latex output =
*  ===================================================
// now produce this as a latex table
// - use a 2 level model
// but though for the propensity score you need to think about this
logistic early4 $prvars_c
est store prscore1_c_1level
xtset site
xtlogit early4 $prvars_c
xtlogit, or
est store prscore1_c_2level
estimates save ../data/estimates/early4_2level.ster, replace


*  ============================================
*  = Produce a model results table for thesis =
*  ============================================
* NOTE: 2013-02-28 - this includes the instruments
* NOTE: 2013-02-28 - this is a 2 level model:
* not (necesarily) directly translatable to propensity
use ../data/working_postflight.dta, clear
qui include mt_Programs
estimates use ../data/estimates/early4_2level.ster
// replay
xtlogit
tempfile temp1
parmest , ///
	eform ///
	label list(parm label estimate min* max* p) ///
	format(estimate min* max* %8.3f p %8.3f) ///
	saving(`temp1', replace)
use `temp1', clear

// now label varname
mt_extract_varname_from_parm

// now get tablerowlabels
spot_label_table_vars

// label age categories by hand
replace var_level_lab = "18--39" if varname == "age" & var_level == 0
replace var_level_lab = "40--59" if varname == "age" & var_level == 1
replace var_level_lab = "60--79" if varname == "age" & var_level == 2
replace var_level_lab = "80--" if varname == "age" & var_level == 3


// now produce table order
global table_order ///
	hes_overnight hes_emergx ccot_shift_pattern patients_perhesadmx ///
	ccot_shift_pattern small_unit ///
	gap_here ///
	weekend out_of_hours beds_none ///
	gap_here ///
	age male sepsis1_b v_ccmds periarrest icnarc0
mt_table_order
sort table_order var_level
// indent categorical variables
mt_indent_categorical_vars

ingap 1 20 23
replace tablerowlabel = "\textit{Site factors}" if _n == 1
replace tablerowlabel = "\textit{Timing factors}" if _n == 21
replace tablerowlabel = "\textit{Patient factors}" if _n == 25
ingap 21 25

sdecode estimate, format(%9.2fc) gen(est)
sdecode min95, format(%9.2fc) replace
sdecode max95, format(%9.2fc) replace
sdecode p, format(%9.3fc) replace
replace p = "<0.001" if p == "0.000"
gen est_ci95 = "(" + min95 + "--" + max95 + ")" if !missing(min95, max95)
replace est = "--" if reference_cat == 1
replace est_ci95 = "" if reference_cat == 1

* now write the table to latex
order tablerowlabel var_level_lab est est_ci95 p
local cols tablerowlabel est est_ci95 p
order `cols'
cap br

local table_name early4_2level
local h1 "Parameter & Odds ratio & (95\% CI) & p \\ "
local justify lrll
* local justify X[5l] X[1l] X[2l] X[1r]
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}
local rho: di %9.3fc `=e(rho)'
local f1 "Intraclass correlation & `rho' && \\"
di "`f1'"

listtab `cols' ///
	using ../outputs/tables/`table_name'.tex ///
	if parm != "_cons", ///
	replace ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} to " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\midrule" ///
		"`f1'" ///
		"\bottomrule" ///
		"\end{tabu} " ///
		"\label{tab:`table_name'} ") ///


cap log off