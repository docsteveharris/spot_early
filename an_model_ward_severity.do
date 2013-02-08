GenericSetupSteveHarris spot_early an_model_ward_severity, logon


use ../data/working.dta, clear
qui include cr_preflight.do
save ../data/scratch/scratch.dta, replace

*  ======================================
*  = Set up hierarchical nature of data =
*  ======================================
encode icode, gen(site)
xtset site
/* Example of how to inspect for within/between variation */
xtsum age sex visit_hour visit_dow visit_month ccot_shift_pattern ///
	count_patients count_all_eligible

/* Examine the outcome variable */
su icnarc_score,d
hist icnarc_score, s(0) w(1) percent
* NOTE: 2013-01-16 - note small spike at zero
gen icnarc_score0 = icnarc_score == 0


/* Clearly patients who are missing many vars are sicker - adjust by this */
* less of a difference visually than with simple comparison of means
* TODO: 2013-01-17 - ask Colin or David

cap drop icnarc_miss10
gen icnarc_miss10 = icnarc_miss > 10
bys icnarc_miss10: su dead28 time2icu
running dead28 icnarc_miss

bys icnarc_score0: su dead28
bys icnarc_score0: su time2icu

drop if icnarc_miss10


*  ================================
*  = Model without any covariates =
*  ================================
xtmixed icnarc_score || icode:, reml covariance(unstructured)
estimates store noivars
/* inspect group composition */
estat group
/* inspect intra-class correlation coefficient */
estat icc
/* Random effects correlation matrix */
estat recovariance, correlation

*  =========================================
*  = Univariate inspection of timing vars  =
*  =========================================
/*
Timing variables
- may have both site and individual interpreation
- ccot_on

- beds_none
- full_active1
- visit_hour
- visit_day
- visit_month
*/

running icnarc_score visit_hour
running icnarc_score visit_dow
ttest icnarc_score , by(ccot_on)

/*
Specify timing variables at the site level?
- consider cross level random effects
- for now keep this as an individual level and keep the site as the only 'cluster'
Makes sense since a Saturday at one hospital should be similar for all patients
TODO: 2013-01-16 - check with Colin
*/



xtmixed icnarc_score weekend || icode: , reml cov(unstructured)
est store candidate
estimates stats noivars candidate
estat icc

regress icnarc_score out_of_hours
est store nocluster
xtmixed icnarc_score out_of_hours || icode: , reml cov(unstructured)
est store candidate
estimates stats nocluster noivars candidate
estat icc

* NOTE: 2013-01-15 - don't use visit month? (unless 11-12 months data available)
* visit_month
cap drop studymonth_max
bys icode: egen studymonth_max = max(studymonth)
running icnarc_score visit_month if studymonth_max
tabstat icnarc_score lactate news_score sofa_score if studymonth_max >= 11, ///
	by(visit_month) format(%9.3g)
xtmixed icnarc_score i.visit_month || icode: if studymonth_max >= 12 ///
	, reml cov(unstructured) nolog
est store candidate
estat icc

regress icnarc_score ccot_on
est store nocluster
xtmixed icnarc_score ccot_on || icode: , reml cov(unstructured)
est store candidate
estimates stats nocluster noivars candidate
estat icc

xtmixed icnarc_score beds_none || icode: , reml cov(unstructured)
est store candidate
estimates stats noivars candidate
estat icc

/*
So little effect of weekend alone
Office hours important
But CCOT on appears to be more so
*/
xtmixed icnarc_score ccot_on || icode: , reml cov(unstructured)
est store candidate1
xtmixed icnarc_score ccot_on out_of_hours || icode: , reml cov(unstructured)
est store candidate2
estimates stats candidate1 candidate2
estat icc

tabstat icnarc_score lactate news_score sofa_score , ///
	by(ccot_shift_start) format(%9.3g)
xtmixed icnarc_score ccot_shift_start || icode: , reml cov(unstructured)
est store candidate
estimates stats noivars candidate

*  =================================================
*  = Univariate inspection of site-only level vars =
*  =================================================

* Hospital admissions (using HES data)
xtmixed icnarc_score || icode:, reml covariance(unstructured) nolog
estimates store noivars
estat icc



* CCOT shift pattern
tab ccot_shift_pattern
tab ccot
* NOTE: 2013-01-16 - use 24/7 as the baseline as the largest group

/* Define baseline model */
xtmixed icnarc_score || icode:, reml covariance(unstructured) nolog
estimates store noivars
estat icc

regress icnarc_score ib3.ccot_shift_pattern
est store nocluster
xtmixed icnarc_score ib3.ccot_shift_pattern || icode: , reml cov(unstructured) nolog
est store candidate1
estimates stats noivars candidate
estat icc

xtmixed icnarc_score ccot ib3.ccot_shift_pattern  || icode: , reml cov(unstructured) nolog
est store candidate2
estimates stats noivars candidate1 candidate2
estat icc


/*
NOTE: 2013-01-17 - ??exciting: very little evidence of an effect of CCOT provision
Given that CCOT provision is strongly correlated with the number of visits then
- suggests that even with higher CCOT provision the 'pool' of deteriorating patients
is deep and we are not seeing all of them:
- things to think about:
	- might be reasonable to consider sites without CCOT separately as
		- no CCOT means all patients must be referred via doctors
		- levels of shift pattern suggest the coverage of nursing led referrals
	- is the same true if you examine visits per month (adjusted for hospital size, emergencies)
		- better can you plot a relationship whereby you can estimate the point when severity starts to fall
*/
* HES admissions
cap drop pickone_site
egen pickone_site = tag(icode)
su hes_admissions if pickone_site
cap drop icnarc_score_bar1
bys icode: egen icnarc_score_bar1 = mean(icnarc_score)

running icnarc_score_bar1 hes_admissions if pickone_site
regress icnarc_score_bar1 hes_admissions if pickone_site
est store nocluster
xtmixed icnarc_score hes_admissions || icode: , reml cov(unstructured) nolog
est store candidate
estimates stats noivars candidate
estat icc

running icnarc_score_bar1 hes_emergx if pickone_site
regress icnarc_score_bar1 hes_emergx if pickone_site
est store nocluster
xtmixed icnarc_score hes_emergx || icode: , reml cov(unstructured) nolog
est store candidate
estimates stats noivars candidate
estat icc

cap drop pickone_sitemonth
egen pickone_sitemonth = tag(icode studymonth)
cap drop icnarc_score_bar2
bys icode studymonth: egen icnarc_score_bar2 = mean(icnarc_score)

* Ratio of critical care beds to hospital admissions
running icnarc_score_bar1 cmp_beds_max if pickone_site
NOTE: 2013-01-17 - you might expect this to be curvilinear?
regress icnarc_score_bar1 cmp_beds_max if pickone_site
est store nocluster
xtmixed icnarc_score cmp_beds_max || icode: , reml cov(unstructured) nolog
est store candidate1

cap drop cmp_beds_max2
gen cmp_beds_max2 = cmp_beds_max^2
xtmixed icnarc_score cmp_beds_max cmp_beds_max2 || icode: , reml cov(unstructured) nolog
est store candidate2


su cmp_beds_perhesadmx if pickone_site
running icnarc_score_bar2 cmp_beds_perhesadmx if pickone_site
xtmixed icnarc_score cmp_beds_perhesadmx || icode: , reml cov(unstructured) nolog
est store candidate3
estimates stats noivars candidate1 candidate2 candidate3


su count_patients if pickone
running icnarc_score_bar2 count_patients if pickone_sitemonth

cap drop patients_perhesadmx_q5
xtile patients_perhesadmx_q5 = patients_peradmx, nq(5)
tab patients_perhesadmx_q5
tabstat icnarc_score, by(patients_perhesadmx_q5)  format(%9.3g)
tab patients_perhesadmx_q5

cap drop count_patients_q5
cap drop count_patients_q10
xtile count_patients_q5 = count_patients, nq(5)
xtile count_patients_q10 = count_patients, nq(10)
tab count_patients_q5
tabstat icnarc_score, by(count_patients_q5)  format(%9.3g)


* now consider scaling by hospital size
* first inspect visits and hospital size
/*
- so ccot_shift_pattern strongly associated with patients seen
- not clear whether there is a relationship between admissions and patients seen in (SPOT)light

tabulate ccot_shift_pattern, gen(ccot_shift)
gen hes_emergx = hes_emergencies / hes_admissions
mfp: regress count_patients hes_admissions hes_emergx (ccot_shift4 ccot_shift2 ccot_shift3) if pickone
fracplot hes_admissions
fracplot hes_emergx

OK perhaps if just consider admissions

*/


/* Define baseline model */
xtmixed icnarc_score || icode:, reml covariance(unstructured) nolog
estimates store noivars
estat icc

regress icnarc_score i.count_patients_q5 if pickone_sitemonth
est store nocluster_lin
fracpoly, compare: regress icnarc_score count_patients if pickone_sitemonth
est store nocluster_fp
fracplot
graph rename severity_by_patientspermonth, replace
graph export ../logs/severity_by_patientspermonth.pdf, replace
* NOTE: 2013-01-17 - so a small decrease as the number of visits increases

xtmixed icnarc_score i.count_patients_q10 || icode: , reml cov(unstructured)
est store candidate
estimates stats nocluster_lin nocluster_fp noivars candidate
estat icc
* NOTE: 2013-01-17 - not much difference fracpoly versis linear so stick with linear

* Study quality characteristics
* match_quality_by_site
/* Define baseline model */
xtmixed icnarc_score || icode:, reml covariance(unstructured) nolog
estimates store noivars
estat icc

running icnarc_score match_quality_by_site if pickone_site
regress icnarc_score match_quality_by_site if pickone_site
est store nocluster
xtmixed icnarc_score match_quality_by_site || icode: , reml cov(unstructured) nolog
est store candidate
estimates stats noivars candidate
estat icc




*  ======================
*  = Patient level vars =
*  ======================
/*
only include those variables that existed before the severity measurement

Not OK to use
v_ccmds
vitals1
rxlimits
icu_accept
icu_recommend
icu_accept icu_recommend
news_score sofa_* icnarc_score, separator(9)

OK to use
age
sex
v_timely
sepsis_dx
*/
xtmixed icnarc_score || icode:, reml covariance(unstructured) nolog
estimates store noivars
estat icc

running icnarc_score age
regress icnarc_score age
est store nocluster
xtmixed icnarc_score age || icode: , reml cov(unstructured) nolog
est store candidate
estimates stats noivars candidate
estat icc

tabstat icnarc_score, by(male) format(%9.3g)
regress icnarc_score male
est store nocluster
xtmixed icnarc_score male || icode: , reml cov(unstructured) nolog
est store candidate
estimates stats noivars candidate
estat icc


cap drop v_delayed
gen v_delayed = !v_timely
label var v_delayed "Delayed referral"
tabstat icnarc_score, by(v_delayed) format(%9.3g)
regress icnarc_score v_delayed
est store nocluster
xtmixed icnarc_score v_delayed || icode: , reml cov(unstructured) nolog
est store candidate
estimates stats noivars candidate
estat icc

tabstat icnarc_score, by(sepsis_dx) format(%9.3g)
regress icnarc_score i.sepsis_dx
est store nocluster
xtmixed icnarc_score i.sepsis_dx || icode: , reml cov(unstructured) nolog
est store candidate1
estimates stats noivars candidate1
estat icc

* NOTE: 2013-01-17 - all sepsis increases severity hence just use sepsis_b
tabstat icnarc_score, by(sepsis_b) format(%9.3g)
regress icnarc_score i.sepsis_b
est store nocluster
xtmixed icnarc_score i.sepsis_b || icode: , reml cov(unstructured) nolog
est store candidate2
estimates stats noivars candidate1 candidate2
estat icc


*  ===============
*  = Final model =
*  ===============

xtsum ///
	ccot ccot_on ccot_shift_pattern  ///
	ccot_shift_start ///
	beds_none ///
	out_of_hours weekend ///
	hes_emergx hes_admissions ///
	cmp_beds_max ///
	match_quality_by_site ///
	patients_perhesadmx_q5 ///
	age male sepsis_b v_delayed


local final_ivars ///
	ccot ccot_on ib3.ccot_shift_pattern  ///
	ccot_shift_start ///
	beds_none ///
	out_of_hours weekend ///
	hes_emergx hes_admissions ///
	cmp_beds_max ///
	match_quality_by_site ///
	i.count_patients_q5 ///
	age male sepsis_b v_delayed

xtmixed icnarc_score `final_ivars' ///
	|| icode:, reml cov(unstructured) nolog
estat icc

* NOTE: 2013-01-17 - now inspect for different 'aspects' of severity
xtmixed lactate `final_ivars' ///
	|| icode:, reml cov(unstructured) nolog
estat icc

xtmixed news_score `final_ivars' ///
	|| icode:, reml cov(unstructured) nolog
estat icc

xtmixed sofa_score `final_ivars' ///
	|| icode:, reml cov(unstructured) nolog
estat icc

*  ============================
*  = Ideas and playing around =
*  ============================

* How does the risk of a delayed referral depend on CCOT provision
/*
Use similar vars to the model above
*/
xtmelogit v_delayed || ///
	|| icode:,  cov(unstructured) intpoints(30) nolog
estimates store noivars
estat icc
predict ybar
su ybar

local final_ivars ///
	ccot ccot_on ib3.ccot_shift_pattern  ///
	ccot_shift_start ///
	beds_none ///
	out_of_hours weekend ///
	hes_emergx hes_admissions ///
	cmp_beds_max ///
	match_quality_by_site ///
	i.count_patients_q5 ///
	age male sepsis_b

xtmelogit v_delayed `final_ivars' || ///
	|| icode:,  cov(unstructured) intpoints(30) nolog
estimates store candidate
estimates stats noivars candidate
estat icc

/*
NOTE: 2013-01-17 - factors predicting delayed referral
Not much to say other than septis diagnoses are more commonly associated
And 5/7 versus 24/7 shift patterns see more delayed referral

*/

cap log close
