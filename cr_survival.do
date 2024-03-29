*  =====================================
*  = Set up data for survival analysis =
*  =====================================


* CHANGED: 2013-02-05 - now will run on any given data set
local clean_run 1
if `clean_run' == 1 {
	clear
	use ../data/working.dta, clear
	include cr_preflight.do
}
else {
	di as error "Please check you are starting with working_postflight"
}


* CHANGED: 2012-11-26 - commented this out: moved to cr_working
*  ==============
*  = Exclusions =
*  ==============


gen double dt1 = v_timestamp
gen double dt2 = icu_admit
gen double dt3 = icu_discharge
gen double dt4 = last_trace

format dt1-dt4 %tc
sort dt1
* Examples of never admitted, admitted and died hence precise dt4, admitted and survived hence imprecise dt4
list id dt1-dt4 if inlist(id,7847,7643,11781)

* NOTE: 2012-10-02 - save file now as snapspan will 'lose data' for records which can't be used
* i.e. if events all on the same day (die on day of visit) then can't contribute
* this just allows me to check
tempfile 2merge
save `2merge', replace
* You don't need ICU survival as this is recorded now in 'dead'
drop dead_icu
reshape long dt, i(id) j(event)

* CHANGED: 2013-01-29 - Changing this to work at the hours resolution vs days
/*
- if work at hours then can properly assess the benefit of prompt admission and survival during day 1
- else have to consider (or discard?) all patients where admission occurs on in 1st 24hrs
- hence define origin as v_timestamp and then event time as days thereafter with a resolution of hours
*/
* NOTE: 2012-09-27 - use floor rather than round so dates and times don't rounded 'together' from below and above
* gen dt1_hrs = floor(hours(dt1))

cap drop dt1
gen dt1 = floor(hours(dt - v_timestamp))/24
order dt1, after(event)
label var dt1 "Event (days after visit)"

order id event dt1 v_timestamp icu_admit icu_discharge last_trace dead
drop if missing(dt1)

* NOTE: 2012-10-02 - snapspan cannot handle events that share the same time
* i.e. it is not possible to have a ward visit and be admitted on the same day
* need to consolidate your events
duplicates report id dt1
duplicates list id dt1 in 1/100, sepby(id dt1)
duplicates tag id dt1 if inlist(event,3,4), gen(dups1)
tab event if dups1 == 1
* NOTE: 2013-01-29 - so duplicates now occur when death and discharge are co-incident

* NOTE: 2013-01-29 - these represent where visit and admission are at identical times
duplicates tag id dt1 if !inlist(event,3,4), gen(dups2)
duplicates list id dt1 if dups2 == 1, sepby(id dt1)
tab event if dups2 == 1

* NOTE: 2013-01-29 - dropping dups with sort order events means
* icu admission will be dropped where visit = admission
* icu discharge will be dropped where discharge = death
sort id event
duplicates drop id dt1, force

* produce time-period data
snapspan id dt1 event, gen(dt0) replace
order id event dt0 dt1 v_timestamp icu_admit icu_discharge last_trace dead

* Default is that patients are not in ICU unless ...
/*
Need to convert icu_discharge and icu_admit into the day.hours metric for comparing
Do this by creating icu_in and icu_out vars: a bit long winded but seems to avoid rounding errors
*/
cap drop icu_in icu_out
gen icu_in = floor(hours(icu_admit - v_timestamp))/24
gen icu_out = floor(hours(icu_discharge - v_timestamp))/24
order icu_in icu_out, after(v_timestamp)
cap drop icu
gen icu = 0
order icu, after(icu_discharge)
replace icu = 1 ///
	if dt1 <= icu_out ///
	& dt0 >= icu_in & !missing(dt0,dt1)
label var icu "ICU"
cap label define truefalse 0 "False" 1 "True"
label values icu truefalse

* Make sure dead only available for the last event
bys id (event): replace dead = . if _n != _N

drop dups1 dups2
*  ==================
*  = STSET the data =
*  ==================
/*
So analysis time is days but with a resolution of hours
Origin is v_timestamp which now defined as zero
*/

// NOTE: 2013-03-13 - you are about to update your failure indicator 
// Do not use dead for stset commands from now on
clonevar dead_st = dead
label var dead_st "Use this for stset commands"
noi stset dt1, id(id) origin(dt0) failure(dead_st) exit(time dt0+28)
/*
NOTE: 2013-01-29 - inspect stset output and think this through
- 166 obs begin on or after exit: presumably die at time of visit

*/

order id event v_timestamp icu_admit icu_discharge date_trace dead dt0 dt1 _t0 _t _st _d icu
* br id event v_timestamp icu_admit icu_discharge date_trace dead dt0 dt1 _t0 _t _st _d icu

cap drop _merge
merge m:1 id using `2merge', ///
	keepusing(v_timestamp icu_admit icu_discharge date_trace dead) update nolabel
drop _m

* Flag a single record per patient for examining non-timedependent characteristics
bys id: gen ppsample =  _n == _N
label var ppsample "Per patient sample"

* NOTE: 2013-01-29 - example commands to check the data and stset
* NOTE: 2013-01-29 - example stvary command
stdescribe
stvary age icu
sts list, at(0/28)

save ../data/working_survival.dta, replace
