*  ========================================================
*  = Plot / understand visits by time of day, day of week =
*  ========================================================

* Q: Summarise pattern of visits (and admissions) by time of day, day of week etc
clear
use ../data/working.dta
merge m:1 icode using ../data/sites.dta, ///
	 keepusing(ccot_hours ccot_days ccot_start ccot_shift_pattern cmp_beds_persite)
keep if _m == 3
drop _m
gen dofw = dow(dofc(v_timestamp))
label var dofw "Day of week (0=Monday)"
replace dofw=dofw+1
label define dofw 1 "Mon" 2 "Tue" 3 "Wed" 4 "Thu" 5 "Fri" 6 "Sat" 7 "Sun"
label values dofw dofw
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
label var dummy "New visits"
graph bar (count) dummy, over(hofd) ///
	by(ccot_shift_pattern, cols(1)) xsize(4) ysize(12) ///
	name(visits_by_hofd_by_ccot_shift, replace)
graph export ../logs/visits_by_hofd_by_ccot_shift.pdf, replace

graph bar (count) dummy, over(dofw) ///
	by(ccot_shift_pattern, cols(1)) xsize(4) ysize(12) ///
	name(visits_by_dofw_by_ccot_shift, replace)
graph export ../logs/visits_by_dofw_by_ccot_shift.pdf, replace

* check how hour, day patterns change over the year: no real trend
gen mofy = month(dofc(v_timestamp))
graph bar (count) dummy, over(hofd, label(labsize(tiny))) over(mofy)
graph bar (count) dummy, over(dofw, label(labsize(tiny))) over(mofy)