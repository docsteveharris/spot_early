*  =========================================================
*  = Produce tables summarising different severity metrics =
*  =========================================================

/*
- Sepsis severity
- NEWS severity
- Organ failure??
*/

* GenericSetupSteveHarris spot_early an_tables_severity, logon
local clean_run 0
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
}

*  ===============
*  = Sepsis 2001 =
*  ===============
use sepsis2001 using ../data/working_postflight.dta, clear
contract sepsis2001
egen percent = total(_freq)
replace percent = round(_freq / percent * 100,0.1)
sdecode _freq, format(%9.0gc) gen(count)
sdecode percent, format(%9.1fc) replace ///
	prefix("(") suffix(")")
sdecode sepsis2001, gen(tablerowname)

replace tablerowname = "No SIRS" if sepsis2001 == 0

local vars tablerowname count percent 
chardef `vars', ///
	char(varname) ///
	prefix("\textit{") suffix("}") ///
	values( ///
		"Sepsis status" ///
		"Number" ///
		"(\%)" ///
		)


listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name severity_sepsis2001
local justify lrl
local tablefontsize "\small"
local arraystretch 1.2
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

*  =============
*  = NEWS risk =
*  =============
use news_risk using ../data/working_postflight.dta, clear
contract news_risk
egen percent = total(_freq)
replace percent = round(_freq / percent * 100,0.1)
sdecode _freq, format(%9.0gc) gen(count)
sdecode percent, format(%9.1fc) replace ///
	prefix("(") suffix(")")
sdecode news_risk, gen(tablerowname)


local vars tablerowname count percent 
chardef `vars', ///
	char(varname) ///
	prefix("\textit{") suffix("}") ///
	values( ///
		"NEWS risk" ///
		"Number" ///
		"(\%)" ///
		)


listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name severity_news_risk
local justify lrl
local tablefontsize "\small"
local arraystretch 1.2
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