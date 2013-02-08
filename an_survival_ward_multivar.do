*  ==================================
*  = Build final multivariate model =
*  ==================================

/*
Aim here is to build up a model of survival for ward patient
Use cox model
Allow for site level effects via frailty

Steps
- univariate: inspect relationship with survival
	- produce figures
	- produce a summary table


*/

GenericSetupSteveHarris spot_early an_survival_ward, logon
* NOTE: 2013-01-29 - cr_survival.do stsets @ 28 days by default
qui include cr_survival.do
sts list, at(0/28)



local graphics_on = 0
if `graphics_on' {
	label var _d "analysis time (days)"
	* Comparison of outcomes at baseline - 'admissions' only
	sts graph, by(delay4) ///
		title("4h cutpoint", size(med)) ///
		legend(pos(6) size(small) row(1)) name(km_at_delay4, replace) ///
		risktable(0 7 14 21 28, order(1 "Early" 2 "Delayed") size(small) righttitles)

		* Comparison of outcomes at baseline without stratification
	sts graph, by(defer4)  ///
		title("4h cutpoint", size(med)) ///
		legend(pos(6) size(small) row(1)) name(km_at_icu4, replace) ///
		risktable(0 7 14 21 28, order(1 "Early" 2 "Deferred") size(small) righttitles)

	graph combine km_at_delay4 km_at_icu4, col(1) ysize(4) xsize(3) xcommon ycommon
	graph export ../logs/km_delay_vs_defer.pdf, replace
}

local graphics_on = 0
if `graphics_on' {

	forvalues i = 1/4 {
		sts graph if icnarc_q4 == `i', by(defer4) ///
			title("Early vs deferred: ICNARC q`i'", size(med)) ///
			legend(pos(3) size(small) col(1)) name(km`i', replace)
	}
	graph combine km1 km2 km3 km4, col(1) ysize(6) xsize(3) xcommon ycommon
	graph export ../logs/km_e_vs_d_by_icnarc_q4.pdf, replace
}


local graphics_on = 0
*  =================================================
*  = Now inspect survival at different time points =
*  =================================================
* repeatedly reset the origin for analysis time and hence examine a different risk set
* understand how many deaths are being excluded by moving the origin forward
local origins 0 1 2 3 7
sts list, at(`origins')
foreach origin of local origins {
	noi di as result "=========================="
	noi di as result "= Time origin = `origin' ="
	noi di as result "=========================="

	cap drop dt_origin
	gen dt_origin = dt0 + `origin'
	stset dt1, id(id) origin(dt_origin) failure(dead) exit(time dt0+30)

	cap drop icu_dose
	cap drop icu_future
	cap drop icu_past
	cap drop time2icu_cat

	gen icu_dose = (icu_admit - cofd(dt_origin)) / msofhours(1)
	replace icu_dose = 0 if icu_dose < 0 | icu_admit == .

	gen icu_future = .
	replace icu_future = 1 if time2icu / 24 > `origin' & ppsample & !missing(time2icu)
	tab icu_future if ppsample

	gen icu_past = .
	replace icu_past = 0 if (time2icu / 24 > `origin' | missing(time2icu)) & ppsample
	replace icu_past = 1 if time2icu / 24 <= `origin' & ppsample & !missing(time2icu)
	tab icu_past

	cap drop dead_already
	gen dead_already = dead & dt1 < dt_origin
	tab dead_already icu_past if ppsample

	sum icu_dose if icu_past == 1 & ppsample

	egen time2icu_cat = cut(time2icu), at(0,4,12,24,36,72,168,672) label
	replace time2icu_cat = 999 if time2icu == .
	replace time2icu_cat = 999 if time2icu / 24 > `origin'
	tab time2icu_cat if ppsample & _st == 1
	sts list, at(0 1 2 3 7 14 21 28) by(time2icu_cat) compare
	stcox male sepsis_b rxlimits age ib1.icnarc_q10 ib(first).time2icu_cat

	if `graphics_on' {
		sts graph, by(time2icu_cat) ///
			 legend(pos(3) size(small) col(1)) name(km_`origin', replace) ///
			 scheme(tufte_color)
	}


}


cap log close
exit


