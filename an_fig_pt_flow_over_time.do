GenericSetupSteveHarris spot_early pt_flow_over_time, logon

local clean_run 1
if `clean_run' == 1 {
	clear
	use ../data/working.dta
	include cr_preflight.do
}

*  ===================================================================
*  = Do this by moving forward through time and then posting results =
*  ===================================================================

/*
loop forward using a number list specified in hours
at each step of the loop
	- define the time by adding the step onto the visit time (in hours)
	- this generates a real date time
	- now compare this real data time to events
		- in icu if icu_admit < working_time
		- dead if dead < working_time
		- dead on ward if dead < icu_admit
		- dead on icu if dead > icu_admit
*/

*  ==============================================
*  = Code copied from cr_survival.do 9 Feb 2013 =
*  ==============================================
tab dead, missing
drop if dead == .
sort dorisname
di as error "NOTE: 2013-01-29 - 23 ICU deaths not found in MRIS"
tab dead dead_icu
list id dorisname dead_icu dead if dead_icu == 1 & dead == 0, sepby(dorisname)

* TODO: 2013-01-29 - check for mismatched dates of death
list id dorisname dead_icu ddicu date_trace ///
	if icu_discharge != date_trace  & ddicu != . & dead_icu == 1 & dead == 1
* drop these for now
drop if dead_icu == 1 & dead == 0
* TODO: 2013-01-29 - missing ICU icu_discharge
* of which one has a mismatched death
list id dorisname dead dead_icu ddicu date_trace ///
	if dofC(icu_discharge) != date_trace & dead_icu == 1 & dead !=. ///
	, sepby(dorisname)
* replace ddicu with date_trace + 23hrs and 59mins in these patients
replace icu_discharge = dhms(date_trace,0,0,0) ///
	if dofc(icu_discharge) == . & dead_icu == 1 & dead !=.
* TODO: 2013-01-29 - this should really be moved to validation level checks
* count problem dates and times
count if floor(hours(icu_admit))		> floor(hours(icu_discharge)) 	& !missing(icu_admit, icu_discharge)
count if floor(hours(v_timestamp))		> floor(hours(icu_admit)) 		& !missing(v_timestamp, icu_admit)
list id icode v_timestamp icu_admit ///
	if floor(hours(v_timestamp))		> floor(hours(icu_admit)) 		& !missing(v_timestamp, icu_admit) ///
	, sepby(icode)
count if floor(hours(v_timestamp)) 		> floor(hours(icu_discharge)) 	& !missing(v_timestamp, icu_discharge)
count if floor(hours(icu_admit)) 		> floor(hours(last_trace)) 		& !missing(icu_admit, last_trace)
count if floor(hours(icu_discharge))	> floor(hours(last_trace)) 		& !missing(icu_discharge, last_trace)
list id icode icu_discharge last_trace ///
	if floor(hours(icu_discharge))	> floor(hours(last_trace)) 		& !missing(icu_discharge, last_trace) ///
	, sepby(icode)
count if floor(hours(v_timestamp)) 		> floor(hours(last_trace)) 		& !missing(v_timestamp, last_trace)
* NB all done at the at hours resolution
drop if floor(hours(icu_admit))		> floor(hours(icu_discharge)) 	& !missing(icu_admit, icu_discharge)
drop if floor(hours(v_timestamp))	> floor(hours(icu_admit)) 		& !missing(v_timestamp, icu_admit)
drop if floor(hours(v_timestamp)) 	> floor(hours(icu_discharge)) 	& !missing(v_timestamp, icu_discharge)
drop if floor(hours(icu_admit)) 	> floor(hours(last_trace)) 		& !missing(icu_admit, last_trace)
drop if floor(hours(icu_discharge)) > floor(hours(last_trace)) 		& !missing(icu_discharge, last_trace)
drop if floor(hours(v_timestamp)) 	> floor(hours(last_trace)) 		& !missing(v_timestamp, last_trace)

sort v_timestamp
* Examples of never admitted, admitted and died hence precise dt4, admitted and survived hence imprecise dt4
list id v_timestamp icu_admit icu_discharge last_trace if inlist(id,7847,7643,11781)

tempname pname
tempfile pfile
postfile `pname' ///
	int 	time_point ///
	int 	all_pts ///
	int 	all_dead ///
	int 	ward_dead ///
	int 	icu_dead ///
	int 	icu_dc_dead ///
	int 	all_alive ///
	int 	icu_alive ///
	int 	ward_alive ///
	int 	icu_dc_alive ///
	int 	check_sum ///
	using `pfile' , replace


local time_points 0 4 12 24 36 48 72 96 120 144 168
foreach time_point of local time_points {
	cap drop now
	gen double now = msofhours(`time_point') + v_timestamp
	format now %tc
	count
	local all_pts = r(N)
	count if dead & last_trace < now
	local all_dead = r(N)
	count if dead & last_trace < now & icu_admit < now & icu_discharge == last_trace
	local icu_dead = r(N)
	count if dead & last_trace < now & icu_admit == .
	local ward_dead = r(N)
	count if dead & last_trace < now & icu_admit < now & icu_discharge < last_trace
	local icu_dc_dead = r(N)
	count if last_trace >= now
	local all_alive = r(N)
	count if icu_admit < now & icu_discharge >= now
	local icu_alive = r(N)
	count if (icu_admit == . | icu_admit >= now) & last_trace > now
	local ward_alive = r(N)
	count if icu_admit < now & icu_discharge < now & last_trace > now
	local icu_dc_alive = r(N)
	local check_sum =  `ward_dead' + `icu_alive' + `icu_dead' ///
		+ `icu_dc_alive' + `icu_dc_dead'
	post `pname' ///
		(`time_point') ///
		(`all_pts') ///
		(`all_dead') ///
		(`ward_dead') ///
		(`icu_dead') ///
		(`icu_dc_dead') ///
		(`all_alive') ///
		(`icu_alive') ///
		(`ward_alive') ///
		(`icu_dc_alive') ///
		(`check_sum')
}

postclose `pname'
use `pfile', clear
br

gen icu_all_dead = icu_dead + icu_dc_dead
gen zero = 0

tw ///
	(rbar ward_dead zero time_point) ///
	(rbar icu_all_dead zero time_point) 
