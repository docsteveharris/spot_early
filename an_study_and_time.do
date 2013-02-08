 * ========================================
 * = Study variables with respect to time =
 * ========================================

GenericSetupSteveHarris spot_early an_study_and_time, logon


use ../data/working.dta, clear
include cr_preflight.do

/*
Metrics
- wrt to
	- time of day
	- day of week
	- month of year for sites with 12 months or nearly of data
*/

*  ===============
*  = Ward visits =
*  ===============

save ../data/scratch/scratch, replace

forvalues i = -1/3 {
	use ../data/scratch/scratch, clear
	if `i' >= 0 {
		keep if ccot_shift_pattern == `i'
		local 2nd_split ccot_shift_pattern
	}
	local j = `i' + 1
	cap restore, not
	preserve

	if `j' == 0 local title "All sites"
	if `j' == 1 local title "No CCOT"
	if `j' == 2 local title "CCOT less than 7 days/week"
	if `j' == 3 local title "CCOT 7 days/week"
	if `j' == 4 local title "CCOT 24hrs/day and 7 days/week"

	*  ==================
	*  = by hour of day =
	*  ==================
	// use ../data/scratch/scratch, clear

	keep icode idvisit ccot_shift_pattern visit_hour visit_tod visit_dow visit_month studymonth
	gen v = 1
	label var v "Tag marking each visit"
	tab v

	contract visit_hour `2nd_split', freq(n)
	drop if visit_hour == .

	/*
	NOTE: 2013-01-11 - binomial CI does not work well with small proportions
	- calculate instead on the log scale
	gen sebinomial = ( p * (1 - p) / n ) ^ 0.5
	gen p_l95 = (p - 1.96 * sebinomial) * 100
	gen p_u95 = (p + 1.96 * sebinomial) * 100
	*/
	egen tot = total(n)
	gen p = n / tot
	gen p100 = p * 100
	// convert the proportion to an odds
	gen o = p / (1 - p)
	// standard error of log odds
	gen se_logodds = (((1 / p) + 1 / (1 - p)) / n) ^ 0.5
	gen error_factor = exp(1.96 * se_logodds)
	gen o_l95 = o / error_factor
	gen o_u95 = o * error_factor
	gen p_l95 = (o_l95 / (1 + o_l95)) * 100
	gen p_u95 = (o_u95 / (1 + o_u95)) * 100
	// for the purposes of the plot don't draw the upper CI if too high
	replace p_u95 = 20 if p_u95 > 20

	tw 	(rspike p_u95 p_l95 visit_hour, lcolor(gs12)) ///
		(scatter p100 visit_hour, msize(small) msymbol(o)), ///
		xlabel(0(4)24) xscale(noextend) ///
		xtitle("Hour of day") ///
		ylabel(0(5)20, nogrid) yscale(noextend) ///
		ytitle("Visits (%)") ///
		title("`title'", size(med)) ///
		legend(off)

	graph rename visits_by_hour`j', replace
	graph export ../logs/visits_by_hour`j'.pdf, replace
	if `j' >0 local all_graphs `all_graphs' visits_by_hour`j'

	*  ==================
	*  = by day of week =
	*  ==================

	restore
	preserve

	keep icode idvisit ccot_shift_pattern visit_hour visit_tod visit_dow visit_month studymonth
	gen v = 1
	label var v "Tag marking each visit"
	tab v

	contract visit_dow `2nd_split', freq(n)
	drop if visit_dow == .
	egen tot = total(n)
	gen p = n / tot
	gen p100 = p * 100
	// convert the proportion to an odds
	gen o = p / (1 - p)
	// standard error of log odds
	gen se_logodds = (((1 / p) + 1 / (1 - p)) / n) ^ 0.5
	gen error_factor = exp(1.96 * se_logodds)
	gen o_l95 = o / error_factor
	gen o_u95 = o * error_factor
	gen p_l95 = (o_l95 / (1 + o_l95)) * 100
	gen p_u95 = (o_u95 / (1 + o_u95)) * 100
	// for the purposes of the plot don't draw the upper CI if too high
	replace p_u95 = 20 if p_u95 > 20

	tw 	(rspike p_u95 p_l95 visit_dow, lcolor(gs12)) ///
		(scatter p100 visit_dow, msize(small) msymbol(o)), ///
		xlabel(0 "Sun" 1 "Mon" 2 "Tue" 3 "Wed" 4 "Thu" 5 "Fri" 6 "Sat") ///
		xscale(noextend) ///
		xtitle("Day of week") ///
		ylabel(0(5)20, nogrid) yscale(noextend) ///
		ytitle("Vists (%)") ///
		title("`title'", size(med)) ///
		legend(off)

	graph rename visits_by_dow`j', replace
	graph export ../logs/visits_by_dow`j'.pdf, replace
	if `j' >0 local all_graphs `all_graphs' visits_by_dow`j'

}

global all_graphs `all_graphs'
graph combine $all_graphs, cols(2) ysize(8) xsize(6) ycommon iscale(*.8)
graph rename visits_by_time_all, replace
graph export ../logs/visits_by_time_all.pdf, replace




cap log close