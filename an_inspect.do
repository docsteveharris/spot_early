*  ==========================
*  = Explore / inspect data =
*  ==========================

GenericSetupSteveHarris spot_early an_inspect.do

*  ========================
*  = Study quality issues =
*  ========================

* How many reported admissions to a cmp unit have not been found?
* TODO: 2012-09-24 - what about where CMP data was after study end?
bys icode: gen match_tail_missing=inlist(v_disposal,1,2) & missing(match_is_ok)
tabstat match_tail_missing, s(n mean) by(icode)

*  ====================
*  = Understand sites =
*  ====================
use ../data/working.dta, clear

* Q: How did participation vary by site?
preserve
gen v=1
collapse (count) v, by(icode studymonth)
collapse (min) minvisits=v (max) maxvisits=v (median) medianvisits=v (mean) meanvisits=v (sd) sdvisits=v, by(icode)
gen cov=sdvisits/meanvisits
su meanvisits medianvisits sdvisits cov
sort cov
restore

* Q: How did participation vary by site and by month?
preserve
gen v_month=mofd(dofc(v_timestamp))
encode icode, gen(sid)
gen v=1
collapse (count) v, by(sid v_month)
xtset sid v_month
xtset sid v_month
xtdes, patterns(54)
restore


* Q: Can you plot the number of visits per month over time for each site?
* First of all derive the co-efficient of variation by site (as above)
use ../data/working.dta, clear
preserve
gen flag=1
collapse (count) flag, by(icode studymonth)
collapse (min) minvisits=flag (max) maxvisits=flag (median) medianvisits=flag (mean) meanvisits=flag (sd) sdvisits=flag, by(icode)
gen cov=sdvisits/meanvisits
su meanvisits medianvisits sdvisits cov
sort cov
tempfile 2merge
save `2merge',replace
restore

gen v_week = wofd(dofc(v_timestamp))
encode icode, gen(sid)
gen v=1
collapse (firstnm) icode (count) v , by(sid v_week)
format v_week %tw
xtset sid v_week
merge m:1 icode using `2merge', keepusing(cov)
qui summ cov,d
local cov25=r(p25)
local cov75=r(p75)
xtline v if cov<`cov25', overlay legend(off) title("cov_low") nodraw name(cov_low, replace)
xtline v if cov>=`cov25' & cov<`cov75', overlay legend(off) title("cov_med") nodraw name(cov_med, replace)
xtline v if cov>=`cov75', overlay legend(off) title("cov_high") nodraw name(cov_high, replace)
graph combine cov_low cov_med cov_high, cols(1) xcommon ycommon
graph export ../logs/visits_by_site_over_time.pdf, replace

* Q: Summarise the characteristics of the sites
use ../data/sites_early.dta, clear
bys site_in_early: su ccot*
bys site_in_early: su ews*
bys site_in_early: su units*
bys site_in_early: su tails_fr_ward_as_emx heads_tailed tails_othercc
keep if site_in_early
scatter heads_tailed heads_count if ccot_shift_pattern == 0, mcolor(pink) ///
		|| scatter heads_tailed heads_count if ccot_shift_pattern == 1, mcolor(purple) ///
		|| scatter heads_tailed heads_count if ccot_shift_pattern == 2, mcolor(red) ///
		legend(ring(0) pos(2) lab(1 "<7/7") lab(2 "7/7") lab(3 "24/7") note("CCOT shift pattern")) ///
		title("How many (SPOT)light visits were matched to CMP admissions versus (SPOT)light visits recorded", size(small)) 
graph export ../logs/heads_tailed_by_visits.pdf, replace
/*
A:
- sites in early vs deferred analysis
	- more likely to have ccot
	- more likelt that ccot is 7/7
	- no difference in pattern of ccot working
- early warning scores
	- broadly similar
- other units / critical care areas in hospital
	- broadly similar
	- ie.
		- rrt widely available
		- v rare for there to be non-CMP ventilated beds
		- 10-15% seem to have another critical care area
- admissions
	- approx 40% (20-60%) of admissions are unplanned and previously on the ward
- emergency ward admissions matched to a (SPOT)light visit
	- approx 40% (range 6-92%) across sites in the analysis
	- clear inverse correlation between number of visits and proportion of visits matched to tails
*/

* Q: Summarise pattern of visits (and admissions) by time of day, day of week etc
clear
use ../data/working.dta
merge m:1 icode using ../data/sites_early.dta, ///
	 keepusing(ccot_hours ccot_days ccot_start ccot_shift_pattern)
keep if _m == 3
drop _m
gen dofw = dow(dofc(v_timestamp))
label var dofw "Day of week (0=Sunday)"
gen hofd = hh(v_timestamp)
label var hofd "Hour of day"
gen wofy = week(dofc(v_timestamp))
label var wofy "Week of year"
* need to standardise week of year for the number of sites contributing
gen v=1
preserve
collapse (count) v, by(icode wofy)
collapse (count) v, by(wofy)
tempfile 2merge
save `2merge', replace
restore
merge m:1 wofy using `2merge'
rename v sites_per_week
drop _m

gen dummy=1
graph bar (count) dummy, over(hofd, label(labsize(tiny))) over(ccot_shift_pattern)
graph bar (count) dummy, over(dofw, label(labsize(tiny))) over(ccot_shift_pattern)

* check how hour, day patterns change over the year: no real trend
gen mofy = month(dofc(v_timestamp))
graph bar (count) dummy, over(hofd, label(labsize(tiny))) over(mofy)
graph bar (count) dummy, over(dofw, label(labsize(tiny))) over(mofy)

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






