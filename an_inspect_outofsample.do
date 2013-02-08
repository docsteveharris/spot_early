*  ==========================
*  = Explore / inspect data =
*  ==========================

GenericSetupSteveHarris spot_early an_inspect_outofsample.do
/*
Compare major characteristics of participating and non-participating sites
- where participation is defined by meeting the early/ward inclusion criteria
*/

*  ========================
*  = Study quality issues =
*  ========================
*  ====================
*  = Understand sites =
*  ====================
use ../data/working_all.dta, clear
gen v=1
label var v "Visit"


count
* drop patients that could never have been in the study
gen never_in = 0
replace never_in = 1 if allreferrals == 0
replace never_in = 1 if elgdate == 0
replace never_in = 1 if elgprotocol == 0
replace never_in = 1 if elgfirst_episode == 0 | withinsh == 1
drop if never_in
count

* classify problem
gen dropbc = 0
replace dropbc = 2 if include == 0
replace dropbc = 1 if exclude == 1
label var dropbc "Dropped because"
label define dropbc 0 "OK" 1 "Exclusion" 2 "Quality issue"
label values dropbc dropbc
tab dropbc

* Plot contribution by site
preserve
gen sq1 = site_quality_q1 < 80
tab sq1
collapse (count) v (firstnm) sq1, by(icode)
sort v
outsheet using ../data/datagraph/v_bysite_by_sq1.txt, replace
* Now copy and paste data into datagraph
restore

* Now inspect key variables by sample
gen time2icu = floor(hours(icu_admit - v_timestamp))
replace time2icu = 0 if time2icu < 0
label var time2icu "Time to ICU (hrs)"
gen male=sex==2
gen sepsis_b = inlist(sepsis,3,4)
gen rxlimits = inlist(v_disposal,4,7)
label var rxlimits "Treatment limits at visit end"
gen dead28 = (date_trace - dofc(v_timestamp) <= 28 & dead) 
replace dead28 = . if missing(date_trace)
label var dead28 "28d mortality"

tabstat male, s(n mean) format(%9.3g) col(s) by(dropbc)
tabstat sepsis_b, s(n mean) format(%9.3g) col(s) by(dropbc)
tabstat rxlimits, s(n mean) format(%9.3g) col(s) by(dropbc)
tabstat age, s(n mean sd min q max) format(%9.3g) col(s) by(dropbc)
tabstat news_score, s(n mean sd min q max) format(%9.3g) col(s) by(dropbc)
tabstat icnarc_score, s(n mean sd min q max) format(%9.3g) col(s) by(dropbc)
tabstat time2icu, s(n mean sd min q max) format(%9.3g) col(s) by(dropbc)
tabstat dead28, s(n mean) format(%9.3g) col(s) by(dropbc)


* Q: Summarise pattern of visits (and admissions) by time of day, day of week etc
gen dofw = dow(dofc(v_timestamp))
label var dofw "Day of week (0=Sunday)"
gen hofd = hh(v_timestamp)
label var hofd "Hour of day"
gen wofy = week(dofc(v_timestamp))
label var wofy "Week of year"
* need to standardise week of year for the number of sites contributing
preserve
collapse (count) v, by(icode wofy)
collapse (count) v, by(wofy)
tempfile 2merge
save `2merge', replace
restore
merge m:1 wofy using `2merge'
rename v sites_per_week
drop _m

cap drop v
gen v = 1
label var v "Visits"
graph bar (count) v, over(hofd, label(labsize(tiny))) ///
	name(dropbc_by_hofd, replace) by(dropbc, col(1))
graph bar (count) v, over(dofw, label(labsize(tiny))) ///
	name(dropbc_by_dofw, replace) by(dropbc, col(1))
graph combine dropbc_by_dofw dropbc_by_hofd, row(1)
graph export ../logs/dropbc_by_vtime.pdf, replace

* check how hour, day patterns change over the year: no real trend
gen mofy = month(dofc(v_timestamp))
graph bar (count) v, over(hofd, label(labsize(tiny))) over(mofy)
graph bar (count) v, over(dofw, label(labsize(tiny))) over(mofy)

* Q: How does patient severity vary by type of site?
clear
use ../data/working.dta
merge m:1 icode using ../data/sites_early.dta, ///
	 keepusing(ccot_hours ccot_days ccot_start ccot_shift_pattern)
keep if _m == 3
drop _m
gen v=1
bys icode: gen v_per_day = round(_N / (lite_close - lite_open), 0.01)
local severity_scores news_score sofa_score icnarc_score
foreach sev_score of local severity_scores {
	preserve
	collapse (firstnm) v_per_day dorisname  ///
		(mean) sev_mean=`sev_score' (semean) sev_sd=`sev_score', by(icode)
	gen sev_l95 = sev_mean - 1.96 * sev_sd
	gen sev_u95 = sev_mean + 1.96 * sev_sd
	twoway rspike sev_l95 sev_u95 v_per_day ///
		|| scatter sev_mean v_per_day ///
		, msymbol(O) mlabel(dorisname) mlabsize(tiny) mlabpos(9) ///
		name(news_by_sitevisits, replace)
	graph export ../logs/`sev_score'_by_sitevisits.pdf, replace
	restore
}






