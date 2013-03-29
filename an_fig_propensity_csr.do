*  ===============================
*  = Show common support regions =
*  ===============================

/*
created: 	130329
modified:	130329
notes: |
	CSR plots generated from single level models
*/


local clean_run 0
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
	qui include an_model_propensity_logistic
}
else {
	use ../data/working_propensity_all.dta, clear
}
est drop _all
cap drop __*

cap program drop redefine_esample
program redefine_esample
	cap {
		local cmdline `e(cmdline)'
		foreach v of local cmdline {
			di "`v'"
			if "`v'" == "logistic" {
				continue
			}
			if strpos("`v'",".") {
				local v = substr("`v'", strpos("`v'",".") + 1, .)
			}
			local esample_vars `esample_vars' `v'
		}
		di "`esample_vars'"
		estimates esample: `esample_vars', replace
	}
	di as result "`=e(estimates_title)' e(esample) is `=e(N)' patients"
end

estimates use ../data/estimates/pm_lvl1_cc0.ster
est store pm_lvl1_cc0
redefine_esample
cap drop pm_lvl1_cc0_pr
predict pm_lvl1_cc0_pr
// NOTE: 2013-03-29 - how does the discrimination differ
lroc, nograph

estimates use ../data/estimates/pm_lvl1_cc1.ster
est store pm_lvl1_cc1
redefine_esample
cap drop pm_lvl1_cc1_pr
predict pm_lvl1_cc1_pr
// NOTE: 2013-03-29 - how does the discrimination differ
lroc, nograph

// this is probably better seen with a box plot
// first plot for the prscore without recommendation
graph box pm_lvl1_cc0_pr, ///
	over(early4, axis(noline)) ///
	medtype(cline) medline(lcolor(black)) ///
	marker(1, mcolor(gs8) msymbol(smplus)) ///
	marker(2, mcolor(gs8) msymbol(smplus)) ///
	ylab(0(0.25)1, nogrid) ///
	ytitle("Probability( Critical care within 4 hours )") ///
	yscale(noextend) ///
	title("(A) Propensity score {bf:without} visit recommendation", ///
		size(medsmall))

graph rename box_propensity1, replace
graph export ../outputs/figures/box_propensity1.pdf, ///
	name(box_propensity1) ///
	replace

// now plot for the prscore including the recommendation
graph box pm_lvl1_cc1_pr,  ///
	over(early4, axis(noline)) ///
	medtype(cline) medline(lcolor(black)) ///
	marker(1, mcolor(gs8) msymbol(smplus)) ///
	marker(2, mcolor(gs8) msymbol(smplus)) ///
	ylab(0(0.25)1, nogrid) ///
	ytitle("Probability( Critical care within 4 hours )") ///
	yscale(noextend) ///
	title("(B) Propensity score {bf:with} visit recommendation", ///
		size(medsmall))

graph rename box_propensity2, replace
graph export ../outputs/figures/box_propensity2.pdf, ///
	name(box_propensity2) ///
	replace

graph combine box_propensity1 box_propensity2, rows(1) ycommon
graph rename box_propensity1_2, replace
graph export ../outputs/figures/box_propensity1_2.pdf, ///
	name(box_propensity1_2) ///
	replace


