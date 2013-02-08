GenericSetupSteveHarris spot_early an_model_count_news_risk, logon

/*


Model the number of NEWS high risk assessments per week

NOTE: 2013-02-04 - do not include this in the principal model ... use for sensitivity
- Study factors
	- match quality that month
	- match quality overall for the site
	- study month

- timing
	- beds_none
	- out_of_hours
	- weekend

- Site factors
	- referrals_permonth_c
	- ccot_shift_pattern
	- hes_overnight_c
	- hes_emergx_c
	- cmp_beds_max_c

- patient factors: cannot include

Then repeat the process for medium and low risk assessments.
Estimate separately the IRR for each
Show that high risk is relatively constant across sites but that low risk varies
And that its variation is strongly influences by pattern of CCOT provision
*/

/* First of all collapse the data and examine the distribution of assessments */

global ivars ///
	beds_none out_of_hours weekend ///
	referrals_permonth_c ccot_shift_pattern hes_overnight_c ///
	hes_emergx_c cmp_beds_max_c

global ivars_4model ///
	beds_none out_of_hours weekend ///
	referrals_permonth_c ib3.ccot_shift_pattern hes_overnight_c ///
	hes_emergx_c cmp_beds_max_c

global ivars_site_level ///
	referrals_permonth_c ccot_shift_pattern hes_overnight_c ///
	hes_emergx_c cmp_beds_max_c

global ivars_week_level ///
	beds_none out_of_hours weekend


cap program drop count_news_risk
program count_news_risk
	// syntax varname , newslevel(integer 3)
	syntax varname [, newslevel(integer 3)]

	global newslevel `newslevel'
	keep if `varlist' == $newslevel
	cap drop v_week

	gen v_week = wofd(dofC(v_timestamp))
	label var v_week "Visit week"
	cap drop bedass

	cap drop new_patients
	gen new_patients = 1
	label var new_patients "New patients (per week)"

	collapse ///
		(count) vperweek = new_patients ///
		(firstnm) $ivars_site_level ///
		(mean) $ivars_week_level ///
		(min) studymonth visit_month ///
		, by(icode v_week)

	/* Now centre all your variables so the final intercept in the model is meaningful */
	// CHANGED: 2013-02-04 - this is all done in preflight

	foreach var of global ivars {
		cap drop c_`var'
		qui su `var', meanonly
		gen c_`var' = `var' - r(mean)
	}

	su vperweek,d
	bys icode: egen vperweek_bar = mean(vperweek)
	if $newslevel == 1 local ttitle National Early Warning Score - Low risk
	if $newslevel == 2 local ttitle National Early Warning Score - Medium risk
	if $newslevel == 3 local ttitle National Early Warning Score - High risk
	tw hist vperweek, ///
		s(0) w(1) freq ///
		xscale(noextend) xlab(0(5)20) ///
		yscale(noextend) ylab(0(100)400, nogrid) ///
		ytitle("Study-site-weeks") ///
		xtitle("New bedside assessments", margin(medium)) ///
		title("`ttitle'")

	graph rename vperweek_risk$newslevel, replace

	// quick inspect the distribution of incidence
	graph export ../logs/vperweek_bar_risk$newslevel.pdf, replace

	hist vperweek_bar, s(0) w(1) freq
	graph rename vperweek_bar, replace


	encode icode, gen(site)
	xtset site
	xtsum $ivars

	cap drop pickone_site
	egen pickone_site = tag(icode)

	// Baseline poisson model with no independent vars

	xtmepoisson vperweek || icode:, covariance(unstructured) intpoints(30) irr nolog
	estimates store noivars
	estimates table noivars, stats(N rank ll chi2 aic bic) b(%9.3f) p(%9.3f) stfmt(%9.1g) eform newpanel

	save ../data/scratch/scratch.dta, replace


	*  =======================
	*  = Start analysis here =
	*  =======================

	* Switch to turn off univariate inspection step when running through NEWS risk cats
	global inspect_univariate 0
	if $inspect_univariate {

		use ../data/scratch/scratch.dta, clear

		local cat_vars ccot_shift_pattern
		tabstat vperweek_bar if pickone_site, by(ccot_shift_pattern) format(%9.3g)
		xtmepoisson vperweek ib3.ccot_shift_pattern ///
			|| icode:, covariance(unstructured) intpoints(30) irr nolog
		estat recovariance
		estimates store candidate
		estimates table noivars candidate, ///
			stats(N rank ll chi2 aic bic) ///
			b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
			eform newpanel

		foreach var of global ivars_site_level {
			su `var' if pickone_site
			running vperweek_bar `var' if pickone_site
			graph rename running_`var', replace
			xtmepoisson vperweek `var' ///
				|| icode:, covariance(unstructured) intpoints(30) irr nolog
			estat recovariance
			estimates store candidate
			estimates table noivars candidate, ///
				stats(N rank ll chi2 aic bic) ///
				b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
				eform newpanel
		}

		foreach var of global ivars_week_level {
			tabstat vperweek , by(`var') format(%9.3g)
			xtmepoisson vperweek `var' ///
				|| icode:, covariance(unstructured) intpoints(30) irr nolog
			estat recovariance
			estimates store candidate
			estimates table noivars candidate, ///
				stats(N rank ll chi2 aic bic) ///
				b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
				eform newpanel
		}

	}

	*  ===============
	*  = Final model =
	*  ===============
	use ../data/scratch/scratch.dta, clear


	* TODO: 2013-01-18 - discuss with Colin/David: underdispersion
	/*
	pp 395 of Rabe-Hesketh: recommend using the robust SE (sandwich estimator)
	- this means using gllamm
	*/
	//NOTE: 2013-01-18 - gllamm does not like factor variables
	//so expand up your ccot_shift_pattern (leaving 24/7 as the reference)
	//which is why ccot_p_4 does not appear in the ivars list
	cap drop ccot_p_*
	tabulate ccot_shift_pattern, generate(ccot_p_)
	su ccot_p_*
	local toremove ib3.ccot_shift_pattern
	local ivars $ivars_4model
	local ivars: list ivars - toremove
	local ivars `ivars' ccot_p_1 ccot_p_2 ccot_p_3
	// di "`ivars'"
	cap drop cons
	gen cons = 1
	eq ri: cons
	gllamm vperweek `ivars' ///
		, family(poisson) link(log) i(site) eqs(ri) eform dots nolog
	estimates store gllamm_final
	estimates table noivars , ///
		stats(N rank ll chi2 aic bic) ///
		b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
		eform newpanel

	noisily gllamm, robust eform

end

* NOTE: 2013-01-22
/*
- see nv://find/%23%23%20Mixed%20models/?SN=298408755fdd11e2a973a9fa776b92bb&NV=UjveXJTJRWC%2BUBNCGx7Ybg%3D%3D
No equivalent of ICC in Poisson models
... best alternative is median IRR for two indiviudals sharing the same covariates
Calculate this as

*/

estimates drop _all
use ../data/working.dta, clear
qui include cr_preflight.do
tab news_risk
tempfile working1
save `working1', replace

local first_run  1
forvalues i = 3/3 {
	use `working1', clear
	// Run your model using count_news_risk prog
	qui count_news_risk news_risk , newslevel(`i')
	est store news`i'
	/*
	NOTE: 2013-01-22 - use e(chol) which returns Cholesky decomposition of variance matrix
	I think this contains the standard error so square it to get the level 1 variance
	CHANGED: 2013-02-04 - now all done by parmest
	matrix chol = e(chol)
	local 1 news_risk`i'_var1
	global `1' = chol[1,1]^2
	di $`1'
	// NOTE: 2013-01-22 - now calculate the median IRR
	local 2 news_risk`i'_medianIRR
	global `2' = exp(2^0.5 * $`1') * invnormal(3/4)
	di $`2'
	*/
	// NOTE: 2013-01-22 - now use parmest to store the estimates and the level 1 var
	tempfile temp1
	parmest , ///
		eform ///
		label list(parm label estimate min* max* p) ///
		format(estimate min* max* %8.3f p %8.3f) ///
		erows(chol) ///
		idnum(`i') idstr("NEWS risk") ///
		saving(`temp1', replace)
	if `first_run' {
		use `temp1', clear
		save ../data/count_news_risk_estimates.dta, replace
	}
	else {
		use ../data/count_news_risk_estimates, clear
		append using `temp1'
		save ../data/count_news_risk_estimates.dta, replace
	}
	local first_run 0
}

use ../data/count_news_risk_estimates.dta, clear
// Sort out the Cholesky decomposition matrix
bys idnum (er_1_1): replace er_1_1 = er_1_1[1] if er_1_1 == .
replace er_1_1 = er_1_1^2
rename er_1_1 var_lvl2
gen medianIRR = exp(2^0.5 * var_lvl2) * invnormal(3/4)
format var_lvl2 medianIRR %9.3f
drop if eq == "sit1_1"
br idstr idnum parm estimate min95 max95 p var_lvl2 medianIRR
cap graph combine vperweek_risk1 vperweek_risk2 vperweek_risk3, rows(1) ///
	xcommon ycommon
save ../data/count_news_risk_estimates.dta, replace


*  ==================================
*  = Now produce a table of results =
*  ==================================
use ../data/count_news_risk_estimates.dta, clear
* store level 2 variance as local macro
* Level 2 variance
sdecode var_lvl2, format(%9.3fc) replace
global var_lvl2 = var_lvl2[1]

local n = _N + 1
set obs `n'
replace parm = "ccot_p_4" if parm == ""
cap drop varname
gen varname = parm
replace varname = substr(parm, 1, length(parm) - 2) if substr(parm, -2, 2) == "_c"
replace varname = "ccot_shift_pattern" if substr(parm, 1, 6) == "ccot_p"
cap drop var_level
gen var_level = substr(parm, -1, 1) if substr(parm, 1, 6) == "ccot_p"
destring var_level, replace

local table_order hes_overnight hes_emergx cmp_beds_max ccot_shift_pattern ///
	 referrals_permonth out_of_hours weekend beds_none _cons
cap drop table_order
gen table_order = .
local i = 1
foreach var of local table_order {
	replace table_order = `i' if varname == "`var'"
	local ++i
}

cap drop var_level_lab
gen var_level_lab = ""
* CCOT shift pattern
replace var_level_lab = "No CCOT" if varname == "ccot_shift_pattern" & var_level == 1
replace var_level_lab = "Less than 7 days" if varname == "ccot_shift_pattern" & var_level == 2
replace var_level_lab = "7 days / week" if varname == "ccot_shift_pattern" & var_level == 3
replace var_level_lab = "24 hrs / 7 days" if varname == "ccot_shift_pattern" & var_level == 4

sdecode estimate, format(%9.3fc) gen(est)
replace est = "--" if est == ""
sdecode min95, format(%9.3fc) replace
sdecode max95, format(%9.3fc) replace
sdecode p, format(%9.3fc) replace
replace p = "<0.001" if p == "0.000"
gen est_ci95 = "(" + min95 + "--" + max95 + ")" if !missing(min95, max95)

* user written command to label vars
spot_label_table_vars
sort table_order var_level
order table_order tablerowlabel var_level_lab unitlabel est est_ci95 p

ingap 4
replace tablerowlabel = "CCOT shift pattern" if _n == 4
* now format the table
replace tablerowlabel = var_level_lab if !missing(var_level_lab)
replace tablerowlabel =  "\hspace*{1em}{" + tablerowlabel + "}" ///
	if missing(var_level_lab)
replace tablerowlabel =  "\hspace*{2em}\smaller[0]{" + tablerowlabel + "}" ///
	if !missing(var_level_lab)

ingap 1 10 13
replace tablerowlabel = "\textit{Site factors}" if _n == 1
replace tablerowlabel = "\textit{Timing factors}" if _n == 11
replace tablerowlabel = "\textit{Baseline incidence rate}" if parm == "_cons"

* now write the table to latex
local cols tablerowlabel est est_ci95 p
order `cols'

local h1 "Parameter & IRR & (95\% CI) & p \\ "
local justify X[5l] X[1l] X[2l] X[1r]
local tablefontsize "\footnotesize"
local arraystretch 1.1
local taburowcolors 2{white .. white}
local table_name incidence_news_risk_high
local f1 "Site level variance & \multicolumn{3}{l}{$var_lvl2} \\"

listtab `cols' ///
	using ../outputs/tables/`table_name'.tex, ///
	replace rstyle(tabular) ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\sffamily{" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\midrule" ///
		"`f1'" ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{`table_name'_best} " ///
		"\normalfont" ///
		"\normalsize")


di as result "Created and exported `table_name'"

cap log close


