*  =============================
*  = Propensity score analysis =
*  =============================
GenericSetupSteveHarris spot_early cr_propensity, logon

local clean_run 0
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	qui include cr_preflight.do
}
use ../data/working_postflight.dta, clear

local patient_vars 	age_c male periarrest sepsis_b ib1.v_ccmds rxlimits
local aps_vars 		icnarc0_c sofa_score_c news_score_c
local decision_vars ib2.ccmds_delta icu_accept
* local decision_vars ib(freq).ccmds_delta 
local timing_vars	out_of_hours weekend beds_none
local site_vars		ccot_hrs_perweek hes_overnight hes_emergx patients_perhesadmx
global pscore_vars `patient_vars' `aps_vars' `decision_vars' `timing_vars' `site_vars' 

// NOTE: 2013-02-06 - don't use instrument or decisison vars here
global outcome_vars `patient_vars' `aps_vars' `site_vars' out_of_hours weekend

* NOTE: 2013-02-05 - run full model to define sample for comparisons
qui regress icufree_days `patient_vars' `aps_vars' `decision_vars' `timing_vars' `site_vars'
estat vif
qui logistic early4 `patient_vars' `aps_vars' `decision_vars' `timing_vars' `site_vars'
gen esample = e(sample)
label var esample "Patients analysed in full model"

logistic early4 if esample
estat ic
est store null


qui logistic early4 `patient_vars' if esample
est store patient
est stats null patient

qui logistic early4 `aps_vars' if esample
est store aps
est stats null patient aps

qui logistic early4 `decision_vars' if esample
est store decision
est stats null patient aps decision

qui logistic early4 `timing_vars' if esample
est store timing
est stats null patient aps decision timing

qui logistic early4 `site_vars' if esample
est store site
est stats null patient aps decision timing site

logistic early4 ///
	`patient_vars' `aps_vars' `decision_vars' `timing_vars' `site_vars' ///
	if esample
est store full
est stats null patient aps decision timing site full
estat classification
lroc

xtset site
xtlogit early4 ///
	`patient_vars' `aps_vars' `decision_vars' `timing_vars' `site_vars' ///
	if esample, or 
est store xt
est stats null patient aps decision timing site full xt

est restore xt
cap drop prscore
predict prscore, xb
replace prscore = invlogit(prscore)
label var prscore "Propensity score"
*  ===================================
*  = Produce the common overlap plot =
*  ===================================
hist prscore ///
	, ///
	by(early4, ///
		ixaxes col(1)) ///
	s(0) w(0.025) percent ///
	xscale(noextend) ///
	xlab(0(0.25)1, format(%9.1f)) ///
	yscale(noextend) ///
	ylab(0(10)50, format(%9.0gc) nogrid)

graph rename hist_propensity, replace
graph export ../outputs/figures/hist_propensity.pdf, ///
	name(hist_propensity) ///
	replace

tabstat prscore, by(early4) s(n mean sd min q max) format(%9.3g)

save ../data/working_propensity_all.dta, replace


*  =====================================
*  = Run propensity matching procedure =
*  =====================================
use ../data/working_propensity_all.dta, clear
set seed 3001
cap drop random_sort
gen random_sort=runiform()
sort random_sort
su prscore
local caliper = r(sd)/4
psmatch2 early4 , pscore(prscore) caliper(`caliper')
preserve
keep _n1
drop if _n1==.
rename _n1 _id
tempfile 2merge
save `2merge',replace
restore
gen case=1 if _nn==1
tab case
merge 1:m _id using `2merge'
replace case=0 if _m==3
tab case
drop if case==.
tabstat _pscore, s(n mean sd min q max) format(%9.3g) by(case)
duplicates report _id
gen groupid = _n1
replace groupid = _id if case==0
duplicates report groupid
* CHANGED: 2013-02-05 - because the matching means they are dups
rename id id_original
label var id_original "ID (prior to propensity match grouping)"
gen id = r(runiform)
sort id
replace id = _n
save ../data/working_propensity.dta, replace
exit

// playing around
use ../data/working_propensity.dta, clear
include cr_survival
exit
*  ==================================================
*  = Rough working code to get the propensity score =
*  ==================================================
* NOTE: 2012-09-24 - lay out tables with early in row so can easily scan balance
tab early4 cmp_beds_cat, row nofreq
tab early4 hofd_cat, row nofreq
tab early4 v_ccmds_rec, row nofreq

logistic early4 i.cmp_beds_cat i.hofd_cat i.sex icnarc_score

cap drop yhat
cap drop prop_score
predict yhat
replace yhat = logit(yhat)
rename yhat prop_score
label var prop_score "Propensity score"
hist prop_score, by(early4)

set seed 3001
cap drop random_sort
gen random_sort=runiform()
sort random_sort
su prop_score
local caliper = r(sd)/4
psmatch2 early4 , pscore(prop_score) caliper(`caliper')
preserve
keep _n1
duplicates drop _n1, force
count
rename _n1 _id
tempfile 2merge
save `2merge', replace
restore
merge 1:m _id using `2merge'
gen _id1 = _id if _m==3
drop _m
preserve
keep _id1 icnarc_score
rename icnarc_score icnarc_score1
drop if _id1==.
tempfile 2merge
save `2merge',replace
restore
merge m:1 _id1 using `2merge'
drop _m


tab early4 cmp_beds_cat, row nofreq
tab case cmp_beds_cat, row nofreq
tab early4 hofd_cat, row nofreq
tab case hofd_cat, row nofreq
tab early4 v_ccmds_rec, row nofreq
tab case v_ccmds_rec, row nofreq


*  ==========================================================
*  = Rough working code to generate case ids after psmatch2 =
*  ==========================================================
* NOTE: 2012-09-25 - assumes 1:1 match in psmatch2 at present
exit

preserve
keep _n1
drop if _n1==.
rename _n1 _id
tempfile 2merge
save `2merge',replace
restore
gen case=1 if _nn==1
tab case
merge 1:1 _id using `2merge'
replace case=0 if _m==3
tab case
drop if case==.
tabstat _pscore, s(n mean sd min q max) format(%9.3g) by(case)
duplicates report _id
gen groupid = _n1
replace groupid = _id if case==0
duplicates report groupid
exit
