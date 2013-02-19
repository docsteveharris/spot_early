*  ===================================
*  = Model determinants of occupancy =
*  ===================================

/*
Use the full occupancy data set as this produces your dependent variable
Merge in site level characteristics
- unit size
- severity of illness at admission
- CCOT provision
- HES admissions
- HES case mix
*/

clear
use ../data/working_occupancy.dta
replace icnno = lower(icnno)
replace icode = lower(icode)
count


// code copied from cr_preflight.do 130219
gen open_beds_cmp = (cmp_beds_max - occupancy_active)
label var open_beds_cmp "Open beds with respect to CMP reported number"

gen beds_none = open_beds_cmp <= 0
label var beds_none "Critical care unit full"
label values beds_none truefalse

gen beds_blocked = cmp_beds_max - occupancy <= 0
label var beds_blocked "Critical care unit unable to discharge"
label values beds_blocked truefalse

cap drop bed_pressure
gen bed_pressure = 0
label var bed_pressure "Bed pressure"
replace bed_pressure = 1 if beds_blocked == 1
replace bed_pressure = 2 if beds_none == 1
label define bed_pressure 0 "Beds available"
label define bed_pressure 1 "No beds but discharges pending", add
label define bed_pressure 2 "No beds and no discharges pending", add
label values bed_pressure bed_pressure

// try using the variables generated at the site level via cr_preflight
// should help make sure this remains uptodate

tempfile working
save `working', replace

use ../data/working_all_sensitivity.dta, clear
// make sure you use the above data and not working.dta fr cr_preflight
global debug = 0
include cr_preflight.do
duplicates drop icode, force
keep icode cmp_beds_persite hes_admissions hes_daycase hes_emergencies ///
	hes_los_mean ccot ccot_days ccot_start ccot_hours all_cc_in_cmp ///
	studydays tails_all_percent tails_othercc cmp_patients_permonth ///
	ccot_shift_pattern hes_overnight hes_overnight_k hes_emergx ///
	hes_emergx_k cmp_beds_perhesadmx cmp_beds_peradmx_k

tempfile 2merge
save `2merge', replace
use `working', clear
merge m:1 icode using `2merge'
keep if _m == 3
drop _m

// now merge in key cmp characterisitcs
tempfile working
save `working', replace

* Now pull the tailsfinal data
local ddsn mysqlspot
local uuser stevetm
local ppass ""
* odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose
clear
odbc load, exec("SELECT * FROM spot_early.tailsfinal")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
count
bys icnno studymonth: egen admx_count = count(adno)

gen admx_elsurg_b = pa_v3 == "s" 
label var admx_elsurg_b "Planned surgical admission"
collapse 	(median) imscore_p50 = imscore ///
			admx_p50 = admx_count ///
			(mean) admx_elsurg = admx_elsurg_b , ///
		 	by(icnno)
tempfile 2merge
save `2merge', replace
use `working', clear
merge m:1 icnno using `2merge'
cap drop _merge
label var imscore_p50 "Median ICNARC score at site"
label var admx_p50 "Median monthly CMP admissions at site"
label var admx_elsurg "Mean elective surgical admissions at site"

// finally count the number of cmp units per site
tempfile working
save `working', replace
contract icode icnno
bys icode: gen cmp_units = _N
label var cmp_units "Number of CMP units at site"
keep icnno cmp_units
tempfile 2merge
save `2merge', replace
use `working', clear
merge m:1 icnno using `2merge'
cap drop _merge


// final variable preparation
gen month = month(dofc(otimestamp))
label var month "Month of year"
cap label drop month
label define month ///
	1 	"Jan" ///
	2 	"Feb" ///
	3 	"Mar" ///
	4 	"Apr" ///
	5 	"May" ///
	6 	"Jun" ///
	7 	"Jul" ///
	8 	"Aug" ///
	9 	"Sep" ///
	10 	"Oct" ///
	11 	"Nov" ///
	12 	"Dec"
label values month month
tab month

cap drop tofd
gen tofd = 0
replace tofd = 1 if inlist(ohrs,4)
replace tofd = 2 if inlist(ohrs,16)
label var tofd "Time of day"
cap label drop tofd
label define tofd 0 "Reference"
label define tofd 1 "Early shift", modify
label define tofd 2 "Late shift", modify
label values tofd tofd
tab tofd

cap drop dow
gen dow = dow(dofc(otimestamp))
label var dow "Day of week"
cap label drop dow
label define dow ///
	0 "Sun" ///
	1 "Mon" ///
	2 "Tue" ///
	3 "Wed" ///
	4 "Thu" ///
	5 "Fri" ///
	6 "Sat"
label values dow dow
tab dow

egen pickone_site = tag(icode)
egen pickone_unit = tag(icnno)

save ../data/scratch.dta, replace
*  =========================
*  = Now prepare the model =
*  =========================
/*
dependent var is beds_none 
	- and later repeat for beds_blocked
	- or run as multinomial
independent vars
site level
	- CCOT provision
	- HES overnight
	- HES emergency case mix
unit level
	- median number of admissions
	- median severity of illness at admission
	- proportion of admissions that are elective surgical
	- unit size: cmp beds
time level
	- hour of the day
		parameterise as early am, late afternoon and other
	- day of the week
	- month of the year

Model form: random effects logistic
- 
*/
use ../data/scratch.dta, clear

xtsey
// univariate inspection
