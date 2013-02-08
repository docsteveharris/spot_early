*  =============================================
*  = Understand patient flow through the study =
*  =============================================

GenericSetupSteveHarris spot_early an_figure_pt_flow, logon

use ../data/working.dta, clear
include cr_preflight.do
* NOTE: 2013-01-28 - drop if patient died at visit
drop if v_disp == 5

tab route_to_icu
save ../data/scratch/working.dta, replace

*  =====================================================
*  = Flow using spotlight data: i.e. available for all =
*  =====================================================
use ../data/scratch/working.dta, clear

* How many bedside assessments?
count
tab route_to_icu, missing


forvalues i = 0/1 {
	forvalues j = 0/2 {
		di "cc_recommend `i' cc_decision `j'"
		qui tab cc_decision cc_recommended
		tab icucmp if cc_recommended == `i' & cc_decision == `j'
	}
}

* NOTE: 2013-01-28 - transfer all of this to the observed pathways figure
* This becomes figure patient_flow_all


*  ================================================================================
*  = Now repeat the above in just those sites without complicated crit care units =
*  ================================================================================
use ../data/scratch/working.dta, clear

* How many bedside assessments?
egen pickone_site = tag(icode)
tab pickone_site

drop if all_cc_in_cmp == 0
tab pickone_site
* NOTE: 2013-01-28 - you lose 4 sites

count

* What was recommended
tab v_ccmds_rec, miss
cap drop cc_recommended 
gen cc_recommended = .
replace cc_recommended = 0 if inlist(v_ccmds,0,1)
replace cc_recommended = 1 if inlist(v_ccmds,2,3)
label values cc_recommended truefalse
tab cc_recommended


* What decison was made
tab v_disp, miss
cap drop cc_decision 
gen cc_decision = .
replace cc_decision = 0 if inlist(v_disposal,6,7)
replace cc_decision = 1 if inlist(v_disposal,3,4)
replace cc_decision = 2 if inlist(v_disposal,1,2)
label define cc_decision ///
	0 "No ward follow-up planned" ///
	0 "Ward follow-up planned" ///
	0 "Accepted to Critical care" 
tab cc_decision

tab cc_decision cc_recommended, col row

cap drop icucmp
gen icucmp = time2icu != .
label var icucmp "Admitted to ICU in CMP"
tab icucmp

forvalues i = 0/1 {
	forvalues j = 0/2 {
		di "cc_recommend `i' cc_decision `j'"
		qui tab cc_decision cc_recommended
		tab icucmp if cc_recommended == `i' & cc_decision == `j'
	}
}

* NOTE: 2013-01-28 - transfer all of this to the observed pathways figure
* This becomes figure patient_flow_uncomplicated


*  ===================================================
*  = Now flow through the study by physical location =
*  ===================================================
use ../data/scratch/working.dta, clear

tab icucmp
tab route_to_icu
tab dead_icu if icucmp == 1
tab ahsurv if dead_icu == 0 & icucmp == 1
tab dead28 if icucmp == 1
tab dead90 if icucmp == 1 and dead28  == 0

tab ahsurv if icucmp
tab dead90 if icucmp == 1

tab dead28 if icucmp == 0
tab dead90 if icucmp == 0 and dead28  == 0

tab dead90 if icucmp == 0

* This becomes figure patient_flow_physical

*  ===================================================================
*  = Now produce a table summarising patient flow for those admitted =
*  ===================================================================
use ../data/scratch/working.dta, clear



contract route_to_icu
sdecode route_to_icu, replace
drop if missing(route_to_icu)
egen percent = total(_freq)
replace percent = round(_freq / percent * 100,0.1)
sdecode _freq, format(%9.0gc) replace
sdecode percent, format(%9.1fc) replace ///
	prefix("(") suffix(")")

local vars route_to_icu _freq percent
chardef `vars', ///
	char(varname) ///
	prefix("\textit{") suffix("}") ///
	values( ///
		"ICU admission pathway" ///
		"Number" ///
		"(\%)" ///
		)


listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name pt_flow_pre_icu
local justify rrl
local tablefontsize "\normalsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}
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




cap log close