*  ========================================
*  = Describe the patient admitted to ICU =
*  ========================================

/*
Pull tailsfinal, then merge against months, working
Strip out non-eligible patients
This can be the basis for comparison with spotlight vs other
Focus on characteristics not available for all (SPOT)light patients
i.e.
- diagnosis
*/

GenericSetupSteveHarris spot_early cr_admitted_pts, logon



* Now pull the tailsfinal data
local ddsn mysqlspot
local uuser stevetm
local ppass ""
* odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose
clear
odbc load, exec("SELECT * FROM spot_early.tailsfinal")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
count
save ../data/working_tails.dta, replace
clear
odbc load, exec("SELECT * FROM spot_early.lite_summ_monthly")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
count
tempfile 2merge
save `2merge', replace
use ../data/working_tails, clear
merge m:1 icnno studymonth using `2merge'
keep if _m == 3
drop _m
drop if studymonth_allreferrals == 0
drop if studymonth_protocol_problem == 1
drop if withinsh == 1
drop if elgreport_heads == 0
drop if elgreport_tails == 0
drop if site_quality_by_month < 80
drop if elgage == 0
drop if elgcpr == 0

save ../data/working_tails.dta, replace

use ../data/working.dta, clear
contract icode studymonth
drop _freq
tempfile 2merge
save `2merge', replace
use ../data/working_tails, clear
merge m:1 icode studymonth using `2merge'
drop if _m != 3
drop _m
save ../data/working_tails.dta, replace

use ../data/working.dta,clear
keep icnno adno
drop if missing(icnno, adno)
count
tempfile 2merge
save `2merge'

use ../data/working_tails.dta, clear
cap drop _m
merge 1:1 icnno adno using `2merge'
gen spotlight = _m == 3
label var spotlight "(SPOT)light study pt"
label values spotlight truefalse
* NOTE: 2013-01-28 - why did 43 patients not merge?
drop if _m == 2
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


save ../data/working_tails.dta, replace

* Start here
use ../data/working_tails.dta, clear
egen pickone_site = tag(icode)
tab pickone_site

tab pa_v3 spotlight
tab loca spotlight if pa_v3 == 5




cap log close
