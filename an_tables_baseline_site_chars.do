*  ===================
*  = Baseline tables =
*  ===================

GenericSetupSteveHarris spot_early an_tables_baseline_sites, logon

*  ===========================================================
*  = Pull together data from all patients at all study sites =
*  ===========================================================
clear
use ../data/working_raw.dta
keep icode dorisname allreferrals site_quality_q1
gsort icode dorisname -allreferrals
egen pickone = tag(icode)
drop if pickone == 0
count
tempfile working
save `working', replace

preserve
use ../data/working_all,clear
keep icode idvisit include exclude1-exclude3 filled_fields_count _valid_allfields
rename _valid_allfields valid_allfields
gen analysed = include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
label var analysed "Patient to analyse"
collapse ///
	(mean) filled_fields_count valid_allfields ///
	(count) n = include ///
	(sum) include exclude1-exclude3 analysed, ///
	by(icode)

replace valid_allfields = round(100 * valid_allfields)

gen crf_completeness = round(filled_fields_count / 48 * 100)
label var crf_completeness "Median percentage of CRF completed"
label var exclude1 "Exclude - by design"
label var exclude2 "Exclude - by choice"
label var exclude3 "Exclude - lost to follow-up"

tempfile 2merge
save `2merge',replace
restore

merge 1:1 icode using `2merge'
drop _m pickone

merge 1:1 icode using ../data/sites.dta
sort dorisname
drop _m

*  =============================
*  = Now prepare summary table =
*  =============================
/*
- 1 row per site
- keep all sites for now
- then the following columns
	- hes_overnight
	- proportion of these that are emergencies
*/

cap drop hes_overnight
gen hes_overnight = hes_admissions - hes_daycase
label var hes_overnight "HES (overnight) admissions"
cap drop allreferrals_site
gen allreferrals_site = include > 0 & include != .
cap drop hes_emergencies_percent
gen hes_emergencies_percent = round(hes_emergencies / hes_overnight * 100)
cap drop hes_overnight_1000
gen hes_overnight_1000 = round(hes_overnight / 1000)
cap drop simple_site
gen simple_site = all_cc_in_cmp == 1 & tails_othercc == 0
label var simple_site "All critical care provided in CMP units"

local table_vars icode dorisname hes_overnight_1000 ///
	hes_emergencies_percent ///
	ccot_shift_pattern ///
	cmp_beds_persite ///
	simple_site ///
	cmp_patients_permonth ///
	tails_all_percent

order `table_vars'
br `table_vars' if allreferrals_site == 1

* CHANGED: 2013-01-25 - now export directly to latex
* cap restore, not
* preserve
keep if allreferrals_site == 1
local vars icode hes_overnight_1000 hes_emergencies_percent ccot_shift_pattern cmp_beds_persite cmp_patients_permonth tails_all_percent
keep `vars'
sort icode
* Convert to string var
foreach var of local vars {
	cap confirm string var `var'
	if !_rc continue
	sdecode `var', replace
}
chardef `vars', ///
	char(varname) ///
	prefix("\textit{") suffix("}") ///
	values( ///
		"Site code" ///
		"Hospital overnight admissions (1000's/yr)" ///
		"Emergency admissions (\%)" ///
		"Critical care outreach" ///
		"Critical care beds" ///
		"Critical care admissions (per month)" ///
		"Emergency ward admissions to critical care (\%)" ///
		)


listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name baseline_sites_chars
local justify X[l]X[m]X[m]X[3m]X[m]X[m]X[m]
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. gray90}
/*
NOTE: 2013-01-28 - needed in the pre-amble for colors
\usepackage[usenames,dvipsnames,svgnames,table]{xcolor}
\definecolor{gray90}{gray}{0.9}
*/

listtab `vars' ///
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
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{$table_name} " ///
		"\normalfont" ///
		"\normalsize")

* restore
* preserve



