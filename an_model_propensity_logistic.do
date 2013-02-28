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

*/

// univariate inspection
tab dead28
tab early4

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

// TODO: 2013-02-23 - check that the propensity score works is available to all patients

estimates drop _all

// categorical version
global prvars_k ///
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
	sepsis1_b ///
	i.v_ccmds ///
	i.icnarc_q10 ///
	i.v_ccmds


// using continuous variables where possible
global prvars_c ///
	i.hes_overnight_k ///
	i.hes_emergx_k ///
	i.patients_perhesadmx_k ///
	ib3.ccot_shift_pattern ///
	small_unit ///
	weekend ///
	out_of_hours ///
	beds_none ///
	age_c ///
	male ///
	periarrest ///
	sepsis1_b ///
	i.v_ccmds ///
	icnarc0_c ///
	i.v_ccmds


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

save ../data/scratch/scratch.dta, replace

*  ============================================
*  = Produce a model results table for thesis =
*  ============================================
* NOTE: 2013-02-28 - this includes the instruments
* NOTE: 2013-02-28 - this is a 2 level model:
* not (necesarily) directly translatable to propensity

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



// temporary file stop while coding output table
exit
// check vars in full *outcome* model
logistic dead28 $prvars
est store dead28
logistic early4 $prvars
est store prscore1



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