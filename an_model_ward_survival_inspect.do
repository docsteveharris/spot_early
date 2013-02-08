*  =========================================
*  = Basic inspection of survival outcomes =
*  =========================================

/*
Aim here is to build up a model of survival for ward patient
Use cox model
Allow for site level effects via frailty
*/

GenericSetupSteveHarris spot_early an_model_ward_survival_inspect, logon
* NOTE: 2013-01-29 - cr_survival.do stsets @ 28 days by default

local patient_vars age sex sepsis_b delayed_referral icnarc0
local timing_vars out_of_hours weekend i.bed_pressure
local site_vars ///
	referrals_permonth ///
	ib3.ccot_shift_pattern ///
	ibn.hes_overnight_k ///
	ibn.hes_emergx_k ///
	cmp_beds_max

*  ==========================
*  = Check for co-linearity =
*  ==========================

// Pre model checks: check collinearity between the variables
use ../data/working_postflight.dta, clear
/*
Variance inflation factor - need a linear regression model to do this in stata
So use ICU free survival as a proxy outcome
*/
su icufree_days

regress `patient_vars' `timing_vars' `site_vars'
estat vif
/*
NOTE: 2013-01-31 - so using cmp_beds_peradmx ... some signicant co-linearity
which is much improved if just use cmp_beds_max
*/


*  ======================================================
*  = Inspect functional forms with respect to mortality =
*  ======================================================

* ICNARC score
use ../data/working_postflight.dta, clear

egen icnarc0_k20 = cut(icnarc0), at(0(2)100)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	if icnarc0 <= 50 ///
	, by(icnarc0_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n icnarc0_k20, ///
		barwidth(1) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 icnarc0_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar icnarc0_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("ICNARC Acute Physiology Score", margin(medium)) ///
	xlabel(0(10)50) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_icnarc0, replace
graph export ../outputs/figures/dead28_vs_icnarc0.pdf, replace

* NEWS score
use ../data/working_postflight.dta, clear
egen news_k20 = cut(news_score), at(0(1)20)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	, by(news_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n news_k20, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 news_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar news_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("NHS Early Warning Score", margin(medium)) ///
	xlabel(0(5)20) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_news, replace
graph export ../outputs/figures/dead28_vs_news.pdf, replace

* SOFA score
use ../data/working_postflight.dta, clear
egen sofa_k20 = cut(sofa_score), at(0(1)24)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	, by(sofa_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n sofa_k20, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 sofa_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar sofa_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("SOFA (Sepsis-related Organ Failure Assessment) score", margin(medium)) ///
	xlabel(0(4)16) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_sofa, replace
graph export ../outputs/figures/dead28_vs_sofa.pdf, replace

* Export this as figure in the thesis
graph combine dead28_vs_news dead28_vs_sofa dead28_vs_icnarc0, ///
	ycommon cols(1) ysize(12) xsize(6)
graph export ../outputs/figures/dead28_vs_severity_all.pdf, replace

* Now other continuous vars
* Age
use ../data/working_postflight.dta, clear
egen age_k20 = cut(age), at(18 25(5)95 105)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	, by(age_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n age_k20, ///
		barwidth(2) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 age_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar age_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("Age (years)", margin(medium)) ///
	xlabel(18 30(10)90 104) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_age, replace
graph export ../outputs/figures/dead28_vs_age.pdf, replace

* Now other continuous vars
* cmp_beds_max
use ../data/working_postflight.dta, clear
egen cmp_beds_k20 = cut(cmp_beds_max), at(5(5)65)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	, by(cmp_beds_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n cmp_beds_k20, ///
		barwidth(2) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 cmp_beds_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar cmp_beds_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("Critical care beds", margin(medium)) ///
	xlabel(5(5)65) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_cmp_beds, replace
graph export ../outputs/figures/dead28_vs_cmp_beds.pdf, replace

* CCOT hours per week
use ../data/working_postflight.dta, clear
egen ccot_hrs_perweek_k20 = cut(ccot_hrs_perweek), at(0(12)180)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	, by(ccot_hrs_perweek_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n ccot_hrs_perweek_k20, ///
		barwidth(2) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 ccot_hrs_perweek_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar ccot_hrs_perweek_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("CCOT hours per week", margin(medium)) ///
	xlabel(0(12)168) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_ccot_hrs_perweek, replace
graph export ../outputs/figures/dead28_vs_ccot_hrs_perweek.pdf, replace

* Patients review per week
use ../data/working_postflight.dta, clear
egen referrals_permonth_k20 = cut(referrals_permonth), at(0(10)150 200)

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	, by(referrals_permonth_k20)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n referrals_permonth_k20, ///
		barwidth(5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 referrals_permonth_k20 if n > 10, yaxis(2)) ///
	(scatter dead28_bar referrals_permonth_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("New ward referrals to critical care (per month)", margin(medium)) ///
	xlabel(0(10)150) ///
	xscale(noextend) ///
	legend(off)

graph rename dead28_vs_referrals_permonth, replace
graph export ../outputs/figures/dead28_vs_referrals_permonth.pdf, replace
exit

*  ===========================================
*  = Now check for time-dependence of hazard =
*  ===========================================
local clean_run 0
if `clean_run' == 1 {
	include cr_survival.do
}

use ../data/working_survival.dta, clear
sts list, at(0/28)
sts graph
count if ppsample
stci, p(25)
sts graph, hazard ci ///
	ciopts(color(gs12)) ///
	tscale(noextend) ///
	tlabel(0(7)28) ///
	ttitle("Days following bedside assessment", margin(medium)) ///
	yscale(noextend) ///
	ylabel( ///
		0.000 "0" ///
		0.010 "10" ///
		0.020 "20" ///
		0.030 "30" ///
		0.040 "40" ///
		0.050 "50" ///
		, nogrid) ///
	ytitle("Deaths" "(per 1000 patients per day)", margin(medium)) ///
	legend(off) ///
	title("Mortality rate") ///
	xsize(6) ysize(6)
graph rename hazard_all, replace

sts graph, surv ci ///
	ciopts(color(gs12)) ///
	plotopts(lwidth(thin)) ///
	tscale(noextend) ///
	tlabel(0(7)28) ///
	ttitle("Days following bedside assessment", margin(medium)) ///
	yscale(noextend) ///
	ylabel( ///
		0 	"0" ///
		.25 "25%" ///
		.5 	"50%" ///
		.75 "75%" ///
		1 	"100%" ///
		, nogrid) ///
	ytitle("Survival" "(percentage)", margin(medium)) ///
	legend(off) ///
	title("Survival curve") ///
	xsize(6) ysize(6)
graph rename survival_all, replace
graph combine hazard_all survival_all, rows(1) ysize(4) xsize(6)
graph export ../outputs/figures/hazard_and_survival_all.pdf, replace




*  =================
*  = Patient level =
*  =================


cap program drop bashazard_by_univariate
program define bashazard_by_univariate
	syntax varname(min=1 max=1), ///
		[ ///
		title(string asis) ///
		legend_label(string asis) ///
		ylabel(string asis) ///
		]

	if `"`ylabel'"' == "" {
		local ylabel ///
				0.000 "0" ///
				0.010 "10" ///
				0.020 "20" ///
				0.030 "30" ///
				0.040 "40" ///
				0.050 "50"
	}

	sts graph, hazard noshow ///
		by(`varlist') ///
		ciopts(color(gs14)) ///
		tscale(noextend) ///
		tlabel(0(7)28) ///
		ttitle("Days following bedside assessment", margin(medium)) ///
		yscale(noextend) ///
		ylabel( ///
			`ylabel' ///
			, nogrid) ///
		ytitle("Deaths" "(per 1000 patients per day)", margin(medium)) ///
		legend(pos(2) ring(0) ///
			size(small) ///
			`legend_label' ///
			) ///
		title(`title', size(medium)) ///
		xsize(6) ysize(6)

end


* Age
su age if ppsample
cap drop age_cat
egen age_cat = cut(age), at(18 40 60 80 120) icodes
tab age_cat if ppsample
local legend_label ///
	label(1 "18-39 yrs") ///
	label(2 "40-59 yrs") ///
	label(3 "60-79 yrs") ///
	label(4 "80+ yrs") 
bashazard_by_univariate age_cat , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_age, replace
* NOTE: 2013-01-30 - difference sustained

* Sex
local legend_label ///
	label(1 "Female") ///
	label(2 "Male")

bashazard_by_univariate sex , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_sex, replace

* Sepsis
local legend_label ///
	label(1 "Unlikely") ///
	label(2 "Likely")

bashazard_by_univariate sepsis_b , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_sepsis, replace
* NOTE: 2013-01-30 - early difference not sustained

* Severity of illness
local legend_label ///
	label(1 "1st quartile") ///
	label(2 "2nd quartile") ///
	label(3 "3rd quartile") ///
	label(4 "4th quartile")

local ylabel ///
			0.000 "0" ///
			0.010 "10" ///
			0.020 "20" ///
			0.030 "30" ///
			0.040 "40" ///
			0.050 "50" ///
			0.060 "60" ///
			0.070 "70"

bashazard_by_univariate icnarc_q4 , title("") ///
	legend_label(`legend_label') ylabel(`ylabel')
graph rename baseline_hazard_by_icnarc_q4, replace
* NOTE: 2013-01-30 - early difference tails off but more slowly

* CCOT on
local legend_label ///
	label(1 "CCOT out-of-hours") ///
	label(2 "CCOT hours")

bashazard_by_univariate ccot_on , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_ccot_on, replace

* CCOT shift start
local legend_label ///
	label(1 "Baseline") ///
	label(2 "CCOT shift start")

bashazard_by_univariate ccot_shift_start , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_ccot_start, replace

* Weekend
local legend_label ///
	label(1 "Weekday") ///
	label(2 "Weekend")

bashazard_by_univariate weekend , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_weekend, replace

* Office hours
local legend_label ///
	label(1 "Out-of-hours") ///
	label(2 "Office hours")

bashazard_by_univariate out_of_hours , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_out_of_hours, replace

* Critical care unit - no active beds
tab beds_none if ppsample
local legend_label ///
	label(1 "Available beds") ///
	label(2 "No available beds")

bashazard_by_univariate beds_none , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_beds_none, replace
graph export ../outputs/figures/baseline_hazard_by_beds_none.pdf, replace


*  ==============
*  = Site level =
*  ==============

* CCOT shift pattern
local legend_label ///
	label(1 "No CCOT") ///
	label(2 "< 7/7") ///
	label(3 "7/7") ///
	label(4 "24/7")

bashazard_by_univariate ccot_shift_pattern , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_ccot_shift, replace

* HES overnight admissions
su hes_overnight if ppsample
cap drop hes_overnight_cat
egen hes_overnight_cat = cut(hes_overnight), at(0 50 100 200)

local legend_label ///
	label(1 "<50k / yr") ///
	label(2 "50-100k / yr") ///
	label(3 ">100k / yr")

bashazard_by_univariate hes_overnight_cat , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_hes_overnight, replace

* HES emergencies
su hes_emergx if ppsample
cap drop hes_emergx_cat
xtile hes_emergx_cat = hes_emergx, nq(3)

local legend_label ///
	label(1 "1st tertile") ///
	label(2 "2nd tertile") ///
	label(3 "3rd tertile")

bashazard_by_univariate hes_emergx_cat , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_hes_emergx, replace

* CMP beds max
su cmp_beds_max if ppsample
cap drop cmp_beds_max_cat
xtile cmp_beds_max_cat = cmp_beds_max, nq(3)

local legend_label ///
	label(1 "1st tertile") ///
	label(2 "2nd tertile") ///
	label(3 "3rd tertile")

bashazard_by_univariate cmp_beds_max_cat , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_cmp_beds_max, replace

* spotlight visits per hes admission
su patients_perhesadmx if ppsample
cap drop patients_perhesadmx_cat
xtile patients_perhesadmx_cat = patients_perhesadmx, nq(3)

local legend_label ///
	label(1 "1st tertile") ///
	label(2 "2nd tertile") ///
	label(3 "3rd tertile")

bashazard_by_univariate patients_perhesadmx_cat , title("") ///
	legend_label(`legend_label')
graph rename baseline_hazard_by_spot_pts, replace

graph dir


exit

