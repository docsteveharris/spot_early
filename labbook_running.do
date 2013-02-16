* labbook running
* keep a running archive of code snippets you don't want to lose


* ===================
* = Labbook - today =
* ===================

* Simple way to write and trial bits of code




*  ==================================================================
*  = Disease severity at admission by occupancy at time of referral =
*  ==================================================================
// 130214
use ../data/working_postflight.dta, clear
drop if missing(icnno, adno)
tempfile 2merge
save `2merge', replace
use ../data/working_tails.dta, clear
merge 1:1 icnno adno using `2merge', ///
	keepusing(free_beds_cmp bed_pressure beds_none dead28 date_trace dead) 

tab beds_none
tab bed_pressure
tabstat imscore, by(bed_pressure) s(n mean sd q) format(%9.3g)
regress imscore i.bed_pressure
// LOS
gen yulos_log = log(yulos)
regress yulos_log i.bed_pressure
regress yulos_log i.bed_pressure if yusurv == 0
regress yulos_log i.bed_pressure if yusurv == 1

// mortality
logistic dead28 i.bed_pressure
logistic yusurv i.bed_pressure
logistic ahsurv i.bed_pressure

// survival
gen t = date_trace - dofc(v_timestamp)
stset t, failure(dead == 1) exit(t == 90)
sts graph, by(beds_none) 
sts graph, by(beds_none) ci
sts test beds_none
stcox beds_none, shared(site)


*  ================================================================
*  = code snippets from deriving strobe diagram for working_early =
*  ================================================================
* 130207
exit
tab route_to_icu all_cc_in_cmp, col
tab route_to_icu simple_site, col

// so it more likely you go to the CMP monitored unit at a simple site
tabstat icucmp , by(simple_site) s(n mean sd q) format(%9.3g)
// do you get there more quickly (and therefore by a less round about route)
tabstat tails_othercc, by(simple_site) s(n mean sd q) format(%9.3g)
tabstat time2icu, by(simple_site) s(n mean sd q) format(%9.3g)

cap drop route_via_theatre
gen route_via_theatre = route_to_icu == 1
label var route_via_theatre "Admitted to ICU via theatre"
label values route_via_theatre truefalse

tabstat time2icu, by(route_via_theatre) s(n mean sd q) format(%9.3g)
ttest time2icu, by(route_via_theatre)

// add these as 2 extra exclusions
count if simple_site == 0
count if route_via_theatre == 1
drop if simple_site == 0
drop if route_via_theatre == 1

count
count if pickone_site
egen pickone_month = tag(icode studymonth)
count if pickone_month



