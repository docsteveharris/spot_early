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

// convert to wide
tempfile working 2merge
cap restore, not
preserve
local wide_vars estimate stderr z p stars min95 max95
forvalues i = 1/4 {
	keep parm model_sequence `wide_vars'
	keep if model_sequence == `i'
	foreach name in `wide_vars' {
		rename `name' `name'_`i'
	}
	save `2merge', replace
	if `i' == 1 {
		save `working', replace
	}
	else {
		use `working', clear
		merge 1:1 parm using `2merge'
		drop _merge
		save `working', replace
	}
	restore
	preserve

}
restore, not
use `working', clear
qui include mt_Programs.do

cap drop model_name
gen model_name = model_sequence
cap label drop model_name
label define model_name 1 "Univariate"
label define model_name 2 "Admissions only", add
label define model_name 3 "All referrals", add
label define model_name 4 "Time-varying", add
label values model_name model_name
decode model_name, gen(model)

mt_extract_varname_from_parm
order model_sequence varname var_level

// label the vars
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

mt_table_order
sort table_order var_level

forvalues i = 1/4 {
	gen est_raw_`i' = estimate_`i'
	sdecode estimate_`i', format(%9.2fc) replace
	replace stars_`i' = "\textsuperscript{" + stars_`i' + "}"
	replace estimate_`i' = estimate_`i' + stars_`i'
	replace estimate_`i' = "--" if parm == "1b.v_ccmds"
	replace estimate_`i' = "--" if parm == "0b.sepsis_dx"
	replace estimate_`i' = "" if est_raw_`i' == .
}

// indent categorical variables
mt_indent_categorical_vars

ingap 15 19 20 21

// now send the table to latex
local cols tablerowlabel estimate_1 estimate_2 estimate_3 estimate_4
order `cols'

local super_heading "& \multicolumn{4}{c}{Hazard ratio} \\"
local h1 "& Univariate & Admissions only & All referrals & Time-varying \\ "
local justify lXXXX
local tablefontsize "\footnotesize"
local taburowcolors 2{white .. white}

listtab `cols' ///
	using ../outputs/tables/$table_name.tex, ///
	replace  ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`super_heading'" ///
		"\cmidrule(r){2-5}" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu}  " ///
		"\label{tab: $table_name} ") 

*  ==========================
*  = Final best model table =
*  ==========================
// now produce the final table with 95% CI etc in usual format
gen estimate = est_raw_4
gen min95 = min95_4
gen max95 = max95_4
gen p = p_4

sdecode estimate, format(%9.2fc) gen(est)
sdecode min95, format(%9.2fc) replace
sdecode max95, format(%9.2fc) replace
sdecode p, format(%9.3fc) replace
replace p = "<0.001" if p == "0.000"
gen est_ci95 = "(" + min95 + "--" + max95 + ")" if !missing(min95, max95)
replace est = "--" if reference_cat == 1
replace est_ci95 = "" if reference_cat == 1

* now write the table to latex
order tablerowlabel var_level_lab est est_ci95 p
local cols tablerowlabel est est_ci95 p
order `cols'
cap br

local table_name cox_final3_best
local h1 "Parameter & Odds ratio & (95\% CI) & p \\ "
local justify lrll
* local justify X[5l] X[1l] X[2l] X[1r]
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}

listtab `cols' ///
	using ../outputs/tables/`table_name'.tex ///
	if !inlist(_n,23,24), ///
	replace ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} to " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} " ///
		"\label{tab:`table_name'} ") ///


