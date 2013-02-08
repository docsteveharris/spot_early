*  ==================================================
*  = Survival using ICU as a time-varying covariate =
*  ==================================================

GenericSetupSteveHarris spot_early an_survival_tvc
include cr_survival.do
stsplit tsplit, every(1) 
gen risktime = _t - _t0

cap drop icu
gen icu = 0
* Default is that patients are not in ICU unless ...
replace icu = 1 if dt1 > dofc(icu_admit) & dt0 <= dofc(icu_admit)
label var icu "ICU"
label values icu truefalse

cap drop icu_lag1
sort id _st tsplit
bys id (_st tsplit): gen icu_lag1 = icu[_n-1]
replace icu_lag1 = 0 if icu_lag1 == .

* gen icu_lag1 = 0
* Now create an icu_lag var that becomes positive 1 day after admission
* And remains positive for 1 day following discharge
* replace icu_lag1 = 1 if dt1 > (dofc(icu_admit) + 1) & dt0 <= (dofc(icu_admit) + 1)
label var icu_lag1 "ICU - lag 1d"
label values icu_lag1 truefalse

* Fit the model with icu as a tvc with lag
* stcox male sepsis_b rxlimits age_c ib1.icnarc_q10 icu_lag1
* Fit again but interacting icu and severity
* stcox male sepsis_b rxlimits age_c ib1.icnarc_q10##icu_lag1

* Now permit ICU to act as a time varying covariate with time dependent effects
cap drop icu_tvc
gen icu_tvc = 0
replace icu_tvc = 1 if icu & tsplit == 0
replace icu_tvc = 2 if icu & tsplit == 1
replace icu_tvc = 3 if icu & tsplit == 2
replace icu_tvc = 4 if icu & tsplit >= 3
replace icu_tvc = 5 if icu & tsplit >= 7

stcox male sepsis_b rxlimits age_c ib1.icnarc_q10 ib3.icu_tvc

stcurve, survival ///
	tscale(range(0(7)28) noextend) ///
	yscale(range(0 1) noextend) ///
	ylabel(0(0.25)1, nogrid) ///
	at(icu_tvc = 0) ///
	at(icu_tvc = 1) ///
	at(icu_tvc = 2) ///
	at(icu_tvc = 3) ///
	at(icu_tvc = 4) ///
	at(icu_tvc = 5) ///
	legend(pos(3) col(1) size(small)) ///
	name(icu_tvc, replace) ///
	outfile(../logs/icu_tvc,replace)

log close

use ../data/icu_tvc.dta,clear
duplicates report surv* _t
duplicates drop surv* _t, force
tw 	///
	(line surv1 _t, color("255 0 0") lpattern(solid)) ///
	(line surv2 _t, color("216 8 39") lpattern(solid)) ///
	(line surv3 _t, color("177 16 78") lpattern(solid)) ///
	(line surv4 _t, color("137 24 118") lpattern(solid)) ///
	(line surv5 _t, color("98 31 157") lpattern(solid)) ///
	(line surv6 _t, color("59 39 196") lpattern(solid)) ///
	, yscale(noextend) xscale(noextend) ///
	title("Adjusted survival") ///
	ttitle("Time (days)") ///
	ytitle("Survival probability") ///
	ylab(0(0.25)1, nogrid) xlab(0(7)28) ///
	legend( ///
		label(1 "Never") ///
		label(2 "<24h") ///
		label(3 "24-48h") ///
		label(4 "48-72h") ///
		label(5 ">3d") ///
		label(6 ">7d") ///
		) ///
	legend(title("Time to ICU", size(medsmall)) symxsize(*.5) col(1) pos(3))
