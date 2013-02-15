* labbook running
* keep a running archive of code snippets you don't want to lose


* ===================
* = Labbook - today =
* ===================

* Simple way to write and trial bits of code


*  ======================================================
*  = Figures: Ix bimodal distribution for ICU admission =
*  ======================================================
* 130215
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
	legend( ///
		order(2 3 4) ///
		title("Critical care", size(medsmall) placement(9) justification(left)) ///
		label(2 "- recommended") ///
		label(3 "- accepted") ///
		label(4 "- admitted {superscript:*}") ///
		size(medsmall) ///
		pos(2)) ///
	note("{superscript:*} Admitted indicates admitted within 4 hours", size(small)) ///
	xsize(8) ysize(6)

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
	legend( ///
		order(2 3 4) ///
		title("Critical care", size(medsmall) placement(9) justification(left)) ///
		label(2 "- recommended") ///
		label(3 "- accepted") ///
		label(4 "- admitted {superscript:*}") ///
		size(medsmall) ///
		pos(2)) ///
	note("{superscript:*} Admitted indicates admitted within 4 hours", size(small)) ///
	xsize(8) ysize(6)

graph rename icu_by_icnarc0, replace
graph export ../outputs/figures/icu_by_icnarc0.pdf, replace ///
	name(icu_by_icnarc0)

exit

*  ==================================================================
*  = Disease severity at admission by occupancy at time of referral =
*  ==================================================================
// 130214
use ../data/working_postflight.dta, clear
drop if missing(icnno, adno)
tempfile 2merge
save `2merge', replace
use ../data/working_tails.dta, clear
merge 1:1 icnno adno using `2merge', ///
	keepusing(free_beds_cmp bed_pressure beds_none dead28 date_trace dead) 

tab beds_none
tab bed_pressure
tabstat imscore, by(bed_pressure) s(n mean sd q) format(%9.3g)
regress imscore i.bed_pressure
// LOS
gen yulos_log = log(yulos)
regress yulos_log i.bed_pressure
regress yulos_log i.bed_pressure if yusurv == 0
regress yulos_log i.bed_pressure if yusurv == 1

// mortality
logistic dead28 i.bed_pressure
logistic yusurv i.bed_pressure
logistic ahsurv i.bed_pressure

// survival
gen t = date_trace - dofc(v_timestamp)
stset t, failure(dead == 1) exit(t == 90)
sts graph, by(beds_none) 
sts graph, by(beds_none) ci
sts test beds_none
stcox beds_none, shared(site)


*  ================================================================
*  = code snippets from deriving strobe diagram for working_early =
*  ================================================================
* 130207
exit
tab route_to_icu all_cc_in_cmp, col
tab route_to_icu simple_site, col

// so it more likely you go to the CMP monitored unit at a simple site
tabstat icucmp , by(simple_site) s(n mean sd q) format(%9.3g)
// do you get there more quickly (and therefore by a less round about route)
tabstat tails_othercc, by(simple_site) s(n mean sd q) format(%9.3g)
tabstat time2icu, by(simple_site) s(n mean sd q) format(%9.3g)

cap drop route_via_theatre
gen route_via_theatre = route_to_icu == 1
label var route_via_theatre "Admitted to ICU via theatre"
label values route_via_theatre truefalse

tabstat time2icu, by(route_via_theatre) s(n mean sd q) format(%9.3g)
ttest time2icu, by(route_via_theatre)

// add these as 2 extra exclusions
count if simple_site == 0
count if route_via_theatre == 1
drop if simple_site == 0
drop if route_via_theatre == 1

count
count if pickone_site
egen pickone_month = tag(icode studymonth)
count if pickone_month



