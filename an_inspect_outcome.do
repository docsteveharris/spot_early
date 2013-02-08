*  ==================================
*  = Inspect wrt to death at day 28 =
*  ==================================


GenericSetupSteveHarris spot_ward an_inspect_outcome.do

*  =====================
*  = Set up local vars =
*  =====================
use ../data/working.dta, clear

gen time2icu = floor(hours(icu_admit - v_timestamp))
replace time2icu = 0 if time2icu < 0
label var time2icu "Time to ICU (hrs)"

gen male=sex==2
gen sepsis_b = inlist(sepsis,3,4)
gen rxlimits = inlist(v_disposal,4,7)
label var rxlimits "Treatment limits at visit end"
gen dead28 = (date_trace - dofc(v_timestamp) <= 28 & dead)
label var dead28 "28d mortality"

*  =======================================
*  = xtab recommended ccmds and disposal =
*  =======================================
gen icu_ever = time2icu != .
tab rxlimits icu_ever
tab v_disp v_ccmds_rec, m

tab v_disp v_ccmds_rec if !rxlimits, m


local inspect_cont_vars = 0
if `inspect_cont_vars' {
	local cont_vars age icnarc_score news_score sofa_score lactate
	foreach var of local cont_vars {
		running dead28 `var', ///
			plot(hist `var', percent bin(20) yaxis(2) /// 
				yscale(axis(2) range(0 50)) ///
				ylabel(0(10)50, axis(2)) ///
				ytitle("% of sample",axis(2))) ///
				name(running_28d_`var', replace)
		graph export ../logs/running_28d_`var'.pdf, replace
	}
}

xtile icnarc_q10 = icnarc_score, nq(10)


*  ============================
*  = Very rough working model =
*  ============================
logistic dead28 male sepsis_b rxlimits age ib(freq).icnarc_q10
