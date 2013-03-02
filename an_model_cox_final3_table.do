*  ===================================================================================
*  = Produce tables comparing cox models and presenting co-efficients in final model =
*  ===================================================================================

use ../data/working_survival_tvc.dta, clear

global table_name cox_final3
tempfile estimates_file

// generate your own interaction terms - easier than extracing from stata notation
cap drop icnarc0_c_1_*
gen icnarc0_c_1_f = icnarc0_c * (tb == 1)
gen icnarc0_c_3_f = icnarc0_c * (tb == 3)
gen icnarc0_c_7_f = icnarc0_c * (tb == 7)

save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

// no time-varying so you can specify these as you wish
global confounders_notvc ///
	age_c ///
	male ///
	ib1.v_ccmds ///
	ib0.sepsis_dx ///
	periarrest ///
	cc_recommended

global confounders_tvc ///
	icnarc0_c ///
	icnarc0_c_1_f ///
	icnarc0_c_3_f ///
	icnarc0_c_7_f 

*  ========================
*  = Univariate estimates =
*  ========================
local i = 1
local model_sequence = 1
local table_order = 1

// start with the tvc univariate
use ../data/scratch/scratch.dta, clear
qui stcox $confounders_tvc
est store u_`i'
local model_name: word 4 of `=e(datasignaturevars)'
local model_name = "univariate `model_name'"
parmest, ///
	eform ///
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


// now for the other non-tvc univariates
local uni_vars $confounders_notvc defer4 icu_delay_nospike icu_delay_zero

foreach var of local uni_vars {
	use ../data/scratch/scratch.dta, clear
	qui stcox `var'
	est store u_`i'
	local model_name: word 4 of `=e(datasignaturevars)'
	local model_name = "univariate `model_name'"
	parmest, ///
		eform ///
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

*  ====================================
*  = Delay / immortal time bias model =
*  ====================================
local ++model_sequence
use ../data/scratch/scratch.dta, clear
// Delay with severity as time-varying
stcox $confounders_notvc $confounders_tvc ///
	defer4 if icucmp == 1

local model_name full immortal_bias
est store full1
parmest, ///
	eform ///
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

*  ====================================
*  = Defer / selection on observables =
*  ====================================
local ++model_sequence
use ../data/scratch/scratch.dta, clear
// defer (so all patients)
stcox $confounders_notvc $confounders_tvc ///
	defer4

local model_name full selection_bias
est store full1
parmest, ///
	eform ///
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

*  ============================
*  = Defer / information bias =
*  ============================
local ++model_sequence
use ../data/scratch/scratch.dta, clear
stcox $confounders_notvc $confounders_tvc ///
	icu_delay_nospike icu_delay_zero

local model_name full information_bias
est store full2
parmest, ///
	eform ///
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


*  ===================================
*  = Now produce the tables in latex =
*  ===================================
use ../outputs/tables/$table_name.dta, clear
qui include mt_Programs.do

cap drop model_sequence
gen model_name = model_sequence
cap label drop model_name
label define model_name 0 "Univariate"
label define model_name 1 "Admissions only", add
label define model_name 2 "All referrals", add
label define model_name 3 "Time-varying", add
label values model_name model_name
decode model_name, gen(model)

mt_extract_varname_from_parm
order model_sequence idnum varname var_level

// this does not work for factor variables - do this by hand
replace varname = "" if strpos(varname, "#") > 0
spot_label_table_vars

replace var_level = 0 if varname == "icnarc0" & var_level == .
replace var_level_lab = "Days 1--2 modifier"  if varname == "icnarc0" & var_level == 1
replace var_level_lab = "Days 3--7 modifier"  if varname == "icnarc0" & var_level == 3
replace var_level_lab = "Days 8+ modifier" if varname == "icnarc0" & var_level == 7
replace tablerowlabel = "Level 2/3 care recommended" if varname == "cc_recommended"
replace tablerowlabel = "Delay to critical care (per hour)" if varname == "icu_delay_nospike"
replace tablerowlabel = "Never admitted to critical care" if varname == "icu_delay_zero"
replace tablerowlabel = "Delay to critical care > 4 hours" if varname == "defer4"

global table_order ///
	age ///
	male ///
	v_ccmds ///
	sepsis_dx ///
	periarrest ///
	icnarc0 ///
	cc_recommended ///
	defer4 ///
	icu_delay_nospike ///
	icu_delay_zero

cap drop table_order
mt_table_order
sort model_sequence table_order var_level
order model_sequence table_order varname var_level
// indent categorical variables
mt_indent_categorical_vars
// replace missing values of model_sequence 
replace model_sequence = model_sequence[_n + 1] ///
	if gaprow == 1 & !missing(model_sequence[_n + 1])
gen est = estimate
sdecode estimate, format(%9.2fc) replace
replace stars = "\textsuperscript{" + stars + "}"
replace estimate = estimate + stars



exit

* drop idnum idstr  label stderr z stataformat ///
* 	attributes_found es_1 es_2 dummy table_pos_min model

* chardef tablerowlabel estimate, ///
* 	char(varname) prefix("\textit{") suffix("}") ///
* 	values("Parameter" "Hazard ratio")

order parm model_order table_order tablerowlabel estimate stars est min95 max95 p
br

xrewide estimate stars est min95 max95 p , ///
	i(table_order) j(model_name) cjlabel(models) lxjk(nonrowvars)


exit

