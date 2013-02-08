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
GenericSetupSteveHarris spot_early cr_working, logon


*  =======================================
*  = Visit level data import from SQL db =
*  =======================================

capture {

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
}
save ../data/working_raw.dta, replace

*  ========================
*  = Define analysis axes =
*  ========================
* TODO: 2012-10-01 - you may want to make the definitions more 'transportable'
* i.e. move them back into the python codebase


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
save ../data/working_all.dta, replace

use ../data/working_all.dta, clear
keep if include
drop if exclude1 == 1
drop if exclude2 == 1
drop if exclude3 == 1

* No point keeping these vars since they don't mean anything now
drop include exclude1 exclude2

save ../data/working.dta, replace

log close





