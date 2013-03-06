*  ========================================================================
*  = Produce a table describing the outputs of various propensity methods =
*  ========================================================================

/*

# Overall plan for final table
- use ensemble method approach

Report for each method
- covariate balance achieved (if this is relevant)
- group sizes
- ATT

Axes for the table
- Propensity model
	- kitchen sink @ patient level ignoring correlation in site level vars
	- 2 level model (site as a fixed effect for simplicity)
	- with and without cc_recommend
- Modelled outcome (dead28, survival (hazard ratio))

## Table : dead28 (logistic outcomes)

Rows
- report non-propensity model
- models in rows
	- without_cc recommend
		- kitchen sink @ patient level
		- 2 level fixed effects
	- with cc_recommend
		- kitchen sink @ patient level
		- 2 level fixed effects
- repeat above structure
	- subclassification
	- matching (greedy) {>>will need outer(matching, analysis) methods <<}
		- matching methods
		  {>>use 1:1 matching as default for now<<}
			- mahalanobis with propensity
			- nearest neighbour with calipers (0.25\sigma_prscore_)
		- post-matching analysis
			- multivariate within matched sample
			- stratification
	- propensity adjustment (regression using nearest neighbour with calipers)
	- matching - optmatch: full {>>NB: need to stratify for this to calculate <<	}
	- IPTW
	- matching estimators

Columns
- propensity model fit characteristics
	- AIC / BIC?
- common support: 90th and 95th vs 5th and 10th
- group size
	- control
	- treatment
- Covariate balance: how to summarise (verbally, number of vars not meeting balance)
- result
	- ATE
	- ATT


Loop 1: By model
	Loop 2: By method
		Loop 3: By matching (where method involves this)
*/

*  ======================================================================================
*  = BEWARE: pstest depends on global macros that exist in an_model_propensity_logistic =
*  ======================================================================================
// you will need to run this file first or manually copy the globals across
// I have not automated this because I do not want to define these variables in 2 places simultaneously


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

// DEBUGGING
sample 20

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


// short list while debugging
global models ///
		pm_lvl1_cc1 ///
		pm_lvl2_cc1 ///
		pm_lvl2f_cc1

* // single model list while debugging
* global models ///
* 		pm_lvl1_cc1

// set up postfile
cap postutil clear
tempname pname
tempfile pfile
postfile `pname' ///
	str64  model ///
	str64  match_method ///
	double df ///
	double aic ///
	double bic ///
 	double cs90_0 ///
 	double cs10_1 ///
 	double cs_N10_90 ///
 	double att_strata ///
 	double attse_strata ///
 	double attp_strata ///
 	double bias_mean ///
 	double bias_p50 ///
	using `pfile' , replace

// load each model and extract key characteristics
foreach model of global models {
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

	// TODO: 2013-03-05 - plot common support regions
	// Perform decile stratification
	// deciles for probability
	// egen `model'_yhat_q10 = cut(`model'_yhat), at(0(0.1)1) label
	xtile `model'_yhat_q10 = `model'_yhat, nq(10)
	tab `model'_yhat_q10
	table `model'_yhat_q10 early4, c(freq mean `model'_yhat)

	// Calculate ATT (means) using stata command
	// TODO: 2013-03-05 - d/w David or Colin: better to transform to logit scale?
	// bootstrap se at least
	atts dead28 early4 if `model'_cs_N10_90 ///
		, pscore(`model'_yhat) blockid(`model'_yhat_q10) boot
	local att = r(atts)
	local attse = r(bseatts)
	local attts = r(btsatts)
	local attp = 2 * ttail(r(ncs) + r(nts), r(atts)/r(seatts))
	// NOTE: 2013-03-06 - no way to estimate bias reduction
	// because you have not done any matching other than a weighted version across
	// strata
	// so run pstest for each strata then weight by the size of the strata
	// but given that your strata are (by design) all the same size:
	// just average without weighting
	local meanbias_total = 0
	local medbias_total = 0
	forvalues i = 1/10 {
		cap drop cs
		gen cs = pm_lvl1_cc1_yhat_q10 == `i'
		qui count if cs == 1 & early4 == 0
		local n1 = r(N)
		qui count if cs == 1 & early4 == 1
		local n2 = r(N)
		if `n1' == 0 | `n2' == 0 {
			continue
		}
		pstest age icnarc0 male , support(cs) treated(early4) raw nodist
		ret li
		if r(meanbias) local meanbias_total = `meanbias_total' + r(meanbias)
		if r(medbias) local medbias_total = `medbias_total' + r(medbias)
	}
	local bias_mean = `meanbias_total' / 10
	local bias_p50 = `meanbias_total' / 10

	local match_method strata
	post `pname' ///
		("`model'") ///
		("`match_method'") ///
		(`df') ///
		(`aic') ///
		(`bic') ///
	 	(`cs90_0') ///
	 	(`cs10_1') ///
	 	(`cs_N10_90') ///
	 	(`att') ///
	 	(`attse') ///
	 	(`attp') ///
	 	(`bias_mean') ///
	 	(`bias_p50')

	// Matching: Nearest neighbour within caliper
	// Imposes a stricter common suppot region via if (than option common)
	// 1:1 matching without replacement
	qui su `model'_yhat
	local caliper_size = 0.25 * r(sd)
	psmatch2 early4 ///
		if `model'_cs_N10_90 ///
		, ///
		outcome(dead28) pscore(`model'_yhat) ///
		radius caliper(`caliper_size') noreplacement descending neighbor(1)
	local att= r(att)
	local attse= r(seatt)
	local t = r(att) / r(seatt)
	di `cs_n', `t'
	local attp = 2 * ttail(`cs_n', `t')
	pstest `depvars' ///
		, ///
		support(`model'_cs_N10_90) ///
		treated(early4) both nodist
	local bias_mean = r(meanbiasaft)
	local bias_p50 = r(medbiasaft)

	local match_method nnc
	post `pname' ///
		("`model'") ///
		("`match_method'") ///
		(`df') ///
		(`aic') ///
		(`bic') ///
	 	(`cs90_0') ///
	 	(`cs10_1') ///
	 	(`cs_N10_90') ///
	 	(`att') ///
	 	(`attse') ///
	 	(`attp') ///
	 	(`bias_mean') ///
	 	(`bias_p50')

	// Matching: Nearest neighbour within caliper and mahalanobis
	// mahalanobis vars: site cc_recommend
	// NOTE: 2013-03-05 - this matches with replacement? to discuss
	// NOTE: 2013-03-06 - you are running a tighter common support requirement than normal
		// the default uses max/min rather than p10, p90
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
	local attp = 2 * ttail(`cs_n', `t')
	pstest `depvars' ///
		, ///
		support(`model'_cs_N10_90) ///
		treated(early4) both nodist
	local bias_mean = r(meanbiasaft)
	local bias_p50 = r(medbiasaft)

	local match_method nnm
	post `pname' ///
		("`model'") ///
		("`match_method'") ///
		(`df') ///
		(`aic') ///
		(`bic') ///
	 	(`cs90_0') ///
	 	(`cs10_1') ///
	 	(`cs_N10_90') ///
	 	(`att') ///
	 	(`attse') ///
	 	(`attp') ///
	 	(`bias_mean') ///
	 	(`bias_p50')

	// Optimal matching: Leave this out for now as it will take some time to specify
	// the same models you have created in stata in R

	// IPTW methods
	cap drop `model'_iptw
	// this gives ATE
	gen `model'_iptw_ate = ///
		(1/`model'_prob) * (early4 == 1) ///
		+ (1/(1-`model'_prob)) * (early4 == 0)
	// you want ATT
	gen `model'_iptw_att = ///
		 	(early4 == 1) ///
		+ 	(early4 == 0) * (`model'_prob/(1-`model'_prob))
	binreg dead28 early4 [pw=`model'_iptw_att] ///
		if `model'_cs_N10_90 ///
		, ///
		rd
	lincom early4
	local att = r(estimate)
	local atts e= r(se)
	local t = r(estimate) / r(se)
	di `cs_n', `t'
	local attp = 2 * ttail(`cs_n', `t')
	// NOTE: 2013-03-06 - you are using the IPTW ATE to assess bias ...
	// but the IPTW ATT for the outcome
	pstest `depvars' ///
		, ///
		support(`model'_cs_N10_90) ///
		treated(early4) mweight[`model'_iptw_ate] both nodist
	local bias_mean = r(meanbiasaft)
	local bias_p50 = r(medbiasaft)

	local match_method iptw
	post `pname' ///
		("`model'") ///
		("`match_method'") ///
		(`df') ///
		(`aic') ///
		(`bic') ///
	 	(`cs90_0') ///
	 	(`cs10_1') ///
	 	(`cs_N10_90') ///
	 	(`att') ///
	 	(`attse') ///
	 	(`attp') ///
	 	(`bias_mean') ///
	 	(`bias_p50')



}


postclose `pname'
use `pfile', clear
compress

*  =======================
*  = Now produce a table =
*  =======================

cap log close
