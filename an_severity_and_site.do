*  ================================================================
*  = Inter-site variation and severity of illness of ward patient =
*  ================================================================

GenericSetupSteveHarris spot_early an_severity_and_site, logon


use ../data/working.dta, clear
include cr_preflight.do
save ../data/scratch/scratch.dta, replace

*  ===========================================
*  = Components of severity of illness table =
*  ===========================================

tabstat age, s(n mean sd min q max) format(%9.3g) col(s) longstub

global aps_convars hrate bpsys bpmap lactate ph ///
	temperature ///
 	spo2 rrate fio2_std pf_ratio sf_ratio ///
 	uvol1h urea creatinine sodium ///
 	wcc gcst bili platelets ///
 	icnarc_score ///
 	sofa_score ///
 	news_score
tabstat $aps_convars, s(n mean sd min q max) format(%9.3g) col(s) longstub

global aps_catvars sex v_ccmds v_timely v_arrest ///
	sepsis2001 sepsis ///
	rxrrt gcst hsinus avpu rxcvs_sofa vitals

foreach var of global aps_catvars {
	tab `var'
}


*  ====================================================
*  = Examine distribution of major physiology by site =
*  ====================================================

global cont_vars hrate bpsys lactate spo2 rrate pf_ratio creatinine sodium ///
	platelets icnarc_score sofa_score news_score
local cont_vars $cont_vars

foreach cont_var of local cont_vars {

	use ../data/scratch/scratch, clear
	gen ccot_intensity = inlist(ccot_shift_pattern,2,3)
	label define intensity 0 "Low" 1 "High"
	label values ccot_intensity intensity
	tab ccot_intensity

	local byvar2 ccot_intensity

	if "`byvar2'" == "ccot_intensity" {
		local byvar2_legend_code label(1 "Low intensity CCOT") label(3 "High intensity CCOT")
	}


	/* List of variables being inspected */

	if "`cont_var'" == "hrate" {
		local ytitle "Heart rate"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "bpsys" {
		local ytitle "Systolic BP"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "lactate" {
		local ytitle "Lactate"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "spo2" {
		local ytitle "Oxygen Saturation"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "rrate" {
		local ytitle "Respiratory rate"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "pf_ratio" {
		local ytitle "P:F ratio"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "creatinine" {
		local ytitle "Creatinine"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "sodium" {
		replace sodium = . if sodium > 145
		// NOTE: 2013-01-14 - only inspect low sodiums else median doesn't make sense
		local ytitle "Sodium"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "platelets" {
		local ytitle "Platelets"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "bili" {
		local ytitle "Bilirubin"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "icnarc_score" {
		local ytitle "ICNARC APS score"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "sofa_score" {
		local ytitle "SOFA score"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}
	if "`cont_var'" == "news_score" {
		local ytitle "NEWS score"
		local xtitle2 "ordered by median `ytitle' at time of bedside assessment"
	}


	gen pts_percat = 1
	collapse (firstnm) dorisname (sum) pts_percat  ///
		(firstnm) `byvar2' ///
		(median) `cont_var'_p50 = `cont_var' ///
		(p25) `cont_var'_p25 = `cont_var' ///
		(p75) `cont_var'_p75 = `cont_var' ///
		, by(icode)


	/*
	NOTE: 2013-01-14 - drop small cells where pts_percat < 10
	So where there are very few patients seen at this site at this time or shift then don't show as numbers not meaningful
	CHANGED: 2013-01-14 - no longer should be an issue as you should only classify by site
	drop if pts_percat <= 10
	tab `byvar2'
	label values `byvar2' intensity
	*/

	sort `cont_var'_p50
	cap drop x_order
	gen x_order = _n

	tw 	///
		(rbar `cont_var'_p25 `cont_var'_p75 x_order if `byvar2' == 0, ///
		 	color(gs12) lpattern(blank)) ///
		(scatter `cont_var'_p50 x_order if `byvar2' == 0, ///
		 	color(black) msymbol(+)) ///
		(rbar `cont_var'_p25 `cont_var'_p75 x_order if `byvar2' == 1, ///
		 	color(gs6) lpattern(blank)) ///
		(scatter `cont_var'_p50 x_order if `byvar2' == 1, ///
		 	color(black) msymbol(+)) ///
		,ylabel(, nogrid) ///
		xscale(noextend) xlabel(minmax) ///
		xtitle("All referrals sites" ///
				"(`xtitle2')") ///
		yscale(noextend) ///
		ytitle("`ytitle'") ///
		legend( ///
			order(1 3) ///
			`byvar2_legend_code' ///
			size(small) ///
			symxsize(1) symysize(3) ///
			region(lpattern(solid) lwidth(vvthin) lcolor(black)) ///
			position(10) ring(0))

	graph rename `cont_var'_bysite, replace
	graph export ../logs/`cont_var'.pdf, replace

}

*  ==================================================
*  = Inspect differences with respect to ccot_shift =
*  ==================================================

/*
Manually set byvar2 below depending on the comparison you wish to make
Candidate variables
- ccot_on
- ccot_shift_early
*/
global byvar2 ccot_shift_early

use ../data/scratch/scratch, clear
local byvar2 $byvar2

/* First inspect to see what is not normal */
local cont_vars hrate bpsys lactate spo2 rrate pf_ratio creatinine sodium ///
	platelets icnarc_score sofa_score news_score
tabstat `cont_vars', s(n mean sd skew kurt) format(%9.3g) col(s) longstub


/* first inspect the normal vars */
local norm_vars hrate bpsys rrate sodium icnarc_score sofa_score news_score
tempname pname
tempfile pfile
* NOTE: 2013-01-14 - dummy0 and 1 exist so that table width matches that of skew vars
postfile `pname' str16 varname n0 mean0 sd0 str2 dummy0 n1 mean1 sd1 str2 dummy1  p using `pfile' , replace

foreach var of local norm_vars {
	ttest `var', by(`byvar2')
	post `pname' ("`var'") (r(N_1)) (r(mu_1)) (r(sd_2)) ("") (r(N_2)) (r(mu_2)) (r(sd_2)) ("") (r(p))
}

postclose `pname'
use `pfile', clear
br

/* now inspect the skewed vars */
use ../data/scratch/scratch, clear
local byvar2 $byvar2
local skew_vars lactate spo2 pf_ratio creatinine platelets

tempname pname
tempfile pfile
postfile `pname' str16 varname n0 median0 p0_25 p0_75 n1 median1 p1_25 p1_75 p ///
	using `pfile' , replace

foreach var of local skew_vars {
	forvalues i = 0/1 {
		su `var' if `byvar2' == `i', detail
		local n`i' = r(N)
		local median`i' = r(p50)
		local p`i'_25 = r(p25)
		local p`i'_75 = r(p75)
	}
	ranksum `var', by(`byvar2')
	local p = normalden(r(z))
	di `"`pname' ("`var'") (`n0') (`median0') (`p0_25') (`p0_75') (`n1') (`median1') (`p1_25') (`p1_75') (`p') "'
	post `pname' ("`var'") (`n0') (`median0') (`p0_25') (`p0_75') (`n1') (`median1') (`p1_25') (`p1_75') (`p') 
}

postclose `pname'
use `pfile', clear
br


cap log close
