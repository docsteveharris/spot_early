* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
global ddsn mysqlspot
global uuser stevetm
global ppass ""
******************

GenericSetupSteveHarris spot_early an_external_validity, logon

*  =======================================
*  = Site level data with respect to HES =
*  =======================================

odbc query "$ddsn", user("$uuser") pass("$ppass") verbose
clear
odbc load, exec("SELECT * FROM spot_early.sites_within_hes")  dsn("$ddsn") user("$uuser") pass("$ppass") lowercase sqlshow clear
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
qui compress
drop _* modifiedat

save ../data/scratch/scratch, replace
use ../data/working, clear
contract icode
drop _*
tempfile 2merge
save `2merge', replace
use ../data/scratch/scratch, clear
merge m:1 icode using `2merge'
gen alladmissions_site = _m == 3
drop _m
label values alladmissions_site truefalse
gen study_site = !missing(icode)
label values study_site truefalse
save ../data/scratch/scratch, replace

*  ==============================================================
*  = Plot study sites within HES wrt to all hospital admissions =
*  ==============================================================
* NOTE: 2013-01-10 - ignore sites with < 5000 admissions per year
drop if hes_admissions < 5000
cap drop hes_dups
duplicates tag hes_code, gen(hes_dups)
tab hes_dups
list hes_code dorisname if hes_dups != 0, sepby(hes_code)
duplicates drop hes_code, force

cap drop baseline
gen baseline = 0
sort hes_admissions
cap drop x_order
gen x_order = _n
label var x_order "Hospitals order by admissions from 2010-11 hospital episode statistics"
cap drop hes_admissions_k
gen hes_admissions_k = round(hes_admissions/1000)
label var hes_admissions_k "Hospital admissions (thousands)"

tw 	(rbar hes_admissions_k baseline x_order if alladmissions_site, ///
	 	fcolor(black) lcolor(black) lpattern(blank)) ///
	(rbar hes_admissions_k baseline x_order if !alladmissions_site, ///
		fcolor(gs10) lcolor(gs10) lpattern(blank)), ///
	ylabel(, nogrid) ///
	xscale(noextend) xlabel(minmax) ///
	xtitle("English hospitals reporting hospital episode statistics") ///
	yscale(noextend) ///
	ytitle("Annual hospital admissions" "(thousands)")  ///
	legend(off)

graph rename alladmx_sites_by_hes_admx, replace
graph export ../logs/alladmx_sites_within_hes_admx.pdf, replace

su hes_admissions_k,d


gen hes_emergencies_pct = round(100* hes_emergencies / hes_admissions)
label var hes_emergencies_pct "Emergency hospital admissions as percentage of all admissions"
sort hes_emergencies_pct
cap drop x_order
gen x_order = _n
sort x_order


tw 	(rbar hes_emergencies_pct baseline x_order if alladmissions_site, ///
	 	fcolor(black) lcolor(black) lpattern(blank)) ///
	(rbar hes_emergencies_pct baseline x_order if !alladmissions_site, ///
		fcolor(gs10) lcolor(gs10) lpattern(blank)), ///
	ylabel(0 "0%" 25 "25%" 50 "50%" 75 "75%", nogrid) ///
	xscale(noextend) xlabel(minmax) ///
	xtitle("English hospitals reporting hospital episode statistics") ///
	yscale(noextend) ///
	ytitle("Emergency hospital admissions (%)") ///
	legend(off)


graph rename alladmxsites_by_hes_emergx, replace
graph export ../logs/alladmxsites_by_hes_emergx.pdf, replace

su hes_emergencies_pct,d

*  ========================================
*  = Site level data with respect to CMPD =
*  ====================================

/*
NOTE: 2013-01-11 - need to start afresh since the HES and CMPD cover different populations
*/

odbc query "$ddsn", user("$uuser") pass("$ppass") verbose
clear
odbc load, exec("SELECT * FROM spot_early.sites_within_cmpd")  dsn("$ddsn") user("$uuser") pass("$ppass") lowercase sqlshow clear
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
qui compress
drop _* modifiedat

save ../data/scratch/scratch, replace
use ../data/working, clear
contract icode
drop _*
tempfile 2merge
save `2merge', replace
use ../data/scratch/scratch, clear
merge m:1 icode using `2merge'
gen alladmissions_site = _m == 3
drop _m
label values alladmissions_site truefalse
gen study_site = !missing(icode)
label values study_site truefalse
/*
NOTE: 2013-01-11 - drop sites that were not submitting data during the study
*/
drop if cmp_patients_permonth == 0
save ../data/scratch/scratch, replace

cap drop baseline
gen baseline = 0
sort cmp_patients_permonth
cap drop x_order
gen x_order = _n
label var x_order "Critical care admissions per month"
local xxtitle "Critical care units participating in the ICNARC CMP"

tw 	(rbar cmp_patients_permonth baseline x_order if alladmissions_site, ///
	 	fcolor(black) lcolor(black) lpattern(blank)) ///
	(rbar cmp_patients_permonth baseline x_order if !alladmissions_site, ///
		fcolor(gs10) lcolor(gs10) lpattern(blank)), ///
	ylabel(0(50)350, nogrid) ///
	xscale(noextend) xlabel(minmax) ///
	xtitle("`xxtitle'") ///
	yscale(noextend) ///
	ytitle("Average monthly admissions to CMP units") ///
	legend(off)


graph rename alladmxsites_by_cmp_admx, replace
graph export ../logs/alladmxsites_by_cmp_admx.pdf, replace

su cmp_patients_permonth, d

cap drop baseline
gen baseline = 0
sort tails_all_percent
cap drop x_order
gen x_order = _n
label var x_order "Emergency admissions from the ward"
* TODO: 2013-01-18 - change y axis: ?number of emergency ward admissions ...

tw 	(rbar tails_all_percent baseline x_order if alladmissions_site, ///
	 	fcolor(black) lcolor(black) lpattern(blank)) ///
	(rbar tails_all_percent baseline x_order if !alladmissions_site, ///
		fcolor(gs10) lcolor(gs10) lpattern(blank)), ///
	ylabel(0 "0%" 25 "25%" 50 "50%" 75 "75%" 100 "100%", nogrid) ///
	xscale(noextend) xlabel(minmax) ///
	xtitle("`xxtitle'") ///
	yscale(noextend) ///
	ytitle("Emergency ward admissions (%) to critical care") ///
	legend(off)

* legend(order(1 "Sites participating in (SPOT)light") ///
* 	symxsize(1) symysize(3) ///
* 	region(lpattern(solid) lwidth(vvthin) lcolor(black)) ///
* 	position(10) ring(0))

graph rename alladmxsites_by_cmp_wardemx, replace
graph export ../logs/alladmxsites_by_cmp_wardemx.pdf, replace

su tails_all_percent, d
su tails_core_percent, d


cap log close

*  ===============================================
*  = Combine graphs for presentations and thesis =
*  ===============================================

* NOTE: 2013-01-20 - LSHTM poster presentation 2013
graph combine ///
		alladmx_sites_by_hes_admx ///
		alladmxsites_by_hes_emergx ///
		alladmxsites_by_cmp_admx ///
		alladmxsites_by_cmp_wardemx ///
	, cols(2) colfirst xsize(6) ysize(4) scale(*0.8) ///
	note("Excluding hospitals with < 5000 admissions per year", margin(small))


graph export ../outputs/figures/external_validity.pdf, replace


