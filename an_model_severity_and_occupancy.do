*  ======================================================================
*  = Does the linear IV model have different effects at different times =
*  ======================================================================

/*
- severity as dependent var model
	- include occupancy in the model to demonstrate that there is *no* effect of occupancy on patient severity until *after* the visit
	- table of comparative models: effect of occupancy on
		- severity at referral (all patients)
		- severity at referral (admitted patients): unadjusted
		- severity at referral (admitted patients): adjusted
		- severity at admission (admitted patients): unadjusted
		- severity at admission (admitted patients): adjusted

Try reporting just the effect size for severity at the different times
	- use the newsom plot

*/

*  =============================================================
*  = Set up the data so you have visit and admissions severity =
*  =============================================================

local clean_run 0
if `clean_run' == 1 {
    clear
    use ../data/working.dta
    include cr_preflight.do
    include cr_working_tails.do
}

use ../data/working_tails.dta, clear
tempfile 2merge
save `2merge', replace
use ../data/working_postflight.dta, clear
// double check that icnno and adno are unique
duplicates report icnno adno
merge m:1 icnno adno using `2merge'
drop _m
est drop _all
xtset site
save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

*  ===============================================
*  = Model variables assembled into single macro =
*  ===============================================
local all_vars ///
	delayed_referral ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///

global model_vars `all_vars'



// severity at referral: all, unadjusted
xtreg icnarc0 beds_none
est store v_all_un
// severity at referral: all, adjusted
xtreg icnarc0 beds_none $model_vars
est store v_all_adj
// severity at referral: admitted, adjusted
xtreg icnarc0 beds_none $model_vars if !missing(imscore)
est store v_adm_adj
// severity at admission: unadjusted
xtreg imscore beds_none 
est store i_adm_un
// severity at admission: adjusted
xtreg imscore beds_none $model_vars
est store i_adm_adj

est table _all, b(%9.2fc) keep(beds_none)


*  ========================
*  = Univariate estimates =
*  ========================
tempfile estimates_file
global table_name severity_over_time
local i = 1
local model_sequence = 1
local table_order = 1

// start beds_none as the first univariate
use ../data/scratch/scratch.dta, clear
est restore v_all_un
local model_name = "visit all univariate"
parmest, ///
	label list(parm label estimate min* max* p) ///
	idnum(`i') idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)
use `estimates_file', clear
gen table_order = `table_order'
gen model_sequence = `model_sequence'
local ++table_order
save `estimates_file', replace
save ../outputs/tables/$table_name.dta, replace


// now for the other univariates
local uni_vars $model_vars
foreach var of local uni_vars {
	use ../data/scratch/scratch.dta, clear
	qui xtreg icnarc0 `var'
	est store u_`i'
	if strpos("`var'", ".") {
		local var_name = substr("`var'", strpos("`var'", ".") + 1, .)
	}
	else {
		local var_name `var'
	}
	local model_name = "visit all univariate"
	parmest, ///
		label list(parm label estimate min* max* p) ///
		idnum(`i') idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		format(estimate min* max* %9.2f p %9.3f) ///
		saving(`estimates_file', replace)
	use `estimates_file', clear
	gen table_order = `table_order'
	gen model_sequence = `model_sequence'
	local ++table_order
	save `estimates_file', replace
	use ../outputs/tables/$table_name.dta, clear
	append using `estimates_file'
	save ../outputs/tables/$table_name.dta, replace
	local ++i
}

*  ======================================
*  = severity at referral: all adjusted =
*  ======================================
local ++model_sequence
est restore v_all_adj
local model_name = "visit all adjusted"
parmest, ///
	label list(parm label estimate min* max* p) ///
	idnum(`i') idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)
use `estimates_file', clear
gen table_order = _n
gen model_sequence = `model_sequence'
save `estimates_file', replace
use ../outputs/tables/$table_name.dta, clear
append using `estimates_file'
save ../outputs/tables/$table_name.dta, replace
local ++i

*  ======================================
*  = severity at referral: admitted adjusted =
*  ======================================
local ++model_sequence
est restore v_adm_adj
local model_name = "visit admitted adjusted"
parmest, ///
	label list(parm label estimate min* max* p) ///
	idnum(`i') idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)
use `estimates_file', clear
gen table_order = _n
gen model_sequence = `model_sequence'
save `estimates_file', replace
use ../outputs/tables/$table_name.dta, clear
append using `estimates_file'
save ../outputs/tables/$table_name.dta, replace
local ++i

*  ======================================
*  = severity at admission: unadjusted ==
*  ======================================
local ++model_sequence
local uni_vars beds_none $model_vars
foreach var of local uni_vars {
	use ../data/scratch/scratch.dta, clear
	qui xtreg imscore `var'
	est store u_`i'
	if strpos("`var'", ".") {
		local var_name = substr("`var'", strpos("`var'", ".") + 1, .)
	}
	else {
		local var_name `var'
	}
	local model_name = "icu admitted univariate"
	parmest, ///
		label list(parm label estimate min* max* p) ///
		idnum(`i') idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		format(estimate min* max* %9.2f p %9.3f) ///
		saving(`estimates_file', replace)
	use `estimates_file', clear
	gen table_order = `table_order'
	gen model_sequence = `model_sequence'
	local ++table_order
	save `estimates_file', replace
	use ../outputs/tables/$table_name.dta, clear
	append using `estimates_file'
	save ../outputs/tables/$table_name.dta, replace
	local ++i
}

*  ======================================
*  = severity at admission: admitted adjusted =
*  ======================================
local ++model_sequence
est restore i_adm_adj
local model_name = "icu admitted adjusted"
parmest, ///
	label list(parm label estimate min* max* p) ///
	idnum(`i') idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)
use `estimates_file', clear
gen table_order = _n
gen model_sequence = `model_sequence'
save `estimates_file', replace
use ../outputs/tables/$table_name.dta, clear
append using `estimates_file'
save ../outputs/tables/$table_name.dta, replace
local ++i



*  =========================================
*  = Now draw the confidence interval plot =
*  =========================================
use ../outputs/tables/$table_name.dta, clear
keep if parm == "beds_none"

cap label drop model_sequence
label define model_sequence 1 "Ward severity (all patients,  unadjusted)"
label define model_sequence 2 "Ward severity (all patients,  adjusted)", modify
label define model_sequence 3 "Ward severity (admitted patients,  adjusted)", modify
label define model_sequence 4 "ICU admission severity (admitted patients,  unadjusted)", modify
label define model_sequence 5 "ICU admission severity (admitted patients,  adjusted)", modify
label values model_sequence model_sequence
tab model_sequence

eclplot estimate min95 max95 model_sequence ///
	, ///
	horizontal ///
	rplottype(rspike) ///
	estopts(msymbol(D)) ///
	nociforeground ///
	xscale(noextend) ///
	xlab(-4(2)4, format(%9.1f)) ///
	xtitle("Mean change in ICNARC Acute Physiology Score" ///
			"when ICU has no beds at the time of the ward assessment") ///
	xline(0, lpattern(dot) lcolor(black) ) ///
	yscale(noextend) ///
	ytitle("") ///
	xsize(8) ysize(4)

graph rename icnarc0_beds_none_over_time, replace
graph export ../outputs/figures/icnarc0_beds_none_over_time.pdf ///
    , name(icnarc0_beds_none_over_time) replace

