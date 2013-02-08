*  ======================
*  = Occupancy and time =
*  ======================

GenericSetupSteveHarris spot_early an_occupancy_and_time, logon

global ddsn mysqlspot
global uuser stevetm
global ppass ""

*  =========================
*  = Pull in the spot data =
*  =========================

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
cap log close