*  =====================
*  = Propensity models =
*  =====================

GenericSetupSteveHarris spot_early an_model_propensity_outcome, logon

/*

*/



clear
cap which psmatch2 // makes sure you are using the latest version
if _rc ssc install psmatch2, replace

/*
### Notes on using psmatch2
___________________________
- where a 1:1 match is requested several matches may be possible for each case but only the first one according to the current sort order of the file will be selected.  Therefore make sure you set a seed and then randomly sort the data so that you can reproduce your work.
- non-replacement is recommended when selecting matches but this option does not work for Mahalanobis matching in psmatch2.  You must implement this yourself
- pstest: compares covariares balance before and after matching
- psgraph: compares propensity score histogram by treatment status
*/

cap which imbalance
if _rc ssc install imbalance, replace
/*
### Notes on using imbalance
____________________________
- calculates the covariate imbalance statistics d_x and d_xm developed by Haviland see pp 172 [@Guo:2009vr]
*/


local clean_run 0
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
	qui include an_model_propensity_logistic
}

use ../data/working_postflight.dta, clear
// CHANGED: 2013-03-03 - move this to here in the file to avoid running all checks
egen patients_perhesadmx_k = cut(patients_perhesadmx), at(0, 0.5, 1,100) label
save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

// now bring in your saved estimates
forvalues i = 1/4 {
	estimates use ../data/estimates/early4_prscore`i'.ster
	di "`=e(estimates_title)' e(esample) is `=e(N)' patients"
	cap drop pr`i'_*
	predict pr`i'_p, pr
	predict pr`i'_l, xb
}

save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

// anticipate poor common support b/c of cc_recommend
// concerns over including timing vars when these are ?collinear with the instrument

*  ===================================
*  = Evaluate common support regions =
*  ===================================
// if poor overlap then ?optimal match rather than greedy
*  ===================================
*  = Produce the common overlap plot =
*  ===================================
// hist pr3_p ///
// 	, ///
// 	by(early4, ///
// 		ixaxes col(1)) ///
// 	s(0) w(0.025) percent ///
// 	xscale(noextend) ///
// 	xlab(0(0.25)1, format(%9.1f)) ///
// 	yscale(noextend) ///
// 	ylab(0(10)50, format(%9.0gc) nogrid)
//
// graph rename hist_propensity, replace
// graph export ../outputs/figures/hist_propensity.pdf, ///
// 	name(hist_propensity) ///
// 	replace

// this is probably better seen with a box plot
// first plot for the prscore with recommendation
graph box pr1_p, over(early4) ///
	medtype(cline) medline(lcolor(black)) ///
	marker(1, mcolor(gs8) msymbol(smplus)) ///
	marker(2, mcolor(gs8) msymbol(smplus)) ///
	ylab(0(0.25)1, nogrid) ///
	ytitle("Probability( Critical care within 4 hours )") ///
	yscale(noextend) ///
	title("Propensity score {bf:without} visit recommendation", ///
		size(medsmall))

graph rename box_propensity1, replace
graph export ../outputs/figures/box_propensity1.pdf, ///
	name(box_propensity1) ///
	replace

// now plot for the prscore not including the recommendation
graph box pr2_p, over(early4) ///
	medtype(cline) medline(lcolor(black)) ///
	marker(1, mcolor(gs8) msymbol(smplus)) ///
	marker(2, mcolor(gs8) msymbol(smplus)) ///
	ylab(0(0.25)1, nogrid) ///
	ytitle("Probability( Critical care within 4 hours )") ///
	yscale(noextend) ///
	title("Propensity score {bf:with} visit recommendation", ///
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


// define the covariates needed to adjust for outcome
// use the same as in the cox without TVC
// stay with a logistic model for now
global confounders_notvc ///
	age_c ///
	male ///
	ib1.v_ccmds ///
	ib0.sepsis_dx ///
	periarrest ///
	cc_recommended ///
	icnarc0_c ///

// reference non-propensity logistic model
logistic dead28 $confounders_notvc early4
est store baseline
// so similar to cox-model: early admission is non-significantly harmful

*  =============================
*  = Subclassification methods =
*  =============================
// pscore command generates its own propensity score
// does not like factor variables
tab hes_overnight_k, gen(hes_overnight_k_)
tab hes_emergx_k, gen(hes_emergx_k_)
tab patients_perhesadmx_k, gen(patients_perhesadmx_k_)
tab ccot_shift_pattern, gen(ccot_shift_pattern_)
tab v_ccmds, gen(v_ccmds_)

// user written command as demonstrated in causal inference practical
pscore early4 ///
	hes_overnight_k_* ///
	hes_emergx_k_* ///
	patients_perhesadmx_k_* ///
	ccot_shift_pattern_* ///
	small_unit ///
	weekend ///
	out_of_hours ///
	age_c ///
	male ///
	periarrest ///
	v_ccmds_* ///
	icnarc0_c ///
	cc_recommend ///
	, ///
	pscore(pscore_2_p) logit blockid(psblock_2) det
// fails because balancing property not satisfied: b/c common support so poor?
// main advantage was that it provided an ATT
// try again without cc_recommend
pscore early4 ///
	hes_overnight_k_* ///
	hes_emergx_k_* ///
	patients_perhesadmx_k_* ///
	ccot_shift_pattern_* ///
	small_unit ///
	weekend ///
	out_of_hours ///
	age_c ///
	male ///
	periarrest ///
	v_ccmds_* ///
	icnarc0_c ///
	, ///
	pscore(pscore_1_p) logit blockid(psblock_1) det

// So given the above problem then need to report this
// So divide into quintiles based on PS and report balance
cap drop pr2_p_k
egen pr2_p_k = cut(pr2_p), at(0, 0.01, 0.05, 0.1, 0.25, 0.50, 0.75, 0.9, 0.95, 0.99, 1) label
tab pr2_p_k
table pr2_p_k early4, c(freq mean pr2_p)
// this shows the poor common support - and allows some inspection of the means within strata
// the strata should be chosen so these are as close as possible
// pscore does this 'automatically' - I have not tried to replicate here

// quick look based on quintiles as per causal inference recommendation
// note that this is *pre*-matching
cap drop pr2_p_nq5
xtile pr2_p_nq5 = pr2_p, nq(5)
table pr2_p_nq5 early4, c(freq mean pr2_p)

// check covariate imbalance
ttest icnarc0_c if pr2_p_nq5 == 5, by(early4)
// balanced
ttest age if pr2_p_nq5 == 5, by(early4)
// balanced
tab v_ccmds early4, chi nofreq col
// not balanced
tab periarrest early4, chi nofreq col
// not balanced
tab male early4, chi nofreq col
// not balanced
tab out_of_hours early4, chi nofreq col
// not balanced
tab weekend early4, chi nofreq col
// not balanced
tab small_unit early4, chi nofreq col
// not balanced
tab ccot_shift_pattern early4, chi nofreq col
// not balanced
tab patients_perhesadmx_k early4, chi nofreq col
// not balanced
tab hes_emergx_k early4, chi nofreq col
// not balanced
tab hes_overnight_k early4, chi nofreq col
// not balanced

// nothing balances!!!
// therefore *abandon* this as method of inspecting and understanding


*  =================
*  = IPTW approach =
*  =================
cap drop iptw_1
gen iptw_1 = (1/pr1_p) * (early4 == 1) + (1/(1-pr1_p)) * (early4 == 0)
cap drop iptw_2
gen iptw_2 = (1/pr1_p) * (early4 == 1) + (1/(1-pr2_p)) * (early4 == 0)

logistic dead28 $confounders_notvc early4 [pw=iptw_1]
est store iptw_1
logistic dead28 $confounders_notvc early4 [pw=iptw_2]
est store iptw_1

estimates table baseline iptw_1, b(%9.3fc) eform

*  =======================
*  = Matching approaches =
*  =======================

*  ====================
*  = Optimal Matching =
*  ====================
// use optimal matching data
/*
- examine the ratio of treated to control participants
	- 1:1 matching will mean losing 9270-2357 patients 6913
	- 1:2 matching ...
	- Variable matching ...
		- Hansen's equation: min = .5 * p/(1-p) and max 2*p/(1-p) where p is the % treated (i.e 0.2)
			- thus variable match from 1.25-5
	- Full matching
- examine
	- strata structure
	- total distance
	- percent of cases lost
- examine covariate balance
	- d_x_ vs d_xm_
- post-matching analysis
*/

// R will need a current version of working_propensity_all.dta

local optmatch = 1
if `optmatch' == 1 {
	rsource using an_model_propensity_optmatch.r, ///
		rpath("Applications/R64.app/Contents/MacOS/r")
}

clear
insheet using ../data/optmatch_pr2_strata.dat
// I think these are the original IDs, then the match which is coded 
// as the icnarc score decile.match ID

rename v1 id
rename v2 optmatch2s
cap drop icnarc_q10
gen icnarc_q10 = substr(optmatch2s, 1, strpos(optmatch2s, ".") -1)
cap drop idoptmatch2s
gen idoptmatch2s = substr(optmatch2s, strpos(optmatch2s, ".") + 1, .)
cap drop optmatch2s_ok
gen optmatch2s_ok = optmatch2s != "NA"
destring icnarc_q10, replace force
destring idoptmatch2s, replace force
// now merge the original data against the new (optmatch) ID
tempfile 2merge
save `2merge', replace
use ../data/working_propensity_all, clear
merge 1:1 id using `2merge'
save ../data/scratch/scratch.dta, replace


// now run imbalance against 'itself'
// don't forget that you must do this *within* strata
use ../data/scratch/scratch.dta, clear
local imbalance_vars age male periarrest sepsis1_b v_ccmds icnarc0 ///
	weekend out_of_hours ///
	hes_overnight_k hes_emergx_k patients_perhesadmx_k ccot_shift_pattern ///
	small_unit
tempfile temp results
cap restore, not
forvalues i = 1/10 {
	preserve
	keep if icnarc_q10 == `i'
	local run = 1
	foreach var of local imbalance_vars {
		imbalance ../data/scratch/scratch `var' early4 idoptmatch2s `temp'
		if `run' == 1 & `i' == 1 {
			use `temp', clear
			gen icnarc_q10 = `i'
			save `results', replace
		}
		else {
			use `results', clear
			append using `temp'
			replace icnarc_q10 = `i' if missing(icnarc_q10)
			save `results', replace
		}
		local ++run
	}
	restore
}
use `results', clear
drop if missing(dx, dxm)
save ../data/optmatch2s_imbalance, replace
su dx dxm

// after all that work to get optmatch to work
// doesn't make a big difference :(

// Hodges-Lehman aligned rank test: 
// ado file assumes that matching id is string
use ../data/scratch/scratch.dta, clear
cap drop _m
cap drop id2
tostring idoptmatch2s, gen (id2)
save ../data/scratch/scratch.dta, replace
tempfile results
hodgesl ../data/scratch/scratch dead28 id2 early4 `results'

// so early4 leads to a higher 28 d mortality



*  ====================
*  = Caliper matching =
*  ====================
use ../data/working_propensity_all, clear
su pr2_l
local caliper25 = 25 * r(sd) / 100
psmatch2 early4, radius caliper(`caliper25') ///
	outcome(dead28) ///
	pscore(pr2_l)  ate









cap log off