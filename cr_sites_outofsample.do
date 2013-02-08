*  ===============================================================
*  = Use HES data to compare sites in versus sites out of sample =
*  ===============================================================

clear
* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
local ddsn mysqlspot
local uuser stevetm
local ppass ""
******************

*  ====================
*  = Sites within HES =
*  ====================

odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

clear
timer on 1
odbc load, exec("SELECT * FROM spot_early.sites_within_hes")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
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

preserve
use ../data/working.dta, clear
contract icode, freq(v)
label var v "visits"
tempfile 2merge
save `2merge', replace
restore

merge m:1 icode using `2merge', keepusing(v)
drop if _m == 2
sort sha sitename
gen in_sample = _m == 3
drop _m

gen emx_pct = round(hes_emergencies / hes_admissions * 100) 
save ../data/sites_within_hes.dta, replace


clear
*  =====================
*  = Sites within CMPD =
*  =====================

odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

clear
timer on 1
odbc load, exec("SELECT * FROM spot_early.sites_within_cmpd")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
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

preserve
use ../data/working.dta, clear
contract icode, freq(v)
label var v "visits"
tempfile 2merge
save `2merge', replace
restore

merge m:1 icode using `2merge', keepusing(v)
drop if _m == 2
sort dorisname
gen in_sample = _m == 3
drop _m
drop if dorisname == "aardvark"

* The following code makes it easy to display in datagraph
gen tails_wardemx_study = tails_wardemx if in_sample == 1
gen cmp_patients_permonth_study = cmp_patients_permonth if in_sample == 1
gen tails_wardemx_hmortality_study = tails_wardemx_hmortality if in_sample == 1

save ../data/sites_within_cmpd.dta, replace
