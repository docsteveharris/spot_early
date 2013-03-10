*  ====================================================
*  = Intstrumental variables approach using occupancy =
*  ====================================================

/*
- treat the outcome as linear as per recommendations of Angrist
*/

use ../data/working_postflight.dta, clear
global table_name linear_iv
tempfile estimates_file

global conf_outcome ///
	age_c ///
	male ///
	ib1.v_ccmds ///
	ib0.sepsis_dx ///
	periarrest ///
	cc_recommended ///
	icnarc0_c

ivregress 2sls dead28 $conf_outcome ///
	(early4 = beds_none)

ivregress liml dead28 $conf_outcome ///
	(early4 = beds_none)
est store liml

ivregress gmm dead28 $conf_outcome ///
	(early4 = beds_none)


// all estimation methods give roughly the same answer
// now latexify
est restore liml
parmest, ///
	label list(parm label estimate min* max* p) ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)

use `estimates_file', clear
save ../outputs/tables/$table_name, replace

*  ============
*  = Latexify =
*  ============

use ../outputs/tables/$table_name.dta, clear
drop if parm == "_cons"

qui include mt_Programs.do
mt_extract_varname_from_parm

// label the vars
spot_label_table_vars

global table_order ///
	age ///
	male ///
	v_ccmds ///
	sepsis_dx ///
	periarrest ///
	icnarc0 ///
	cc_recommended 

mt_table_order

sort table_order var_level

replace tablerowlabel = "Level 2/3 care recommended" if varname == "cc_recommended"
replace tablerowlabel = "Delay to critical care > 4 hours" if varname == "early4"


// indent categorical variables
mt_indent_categorical_vars

ingap 14 17

sdecode estimate, format(%9.3fc) gen(est)
sdecode min95, format(%9.3fc) replace
sdecode max95, format(%9.3fc) replace
sdecode p, format(%9.3fc) replace
replace p = "<0.001" if p == "0.000"
gen est_ci95 = "(" + min95 + " -- " + max95 + ")" if !missing(min95, max95)
replace est = "--" if reference_cat == 1
replace est_ci95 = "" if reference_cat == 1

* now write the table to latex
order tablerowlabel var_level_lab est est_ci95 p
local cols tablerowlabel est est_ci95 p
order `cols'
cap br

local table_name $table_name
local h1 "Parameter & ATE & (95\% CI) & p \\ "
local justify lrcr
* local justify X[5l] X[1l] X[2l] X[1r]
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}

listtab `cols' ///
	using ../outputs/tables/`table_name'.tex ///
	if parm != "_cons", ///
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


cap log close
