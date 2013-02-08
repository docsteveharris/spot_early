GenericSetupSteveHarris spot_early an_model_count_severity, logon

/*
Model the number of patients by ICNARC score decile per week

The aim here is to show that study quality factors are less important with sicker patients.
i.e. the data is most trust worthy for sicker patients

 Study factors
	- match quality that month
	- match quality overall for the site
	- study month
	- occupancy (mean per week)

- Site factors
	- hes_overnight
	- hes_los_mean
	- percent emergency admissions
	- cmp beds
	- ccot provision (shift pattern)

*/

/* First of all collapse the data and examine the distribution of assessments */


cap program drop count_severity
program count_severity
	// syntax varname , newslevel(integer 3)
	syntax varname [, category(integer 5)]

	global category `category'
	keep if `varlist' == $category
	cap drop v_week

	gen v_week = wofd(dofC(v_timestamp))
	label var v_week "Visit week"
	cap drop bedass

	cap drop new_patients
	gen new_patients = 1
	label var new_patients "New patients (per week)"

	collapse ///
		(count) vperweek = new_patients ///
		(firstnm) 	match_quality_by_site site_quality_by_month ///
					hes_overnight hes_emergx hes_los_mean ///
					cmp_beds_persite ccot_shift_pattern ///
					ccot_hrs_perweek ///
		(mean) free_beds_cmp beds_none full_active1 ///
		(min) studymonth visit_month ///
		, by(icode v_week)

	/* Now centre all your variables so the final intercept in the model is meaningful */
	replace hes_overnight = hes_overnight / 10000
	label var hes_overnight "Overnight hospital admissions (x 10,000)"
	local vars match_quality_by_site site_quality_by_month hes_overnight ///
		hes_emergx hes_los_mean cmp_beds_persite ///
		free_beds_cmp beds_none full_active1 studymonth

	foreach var of local vars {
		cap drop c_`var'
		qui su `var', meanonly
		gen c_`var' = `var' - r(mean)
	}
	cap drop c_ccot_hrs_perweek
	gen c_ccot_hrs_perweek = 168 - ccot_hrs_perweek

	su vperweek,d
	bys icode: egen vperweek_bar = mean(vperweek)

	tw hist vperweek, ///
		s(0) w(1) freq ///
		xscale(noextend) xlab(0(5)25) ///
		yscale(noextend) ylab(0(100)500, nogrid) ///
		ytitle("Study-site-weeks") ///
		xtitle("New bedside assessments", margin(medium)) ///
		title("Severity category $category")

	graph rename vperweek_severity$category, replace

	graph export ../logs/vperweek_severity$category.pdf, replace

	hist vperweek_bar, s(0) w(1) freq
	graph rename vperweek_bar, replace


	encode icode, gen(site)
	xtset site
	xtsum match_quality_by_site site_quality_by_month ///
		hes_overnight hes_emergx hes_los_mean ///
		cmp_beds_persite ccot_shift_pattern ///
		studymonth visit_month ///
		free_beds_cmp

	cap drop pickone_site
	egen pickone_site = tag(icode)

	* Baseline poisson model with no independent vars

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

		local site_vars match_quality_by_site ///
			hes_overnight hes_emergx hes_los_mean ///
			cmp_beds_persite ccot_hrs_perweek

		foreach var of local site_vars {
			su `var' if pickone_site
			running vperweek_bar `var' if pickone_site
			graph rename running_`var', replace
			xtmepoisson vperweek c_`var' ///
				|| icode:, covariance(unstructured) intpoints(30) irr nolog
			estat recovariance
			estimates store candidate
			estimates table noivars candidate, ///
				stats(N rank ll chi2 aic bic) ///
				b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
				eform newpanel
		}

		* Occupancy (CMP unit)
		foreach occ_var of varlist free_beds_cmp beds_none full_active1 {
			su `occ_var' , d
			running vperweek_bar `occ_var' if pickone_site
			graph rename running_`occ_var', replace
			xtmepoisson vperweek c_`occ_var' ///
				|| icode:, covariance(unstructured) intpoints(30) irr nolog
			estat recovariance
			estimates store candidate
			estimates table noivars candidate, ///
				stats(N rank ll chi2 aic bic) ///
				b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
				eform newpanel

		}


		local week_vars site_quality_by_month i.visit_month

		tabstat vperweek , by(site_quality_by_month) format(%9.3g)
		xtmepoisson vperweek c_site_quality_by_month ///
			|| icode:, covariance(unstructured) intpoints(30) irr nolog
		estat recovariance
		estimates store candidate
		estimates table noivars candidate, ///
			stats(N rank ll chi2 aic bic) ///
			b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
			eform newpanel

		* NOTE: 2013-01-19 - only check where a years worth of data available else selection effect
		cap drop studymonth_max
		bys icode: egen studymonth_max = max(studymonth)
		tab studymonth_max
		tabstat vperweek if studymonth_max >= 11 , by(studymonth)  format(%9.3g)
		xtmepoisson vperweek c_studymonth  ///
			|| icode: if studymonth_max >= 11 , covariance(unstructured) intpoints(30) irr nolog
		estat recovariance
		estimates store candidate
		estimates table noivars candidate, ///
			stats(N rank ll chi2 aic bic) ///
			b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
			eform newpanel

		tabstat vperweek , by(visit_month)  format(%9.3g)
		xtmepoisson vperweek i.visit_month ///
			|| icode:, covariance(unstructured) intpoints(30) irr nolog
		estat recovariance
		estimates store candidate
		estimates table noivars candidate, ///
			stats(N rank ll chi2 aic bic) ///
			b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
			eform newpanel

	}

	*  ===============
	*  = Final model =
	*  ===============
	use ../data/scratch/scratch.dta, clear

	noi su ///
		c_match_quality_by_site c_site_quality_by_month ///
		c_hes_overnight c_hes_emergx c_hes_los_mean ///
		c_cmp_beds_persite ///
		c_studymonth ///
		c_full_active1

	// CHANGED: 2013-01-18 - dropped studymonth from model as this is selection effect

	local all_final_vars ///
		c_match_quality_by_site c_site_quality_by_month ///
		c_hes_overnight c_hes_emergx c_hes_los_mean ///
		c_full_active1 ///
		i.visit_month ///
		ccot_hrs_perweek

	local final_vars ///
		c_match_quality_by_site c_site_quality_by_month ///
		c_hes_overnight c_hes_emergx ///
		c_full_active1 ///
		c_cmp_beds_persite ///
		ccot_hrs_perweek

	/*
	xtmepoisson vperweek `all_final_vars' ///
		|| icode:, covariance(unstructured) intpoints(30) irr nolog
	estat recovariance
	estimates store final
	estimates table noivars final, ///
		stats(N rank ll chi2 aic bic) ///
		b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
		eform newpanel
	*/

	// TODO: 2013-01-18 - discuss with Colin/David: underdispersion
	/*
	pp 395 of Rabe-Hesketh: recommend using the robust SE (sandwich estimator)
	- this means using gllamm
	*/

	local final_vars ///
		c_match_quality_by_site ///
		c_hes_overnight ///
		c_full_active1 ///
		c_cmp_beds_persite ///
		ccot_hrs_perweek

	global final_vars `final_vars'

	/*
	xtmepoisson vperweek $final_vars ///
		|| icode:, covariance(unstructured) intpoints(30) irr nolog
	estat recovariance
	estimates store final
	estimates table noivars final, ///
		stats(N rank ll chi2 aic bic) ///
		b(%9.3f) p(%9.3f) stfmt(%9.1g) ///
		eform newpanel
	*/

	cap drop cons
	gen cons = 1
	eq ri: cons
	gllamm vperweek $final_vars ///
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
Calculate this as below

*/
estimates drop _all
use ../data/working.dta, clear
qui include cr_preflight.do

local tiles 5
tab icnarc_q`tiles'

* CHANGED: 2013-01-22 - replace overnight with emergencies
* check if the parameterisation of emergencies is important - it isn't
* drop hes_overnight
* rename hes_emergencies hes_overnight

tempfile working1
save `working1', replace

local first_run  1
forvalues i = 1/`tiles' {
	use `working1', clear
	global catname "Severity percentile"
	qui count_severity icnarc_q`tiles' , category(`i')
	est store news`i'
	/*
	NOTE: 2013-01-22 - use e(chol) which returns Cholesky decomposition of variance matrix
	I think this contains the standard error so square it to get the level 1 variance
	*/
	matrix chol = e(chol)
	local 1 category`i'_var1
	global `1' = chol[1,1]^2
	di $`1'
	// NOTE: 2013-01-22 - now calculate the median IRR
	local 2 category`i'_medianIRR
	global `2' = exp(2^0.5 * $`1') * invnormal(3/4)
	di $`2'
	// NOTE: 2013-01-22 - now use parmest to store the estimates and the level 1 var
	tempfile temp1
	parmest , ///
		eform ///
		label list(parm label estimate min* max* p) ///
		format(estimate min* max* %8.3f p %8.3f) ///
		erows(chol) ///
		idnum(`i') idstr("$catname") ///
		saving(`temp1', replace)
	if `first_run' {
		use `temp1', clear
		save ../data/count_severity_cat_estimates.dta, replace
	}
	else {
		use ../data/count_severity_cat_estimates, clear
		append using `temp1'
		save ../data/count_severity_cat_estimates.dta, replace
	}
	local first_run 0
}

use ../data/count_severity_cat_estimates, clear
bys idnum (er_1_1): replace er_1_1 = er_1_1[1] if er_1_1 == .
replace er_1_1 = er_1_1^2
rename er_1_1 var_lvl2
gen medianIRR = exp(2^0.5 * var_lvl2) * invnormal(3/4)
format var_lvl2 medianIRR %9.3f
drop if eq == "sit1_1"
br idstr idnum parm estimate min95 max95 p var_lvl2 medianIRR
graph combine ///
	vperweek_severity10 ///
	 , rows(1) ///
	xcommon ycommon
save ../data/count_severity_cat_estimates.dta, replace

*  ====================================
*  = Now plot the estimates by decile =
*  ====================================

use ../data/count_severity_cat_estimates.dta, clear

foreach parm in $final_vars _cons {
	eclplot estimate min95 max95 idnum ///
		if parm == "`parm'" ///
		, horizontal ///
		estopts(msymbol(S)) ///
		xscale(noextend) ///
		xtitle("Incidence Rate Ratio") ///
		yscale(noextend noreverse) ylab(,nogrid) ///
		ytitle("Severity quintile") ///
		title("`parm'")
	graph rename irr_`parm', replace
}


tw ///
	(scatter var_lvl2 idnum if parm == "_cons" ///
		, msymbol(S))
graph rename var_lvl2_severity, replace

cap log close
