*  ===================
*  = Baseline tables =
*  ===================

GenericSetupSteveHarris spot_early an_tables_baseline_site_study, logon

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


*  ==========================================
*  = Now some description of study metrics  =
*  ==========================================
gen allreferrals_site = include > 0 & include != .
cap drop hes_emergencies_percent
keep if allreferrals_site == 1
total n include exclude*
su heads_count

cap drop analysed_perstudymonth
gen analysed_perstudymonth = round(analysed / studymonth_allreferrals_analysed)

cap drop include_pct
cap drop exclude1_pct
cap drop exclude2_pct
cap drop exclude3_pct
gen include_pct = round(100 * include / n)
gen exclude1_pct = round(100 * exclude1 / include)
gen exclude2_pct = round(100 * exclude2 / include)
gen exclude3_pct = round(100 * exclude3 / include)

* NOTE: 2013-01-09 - this reflects mean quality of included and excluded months
replace mean_site_quality = round(mean_site_quality)

local vars ///
	icode ///
	heads_count ///
	mean_site_quality ///
	valid_allfields ///
	crf_completeness ///
	include_pct ///
	exclude1_pct ///
	exclude2_pct ///
	exclude3_pct ///
	analysed ///
	analysed_perstudymonth

order `vars'
br `vars'
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
		"\% Data linkage (overall mean)" ///
		"\% data fields validated" ///
		"\% data fields complete" ///
		"\% CRFs meeting inclusion criteria" ///
		"\% CRFs excluded by design" ///
		"\% CRFs excluded by quality control" ///
		"\% CRFs lost-to-follow-up" ///
		"\% CRFs lost-to-follow-up" ///
		"Patients entering final analysis" ///
		"Patients analysed per study-month" ///
		)


listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name baseline_sites_study
local justify X[l]XXXXXXXXXXX
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


