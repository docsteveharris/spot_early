*  =============================================================
*  = Cox model for early vs deferred working with ICU as a TVC =
*  =============================================================

GenericSetupSteveHarris spot_early an_model_cox_tvc, logon

local clean_run 0
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

/*
Independent vars
- age
- sex
*/

set seed 3001
* keep id event v_timestamp icu_admit icu_discharge date_trace dead ///
* 	 dt0 dt1 _t0 _t _st _d dt0 dt1 ///
* 	 icode idvisit  ppsample ///
* 	 dead28 ///
* 	 sex male age age_k age_c ///
* 	 icnarc0 icnarc0_c icnarc_q5 ///
* 	 sepsis_dx ///
* 	 v_ccmds ccmds_delta v_decision ///
* 	 periarrest ///
* 	 temperature wcc ///
* 	 lactate ///
* 	 time2icu early4


cap drop ccmds_now
clonevar ccmds_now = v_ccmds
replace ccmds_now = 1 if ccmds_now == 0
label copy v_ccmds ccmds_now
label define ccmds_now 0 "" 1 "Level 0/1", modify
label values ccmds_now ccmds_now
tab ccmds_now

// fracpoly can't handle factor variables so generate your own
cap drop ccn_* ccd_* vd_* sp_*
tab ccmds_now, gen(ccn_)
tab ccmds_delta, gen(ccd_)
tab v_decision, gen(vd_)
tab sepsis_dx, gen(sp_)

save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

*  ====================
*  = Modelling checks =
*  ====================
local prechecks 0
if `prechecks' {

	*  =======================
	*  = Variable inspection =
	*  =======================
	/*
	- check for sparse categories
	- non-normal distributions
	- correlations
	*/
	dotplot age, over(dead28) center median msymbol(p) msize(tiny)
	graph rename dead28_age_dotplot, replace
	tab male dead28 if ppsample, row
	tab sepsis_dx dead28 if ppsample, row
	// GU sepsis is (as usual protective)
	tab v_ccmds dead28 if ppsample, row
	tab ccmds_delta dead28 if ppsample, row
	tab v_decision dead28 if ppsample, row
	tab periarrest dead28 if ppsample, row


	*  ================================================
	*  = Variable inspection - versus other variables =
	*  ================================================
	dotplot temperature, over(dead28) center median msymbol(p) msize(tiny)
	graph rename dead28_temperature_dotplot, replace

	qui su lactate,d
	dotplot lactate if lactate < r(p99), over(dead28) center median msymbol(p) msize(tiny)
	graph rename dead28_lactate_dotplot, replace
	dotplot icnarc0, over(age_k) center median msymbol(p) msize(tiny)
	graph rename age_icnarc_dotplot, replace
	*  ================
	*  = Missing data =
	*  ================

}


stcox, estimate nolog noshow
est store baseline
estimates stats baseline

// time fixed confounders
stcox age_c male ib0.sepsis_dx, nolog noshow
est store time_fixed
estimates stats baseline time_fixed

// location
tab v_ccmds dead28, missing row
stcox i.v_ccmds, nolog noshow
est store A
stcox i.ccmds_now, nolog noshow
est store B
estimates stats A B
estimates restore B
est store location
estimates stats baseline time_fixed location

// recommendation and decision
tab ccmds_delta v_decision
stcox i.ccmds_delta, nolog noshow
est store A
stcox i.v_decision, nolog noshow
est store B
stcox i.ccmds_delta i.v_decision i.ccmds_delta#i.v_decision, nolog noshow
est store C
estimates stats A B C
estimates table A B C, b(%9.3f) star eform

// now, recommendation
tab ccmds_now ccmds_delta
stcox i.ccmds_now , nolog noshow
est store A
stcox ib2.ccmds_delta , nolog noshow
est store B
stcox i.ccmds_now ib2.ccmds_delta , nolog noshow
est store C
estimates stats A B C
estimates table A B C, b(%9.3f) star eform
est restore C
estimates store plan
estimates stats baseline time_fixed location plan

// severity
stcox icnarc0, nolog noshow
est store severity
estimates stats baseline time_fixed location plan severity

// full
stcox ///
	age_c male ib0.sepsis_dx icnarc0_c  ///
	ib1.ccmds_now ib2.ccmds_delta ib1.v_decision ///
	, ///
	noshow nolog
estimates store full
estimates stats baseline time_fixed location plan severity full


// assess early
stcox ///
	age_c male ib0.sepsis_dx icnarc0_c  ///
	ib1.ccmds_now ib2.ccmds_delta ib1.v_decision ///
	early4 ///
	, ///
	noshow nolog
estimates store full
estimates stats baseline time_fixed location plan severity full

stcox ///
	age_c male ib0.sepsis_dx ///
	ib1.ccmds_now ib2.ccmds_delta ib1.v_decision ///
	ib3.icnarc_q5 early4 ///
	, ///
	noshow nolog
estimates store A

stcox ///
	age_c male ib0.sepsis_dx ///
	ib1.ccmds_now ib2.ccmds_delta ib1.v_decision ///
	ib3.icnarc_q5##early4 ///
	, ///
	noshow nolog
estimates store B
estimates stats A B
estimates table A B, b(%9.3f) star eform

// inspect the effect of early admission at different levels of severity
lincom 1.icnarc_q5#1.early4 + 1.early4  , eform
lincom 2.icnarc_q5#1.early4 + 1.early4  , eform
lincom 3.icnarc_q5#1.early4 + 1.early4  , eform
lincom 4.icnarc_q5#1.early4 + 1.early4  , eform
lincom 5.icnarc_q5#1.early4 + 1.early4  , eform

// fracpoly

// check functional form for severity
fracpoly, center(no) compare:stcox ///
	icnarc0_c early4 ///
	age_c male ///
	sp_2-sp_5 ///
	ccn_2 ccn_3 ///
	ccd_1 ccd_3 ///
	vd_2-vd_4 ///
	///
	, ///
	noshow nolog

est store full_fp
fracplot
estimates stats baseline time_fixed location plan severity full full_fp
// NOTE: 2013-02-14 - wierd behaviour around zero even though using icnarc0
// given that this is the only major non-linearity then stick with linear form
// and marginal benefit in AIC, BIC

*  ===============================================
*  = Now examine ICU dose using the TVC approach =
*  ===============================================
* NOTE: 2013-02-16 - all of this code currently being developed in the labbook
* Commited as 0500277ae05898b30da61bcbf6d6f94dec1dccbe

cap log close