*  =========================================
*  = Produce final 3 cox models for thesis =
*  =========================================

/*
# Plan

1. early4 vs delayed
2. early4 vs deferred
3. ICU as tvc

Two formulations
	- cox model with baseline (4hrs onwards) data only: (ignores deaths in 1st 4hrs)
	- stsplit the data to manage ICU as a time-varying covariate without immortal time bias

Target variable
- Visit decision
- early4
- ICU admission timing with respect to visit

Confounders / independent variables

Site level - do not use because you don't *want* to adjust this out
	Avoid frailty
Timing level - ditto

Patient level
- demographics
	- age (centred)
	- sex
- current level of care
	- v_ccmds (or cc_now)
- diagnostic class
	- sepsis_dx
- physiology
	- periarrest
	- icnarc score (centred, continuous ?with spike at zero)
- current treatment (something unsustainable for the ward)
	-
- subjective visit recommendation ...
	- cc_recommneded

 - NOTE: 2013-03-01 - this is difficult to distinguish from v_ccmds because of
the way that ccmds refers to the care being delivered (imagine a patient is being
managed as a Level 2 temporarily on the ward then it is unlikely that they would
*not* be recommended for admissiont to a Level 2 area)

# Outputs

Tables ...


*/


GenericSetupSteveHarris spot_early an_model_cox_final3, logon


*  ===================
*  = Prep clean data =
*  ===================

local clean_run 1
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
	qui include cr_survival.do
}
else {
	di as error "WARNING: You are assuming that working_survival.dta is up-to-date"
	clear
	use ../data/working_survival.dta
	st
}
est drop _all

save ../data/scratch/scratch.dta, replace

*  ====================
*  = Pre-model checks =
*  ====================
use ../data/working_postflight.dta, clear
estimates drop _all
// use working_postflight for simplicity when doing variable checks
// see an_model_building.do


// so planned confounders are ...
global confounders_full ///
	age_c ///
	male ///
	ib1.v_ccmds ///
	ib0.sepsis_dx ///
	periarrest ///
	icnarc0_c ///
	cc_recommended

// no time-varying so you can specify these as you wish
global confounders_notvc ///
	age_c ///
	male ///
	ib1.v_ccmds ///
	ib0.sepsis_dx ///
	periarrest ///
	cc_recommended

global confounders_short ///
	age_c ///
	male ///
	cc_now ///
	sepsis1_b ///
	periarrest ///
	icnarc0_c ///
	cc_recommended

logistic dead28 icu_accept $confounders
est store logit_dead28_accept

logistic dead28 early4 $confounders
est store logit_dead28_early4

logistic dead28 icu_accept $confounders_short
est store logit_dead28_accept_short

logistic dead28 early4 $confounders_short
est store logit_dead28_early4_short

estimates stats *

// so prefer the full specification

*  ===================
*  = Survival models =
*  ===================
use ../data/scratch/scratch.dta, clear
estimates drop _all

/*
Models for comparative table
Enter severity as a TVC

- delay_delay_b (early4 within admitted only )
- defer_delay_b (early4 within all)
- defer_delay_c (icu_delay as TVC - time-constant effect)

NOTE: 2013-03-01 - you have allowed delay_c to have flexible forms below
I have not included these here because then I end up talking about a
time-varying co-efficient for a time varying co-variate!!!! Too much!

Then final table will be defer_delay_c

*/

// model 1: early4 versus delay (amongst the admitted)
// immortal time bias because the only way you can be admitted >4hrs is to survive longer
// therefore would expect the delay group to survive better
stcox icu_accept $confounders_full if icucmp == 1
stcox early4 $confounders_full if icucmp == 1
est store delay_delay_b

// model 2: early4 versus deferred (amongst all)
stcox icu_accept $confounders_full
stcox early4 $confounders_full
est store defer_delay_b

// model 3: early4 versus delay in TVC set-up
// tvc so no immortal time bias
// SWITCHING TO TVC data
use ../data/working_survival_tvc.dta, clear

// the first two model just replicates the analysis in the non-split data
stcox early4 $confounders_full if icucmp == 1

// the next model now permits severity to have a time-varying effect
stcox early4 $confounders_notvc icnarc0_c c.icnarc0_c#tb if icucmp == 1
est store delay_delay_b

// now model icu_delay as a tvc
// set 4 as the baseline: indicates admitted within 4 hours
stcox ib4.icu_delay_k $confounders_notvc icnarc0_c c.icnarc0_c#tb if icucmp == 1


// model 4: early4 versus deferred in TVC set-up
// the first two model just replicates the analysis in the non-split data
stcox early4 $confounders_full
estat phtest, detail

// the next model now permits severity to have a time-varying effect
stcox early4 $confounders_notvc icnarc0_c c.icnarc0_c#tb
est store defer_delay_b
estat phtest, detail

// now model icu_delay as a tvc
// set 4 as the baseline: indicates admitted within 4 hours
stcox ib4.icu_delay_k $confounders_notvc icnarc0_c c.icnarc0_c#tb
est store defer_delay_k

// now look at using icu_delay as a continuous predictor
stcox icu_delay_nospike icu_delay_zero $confounders_notvc icnarc0_c c.icnarc0_c#tb
est store defer_delay_c

// use fracpoly to inspect functional form
// produce your own vars since doesn't like the factor variabel notation
cap drop v_ccmds_* sepsis_dx_* icnarc0_c_*
tab v_ccmds, gen(v_ccmds_)
tab sepsis_dx, gen(sepsis_dx_)
gen icnarc0_c_1 = icnarc0_c * (tb == 1)
gen icnarc0_c_3 = icnarc0_c * (tb == 3)
gen icnarc0_c_7 = icnarc0_c * (tb == 7)
list id dt1 icnarc0_c icnarc0_c_* in 1/56, sepby(id)

global confounders_notvc_nofactors ///
	age_c ///
	male ///
	v_ccmds_1 v_ccmds_3 v_ccmds_4 ///
	sepsis_dx_2-sepsis_dx_5 ///
	periarrest ///
	cc_recommended ///

// double check this model is the same as the stata generated one above
local double_check = 0
if `double_check' {
	qui stcox early4 $confounders_notvc icnarc0_c c.icnarc0_c#tb
	est store A
	qui stcox early4 $confounders_notvc_nofactors ///
		icnarc0_c icnarc0_c_1-icnarc0_c_7
	est store B
	est table A B, eform
}


local double_check = 0
if `double_check' {
fracpoly, compare: ///
	stcox 	icu_delay_nospike icu_delay_zero ///
	 		$confounders_notvc_nofactors ///
				icnarc0_c icnarc0_c_1-icnarc0_c_7
	fracplot ///
		, ///
		msymbol(+) msymbolsize(tiny) ///
		xscale(noextend) ///
		xlab(0(1)7) ///
		xtitle("Delay to critical care (days)") ///
		yscale(noextend) ///
		ylab(-4 0 4) ///
		ytitle("(Adjusted) linear predictor") ///
		ylab(,nogrid) ///
		title("")
	graph rename defer_delay_fp, replace
	graph export ../outputs/figures/defer_delay_fp.pdf ///
	    , name(defer_delay_fp) replace
}
// NOTE: 2013-03-01 - selected powers 1 2 but if you need to recheck then run above
// you will also need to re-run above if you want to call fracplot
fracgen icu_delay_nospike 1 2, replace
stcox 	icu_de_1 icu_de_2 icu_delay_zero ///
	 		$confounders_notvc_nofactors ///
				icnarc0_c icnarc0_c_1-icnarc0_c_7
est store defer_delay_fp

// Inspection would suggest that linear between days 0-3 and then roughly constant
// similar to Simchen
cap drop icu_delay_nospike_lt3
gen icu_delay_nospike_lt3 = 0
replace icu_delay_nospike_lt3 = icu_delay_nospike if icu_delay_nospike < 3
cap drop icu_delay_nospike_gt3
gen icu_delay_nospike_gt3 = icu_delay_nospike > 3
format icu_delay_nospike* %9.2f
list id event_t dt1 risktime icu_delay_nospike* if inlist(id,1,46,27,29), sepby(id)


// now refit the model with this linear spline
stcox 	icu_delay_nospike_lt3 icu_delay_nospike_gt3 icu_delay_zero ///
 		$confounders_notvc_nofactors ///
			icnarc0_c icnarc0_c_1-icnarc0_c_7
est store defer_delay_ls
est table defer_delay_k defer_delay_c defer_delay_fp defer_delay_ls, eform stats(N ll chi2 aic bic)
// ls and fp marginally better than linear model
// ls and fp models almost identical in terms of IC
// c model simplest ... but ls makes more intuitive sense (delay can't keep being more harmful)

// let's inspect margins so for convenience refit model using factor notation
cap drop tb_delay
gen tb_delay = .
replace tb_delay = 0 if tsplit < 3
replace tb_delay = 3 if tsplit >= 3
replace tb_delay = . if tsplit == .
label var tb_delay "Delay time band"
tab tsplit tb_delay
stcox icu_delay_nospike c.icu_delay_nospike#ib0.tb_delay icu_delay_zero ///
	$confounders_notvc icnarc0_c c.icnarc0_c#tb

est restore defer_delay_ls
margins, at(icu_delay_nospike_lt3 0(0.1)1)


*  ======================
*  = Now produce tables =
*  ======================

// check you have the same co-variates in each
est table defer_delay_k defer_delay_c defer_delay_fp defer_delay_ls, eform stats(N ll chi2 aic bic)





cap log close
