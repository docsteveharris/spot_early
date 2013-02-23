*  ======================================================
*  = Define data set for the early vs deferred analysis =
*  ======================================================

/*
Run this as if it was fresh ... that means duplicating a lot of the cr_working
Then identify and drop
- sites with complicated ICU referral patterns
- patients who have complicated journeys into ICU
*/


local clean_run 1
if `clean_run' {
	// capture {

		clear
		local ddsn mysqlspot
		local uuser stevetm
		local ppass ""
		odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

		clear
		timer on 1
		odbc load, exec("SELECT * FROM spot_early.working_early")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
		timer off 1
		timer list 1
		count

		* Merge in site level data
		preserve
		include cr_sites.do
		restore
		merge m:1 icode using ../data/sites.dta, ///
			keepusing(heads_tailed* ccot_shift_pattern all_cc_in_cmp ///
				tails_wardemx* tails_othercc* ///
				ht_ratio cmp_beds_persite*)
		drop _m


		file open myvars using ../data/scratch/vars.yml, text write replace
		foreach var of varlist * {
			di "- `var'" _newline
			file write myvars "- `var'" _newline
		}
		file close myvars

		compress


		shell ../ccode/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"

		capture confirm file ../data/scratch/_label_data.do
		if _rc == 0 {
			include ../data/scratch/_label_data.do
			* shell  rm ../data/scratch/_label_data.do
			* shell rm ../data/scratch/myvars.yml
		}
		else {
			di as error "Error: Unable to label data"
			exit
		}
	// }
	save ../data/working_raw.dta, replace
}

GenericSetupSteveHarris spot_early cr_working, logon

use ../data/working_raw.dta, clear
cap drop included_sites
egen included_sites = tag(icode)
count if included_sites == 1

* Define the inclusion by intention
gen include = 1

/*
NOTE: 2013-01-07
- only include admissions from months where CMPD data known to be available
- this will drop both known missing (1) and presumed missing (.)
*/
replace include = 0 if cmpd_month_miss != 0
replace include = 0 if studymonth_allreferrals == 0
* replace include = 0 if allreferrals == 0
replace include = 0 if elgdate == 0
replace include = 0 if studymonth_protocol_problem == 1
replace include = 0 if elgprotocol == 0

tab include

* Theoretical pool of patients if all sites had been perfect
cap drop included_sites
egen included_sites = tag(icode)
cap drop included_months
egen included_months = tag(icode studymonth)
count if include == 1
count if included_sites == 1 & include == 1
count if included_months == 1 & include == 1

* Pool of patients after initial 3 month screening check
/*
CHANGED: 2013-01-07
- permit through sites where the overall quality is good (late improvers)
*/
replace include = 0 if ///
	(site_quality_q1 < 80 | site_quality_q1 == .) ///
	& include == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1
count if include == 1
count if included_sites == 1 & include == 1
count if included_months == 1 & include == 1

* Non-eligible patients (no risk of bias ... dropped by design)
* What proportion of these were ineligible and for what reason?
cap drop exclude1
gen exclude1 = 0
label var exclude1 "Exclude - by design"
count if include == 1 & elgfirst_episode == 0 & exclude1 == 0
count if include == 1 & withinsh == 1 & exclude1 == 0
count if include == 1 & elgreport_heads == 0 & exclude1 == 0
count if include == 1 & elgreport_tails == 0 & exclude1 == 0
* CHANGED: 2013-02-06 - extra exclusions for early arm of study
count if include == 1 & all_cc_in_cmp == 0 & exclude1 == 0
count if include == 1 & tails_othercc != 0 & exclude1 == 0
count if include == 1 & loca == 1 & exclude1 == 0
count if include == 1 & inlist(v_disposal, 2, 6) & exclude1 == 0
* CHANGED: 2013-02-16 - also excluded arrests and deaths
count if include == 1 & inlist(v_arrest, 2, 3) & exclude1 == 0
count if include == 1 & inlist(v_disposal, 7) & exclude1 == 0


replace exclude1 = 1 if include == 1 & elgfirst_episode == 0
replace exclude1 = 1 if include == 1 & withinsh == 1
replace exclude1 = 1 if include == 1 & elgreport_heads == 0
replace exclude1 = 1 if include == 1 & elgreport_tails == 0
* CHANGED: 2013-02-06 - drop patients admitted via theatre
replace exclude1 = 1 if include == 1 & loca == 1
* CHANGED: 2013-02-08 - drop patients with treatment limits
replace exclude1 = 1 if include == 1 & inlist(v_disposal, 2, 6)
replace exclude1 = 1 if include == 1 & inlist(v_disposal, 7)
replace exclude1 = 1 if include == 1 & inlist(v_arrest, 2, 3)
* CHANGED: 2013-02-06 - drop sites with non-CMP critical care areas
replace exclude1 = 1 if all_cc_in_cmp == 0
* CHANGED: 2013-02-06 - drop sites with admissions reported to CMP units
* via other non-CMP areas
replace exclude1 = 1 if tails_othercc != 0
tab exclude1 if include == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0
count if include == 1 & exclude1 == 0
count if included_sites == 1 & include == 1 & exclude1 == 0
count if included_months == 1 & include == 1 & exclude1 == 0

* Eligible patients not recruited (potential bias ... not dropped by design)
* Lost to follow-up is not an exclusion
count if include == 1 & exclude1 == 0 & site_quality_by_month < 80
gen exclude2 = 0
label var exclude2 "Exclude - by choice"
replace exclude2 = 1 if include == 1 & exclude1 == 0 & site_quality_by_month < 80
tab exclude2 if include == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0
count if included_sites == 1 & include == 1 & exclude1 == 0 & exclude2 == 0
count if included_months == 1 & include == 1 & exclude1 == 0 & exclude2 == 0

* Eligible - lost to follow-up
gen exclude3 = 0
label var exclude3 "Exclude - lost to follow-up"
count if include == 1 & exclude1 == 0 & exclude2 == 0 & missing(date_trace) == 1
replace exclude3 = 1 if include == 1 & exclude1 == 0 & exclude2 == 0 & missing(date_trace) == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
count if included_sites == 1 & include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
count if included_months == 1 & include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0

* CHANGED: 2013-02-23 - moved from cr_survival
* Patients where the data is impossible
* add to CONSORT diagram
gen exclude4 = 0
tab dead, missing
replace exclude4 = 1 if missing(dead)

* TODO: 2012-09-27 - mismatch between icu outcome and dates and MRIS data
sort dorisname
di as error "NOTE: 2013-01-29 - 23 ICU deaths not found in MRIS"
tab dead dead_icu
list dorisname dead_icu dead if dead_icu == 1 & dead == 0, sepby(dorisname)

* TODO: 2013-01-29 - check for mismatched dates of death
list dorisname dead_icu ddicu date_trace ///
	if icu_discharge != date_trace  & ddicu != . & dead_icu == 1 & dead == 1

* drop these for now
replace exclude4 = 1 if dead_icu == 1 & dead == 0

* TODO: 2013-01-29 - missing ICU icu_discharge
* of which one has a mismatched death
list dorisname dead dead_icu ddicu date_trace ///
	if dofC(icu_discharge) != date_trace & dead_icu == 1 & dead !=. ///
	, sepby(dorisname)
* replace ddicu with date_trace + 23hrs and 59mins in these patients
replace icu_discharge = dhms(date_trace,0,0,0) ///
	if dofc(icu_discharge) == . & dead_icu == 1 & dead !=.

* NOTE: 2012-09-27 - get more precise survival timing for those who die in ICU
* Add one hour though else ICU discharge and last_trace at same time
* this would mean these records being dropped by stset
* CHANGED: 2012-10-02 - changed to 23:59:00 from 23:59:59 because of rounding errors
gen double last_trace = cofd(date_trace) + hms(23,58,00)
replace last_trace = icu_discharge if dead_icu == 1 & !missing(icu_discharge)
format last_trace %tc
label var last_trace "Timestamp last event"

* TODO: 2013-01-29 - this should really be moved to validation level checks
* count problem dates and times
count if floor(hours(icu_admit))		> floor(hours(icu_discharge)) 	& !missing(icu_admit, icu_discharge)
count if floor(hours(v_timestamp))		> floor(hours(icu_admit)) 		& !missing(v_timestamp, icu_admit)
list icode v_timestamp icu_admit ///
	if floor(hours(v_timestamp))		> floor(hours(icu_admit)) 		& !missing(v_timestamp, icu_admit) ///
	, sepby(icode)
count if floor(hours(v_timestamp)) 		> floor(hours(icu_discharge)) 	& !missing(v_timestamp, icu_discharge)
count if floor(hours(icu_admit)) 		> floor(hours(last_trace)) 		& !missing(icu_admit, last_trace)
count if floor(hours(icu_discharge))	> floor(hours(last_trace)) 		& !missing(icu_discharge, last_trace)
list icode icu_discharge last_trace ///
	if floor(hours(icu_discharge))	> floor(hours(last_trace)) 		& !missing(icu_discharge, last_trace) ///
	, sepby(icode)
count if floor(hours(v_timestamp)) 		> floor(hours(last_trace)) 		& !missing(v_timestamp, last_trace)

* NB all done at the at hours resolution
replace exclude4 = 1 if floor(hours(icu_admit))		> floor(hours(icu_discharge)) 	& !missing(icu_admit, icu_discharge)
replace exclude4 = 1 if floor(hours(v_timestamp))	> floor(hours(icu_admit)) 		& !missing(v_timestamp, icu_admit)
replace exclude4 = 1 if floor(hours(v_timestamp)) 	> floor(hours(icu_discharge)) 	& !missing(v_timestamp, icu_discharge)
replace exclude4 = 1 if floor(hours(icu_admit)) 	> floor(hours(last_trace)) 		& !missing(icu_admit, last_trace)
replace exclude4 = 1 if floor(hours(icu_discharge)) > floor(hours(last_trace)) 		& !missing(icu_discharge, last_trace)
replace exclude4 = 1 if floor(hours(v_timestamp)) 	> floor(hours(last_trace)) 		& !missing(v_timestamp, last_trace)

label var exclude4 "Exclude - data error"
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 ==0 & missing(date_trace) == 1
replace exclude4 = 1 if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 ==0  & missing(date_trace) == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
count if included_sites == 1 & include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
count if included_months == 1 & include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
save ../data/working_all.dta, replace


use ../data/working_all.dta, clear
keep if include
drop if exclude1 == 1
drop if exclude2 == 1
drop if exclude3 == 1
drop if exclude4 == 1

* No point keeping these vars since they don't mean anything now
drop include exclude1 exclude2 exclude3 exclude4

save ../data/working.dta, replace

cap log close





