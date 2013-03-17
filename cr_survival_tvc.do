*  =================================================
*  = Build the TVC version of the survival dataset =
*  =================================================

/*
Generate three different metrics
- ICU age or ICU time (how long you have been in ICU)
- ICU delay: how long it took you to get into ICU
- ICU dose: how much ICU you have seen

Also construct a time dependent effect for severity (icnarc0_c)
*/

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


// split the data every 6 hours for the first 3 days as per Simchen then 4-7 then 7+
stsplit tsplit, at(0(0.25)3 7)
cap drop ppsample
bys id (_t0): gen ppsample = _n == 1
count if ppsample
gen risktime = _t - _t0
order id event v_timestamp icu_admit icu_discharge date_trace dead dt0 dt1 _t0 _t _st _d icu dt _origin ppsample tsplit risktime
format _t0 _t dt0 dt1 risktime %9.2fc

// save now as the above takes some time and the work below might need further improvement
save ../data/scratch/scratch.dta, replace

use ../data/scratch/scratch.dta, clear
// generate severity time interactions as in the ward model (i.e. 0,1,3,7, ...)
cap drop tb
gen tb = .
replace tb = 0 if tsplit < 1
replace tb = 1 if tsplit >= 1
replace tb = 3 if tsplit >= 3
replace tb = 7 if tsplit >= 7
replace tb = . if tsplit == .
label var tb "Severity time band"
tab tsplit tb


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
tab event_t

list id event_t dt1 risktime if inlist(id,1,46,27,29), sepby(id)

// now calculate icu dose at each time interval
// so if you are not in ICU your dose is zero
// if you are in ICU then your dose depends on length of stay
cap drop icu_dose
gen icu_dose = 0
label var icu_dose "ICU dose"
order icu_dose, after(icu)
bys id (dt1): replace icu_dose = sum(risktime) if icu == 1
bys id (dt1): replace icu_dose = sum(icu_dose)
// handle the expected non-linearity at zero
cap drop icu_dose_nospike
gen icu_dose_nospike = icu_dose + 1/24
cap drop icu_dose_zero
gen icu_dose_zero = icu_dose == 0 if !missing(icu_dose)
format icu_dose icu_dose_zero icu_dose_nospike %9.2fc
list id event_t dt1 risktime icu_dose if inlist(id,1,46,27,29), sepby(id)

cap drop icu_dose_max
bys id: egen icu_dose_max = max(icu_dose)
tw hist icu_dose_max if ppsample & icu_dose_max <= 28, s(0) w(0.5) percent ///
	, ///
	xscale(noextend) ///
	xlab(0(7)28) ///
	xtitle("Duration of ICU exposure (days)") ///
	yscale(noextend) ///
	ylab(minmax, nogrid format(%9.0f)) ///
	ytitle("Percentage of patients") ///
	b1title("")
graph rename hist_icu_dose_28_all, replace
graph export ../outputs/figures/hist_icu_dose_28_all.pdf, ///
	name(hist_icu_dose_28_all) replace

// note the big spike of zero ICU time (71%) of patients never admitted
// draw again without the zero dose
tw hist icu_dose_max if ppsample & icu_dose_max <= 28 & icu_dose_max > 0 ///
	, s(0) w(0.5) percent ///
	, ///
	xscale(noextend) ///
	xlab(0(7)28) ///
	xtitle("Duration of ICU exposure (days)") ///
	yscale(noextend) ///
	ylab(minmax, nogrid format(%9.0f)) ///
	ytitle("Percentage of patients") ///
	b1title("")
graph rename hist_icu_dose_28_admitted, replace
graph export ../outputs/figures/hist_icu_dose_28_admitted.pdf, ///
	name(hist_icu_dose_28_admitted) replace

// now define ICU admission time such that it doesn't exist until observed
// i.e. every patient starts out with an ICU admission time of zero
// then if admitted the time of admission becomes the covariate
// so before admission
//	- they are in the defer group
// after the admission they take on the time of that admission wrt to the visit

cap drop icu_delay
gen icu_delay = icu_in
// CHANGED: 2013-03-16 - commented out line below: not sure why it was here anyway
// replace icu_delay = round(icu_delay + (1/24),0.01)
replace icu_delay = 7 if icu_delay > 7 & !missing(icu_delay)
su icu_delay
label var icu_delay "Delay (moving observation)"
replace icu_delay = 0 if icu_delay == .
bys id (dt1): replace icu_delay = 0 if icu_delay >= dt1
// handle the expected non-linearity at zero
cap drop icu_delay_nospike
gen icu_delay_nospike = icu_delay + 1/24
cap drop icu_delay_zero
gen icu_delay_zero = icu_delay == 0 if !missing(icu_delay)
// categorical version
cap drop icu_delay_k
gen icu_delay_k = 0
replace icu_delay_k = 4 if icu_delay > 0
forvalues i = 12(12)72 {
	replace icu_delay_k = `i' if icu_delay > `i'/24
}
label var icu_delay_k "Delay (moving observation) - categorical"
format icu_delay icu_delay_zero icu_delay_nospike %9.2fc

// now make an icu_early version of icu_delay (ceiling of 1 week)
cap drop icu_early
gen icu_early = 7 - icu_in
replace icu_early = 0 if icu_early < 0 & !missing(icu_early)
label var icu_early "Early (moving observation)"
bys id (dt1): replace icu_early = 0 if icu_in >= dt1 
replace icu_early = 0 if icu_early == .
cap drop icu_early_nospike icu_early_zero
gen icu_early_nospike = icu_early + (1/24)
gen icu_early_zero = icu_early == 0
format icu_early icu_early_zero icu_early_nospike %9.2fc

list id event_t dt1 risktime icu_dose icu_delay if inlist(id,1,46,27,29), sepby(id)
// NOTE: 2013-03-01 - equivalent to specifying ICU with time-varying co-efficient?
// because ICU would be given the dummy 1 and then times would be assigned

// testing ...
// think instead of this as an 'earliness or promptness parameter'
// if you have not yet been admitted then you cannot be 'prompt'
sort id dt1
cap drop icu_time
gen icu_time = 0
order icu_time, after(icu_in)
label var icu_time "ICU time metric"
replace icu_time = _t - icu_in if icu_in < _t
// but the bigger icu_time is, the earlier you were admitted, the more ICU you have had
// but icu_time only exists (in time) once you have been admitted

// handle the expected non-linearity at zero
cap drop icu_time_nospike
gen icu_time_nospike = icu_time + 1/24
cap drop icu_time_zero
gen icu_time_zero = icu_time == 0 if !missing(icu_time)
format icu_time icu_time_nospike icu_time_zero %9.2fc
list id event_t dt1 risktime icu_dose icu_delay icu_time if inlist(id,1,46,27,29), sepby(id)

// generate a categorical version of icu_time
cap drop icu_time_k
gen icu_time_k = .
replace icu_time_k = 1 if icu_time != 0 & icu_time < 0.5 & icu_time_k == .
replace icu_time_k = 2 if icu_time != 0 & icu_time < 1.0 & icu_time_k == .
replace icu_time_k = 3 if icu_time != 0 & icu_time < 1.5 & icu_time_k == .
replace icu_time_k = 4 if icu_time != 0 & icu_time < 2.0 & icu_time_k == .
replace icu_time_k = 5 if icu_time != 0 & icu_time < 2.5 & icu_time_k == .
replace icu_time_k = 6 if icu_time != 0 & icu_time < 3.0 & icu_time_k == .
replace icu_time_k = 0 if icu_time == 0
tab icu_time_k

save ../data/working_survival_tvc.dta, replace



