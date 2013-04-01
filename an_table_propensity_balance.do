*  ==============================================
*  = Table to show balance among matched groups =
*  ==============================================

/*
created:	130329
modified:	130401

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
and then report the balance stats for each level of the category (ie each dummy)

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

global table_name propensity_balance

// set up random sort for matching steps
set seed 3001
cap drop sort_order
gen sort_order = r(uniform)
sort sort_order

// set up postfile
cap postutil clear
tempname pname
tempfile pfile
postfile `pname' ///
	str32	model ///
	str32 	varname ///
	str32 	var_type ///
	int 	var_level ///
	int 	count_all ///
	int 	count_matched ///
	double 	vmean_all0 ///
	double 	vmean_all1 ///
	double	dx ///
	double 	vmean_match0 ///
	double 	vmean_match1 ///
	double	dxm ///
	using `pfile' , replace

// list of candidate models
global models ///
		pm_lvl1_cc0 ///
		pm_lvl1_cc1 ///
		pm_lvl2_cc0 ///
		pm_lvl2_cc1 ///
		pm_lvl2f_cc0 ///
		pm_lvl2f_cc1

* NOTE: 2013-03-29 - work with level 1 model including cc recommend for now
local balance_models pm_lvl1_cc0 pm_lvl1_cc1
foreach model of local balance_models {

	// define the depvars (to be used in pstest)
	if "`model'" == "pm_lvl1_cc0" local depvars ///
		hes_overnight hes_emergx patients_perhesadmx ccot_shift_pattern cmp_beds_max ///
		weekend out_of_hours ///
		age male periarrest sepsis_dx v_ccmds icnarc0

	if "`model'" == "pm_lvl1_cc1" local depvars ///
		hes_overnight hes_emergx patients_perhesadmx ccot_shift_pattern cmp_beds_max ///
		weekend out_of_hours ///
		age male periarrest sepsis_dx v_ccmds icnarc0
		cc_recommend

	// describe baseline bias *for this model* using pstest
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

	count if !missing(early4)
	local count_all = r(N)
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
	local count_matched r(N)

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



	// now you should have in the data the matching indicators you need to produce the balance Table
	// loop over variables in propensity score
	foreach varname of global depvars {
		local var_type = ""
		if inlist("`varname'", ///
			"hes_overnight_k", ///
			"hes_emergx_k", ///
			"ccot_shift_pattern", ///
			"age_k", ///
			"sepsis_dx", ///
			"v_ccmds") {
				local var_type categorical
		}

		// for continuous and non-categorical variables
		// local varname age
		// local var_type = ""
		if "`var_type'" == "" {
			local var_level = .
			qui inspect `varname'
			// handle binary vars
			if r(N_unique) == 2 {
				local var_type = "binary"
				// for unmatched (full sample)
				su `varname' if early4 == 0
				local vmean_all0 = r(mean)
				su `varname' if early4 == 1
				local vmean_all1 = r(mean)
				// now for matched sample
				su `varname' if _treated == 0
				local vmean_match0 = r(mean)
				local var0 = ((`vmean_match0' * (1 - `vmean_match0'))/ r(N))
				su `varname' if _treated == 1
				local vmean_match1 = r(mean)
				// now using the matched sample calculate a summary variance to standardise means
				local var1 = ((`vmean_match1' * (1 - `vmean_match1'))/ r(N))
				local s = ((`var0' + `var1')/2)^0.5
				local dx = abs((`vmean_all1' - `vmean_all0') / `s')
				local dxm = abs((`vmean_match1' - `vmean_match0') / `s')
			}
			else {
				local var_type = "continuous"
				// for unmatched (full sample)
				su `varname' if early4 == 0
				local vmean_all0 = r(mean)
				su `varname' if early4 == 1
				local vmean_all1 = r(mean)
				// now for matched sample
				su `varname' if _treated == 0
				local vmean_match0 = r(mean)
				local var0 = r(Var)
				su `varname' if _treated == 1
				local vmean_match1 = r(mean)
				// now using the matched sample calculate a summary variance to standardise means
				local var1 = r(Var)
				local s = ((`var0' + `var1')/2)^0.5
				local dx = abs((`vmean_all1' - `vmean_all0') / `s')
				local dxm = abs((`vmean_match1' - `vmean_match0') / `s')
			}

			// di "`s' `vmean_all0' `vmean_all1' `dx' `vmean_match0' `vmean_match1' `dxm'"
			post `pname' ///
				("`model'") ///
				("`varname'") ///
				("`var_type'") ///
				(`var_level') ///
				(`count_all') ///
				(`count_matched') ///
				(`vmean_all0') ///
				(`vmean_all1') ///
				(`dx') ///
				(`vmean_match0') ///
				(`vmean_match1') ///
				(`dxm')
			continue
		}
		// categorical variables
		// local varname ccot_shift_pattern
		// local var_type categorical
		if "`var_type'" == "categorical" {
			levelsof `varname'
			foreach lvl in `=r(levels)' {
				local var_level = `lvl'
				// for unmatched (full sample)
				count if `varname' == `lvl'
				local denominator = r(N)
				count if early4 == 0 & `varname' == `lvl'
				local vmean_all0 = r(N)/`denominator'
				count if early4 == 1 & `varname' == `lvl'
				local vmean_all1 = r(N)/`denominator'
				// now for matched sample
				count if  _treated != . & `varname' == `lvl'
				local denominator = r(N)
				count if _treated == 0 & `varname' == `lvl'
				local vmean_match0 = r(N)/`denominator'
				local var0 = ((`vmean_match0' * (1 - `vmean_match0'))/ r(N))
				count if _treated == 1 & `varname' == `lvl'
				local vmean_match1 = r(N)/`denominator'
				// now using the matched sample calculate a summary variance to standardise means
				local var1 = ((`vmean_match1' * (1 - `vmean_match1'))/ r(N))
				local s = ((`var0' + `var1')/2)^0.5
				local dx = abs((`vmean_all1' - `vmean_all0') / `s')
				local dxm = abs((`vmean_match1' - `vmean_match0') / `s')
				// di "`s' `vmean_all0' `vmean_all1' `dx' `vmean_match0' `vmean_match1' `dxm'"
				post `pname' ///
					("`model'") ///
					("`varname'") ///
					("`var_type'") ///
					(`var_level') ///
					(`count_all') ///
					(`count_matched') ///
					(`vmean_all0') ///
					(`vmean_all1') ///
					(`dx') ///
					(`vmean_match0') ///
					(`vmean_match1') ///
					(`dxm')
			}
		}
	}
}

postclose `pname'
use `pfile', clear
compress
save ../outputs/tables/$table_name, replace

*  =======================
*  = Now produce a table =
*  =======================
use ../outputs/tables/$table_name, clear
keep if model == "pm_lvl1_cc1"
gen table_order = _n
// Hack to get age as categorical since you stripped this out above
replace varname = "age_k" if varname =="age"
replace varname = "icu_recommend" if varname =="cc_recommend"

levelsof model, clean local(models)
foreach model of local models {
	qui su dx if model == "`model'"
	global `model'_dx_mean = r(mean)
	global `model'_dx_max = r(max)
	qui su dxm if model == "`model'"
	global `model'_dxm_mean = r(mean)
	global `model'_dxm_max = r(max)
}

cap drop prmodel_name
gen prmodel_name = ""
replace prmodel_name = "Single level" if model      == "pm_lvl1_cc0"
replace prmodel_name = "Single level" if model      == "pm_lvl1_cc1"
replace prmodel_name = "Random effects" if model    == "pm_lvl2_cc0"
replace prmodel_name = "Random effects" if model    == "pm_lvl2_cc1"
replace prmodel_name = "Fixed effects" if model     == "pm_lvl2f_cc0"
replace prmodel_name = "Fixed effects" if model     == "pm_lvl2f_cc1"

qui include mt_Programs

// now label varname
// but this messes up var_level because it assumes vars are in factor level variables
clonevar var_level_ok = var_level
clonevar var_type_ok = var_type
rename varname parm
mt_extract_varname_from_parm
drop var_level
rename var_level_ok var_level
drop var_type
rename var_type_ok var_type

// now get tablerowlabels
spot_label_table_vars

// label age categories by hand
replace var_level_lab = "18--39" if varname == "age" & var_level == 0
replace var_level_lab = "40--59" if varname == "age" & var_level == 1
replace var_level_lab = "60--79" if varname == "age" & var_level == 2
replace var_level_lab = "80--" if varname == "age" & var_level == 3

// now produce table order
global table_order ///
	hes_overnight hes_emergx patients_perhesadmx ccot_shift_pattern cmp_beds_max ///
	gap_here ///
	weekend out_of_hours ///
	gap_here ///
	age male periarrest sepsis_dx v_ccmds icnarc0 ///
	icu_recommend

mt_table_order
sort table_order var_level
// indent categorical variables
mt_indent_categorical_vars

ingap 1 17 19
replace tablerowlabel = "\textit{Site factors}" if _n == 1
replace tablerowlabel = "\textit{Timing factors}" if _n == 18
replace tablerowlabel = "\textit{Patient factors}" if _n == 21

// indent category labels
replace tablerowlabel =  "\hspace*{1em}\smaller[1]{" + tablerowlabel + "}"

local vars vmean_all0 vmean_all1 vmean_match0 vmean_match1
foreach var of local vars {
	replace `var' = 100 * `var' if var_type == "categorical"
	replace `var' = round(100 * `var', 0.1) if var_type == "binary"
	sdecode `var', format(%9.2fc) replace
	// one decimal place if %
	replace `var' = substr(`var', 1, length(`var')-1) if var_type == "categorical"
	replace `var' = substr(`var', 1, length(`var')-1) if var_type == "binary"
}

sdecode dx, format(%9.2fc) replace
sdecode dxm, format(%9.2fc) replace
local vars vmean_all0 vmean_all1 dx vmean_match0 vmean_match1 dxm
local cols tablerowlabel `vars'
order `cols'




