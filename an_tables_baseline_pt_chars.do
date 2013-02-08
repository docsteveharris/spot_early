*  =========================
*  = Baseline patient data =
*  =========================

/*
Prepare table 1 for chapter that describes patient level characteristics

Patient
	Age
	Sex
	Level of care at assessment
	Clinically in extremis
	Referral timing
	Frequency of nursing observations

CHANGED: 2013-02-08 - now combined with visit outcome fields
	rx_visit
	rxlimits
	ccmds_delta
	v_decision

*/


*  =========================
*  = Define you table name =
*  =========================
GenericSetupSteveHarris spot_early an_tables_baseline_pt_chars, logon
global table_name baseline_pt_chars

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
	qui include cr_preflight.do
}

use ../data/working_postflight.dta, clear

*  ======================================
*  = Define column categories or byvars =
*  ======================================
* NOTE: 2013-02-07 - dummy variable for the byvar loop that forces use of all patients
cap drop by_all_patients
gen by_all_patients = 1
* NOTE: 2013-02-07 - label this value to create super-category label
label define by_all_patients 1 "All patients"
label values by_all_patients by_all_patients

local byvar by_all_patients
* Think of these as the gap row headings
local super_vars patient sepsis outcome

local patient age male v_ccmds vitals delayed_referral
local sepsis sepsis
local outcome rx_visit rxlimits ccmds_delta v_decision

* This is the layout of your table by sections
local table_vars ///
	`patient' ///
	`sepsis' ///
	`outcome'

* Specify the type of variable
local norm_vars
local skew_vars spo2 fio2_std uvol1h creatinine urea gcst ///
	hrate bpsys bpmap rrate temperature ///
	`laboratory'
local range_vars age
local bin_vars male periarrest delayed_referral hsinus rxrrt ///
	rxlimits
local cat_vars v_ccmds vitals sepsis rxcvs rx_resp avpu sepsis_site ///
	rx_visit ccmds_delta v_decision 

* CHANGED: 2013-02-05 - use the gap_here indicator to add gaps
* these need to be numbered as _1 etc
* Define the order of vars in the table
global table_order ///
	age gap_here_1 ///
	male gap_here_2 ///
	delayed_referral gap_here_3 ///
	sepsis gap_here_4 ///
	vitals gap_here_5 ///
	v_ccmds  gap_here_6 ///
	rxlimits gap_here_7 ///
	rx_visit gap_here_8 ///
	ccmds_delta gap_here_9 ///
	v_decision


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
local j = 1
foreach word of global lvl_labels {
	local bytext: word `j' of $lvl_labels
	local super_heading1 "`super_heading1' & \multicolumn{2}{c}{`bytext'} "
	local grp_size "`grp_size' patients"
	local super_heading2 "`super_heading2' & \multicolumn{2}{c}{`grp_size'} "
	local ++j
}
* NOTE: 2013-02-05 - you have an extra & at the beginning but this is OK as covers parameters
local grp_size: word 1 of $grp_sizes
local grp_size: di %9.0gc `grp_size'
local super_heading1 "& \multicolumn{2}{c}{`grp_size' patients}  \\"
* local super_heading1 " `super_heading1' \\"
* local super_heading2 " `super_heading2' \\"
* Prepare sub-headings
* local sub_heading "Mean/Median/Count (SD/IQR/\%)"
* CHANGED: 2013-02-07 - drop parameter from column heading and leave blank
* - if needed then Characteristic is preferred
* local sub_heading "& \multicolumn{2}{c}{`sub_heading'} &  \multicolumn{2}{c}{`sub_heading'} \\"

xrewide vcentral_fmt vbracket , ///
	i(seq) j(bylevel) ///
	lxjk(nonrowvars)

order seq tablerowlabel vcentral_fmt1 vbracket1

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
di "`gaprows'"
ingap `gaprows', gapindicator(gaprow)
replace tablerowlabel = tablerowlabel[_n + 1] ///
	if gaprow == 1 & !missing(tablerowlabel[_n + 1])
replace tablerowlabel = var_level_lab if var_type == "Categorical"
replace table_order = _n

* Indent subcategories
* NOTE: 2013-01-28 - requires the relsize package
replace tablerowlabel =  "\hspace*{1em}\smaller[1]{" + tablerowlabel + "}" if var_type == "Categorical"
* CHANGED: 2013-02-07 - by default do not append statistic type
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

local justify lrl

local tablefontsize "\footnotesize"
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
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{$table_name} " ///
		"\normalfont")

cap log off
