 * =======================
 * = Model building code =
 * =======================

/*
Go through the steps needed to define your variables and justify how you set them up
Ultimately you will need to transfer the results of these decisions
into a small pre-flight do file before running a model
*/

GenericSetupSteveHarris spot_early an_model_building.do

use ../data/working.dta, clear
include cr_survival.do
stset dt1, id(id) origin(dt0) failure(dead) exit(time dt0+28)
save ../data/survival.dta, replace

*  =================================================================
*  = Dependent variable and functional form of the baseline hazard =
*  =================================================================

* What will be the dependent variable?
* Use 28 day survival

count
tab dead28 if ppsample

* What is the functional form of the baseline survival curve?
* Inspect directly and then fit parametric curves to see what fits best

* Simply tabulate the number of deaths per day
tempfile scratch

use ../data/survival.dta, replace
keep id _t _t0 _d _st
stsplit tsplit, every(1) 
gen risktime = _t - _t0
collapse (min) _t0 (max) _t  (count) n = id (sum) risktime _d, by(tsplit)
* stata does not like _d being used with index ie _d[1]
rename _d d
gen d_per_day = d / n * 1000

* Deaths per day are separate binomials so ...
gen d_mean = .
gen d_ub = .
gen d_lb = .

forvalues i = 1/28 {
	cii n[`i'] d[`i']
	replace d_mean = r(mean) * 1000 if _n == `i'
	replace d_ub = r(ub) * 1000 if _n == `i'
	replace d_lb = r(lb) * 1000 if _n == `i'
}
twoway (rspike d_ub d_lb tsplit, sort) || ///
	(scatter d_mean tsplit, msize(tiny) scheme(tufte_color) ///
	 name(hazard_direct, replace))

* See the same result by fitting a poisson model to this
* but you get all the strengths of the GLM family
save `scratch', replace


* Fully saturated model piece-wise exponential
glm d ibn.tsplit, family(poisson) lnoffset(risktime) nocons eform

* Fit an Weibull model
use ../data/survival.dta, replace
streg , dist(weibull)
predict h, hazard
replace h = h * 1000
egen pickone = tag(_t)
br h _t if pickone

* Fit a gompertz model
streg , dist(gompertz) 
predict h_gompertz, hazard
sort _t
replace h_gompertz = h_gom * 1000


* Fit a splines and FP models
use ../data/survival.dta, replace
keep id _t _t0 _d _st
stsplit tsplit, every(1) 
gen risktime = _t - _t0
collapse (min) start = _t0 (max) end =  _t  (count) n = id (sum) risktime _d, ///
	 by(tsplit)
gen midt = (start + end) / 2

* Cubic splines
rcsgen midt, df(4) gen(t_rcs) fw(_d) orthog
local knots `r(knots)'
glm _d t_rcs1-t_rcs4, family(poisson) lnoffset(risktime)
predict lh_rcs,xb nooffset
gen h_rcs = exp(lh_rcs) * 1000

* Frac poly
fracpoly, degree(2) compare: glm _d midt, family(poisson) lnoffset(risktime)
predict lh_fp2, nooffset xb
gen h_fp2 = exp(lh_fp2) * 1000



*  ====================================
*  = Binary and categorical variables =
*  ====================================
/*
Inspect, and assess time dependence as univariate parameters ///
	in a piece-wise exponential model
*/
use ../data/survival.dta, replace
keep id _t _t0 _d _st rxlimits
stsplit tsplit, every(1) 
gen risktime = _t - _t0
collapse (min) _t0 (max) _t  (count) n = id (sum) risktime _d, by(tsplit rxlimits)
* Fully saturated model piece-wise exponential
glm _d ibn.tsplit rxlimits, family(poisson) lnoffset(risktime) nocons eform
predict loghaz, xb nooffset
gen haz = exp(lh_rcs) * 1000
line haz _t if rxlimits == 0, c(l) sort(_t) ///
	|| line haz _t if rxlimits == 1, c(l) scheme(tufte_color) ///
	legend(order(1 "No Rx limits" 2 "Rx limits"))

