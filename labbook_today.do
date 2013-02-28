* ===================
* = Labbook - today =
* ===================

* Simple way to write and trial bits of code

use ../data/working.dta, clear
qui include cr_preflight.do
count

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
forvalues h = 0(24)72 {

	replace location_last = location_now
	di _newline
	di "========================================"
	di "ASSESSING PATIENT LOCATION AT `h' hours"
	di "========================================"
	di _newline

	forvalues i = 0/2 {
		// accepted to ICU
		if `i' == 2 {
			local touse "cc_decision == 2"
			local cc_cat "Accepted to critical care: "
		}
		// ward follow-up planned
		if `i' == 1 {
			local touse "cc_decision == 1"
			local cc_cat "Ward follow-up planned: "
		}
		// no ward follow-up planned
		if `i' == 0 {
			local touse "cc_decision == 0"
			local cc_cat "No ward follow-up planned: "
		}

		// alive without icu admission
		local alive_without ///
			`touse' ///
			& (time2icu >= `h' | time2icu == .) ///
			& (date_trace >= (dofc(v_timestamp) + 1))
		qui replace location_now = 0 if `alive_without'

		// in critical care
		local alive_ICU ///
			`touse' ///
			& (time2icu < `h') ///
			& (date_trace >= (dofc(v_timestamp) + 1))
		qui replace location_now = 1 if `alive_ICU'

		// dead - regardless of route

		local dead_all ///
			`touse' ///
			& dead == 1 ///
			& (date_trace <= (dofc(v_timestamp) + (`h'/24)))
		qui replace location_now = 2 if `dead_all'

	}
	tab location_now cc_decision
	di _newline
	di "NO follow-up"
	tab location_now location_last if cc_decision == 0
	di "Ward follow-up planned"
	tab location_now location_last if cc_decision == 1
	di "Accepted to critical care"
	tab location_now location_last if cc_decision == 2
	di _newline
}

