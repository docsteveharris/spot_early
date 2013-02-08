*  =========================================================================
*  = Use a piece-wise exponential approach to describe the baseline hazard =
*  =========================================================================

/*
This code focuses on using piece-wise exponential to understand baseline survival
See the an_survival.do code for a more traditional approach that sticks with the Cox method
*/

GenericSetupSteveHarris spot_early an_survival_ward_baseline
* qui include cr_survival.do

use ../data/working_survival.dta, clear
st
* NOTE: 2013-01-29 - split the data every 6 hours
stsplit tsplit, every(0.25)
gen risktime = _t - _t0
save ../data/scratch.dta, replace

use ../data/scratch.dta, clear
collapse ///
	(min) _t0 (max) _t ///
	(count) n = _d ///
	(sum) risktime _d ///
	, by(tsplit)

* NOTE: 2013-01-29 - factor variables may not contain non-integer vars
gen tsplit4 = tsplit * 4
glm _d i.tsplit4, ///
	family(poisson) lnoffset(risktime) nocons eform

cap drop yhat* ymin* ymax*
predict yhat, xb
label var yhat "linear prediction"
predict yhat_se, stdp
label var yhat_se "SE of linear prediction"
gen estimate = exp(yhat)
gen min95 = exp(yhat - 1.96 * yhat_se)
gen max95 = exp(yhat + 1.96 * yhat_se)

label var estimate "Expected number of deaths"
gen irr = estimate/risktime
label var irr "Incident rate ratio"
gen irr_min95 = min95/risktime
gen irr_max95 = max95/risktime

tw ///
	(rspike irr_max95 irr_min95 tsplit if tsplit != 0) ///
	(scatter irr tsplit if tsplit != 0) ///
	, xscale(noextend) ///
	xtitle("Days following bedside assessment") ///
	yscale(noextend) ///
	ytitle("Incident Rate (deaths per day)") ///
	ylabel(,nogrid) ///
	legend(off)

graph rename baseline_hazard_piecewise_exp, replace
graph export ../logs/baseline_hazard_piecewise_exp.pdf, replace

/*
NOTE: 2013-01-29 - multilevel version attempted below but do not understand IRR
Seems to be an order of magnitude out
?calculating the IRR aggregated for all sites?

*  ===============================
*  = Now try multi-level version =
*  ===============================
use ../data/scratch.dta, clear
collapse ///
	(min) _t0 (max) _t ///
	(count) n = _d ///
	(sum) risktime _d ///
	, by(tsplit icode)

* NOTE: 2013-01-29 - factor variables may not contain non-integer vars
gen tsplit4 = tsplit * 2

encode icode, gen(site)
xtpoisson _d i.tsplit4, irr nocons exposure(risktime) i(site) normal

* NOTE: 2013-01-29 - this command is VERY slow and gives v similar results to above
// xtmepoisson _d i.tsplit4, nocons exposure(risktime) || site:, irr
exit
*/
exit
