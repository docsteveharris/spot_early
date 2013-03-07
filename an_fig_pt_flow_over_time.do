GenericSetupSteveHarris spot_early pt_flow_over_time, logon

* CHANGED: 2013-02-27 - code re-written to produce by decison, over time

use ../data/working.dta, clear
qui include cr_preflight.do
save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear
count
local original_N = _N
// impute a time of death for patients who die on the ward
// create a dataset that contains the time of icu death by 'day' wrt visit
// then randomly sample with replacement from this for deaths on the ward
// to generate an hour for the death
cap drop death_day
gen death_day = date_trace - dofc(v_timestamp)
su death_day
cap drop death_hour
gen death_hour = hh(tod) if dead_icu == 1
hist death_hour, discrete
// save temp data
save ../data/scratch/scratch_all.dta, replace

// save the data that is OK (alive or dead ICU)
use ../data/scratch/scratch_all.dta, clear
keep if !(dead == 1 & missing(tod))
count
save ../data/scratch/scratch_dead_ward_not.dta, replace

// save the data into which you will impute
use ../data/scratch/scratch_all.dta, clear
keep if dead == 1 & missing(tod)
count
global obs_needed = r(N)
save ../data/scratch/scratch_dead_ward.dta, replace

// save the data that contains the hours from which you will sample
use ../data/scratch/scratch_all.dta, clear
keep if dead == 1 & !missing(tod)
keep death_hour
set seed 3001
tempvar random_sort
gen `random_sort' = runiform()
sort `random_sort'
drop `random_sort'
gen obsno = _n
count
global sample_size = r(N)
save ../data/scratch/scratch_dead_icu.dta, replace

// see http://blog.stata.com/tag/random-numbers/
// generate your list of sample obs
drop _all
set seed 3001
set obs $obs_needed
generate obsno = floor($sample_size * runiform() + 1)
su obsno
duplicates report obsno
save ../data/scratch/obsno_to_draw.dta, replace
// use your dataset : i.e. use the hours dataset
use ../data/scratch/scratch_dead_icu.dta, clear
merge 1:m obsno using ../data/scratch/obsno_to_draw.dta, keep(match) nogen
// now you have your random with replacement list of hours
// randomly sort again
drop obsno
tempvar random_sort
gen `random_sort' = runiform()
sort `random_sort'
drop `random_sort'
gen obsno = _n
save ../data/scratch/hours_to_draw.dta, replace
use ../data/scratch/scratch_dead_ward.dta, clear
drop death_hour
gen obsno = _n
merge 1:1 obsno using ../data/scratch/hours_to_draw, keep(match) nogen
append using ../data/scratch/scratch_dead_ward_not, nolabel
hist death_hour, discrete by(dead_icu) xlabel(0 24)

// check that you don't have impossible death time
count if death_hour < hh(v_timestamp) & death_day == 0
gen impossible = 1 if death_hour < hh(v_timestamp) & death_day == 0
save ../data/scratch/scratch.dta, replace

use ../data/scratch/scratch.dta, clear
keep if impossible == 1
keep idvisit v_timestamp date_trace death_hour obsno
br
cap drop death_hour_ok
gen death_hour_ok = .

while death_hour_ok[_N] == . {
	cap drop obsno
	generate obsno = floor($obs_needed * runiform() + 1)
	tempvar random_sort
	gen `random_sort' = runiform()
	sort `random_sort'
	drop `random_sort'
	drop death_hour
	merge m:1 obsno using ../data/scratch/hours_to_draw, keep(match) nogen
	replace death_hour_ok = death_hour if death_hour >= hh(v_timestamp) 
	sort death_hour_ok
}
keep idvisit death_hour_ok
tempfile 2merge
save `2merge', replace
use ../data/scratch/scratch.dta, clear
merge 1:1 idvisit using `2merge', nolabel
replace death_hour = death_hour_ok if impossible == 1
count if death_hour < hh(v_timestamp) & death_day == 0
assert r(N) == 0
drop impossible death_hour_ok
save ../data/scratch/scratch.dta, replace


// now generate simple sequential timestamps
// everyone dies at 2 minutes past the hour
cap drop dead_timestamp
gen double dead_timestamp = .
replace dead_timestamp = dhms(date_trace,death_hour,2,0) if dead == 1
replace dead_timestamp = dhms(date_trace,hh(tod),2,0) if dead_icu == 1
replace dead_timestamp = dead_timestamp - v_timestamp
replace dead_timestamp = hours(dead_timestamp)
replace dead_timestamp = 2/60 if dead_timestamp < 0

// everyone is admitted to ICU at one minute past the hour
cap drop icu_timestamp
gen double icu_timestamp = hours(msofminutes(1) + msofhours(time2icu))
list v_timestamp icu_timestamp dead_timestamp in 1/10
br v_timestamp icu_timestamp dead_timestamp dead dead_icu date_trace

//
save ../data/scratch/scratch.dta, replace
// done! you have  now imputed death hours

use ../data/scratch/scratch.dta, clear

label list cc_decision
tab cc_decision

// define the current location of the patients
cap label drop location_now
label define location_now 0 "Ward"
label define location_now 1 "ICU", modify
label define location_now 2 "Dead", modify
cap drop location_now
gen location_now = 0
label var location_now "Location now"
label values location_now location_now
tab location_now

cap drop location_last
gen location_last = 0
label var location_last "Location last"
label values location_last location_now


// work on the 24 hour scale because MRIS survival tracing is date only
foreach h of numlist 0 4 12 24 48 72 168 {

	replace location_last = location_now
	di _newline
	di "========================================"
	di "ASSESSING PATIENT LOCATION AT `h' hours"
	di "========================================"
	di _newline


	// alive without icu admission
	local alive_without ///
		(icu_timestamp > `h' | time2icu == .) ///
		& (dead_timestamp > `h')
	qui replace location_now = 0 if `alive_without'

	// in critical care
	local alive_ICU ///
		(icu_timestamp <= `h') ///
		& (dead_timestamp > `h')
	qui replace location_now = 1 if `alive_ICU'

	// dead - regardless of route
	local dead_all ///
		(dead_timestamp <= `h')
	qui replace location_now = 2 if `dead_all'

	// tab location_now cc_decision
	di _newline
	di "NO follow-up"
	tab location_now location_last if cc_decision == 0
	di "Ward follow-up planned"
	tab location_now location_last if cc_decision == 1
	di "Accepted to critical care"
	tab location_now location_last if cc_decision == 2
	di _newline
}
