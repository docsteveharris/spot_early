*  =================================
*  = Figures: time2icu by decision =
*  =================================

use ../data/working_postflight.dta, clear
bys cc_decision: su time2icu

// get the maximum (95th centile) for the watch grp
su time2icu if cc_decision == 1, d
local xlimit = r(p95) 

su time2icu if cc_decision == 2, d
local pctile_list 0
foreach i in 50 95 {
	local p`i': di %9.1fc `=r(p`i')'
	di "`p`i''"
	local pctile_list `pctile_list' `p`i''
	if `i' == 50 {
		local new_label `" `p`i'' "{bf:`i'{superscript:}}" "'
	}
	else {
		local new_label `" `p`i'' "`i'{superscript:}" "'
	}
	di `"`new_label'"'
	local pctile_labels `"`pctile_labels' `new_label' "'
}
local pctile_list `pctile_list' `xlimit'
di "`pctile_list'"
di `"`pctile_labels'"'

count if cc_decision == 2 & time2icu != .
local count_patients: di %9.0fc `=r(N)'
local count_patients = trim("`count_patients'")

tw hist time2icu ///
	if cc_decision == 2 & time2icu < `xlimit' ///
	, ///
	xaxis( 1 2) ///
	s(0) w(2) freq ///
	xlab(`pctile_list', axis(2) ) ///
	xscale(noextend axis(2) alt) ///
	xtitle( ///
		"Time to critical care (hours) and centiles (50{superscript:th} and 95{superscript:th})" ///
		, axis(2)) ///
	xlab(`pctile_labels', axis(1) angle(90) labsize(small) ) ///
	xscale(noextend axis(1) noline ) ///
	xtitle("", axis(1)) ///
	ylab(,nogrid) ///
	ytitle("Patients") ///
	yscale(noextend) ///
	text(1500 `xlimit' "(A) Accepted and admitted to critical care" "(`count_patients' patients)" ///
		, justification(right) placement(w))

graph rename time2icu_accept, replace

su time2icu if cc_decision == 1, d
local pctile_list 0
local pctile_labels
foreach i in 25 50 75 95 {
	local p`i': di %9.1fc `=r(p`i')'
	di "`p`i''"
	local pctile_list `pctile_list' `p`i''
	if `i' == 50 {
		local new_label `" `p`i'' "{bf:`i'{superscript:}}" "'
	}
	else {
		local new_label `" `p`i'' "`i'{superscript:}" "'
	}
	di `"`new_label'"'
	local pctile_labels `"`pctile_labels' `new_label' "'
}
di "`pctile_list'"
di `"`pctile_labels'"'

count if cc_decision == 1 & time2icu != .
local count_patients: di %9.0fc `=r(N)'
local count_patients = trim("`count_patients'")

tw hist time2icu ///
	if cc_decision == 1 & time2icu < `xlimit' ///
	, ///
	xaxis( 1 2) ///
	s(0) w(2) freq ///
	xlab(`pctile_list', axis(2) ) ///
	xscale(noextend axis(2) alt) ///
	xtitle( ///
		"Time to critical care (hours) and centiles (25{superscript:th}, 50{superscript:th}, 75{superscript:th}, and 95{superscript:th})" ///
		, axis(2)) ///
	xlab(`pctile_labels', axis(1) angle(90) labsize(small) ) ///
	xscale(noextend axis(1) noline ) ///
	xtitle("", axis(1)) ///
	ylab(,nogrid) ///
	ytitle("Patients") ///
	yscale(noextend) ///
	text(150 `xlimit' "(B) Inital ward follow-up and late critical care admission" "(`count_patients' patients)" ///
		, justification(right) placement(w))

graph rename time2icu_watch, replace
graph combine time2icu_accept time2icu_watch, cols(1) 
graph rename time2icu_by_decision, replace
graph display time2icu_by_decision

graph export ../outputs/tables/time2icu_by_decision.pdf ///
    , name(time2icu_by_decision) replace

    
su time2icu if cc_decision == 0, d
exit


