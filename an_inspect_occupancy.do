*  ===================================
*  = Inspect the effect of occupancy =
*  ===================================
/*
- inspect the effect on time to admission
- inspect the effect on severity of illness at admission (instrument)
- define your levels of severity as
    - no unoccupied beds
    - no untreated beds
*/

*  ======================================================================
*  = Recommendation, decision and delivery with respect to bed pressure =
*  ======================================================================
use ../data/working.dta, clear
qui include cr_preflight.do


cap drop icu_deliver
clonevar icu_deliver = early4
tab icu_deliver
tab bed_pressure
tabstat icu_recommend icu_accept icu_deliver, ///
    by(bed_pressure) ///
    s(n sum mean sd) format(%9.3g) labelwidth(32) longstub  ///
    col(s)
// wow!

// now create this as a table
// Simple table describing proportion of admissions
// that are seen when there are no beds




exit

*  ==================================================================
*  = Disease severity at admission by occupancy at time of referral =
*  ==================================================================
/*
Merge in key fields from 'heads' into tails
*/
use ../data/working.dta, clear
qui include cr_preflight.do
// drop all non-admitted patients
drop if missing(icnno, adno)
tempfile 2merge
save `2merge', replace
use ../data/working_tails.dta, clear
merge 1:1 icnno adno using `2merge', ///
    keepusing(cmp_beds_max bed_pressure beds_none beds_blocked ///
        dead28 date_trace dead ///
        v_arrest creatinine uvol1h bpsys ///
        )

tab beds_none
tab beds_blocked
tab bed_pressure

cap drop bpsys_delta
gen bpsys_delta = bpsys - lsys
gen creatinine_delta = hcreat - creatinine
gen uvol1h_delta = uvol1h - (up/24)

tabstat bpsys_delta creatinine_delta uvol1h_delta , ///
    by(bed_pressure) s(n mean sd q) format(%9.3g) ///
    col(s)
gen cpr = cpr_v3
tabstat cp, by(bed_pressure) s(n mean sd q) format(%9.3g)
tabstat imscore, by(bed_pressure) s(n mean sd q) format(%9.3g)
regress imscore i.bed_pressure