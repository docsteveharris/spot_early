
*  ==========================================================
*  = Inspect whether the decision to admit is monotonic ... =
*  ==========================================================


/*
Produces a figure for both age and severity
- at extremes of age then Pr(ICU) decreases
- generally linear with severity but with odd behavior in the tails
*/

clear
cd ~/data/spot_early/vcode
use ../data/working.dta
qui include cr_preflight.do

rename early4 icu_deliver
count

*  ==========
*  = by age =
*  ==========
cap drop *_prob *_stdp *_*95
foreach var in recommend accept deliver {
	// use default options -- this is for demonstration purposes
	fracpoly: logit icu_`var' age
	fracpred `var'_logit
	fracpred `var'_stdp, stdp
	// now convert to probability scale
	gen `var'_prob = invlogit(`var'_logit)
	gen `var'_min95 = invlogit(`var'_logit - 1.96 * `var'_stdp)
	gen `var'_max95 = invlogit(`var'_logit + 1.96 * `var'_stdp)
}

save ../data/scratch.dta, replace
use ../data/scratch.dta, clear
tw ///
	(rarea recommend_max95 recommend_min95 age, sort pstyle(ci)) ///
	(line recommend_prob age, sort connect(direct) lpattern(dot)) ///
	(rarea accept_max95 accept_min95 age, sort pstyle(ci)) ///
	(line accept_prob age, sort connect(direct)  lpattern(dash)) ///
	(rarea deliver_max95 deliver_min95 age, sort pstyle(ci)) ///
	(line deliver_prob age, sort connect(direct) lpattern(solid) ) ///
	, ///
	xscale(noextend) ///
	yscale(noextend) ///
	ylabel(0(0.25)1, nogrid) ///
	ytitle("Unadjusted probability") ///
	text(1 20 "(A)", placement(e) size(large)) ///
	legend( ///
		order(2 3 4) ///
		title("Critical care", size(medsmall) placement(9) justification(left)) ///
		label(2 "recommended") ///
		label(3 "accepted") ///
		label(4 "admitted {superscript:*}") ///
		size(medsmall) ///
		symysize(*1) symxsize(*.3) ///
		ring(0) ///
		pos(2)) ///
	note("{superscript:*} Admitted indicates admitted within 4 hours", ///
			size(small) margin(medium)) ///
	xsize(6) ysize(6)

graph rename icu_by_age, replace
graph export ../outputs/figures/icu_by_age.pdf, replace ///
	name(icu_by_age)

*  ===============
*  = by severity =
*  ===============
cap drop *_prob *_stdp *_*95 *_logit
cap rename early4 icu_deliver
foreach var in recommend accept deliver {
	// use default options -- this is for demonstration purposes
	// NOTE: 2013-02-11 - doesn't converge for -2 power
	local powers powers( -1, -.5, 0, .5, 1, 2, 3)
	fracpoly, `powers': logit icu_`var' icnarc0
	fracpred `var'_logit
	fracpred `var'_stdp, stdp
	// now convert to probability scale
	gen `var'_prob = invlogit(`var'_logit)
	gen `var'_min95 = invlogit(`var'_logit - 1.96 * `var'_stdp)
	gen `var'_max95 = invlogit(`var'_logit + 1.96 * `var'_stdp)
}

save ../data/scratch.dta, replace
use ../data/scratch.dta, clear
tw ///
	(rarea recommend_max95 recommend_min95 icnarc0, sort pstyle(ci)) ///
	(line recommend_prob icnarc0, sort connect(direct) lpattern(dot)) ///
	(rarea accept_max95 accept_min95 icnarc0, sort pstyle(ci)) ///
	(line accept_prob icnarc0, sort connect(direct)  lpattern(dash)) ///
	(rarea deliver_max95 deliver_min95 icnarc0, sort pstyle(ci)) ///
	(line deliver_prob icnarc0, sort connect(direct) lpattern(solid) ) ///
	, ///
	xscale(noextend) ///
	xtitle("ICNARC Acute Physiology Score") ///
	yscale(noextend) ///
	ylabel(0(0.25)1, nogrid) ///
	ytitle("Unadjusted probability") ///
	text(1 0 "(B)", placement(e) size(large)) ///
	legend( ///
		order(2 3 4) ///
		title("Critical care", size(medsmall) placement(9) justification(left)) ///
		label(2 "recommended") ///
		label(3 "accepted") ///
		label(4 "admitted {superscript:*}") ///
		size(medsmall) ///
		symysize(*1) symxsize(*.3) ///
		ring(0) ///
		pos(4)) ///
	note("{superscript:*} Admitted indicates admitted within 4 hours", ///
			size(small) margin(medium)) ///
	xsize(6) ysize(6)

graph rename icu_by_icnarc0, replace
graph export ../outputs/figures/icu_by_icnarc0.pdf, replace ///
	name(icu_by_icnarc0)

graph combine icu_by_age icu_by_icnarc0, ///
	rows(1) ycommon ///
	xsize(8) ysize(6)
graph rename icu_access_bimodal, replace
graph export ../outputs/figures/icu_access_bimodal.pdf, replace ///
	name(icu_access_bimodal)


exit