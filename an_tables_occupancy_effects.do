*  ============================================
*  = Describe the simple effects of occupancy =
*  ============================================

/*
By bed pressure
	- beds
	- no beds but discharges possible
	- no beds and no discharges
Report
	- Number
	- ICU
		- recommend
		- accept
		- deliver
	- Time to ICU
	- Severity at admission
*/


*  =========================
*  = Define you table name =
*  =========================

GenericSetupSteveHarris spot_early an_tables_occupancy_effects, logon
global table_name occupancy_effects

/*
You will need the following columns
- sort order
- varname
- var_super (variable super category)
- value
- min
- max
*/

local clean_run 0
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	include cr_preflight.do
	include cr_working_tails.do
}

use ../data/working_tails.dta, clear
keep icnno adno imscore
tempfile 2merge
save `2merge', replace
use ../data/working_postflight.dta, clear
// double check that icnno and adno are unique
duplicates report icnno adno
merge m:1 icnno adno using `2merge'
drop _m
keep imscore time2icu early4 icu_accept icu_recommend id bed_pressure
save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

*  ======================================
*  = Define column categories or byvars =
*  ======================================
* NOTE: 2013-02-07 - dummy variable for the byvar loop that forces use of all patients

local byvar bed_pressure

* This is the layout of your table by sections
local table_vars ///
	icu_recommend ///
	icu_accept ///
	early4 ///
	time2icu ///
	imscore

* Specify the type of variable
local norm_vars imscore
local skew_vars time2icu
local range_vars
local bin_vars icu_recommend icu_accept early4
local cat_vars

* CHANGED: 2013-02-05 - use the gap_here indicator to add gaps
* these need to be numbered as _1 etc
* Define the order of vars in the table
global table_order ///
	icu_recommend ///
	icu_accept ///
	early4 gap_here ///
	time2icu gap_here ///
	imscore

* number the gaps
local i = 1
local table_order
foreach word of global table_order {
	if "`word'" == "gap_here" {
		local w `word'_`i'
		local ++i
	}
	else {
		local w `word'
	}
	local table_order `table_order' `w'
}
global table_order `table_order'


tempname pname
tempfile pfile
postfile `pname' ///
	int 	bylevel ///
	int 	table_order ///
	str32	var_type ///
	str32 	var_super ///
	str32 	varname ///
	str96 	varlabel ///
	str64 	var_sub ///
	int 	var_level ///
	double 	vcentral ///
	double 	vmin ///
	double 	vmax ///
	double 	vother ///
	using `pfile' , replace

tempfile working
save `working', replace
levelsof `byvar', clean local(bylevels)
foreach lvl of local bylevels {
	use `working', clear
	keep if `byvar' == `lvl'
	local lvl_label: label (`byvar') `lvl'
	local lvl_labels `lvl_labels' `lvl_label'
	count
	local grp_sizes `grp_sizes' `=r(N)'
	local table_order 1
	foreach var of local table_vars {
		local varname `var'
		local varlabel: variable label `var'
		local var_sub
		// CHANGED: 2013-02-05 - in theory you should not have negative value labels
		local var_level -1
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

		// Now assign values base on the type of variable
		local check_in_list: list posof "`var'" in norm_vars
		if `check_in_list' > 0 {
			local var_type	= "Normal"
			su `var'
			local vcentral 	= r(mean)
			local vmin		= .
			local vmax		= .
			local vother 	= r(sd)
		}

		local check_in_list: list posof "`var'" in bin_vars
		if `check_in_list' > 0 {
			local var_type	= "Binary"
			count if `var' == 1
			local vcentral 	= r(N)
			local vmin		= .
			local vmax		= .
			su `var'
			local vother 	= r(mean) * 100
		}

		local check_in_list: list posof "`var'" in skew_vars
		if `check_in_list' > 0 {
			local var_type	= "Skewed"
			su `var', d
			local vcentral 	= r(p50)
			local vmin		= r(p25)
			local vmax		= r(p75)
			local vother 	= .
		}

		local check_in_list: list posof "`var'" in range_vars
		if `check_in_list' > 0 {
			local var_type	= "Skewed"
			su `var', d
			local vcentral 	= r(p50)
			local vmin		= r(min)
			local vmax		= r(max)
			local vother 	= .
		}

		local check_in_list: list posof "`var'" in cat_vars
		if `check_in_list' == 0 {
			post `pname' ///
				(`lvl') ///
				(`table_order') ///
				("`var_type'") ///
				("`var_super'") ///
				("`varname'") ///
				("`varlabel'") ///
				("`var_sub'") ///
				(`var_level') ///
				(`vcentral') ///
				(`vmin') ///
				(`vmax') ///
				(`vother')

			local table_order = `table_order' + 1
			continue
		}

		// Need a different approach for categorical variables
		cap restore, not
		preserve
		contract `var'
		rename _freq vcentral
		egen vother = total(vcentral)
		replace vother = vcentral / vother * 100
		decode `var', gen(var_sub)
		drop if missing(`var')
		local last = _N

		forvalues i = 1/`last' {
			local var_type	= "Categorical"
			local var_sub	= var_sub[`i']
			local var_level	= `var'[`i']
			local vcentral 	= vcentral[`i']
			local vmin		= .
			local vmax		= .
			local vother 	= vother[`i']

		post `pname' ///
			(`lvl') ///
			(`table_order') ///
			("`var_type'") ///
			("`var_super'") ///
			("`varname'") ///
			("`varlabel'") ///
			("`var_sub'") ///
			(`var_level') ///
			(`vcentral') ///
			(`vmin') ///
			(`vmax') ///
			(`vother')


		local table_order = `table_order' + 1
		}
		restore

	}
}
global lvl_labels `lvl_labels'
global grp_sizes `grp_sizes'
postclose `pname'
use `pfile', clear
qui compress
br

*  ===================================================================
*  = Now you need to pull in the table row labels, units and formats =
*  ===================================================================
spot_label_table_vars
save ../outputs/tables/$table_name.dta, replace
order bylevel tablerowlabel var_level var_level_lab

*  ===============================
*  = Now produce the final table =
*  ===============================
/*
Now you have a dataset that represents the table you want
- one row per table row
- each uniquely keyed

Now make your final table
All of the code below is generic except for the section that adds gaps
*/

use ../outputs/tables/$table_name.dta, clear
gen var_label = tablerowlabel

* Define the table row order
local table_order $table_order

cap drop table_order
gen table_order = .
local i = 1
foreach var of local table_order {
	replace table_order = `i' if varname == "`var'"
	local ++i
}
* CHANGED: 2013-02-07 - try and reverse sort severity categories
gsort +bylevel +table_order -var_level
bys bylevel: gen seq = _n

* Now format all the values
cap drop vcentral_fmt
cap drop vmin_fmt
cap drop vmax_fmt
cap drop vother_fmt

gen vcentral_fmt = ""
gen vmin_fmt = ""
gen vmax_fmt = ""
gen vother_fmt = ""

*  ============================
*  = Format numbers correctly =
*  ============================
local lastrow = _N
local i = 1
while `i' <= `lastrow' {
	di varlabel[`i']
	local stataformat = stataformat[`i']
	di `"`stataformat'"'
	foreach var in vcentral vmin vmax vother {
		// first of all specific var formats
		local formatted : di `stataformat' `var'[`i']
		di `formatted'
		replace `var'_fmt = "`formatted'" ///
			if _n == `i' ///
			& !inlist(var_type[`i'],"Binary", "Categorical") ///
			& !missing(`var'[`i'])
		// now binary and categorical vars
		local format1 : di %9.0gc `var'[`i']
		local format2 : di %9.1fc `var'[`i']
		replace `var'_fmt = "`format1'" if _n == `i' ///
			& "`var'" == "vcentral" ///
			& inlist(var_type[`i'],"Binary", "Categorical") ///
			& !missing(`var'[`i'])
		replace `var'_fmt = "`format2'" if _n == `i' ///
			& "`var'" == "vother" ///
			& inlist(var_type[`i'],"Binary", "Categorical") ///
			& !missing(`var'[`i'])
	}
	local ++i
}
cap drop vbracket
gen vbracket = ""
replace vbracket = "(" + vmin_fmt + "--" + vmax_fmt + ")" if !missing(vmin_fmt, vmax_fmt)
replace vbracket = "(" + vother_fmt + ")" if !missing(vother_fmt)
replace vbracket = subinstr(vbracket," ","",.)

* Append units
* CHANGED: 2013-01-25 - test condition first because unitlabel may be numeric if all missing
cap confirm string var unitlabel
if _rc {
	tostring unitlabel, replace
	replace unitlabel = "" if unitlabel == "."
}
replace tablerowlabel = tablerowlabel + " (" + unitlabel + ")" if !missing(unitlabel)


order tablerowlabel vcentral_fmt vbracket
* NOTE: 2013-01-25 - This adds gaps in the table: specific to this table

br tablerowlabel vcentral_fmt vbracket


chardef tablerowlabel vcentral_fmt vbracket, ///
	char(varname) ///
	prefix("\textit{") suffix("}") ///
	values("Characteristic" "Value" "")

listtab_vars tablerowlabel vcentral_fmt vbracket, ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

*  ==============================
*  = Now convert to wide format =
*  ==============================
keep bylevel table_order tablerowlabel vcentral_fmt vbracket seq ///
	varname var_type var_label var_level_lab var_level

chardef tablerowlabel vcentral_fmt, ///
	char(varname) prefix("\textit{") suffix("}") ///
	values("Parameter" "Value")

*  ============================
*  = Prepare super categories =
*  ============================
local textwrap "p{\dimexpr 3\tabucolX+2\tabcolsep+\arrayrulewidth\relax}"
local j = 1
foreach grp_size of global grp_sizes {
	local grp_size: di %9.0gc `grp_size'
	local grp_size "`grp_size' patients"
	local super_heading2 "`super_heading2' & \multicolumn{2}{l}{`grp_size'} "
	local ++j
}
local super_heading2 " `super_heading2' \\"
di "`super_heading2'"
local super_heading1 "`super_heading1' & \multicolumn{2}{`textwrap'}{Beds available}"
local super_heading1 "`super_heading1' & \multicolumn{2}{`textwrap'}{No beds but discharges pending}"
local super_heading1 "`super_heading1' & \multicolumn{2}{`textwrap'}{No beds and no discharges pending}"
local super_heading1 " `super_heading1' \\"


xrewide vcentral_fmt vbracket , ///
	i(seq) j(bylevel) ///
	lxjk(nonrowvars)

order seq tablerowlabel vcentral_fmt0 vbracket0 vcentral_fmt1 vbracket1 vcentral_fmt2 vbracket2

* Now add in gaps or subheadings
save ../data/scratch/scratch.dta, replace
clear
local table_order $table_order
local obs = wordcount("`table_order'")
set obs `obs'
gen design_order = .
gen varname = ""
local i 1
foreach var of local table_order {
	local word_pos: list posof "`var'" in table_order
	replace design_order = `i' if _n == `word_pos'
	replace varname = "`var'" if _n == `word_pos'
	local ++i
}

joinby varname using ../data/scratch/scratch.dta, unmatched(both)
gsort +design_order -var_level
drop seq _merge

*  ==================================================================
*  = Add a gap row before categorical variables using category name =
*  ==================================================================
local lastrow = _N
local i = 1
local gaprows
while `i' <= `lastrow' {
	// CHANGED: 2013-01-25 - changed so now copes with two different but contiguous categorical vars
	if varname[`i'] == varname[`i' + 1] ///
		& varname[`i'] != varname[`i' - 1] ///
		& var_type[`i'] == "Categorical" {
		local gaprows `gaprows' `i'
	}
	local ++i
}
di length("`gaprows'")
di "`gaprows'"
* CHANGED: 2013-02-17 - now check to see if gaprows needed for cat vars
if "`gaprows'" != "" {
	ingap `gaprows', gapindicator(gaprow)
	replace tablerowlabel = tablerowlabel[_n + 1] ///
		if gaprow == 1 & !missing(tablerowlabel[_n + 1])
	replace tablerowlabel = var_level_lab if var_type == "Categorical"
	replace table_order = _n
	// Indent subcategories
	// NOTE: 2013-01-28 - requires the relsize package
	replace tablerowlabel =  "\hspace*{1em}\smaller[1]{" + tablerowlabel + "}" if var_type == "Categorical"
	// CHANGED: 2013-02-07 - by default do not append statistic type
	local append_statistic_type 0
	if `append_statistic_type' {
		local median_iqr 	"\smaller[1]{--- median (IQR)}"
		local n_percent 	"\smaller[1]{--- N (\%)}"
		local mean_sd 		"\smaller[1]{--- mean (SD)}"
		replace tablerowlabel = tablerowlabel + " `median_iqr'" if var_type == "Skewed"
		replace tablerowlabel = tablerowlabel + " `mean_sd'" if var_type == "Normal"
		replace tablerowlabel = tablerowlabel + " `n_percent'" if var_type == "Binary"
		replace tablerowlabel = tablerowlabel + " `n_percent'" if gaprow == 1
	}
}


*  ================================
*  = Edits specific to this table =
*  ================================
ingap 1
replace tablerowlabel = "Critical care" if _n == 1
replace tablerowlabel = "\hspace*{1em}--- recommended" if varname == "icu_recommend"
replace tablerowlabel = "\hspace*{1em}--- accepted" if varname == "icu_accept"
replace tablerowlabel = "\hspace*{1em}--- admitted (within 4 hrs)" if varname == "early4"
local midrules 	`" " \cmidrule(r){2-3}" "\cmidrule(r){4-5}" "\cmidrule(r){6-7}" "'


local justify {X[9l]X[r]X[3l]X[r]X[3l]X[r]X[3l]}
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}
/*
Use san-serif font for tables: so \sffamily {} enclosed the whole table
Add a label to the table at the end for cross-referencing
*/
listtab tablerowlabel `nonrowvars'  ///
	using ../outputs/tables/$table_name.tex, ///
	replace rstyle(tabular) ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"\sffamily{" ///
		"\begin{tabu} to " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`super_heading1'" ///
		`midrules' ///
		"`super_heading2'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{$table_name} " ///
		"\normalfont")

cap log off
