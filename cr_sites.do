clear

* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
local ddsn mysqlspot
local uuser stevetm
local ppass ""
******************


*  ===================
*  = Site level data =
*  ===================

odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

clear
timer on 1
odbc load, exec("SELECT * FROM spot_early.sites_early")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
timer off 1
timer list 1
compress
count

file open myvars using ../data/scratch/vars.yml, text write replace
foreach var of varlist * {
	di "- `var'" _newline
	file write myvars "- `var'" _newline
}
file close myvars


shell ../ccode/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"

capture confirm file ../data/scratch/_label_data.do
if _rc == 0 {
	include ../data/scratch/_label_data.do
	shell  rm ../data/scratch/_label_data.do
	shell rm ../data/scratch/myvars.yml
}
else {
	di as error "Error: Unable to label data"
	exit
}

su _*
drop _*
tempfile working
save `working', replace


*  =====================================
*  = Now merge in site quality metrics =
*  =====================================
* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
local ddsn mysqlspot
local uuser stevetm
local ppass ""
******************
odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

clear
timer on 1
odbc load, exec("SELECT * FROM spot_early.lite_summ_monthly")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
timer off 1
timer list 1
compress
count

file open myvars using ../data/scratch/vars.yml, text write replace
foreach var of varlist * {
	di "- `var'" _newline
	file write myvars "- `var'" _newline
}
file close myvars


shell ../ccode/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"

capture confirm file ../data/scratch/_label_data.do
if _rc == 0 {
	include ../data/scratch/_label_data.do
	shell  rm ../data/scratch/_label_data.do
	shell rm ../data/scratch/myvars.yml
}
else {
	di as error "Error: Unable to label data"
	exit
}

sort icode studymonth
order icode studymonth cmpd_month_miss studymonth_protocol_problem ///
	studymonth_allreferrals

cap drop studymonth_allreferrals_analysed
gen studymonth_allreferrals_analysed = cmpd_month_miss == 0 ///
	& studymonth_protocol_problem == 0 ///
	& studymonth_allreferrals == 1 ///
	& site_quality_by_month > 80 & site_quality_by_month != .


gen mean_site_quality = site_quality_by_month
replace mean_site_quality = . if studymonth_allreferrals != 1 ///
	| studymonth_protocol_problem == 1 | cmpd_month_miss != 0

collapse (firstnm) icode match_quality_by_site ///
	(mean) mean_site_quality ///
	(sum) studymonth_allreferrals ///
	studymonth_protocol_problem ///
	studymonth_allreferrals_analysed, by(icnno)

duplicates drop icode, force
drop icnno
sort icode

tempfile 2merge
save `2merge', replace

use `working', clear
merge 1:1 icode using `2merge'
drop _m

cap drop _*

* CHANGED: 2013-02-07 - all merging with
* 	- sites_within_hes
* 	- sites_within_cmpd
* 	- lite_summ_monthly
* 	now takes place in sites_early sql code

save ../data/sites.dta, replace


