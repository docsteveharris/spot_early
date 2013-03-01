*  ==================================================================
*  = Code for email to Colin thinking about how to parameterise ICU =
*  ==================================================================
// 130215
local clean_run 0
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
	qui include cr_survival.do
}
else {
	di as error "WARNING: You are assuming that working_survival.dta is up-to-date"
	clear
	use ../data/working_survival.dta
	st
}
est drop _all

/*
Independent vars
- age
- sex
*/

set seed 3001
* keep id event v_timestamp icu_admit icu_discharge date_trace dead ///
* 	 dt0 dt1 _t0 _t _st _d dt0 dt1 ///
* 	 icode idvisit  ppsample ///
* 	 dead28 ///
* 	 sex male age age_k age_c ///
* 	 icnarc0 icnarc0_c icnarc_q5 ///
* 	 sepsis_dx ///
* 	 v_ccmds ccmds_delta v_decision ///
* 	 periarrest ///
* 	 temperature wcc ///
* 	 lactate ///
* 	 time2icu early4


cap drop ccmds_now
clonevar ccmds_now = v_ccmds
replace ccmds_now = 1 if ccmds_now == 0
label copy v_ccmds ccmds_now
label define ccmds_now 0 "" 1 "Level 0/1", modify
label values ccmds_now ccmds_now
tab ccmds_now

// fracpoly can't handle factor variables so generate your own
cap drop ccn_* ccd_* vd_* sp_*
tab ccmds_now, gen(ccn_)
tab ccmds_delta, gen(ccd_)
tab v_decision, gen(vd_)
tab sepsis_dx, gen(sp_)

save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

*  ===============================================
*  = Now examine ICU dose using the TVC approach =
*  ===============================================

use ../data/scratch/scratch.dta, clear

// models to run before stsplit
global confounders ///
	icnarc0_c  ///
	age_c male ///
	sp_2-sp_5 ///
	ccn_2 ccn_3 ///
	ccd_1 ccd_3 ///
	vd_2-vd_4 ///

* stcox defer4 $confounders, noshow nolog
* replace time2icu_cat = 6 if missing(time2icu)
* tab time2icu_cat if ppsample
* stcox ib0.time2icu_cat $confounders, noshow nolog


// NOTE: 2013-02-14 - split at 4h, 12h 24h, 36h 72h and 1w
* stsplit tsplit, at(0.1667 0.5 1 1.5 2 3 7)
stsplit tsplit, at(0(0.25)3 7)
cap drop ppsample
bys id (_t0): gen ppsample = _n == 1
count if ppsample
gen risktime = _t - _t0
order id event v_timestamp icu_admit icu_discharge date_trace dead dt0 dt1 _t0 _t _st _d icu dt _origin ppsample tsplit risktime

// now calculate icu dose at each time interval
cap drop icu_time
gen icu_time = 0
order icu_time, after(icu)
bys id (dt1): replace icu_time = sum(risktime) if icu == 1
bys id (dt1): replace icu_time = sum(icu_time)
// now summarise ICU exposure in the first 3 days keeping the time-varying nature
// use 3 days as this was the cut-off in the Simchen paper

foreach i in 4 12 24 72 168 {
	cap drop icu_dose_`i'
	bys id (dt1): gen icu_dose_`i'= cond(icu_time < `i'/24, icu_time, `i'/24)
	cap drop icu_dose_`i'_nospike
	// add an hour to all ICU doses (smallest time step)
	gen icu_dose_`i'_nospike = icu_dose_`i' + 1/24
	cap drop icu_dose_`i'_zero
	gen icu_dose_`i'_zero = icu_dose_`i' == 0 if !missing(icu_dose_`i')
}

cap drop icu_time_max
bys id: egen icu_time_max = max(icu_time)
order icu_time_max, after(icu_time)
* so this is your exposure variable's maximum value for each patient
* but it will increase 'out of step' if needed
tw hist icu_time_max if ppsample & icu_time_max <= 28, s(0) w(0.5) percent ///
	, ///
	xscale(noextend) ///
	xlab(0(7)28) ///
	xtitle("Duration of ICU exposure (days)") ///
	yscale(noextend) ///
	ylab(minmax, nogrid format(%9.0f)) ///
	ytitle("Percentage of patients") ///
	b1title("")

graph rename hist_icu_dose_28, replace
graph export ../outputs/figures/hist_icu_dose_28.pdf, ///
	name(hist_icu_dose_7) replace
// note the big spike of zero ICU time (71%) of patients never admitted
// draw again without the zero dose
tw hist icu_time_max if ppsample & icu_time_max <= 28 & icu_time_max > 0 ///
	, s(0) w(0.5) percent ///
	, ///
	xscale(noextend) ///
	xlab(0(7)28) ///
	xtitle("Duration of ICU exposure (days)") ///
	yscale(noextend) ///
	ylab(minmax, nogrid format(%9.0f)) ///
	ytitle("Percentage of patients") ///
	b1title("")

// now convert icu_dose
// first of all inspect the data
cap label drop event
label define event ///
	1 "Ward visit" ///
	2 "ICU admission" ///
	3 "ICU discharge" ///
	4 "Follow-up end" ///
	5 "ICU death" ///
	6 "Ward death" ///
	7 "Censored"
label values event event
cap drop event_t
clonevar event_t = event
bys id event_t (_t0): replace event_t = . if _n != _N
replace event_t = 5 if event_t == 3 & _d == 1
replace event_t = 6 if event_t == 4 & _d == 1
replace event_t = 7 if event_t == 4 & _d == 0
gsort id dt1
local vars id event_t _t0 _t icu_time _st _d icu_dose_168*
order `vars'
br `vars'
br `vars' if inlist(id,1,46,27,29)
tab event_t

// generate a categorical version of icu_dose_168
egen icu_dose_168_cat = cut(icu_dose_168), at(0 0.01 0.17 0.5 1 3 7 28) icodes
cap label drop icu_dose_168_cat
label define icu_dose_168_cat 0 "0"
label define icu_dose_168_cat 1 "-4h", modify
label define icu_dose_168_cat 2 "-12h", modify
label define icu_dose_168_cat 3 "-1d", modify
label define icu_dose_168_cat 4 "-3d", modify
label define icu_dose_168_cat 5 "-7d", modify
label define icu_dose_168_cat 6 "-28d", modify
label values icu_dose_168_cat icu_dose_168_cat
tab icu_dose_168_cat

stcox ib0.icu_dose_168_cat $confounders, noshow nolog
stcox icu_dose_168_zero icu_dose_168_nospike $confounders, noshow nolog
fracpoly, center(mean) compare: ///
	stcox icu_dose_168_nospike icu_dose_168_zero $confounders ///
	, noshow nolog

// examining ICU dose in ICNARC q5
local show_working = 0
if `show_working' {
	fracpoly, center(mean) compare: ///
		stcox icu_dose_168_nospike icu_dose_168_zero $confounders ///
		if icnarc_q5 == 5 ///
		, noshow nolog

	stcox icu_dose_72_nospike icu_dose_72_zero $confounders ///
		if icnarc_q5 == 5 ///
		, noshow nolog

	fracpoly, center(mean) compare: ///
		stcox icu_dose_72_nospike icu_dose_72_zero $confounders ///
		if icnarc_q5 == 5 ///
		, noshow nolog
	fracplot, msym(p)
	graph rename fp72_5
	// linear model ... but this is largely driven by the spike in mortality
	// from the latest admissions
	stcox icu_dose_72_nospike icu_dose_72_zero $confounders ///
		if icnarc_q5 == 5 ///
		, noshow nolog
	fracpoly, center(mean) compare: ///
		stcox icu_dose_72_nospike icu_dose_72_zero $confounders ///
		if icnarc_q5 == 1 ///
		, noshow nolog
	fracplot, msym(p)
	graph rename fp72_1
}


// think instead of this as an 'earliness or promptness parameter'
// if you have not yet been admitted then you cannot be 'prompt'

order icu_in, after(_t)
sort id dt1
cap drop early
gen early = 0
order early, after(icu_in)
label var early "ICU admission timing"
replace early = _t - icu_in if icu_in < _t
// set ceiling on earliness
replace early = 3 if early > 3
// but the bigger early is, the earlier you were admitted, the more ICU you have had
// but early only exists (in time) once you have been admitted

// handle the expected non-linearity at zero
cap drop early_nospike
gen early_nospike = early + 1/24
cap drop early_zero
gen early_zero = early == 0 if !missing(early)
order early_nospike early_zero, after(early)
br id event_t _t0 _t icu_in early early_nospike early_zero icu_time ///
	_st _d icu_dose_168 icu_dose_168_nospike icu_dose_168_zero

// generate a categorical version of early
cap drop early_cat
gen early_cat = .
replace early_cat = 1 if early != 0 & early < 0.5 & early_cat == .
replace early_cat = 2 if early != 0 & early < 1.0 & early_cat == .
replace early_cat = 3 if early != 0 & early < 1.5 & early_cat == .
replace early_cat = 4 if early != 0 & early < 2.0 & early_cat == .
replace early_cat = 5 if early != 0 & early < 2.5 & early_cat == .
replace early_cat = 6 if early != 0 & early < 3.0 & early_cat == .
replace early_cat = 0 if early == 0
tab early_cat


// now define ICU admission time such that it doesn't exist until observed
cap drop icu_in_t
gen icu_in_t = icu_in
replace icu_in_t = round(icu_in_t + (1/24),0.01)
replace icu_in_t = 7 if icu_in_t > 7 & !missing(icu_in_t)
su icu_in_t
label var icu_in_t "Delay (moving observation)"
replace icu_in_t = 0 if icu_in_t == .
bys id (dt1): replace icu_in_t = 0 if icu_in_t >= dt1
// handle the expected non-linearity at zero
cap drop icu_in_t_nospike
gen icu_in_t_nospike = icu_in_t + 1/24 if icu_in_t > 0
cap drop icu_in_t_zero
gen icu_in_t_zero = icu_in_t == 0 if !missing(icu_in_t)
// categorical version
cap drop icu_in_t_cat
gen icu_in_t_cat = 0
replace icu_in_t_cat = 4 if icu_in_t > 0
forvalues i = 12(12)72 {
	replace icu_in_t_cat = `i' if icu_in_t > `i'/24
}
tab icu_in_t_cat
local vars id event_t dt1 icu_in_t icu_in_t_nospike icu_in_t_zero icu_in_t_cat
order `vars'
br `vars'

*  ===============================================
*  = Admission delay models with fair comparison =
*  ===============================================
// icu_in_t (icu admission delay (low is good) with spike at zero)
// and only available once the patient has been admitted

// univariate categorical
stcox ib0.icu_in_t_cat ///
	, noshow nolog

// adjusted categorical
stcox ib0.icu_in_t_cat ///
	$confounders ///
	, noshow nolog

// univariate
stcox icu_in_t_nospike icu_in_t_zero ///
	, noshow nolog

// adjusted
stcox icu_in_t_nospike icu_in_t_zero ///
	$confounders ///
	, noshow nolog

// adjusted fp
fracpoly, center(no, icu_in_t_nospike:mean): ///
	stcox icu_in_t_nospike icu_in_t_zero ///
	$confounders ///
	, noshow nolog
fracplot, msym(p)
graph rename fp_delay_adjusted

*  ================
*  = Early models =
*  ================
// early measures the time difference between 'now' 
// and when you were admitted to ICU
// univariate categorical
stcox ib0.early_cat ///
	, noshow nolog

// adjusted categorical
stcox ib0.early_cat ///
	$confounders ///
	, noshow nolog

// univariate
fracpoly, center(no, early_nospike:mean): ///
	stcox early_nospike early_zero ///
	, noshow nolog
fracplot, msym(p)
graph rename fp72_early_univariate, replace

// adjusted
fracpoly, center(no, early_nospike:mean): ///
	stcox early_nospike early_zero ///
	$confounders ///
	, noshow nolog
fracplot, msym(p)
graph rename fp72_early_adjusted, replace

