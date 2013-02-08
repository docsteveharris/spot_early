*  ====================================================
*  = Summarise mortality for model building variables =
*  ====================================================

/*
If you code this correctly then should be easy to re-do
- for probability of prompt admission (for the early chapter)
*/

GenericSetupSteveHarris spot_early an_table_binary_outcomes, logon

global table_name binary_outcomes
local patient_vars age_k sex sepsis_b delayed_referral icnarc_q5
local timing_vars out_of_hours weekend bed_pressure
local site_vars ///
	referrals_permonth_k ///
	ccot_shift_pattern ///
	hes_overnight_k ///
	hes_emergx_k ///
	cmp_beds_peradmx_k

* Create scratch data if needed / clean run

local clean_run 1
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	include cr_preflight.do
	keep dead7 dead28 dead90 icu4 `patient_vars' `timing_vars' `site_vars'
	save ../data/scratch/scratch.dta, replace
}

use ../data/scratch/scratch.dta, clear


* Think of these as the gap row headings
local super_vars patient_vars timing_vars site_vars

* This is the layout of your table by sections
local table_vars ///
	`patient_vars' ///
	`timing_vars' ///
	`site_vars'

* Now specify the distribution
local norm_vars
local skew_vars
local range_vars
local bin_vars
local cat_vars age_k

* Now specify the postfile ... and hence table columns
tempname pname
tempfile pfile
postfile `pname' ///
	int 	table_order ///
	str32	var_type ///
	str32 	var_super ///
	str32 	varname ///
	str96 	varlabel ///
	str64 	var_sub ///
	double 	vcentral1 ///
	double 	vmin1 ///
	double 	vmax1 ///
	double 	n1 ///
	double 	vcentral2 ///
	double 	vmin2 ///
	double 	vmax2 ///
	double 	n2 ///
	using `pfile' , replace

global growlabels
local table_order 1
foreach var of local table_vars {
	local varname `var'
	local varlabel: variable label `var'
	global growlabels `" $growlabels "`varlabel'" "'
	local var_sub
	// Little routine to pull the super category
	local super_var_counter = 1
	foreach super_var of local super_vars {
		local check_in_super: list posof "`var'" in `super_var'
		if `check_in_super' {
			local var_super: word `super_var_counter' of `super_vars'
			continue, break
		}
		local var_super
		local super_var_counter = `super_var_counter' + 1
	}

	tempvar var_labels
	decode `var', gen(`var_labels')
	levelsof `var_labels', clean local(llabel)
	levelsof `var', clean local(var_levels)
	local i = 1
	foreach lvl of local var_levels {

		local var_sub: label(`var') `lvl'

		// NOTE: 2013-01-31 - for early vs deferred
		// ci icu4 if `var' == `lvl', binomial
		ci dead28 if `var' == `lvl', binomial
		local vcentral1 	= r(mean)
		local vmin1 		= r(lb)
		local vmax1 		= r(ub)
		local n1 			= r(N)

		ci dead90 if `var' == `lvl', binomial
		local vcentral2 	= r(mean)
		local vmin2 		= r(lb)
		local vmax2 		= r(ub)
		local n2 			= r(N)

		post `pname' ///
			(`table_order') ///
			("`var_type'") ///
			("`var_super'") ///
			("`varname'") ///
			("`varlabel'") ///
			("`var_sub'") ///
			(`vcentral1') ///
			(`vmin1') ///
			(`vmax1') ///
			(`n1') ///
			(`vcentral2') ///
			(`vmin2') ///
			(`vmax2') ///
			(`n2')

		local ++i
		local ++table_order

	}


}

postclose `pname'
use `pfile', clear
qui compress
br
save ../outputs/tables/$table_name.dta, replace

*  =========================
*  = Now produce the table =
*  =========================
use ../outputs/tables/$table_name.dta, clear

replace vcentral1 = 100 * vcentral1
replace vmin1 = 100 * vmin1
replace vmax1 = 100 * vmax1
sdecode vcentral1 , format(%9.1fc) replace
sdecode vmin1, format(%9.1fc) replace
sdecode vmax1, format(%9.1fc) replace
sdecode n1, format(%9.0gc) replace
gen vbracket1 = "(" + vmin1 + "--" + vmax1 + ")"

replace vcentral2 = 100 * vcentral2
replace vmin2 = 100 * vmin2
replace vmax2 = 100 * vmax2
sdecode vcentral2 , format(%9.1fc) replace
sdecode vmin2, format(%9.1fc) replace
sdecode vmax2, format(%9.1fc) replace
sdecode n2, format(%9.0gc) replace
gen vbracket2 = "(" + vmin2 + "--" + vmax2 + ")"

gen tablerowlabel = var_sub
order tablerowlabel vcentral1 vbracket1 vcentral2 vbracket2
* bys varlabel: ingap, growlabel($growlabels) row(tablerowlabel) gapindicator(gap)
gen var_order = _n
bysort varname (table_order): replace var_order = var_order[1]
bys varname varlabel: ingap, row(tablerowlabel) gapindicator(gap) neworder(gap_order)
replace tablerowlabel = varlabel if gap == 1
replace var_order = var_order[_n + 1] if var_order == .
sort var_order gap_order

* Indent subcategories
* NOTE: 2013-01-28 - requires the relsize package
replace tablerowlabel =  "\hspace*{1em}\smaller[0]{" + tablerowlabel + "}" ///
	if gap == 0

br tablerowlabel n1 vcentral1 vbracket1 vcentral2 vbracket2

local vars tablerowlabel n1 vcentral1 vbracket1 vcentral2 vbracket2

* chardef `vars', ///
* 	char(varname) ///
* 	prefix("\textit{") suffix("}") ///
* 	values("" "Early ICU" "" "28 day mortality" "")

* listtab_vars `vars', ///
* 	begin("") delimiter("&") end(`"\\"') ///
* 	substitute(char varname) ///
* 	local(h1)

local h1 `" &N& \multicolumn{2}{l}{28 day mortality} &\multicolumn{2}{l}{90 day mortality} \\ "'
local h2 `" && \multicolumn{2}{l}{\smaller[1]{\% (95\% CI)}} &\multicolumn{2}{l}{\smaller[1]{\% (95\% CI)}} \\ "'


local justify lrrlrl
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}
/*
NOTE: 2013-01-28 - needed in the pre-amble for colors
\usepackage[usenames,dvipsnames,svgnames,table]{xcolor}
\definecolor{gray90}{gray}{0.9}
*/

listtab  `vars' ///
	using ../outputs/tables/$table_name.tex, ///
	replace rstyle(tabular) ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\sffamily{" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		/* "\cmidrule(r){2-3}" */ ///
		"`h1'" ///
		"`h2'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{$table_name} " ///
		"\normalfont" ///
		"\normalsize")

cap log close