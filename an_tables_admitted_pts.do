* =============================
* = Analyse admitted patients =
* =============================

* GenericSetupSteveHarris spot_early an_tables_admitted_pts, logon
use ../data/working_tails.dta, clear
count
icmsplit raicu1
icm raicu1, gen(diagcode1) desc ap2 replace

drop if !spotlight
contract desc
drop if missing(desc)
gsort - _freq
keep in 1/50
gen rank = _n

egen percent = total(_freq)
replace percent = round(_freq / percent * 100,0.1)
sdecode _freq, format(%9.0gc) replace
sdecode percent, format(%9.1fc) replace ///
	prefix("(") suffix(")")

local vars rank desc _freq percent
chardef `vars', ///
	char(varname) ///
	prefix("\textit{") suffix("}") ///
	values( ///
		"Rank" ///
		"Primary reason for ICU admission" ///
		"Number" ///
		"(\%)" ///
		)


listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name admitted_pts_diagnosis
local justify llrl
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




cap log close