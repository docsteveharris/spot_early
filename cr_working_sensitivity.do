clear
* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
local ddsn mysqlspot
local uuser stevetm
local ppass ""


*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
/*
NOTE: 2013-01-08 - less strict (uses a 70% quality threshold)
*/
GenericSetupSteveHarris spot_early cr_working_sensitivity, logon



*  ===========================================================
*  = Now run the include exclude code to produce working.dta =
*  ===========================================================
*  This should produce the data for the consort diagram

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
* replace include = 0 if studymonth_protocol_problem = 0
* replace include = 0 if elgprotocol == 0

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
	(site_quality_q1 < 70 | site_quality_q1 == .) ///
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

replace exclude1 = 1 if include == 1 & elgfirst_episode == 0
replace exclude1 = 1 if include == 1 & withinsh == 1
replace exclude1 = 1 if include == 1 & elgreport_heads == 0
replace exclude1 = 1 if include == 1 & elgreport_tails == 0
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
count if include == 1 & exclude1 == 0 & site_quality_by_month < 70
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
save ../data/working_all_sensitivity.dta, replace

use ../data/working_all_sensitivity.dta, clear
keep if include
drop if exclude1 == 1
drop if exclude2 == 1
drop if exclude3 == 1

* No point keeping these vars since they don't mean anything now
drop include exclude1 exclude2

save ../data/working_sensitivity.dta, replace

log close





