*  ==============================================
*  = Table to show balance among matched groups =
*  ==============================================

/*
created:	130329
modified:	130329

Demonstrate 'balance' between the two populations
This only makes sense as a concept when you are using the propensity score to match
- nearest neighbour within caliper
- nearest neighbour wihtin caliper and mahalanobis

Report balance as per Haviland 2007 (recommended in Guo and Fraser 2010)
	- absolute standardised difference in covariate means
		- d_x_ is the difference between the treated and all possible controls (i.e. pre match)
		- d_xm_ is the difference bwteen the treated and the matched
It is a bit like Cohen's d

In detail:
- calculate the mean in the treated and untreated for the full population
- calculate an overall standard deviation sd_x_ by
	taking the variance within each group
	finding the average of these variances
	taking the square root of the average
- now standardise each mean using the overall sd_x_
- now repeat using the matched cases and their controls
	use the variables left behind by psmatch2
	i.e.
		only for patients within CSR (_support) ... or here cs_N10_90
		_treated

This will not work for categorical variables (and only sort of works for binary ones) if you ignore their boundary constraints
So convert all categorical vars to indicator dummies

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

// set up random sort for matching steps
set seed 3001
cap drop sort_order
gen sort_order = r(uniform)
sort sort_order

// list of candidate models
global models ///
		pm_lvl1_cc0 ///
		pm_lvl1_cc1 ///
		pm_lvl2_cc0 ///
		pm_lvl2_cc1 ///
		pm_lvl2f_cc0 ///
		pm_lvl2f_cc1

* NOTE: 2013-03-29 - work with level 1 model including cc recommend for now
local model pm_lvl1_cc1

// define the depvars (to be used in pstest)
if "`model'" == "pm_lvl1_cc0" local depvars $prvars_patient $prvars_site $prvars_timing
if "`model'" == "pm_lvl2_cc0" local depvars $prvars_patient $prvars_site $prvars_timing
if "`model'" == "pm_lvl2f_cc0" local depvars $prvars_patient $prvars_site $prvars_timing ib(freq).site
if "`model'" == "pm_lvl1_cc1" local depvars $prvars_patient $prvars_site $prvars_timing cc_recommend
if "`model'" == "pm_lvl2_cc1" local depvars $prvars_patient $prvars_site $prvars_timing cc_recommend
if "`model'" == "pm_lvl2f_cc1" local depvars $prvars_patient $prvars_site $prvars_timing ib(freq).site cc_recommend

// strip out any factor notation
local clean = ""
foreach v of local depvars {
	if strpos("`v'",".") != 0 {
		local v = substr("`v'", strpos("`v'",".")+1,.)
	}
	local clean `clean' `v'
}
local depvars `clean'
di "`depvars'"
// describe baseline bias *for this model*
pstest `depvars', treated(early4) raw nodist
local baseline_bias_mean = r(meanbias)
local baseline_bias_p50 = r(medbias)

estimates use ../data/estimates/`model'.ster
estimates store `model'
local `model'_n = e(N)
local `model'_cmd = e(cmd)
estimates stats
matrix stats = r(S)
local df = stats[1,4]
local aic = stats[1,5]
local bic = stats[1,6]


// Report common support boundaries
// Define CSR as within whiskers of box plot
// i.e. below 90th of untreated
// and above 10th of treated
qui su `model'_yhat if early4 == 0, d
local cs90_0 = r(p90)
qui su `model'_yhat if early4 == 1, d
local cs10_1 = r(p10)
gen `model'_cs_N10_90 = ///
		(`model'_yhat <= `cs90_0' & `model'_yhat >= `cs10_1' )
qui count if `model'_cs_N10_90 == 1
local cs_N10_90 = r(N)
// this is the COMMON SUPPORT REGION USED IN ALL FURTHER MODELS
local cs_n = r(N)

*  ====================================================
*  = Nearest neighbour within caliper and mahalanobis =
*  ====================================================
di "************************************************"
di "Nearest neighbour within caliper and mahalanobis"
di "************************************************"
// Matching: Nearest neighbour within caliper and mahalanobis
// mahalanobis vars: site cc_recommend
qui su `model'_yhat
local caliper_size = 0.25 * r(sd)
psmatch2 early4 ///
	if `model'_cs_N10_90 ///
	, ///
	outcome(dead28) pscore(`model'_yhat) ///
	radius caliper(`caliper_size') ///
	mahalanobis(site cc_recommend)

local att= r(att)
local attse= r(seatt)
local t = r(att) / r(seatt)
di `cs_n', `t'
local attp =  ttail(`cs_n', `t')
pstest `depvars' ///
	, ///
	support(`model'_cs_N10_90) ///
	treated(early4) both nodist mweight(_weight)
local bias_mean = r(meanbiasaft)
local bias_p50 = r(medbiasaft)

exit
pstest age male periarrest sepsis1_b v_ccmds icnarc0 ///
	hes_overnight hes_emergx patients_perhesadmx ///
	ccot_shift_pattern cmp_beds_max ///
	weekend out_of_hours ///
	cc_recommend ///
	, ///
	support(`model'_cs_N10_90) ///
	treated(early4) both nodist mweight(_weight)



