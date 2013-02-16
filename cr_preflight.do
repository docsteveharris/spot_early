*  ==============================
*  = Variable sort order and id =
*  ==============================
* NOTE: 2012-10-05 - quick code to be run after working has been created
* Calling it pre-flight for now to distinguish it from the slower code that will
* be needed to work out occupancy and ccot shift patterns


local debug = 1

if `debug' {
	use ../data/working.dta, clear

}

cap label drop truefalse
label define truefalse 0 "False" 1 "True"

label define quantiles 1 "1st"
label define quantiles 2 "2nd", add
label define quantiles 3 "3rd", add
label define quantiles 4 "4th", add
label define quantiles 5 "5th", add


sort idvisit
gen id=_n
encode icode, gen(site)
label var site "Study site"

set seed 3001

count if _valid_row == 0

*  ============================================
*  = Report data quality issues as a reminder =
*  ============================================

tab _valid_row
duplicates example _list_unusual if _count_unusual > 0
duplicates example _list_imposs if _count_imposs > 0

keep if _valid_row

*  ============================
*  = Merge in site level data =
*  ============================

merge m:1 icode using ../data/sites.dta, ///
	keepusing(ccot ccot_days ccot_start ccot_hours ccot_shift_pattern ///
		cmp_patients_permonth tails_othercc all_cc_in_cmp ///
		hes_admissions hes_emergencies hes_los_mean hes_daycase ///
		tails_all_percent cmp_beds_persite studydays)

drop if _m != 3
drop _m

* CHANGED: 2013-01-18 - so hes_admissions only refers to overnight
gen hes_overnight = hes_admissions - hes_daycase
replace hes_overnight = hes_overnight / 1000
label var hes_overnight "HES (overnight) admissions (thousands)"

egen hes_overnight_k = cut(hes_overnight), at(0,30,60,90, 200) icodes
label var hes_overnight_k "Hospital admissions (thousands)"
label define hes_overnight_k	0 	"0--30"
label define hes_overnight_k	1 	"30--60", add
label define hes_overnight_k	2 	"60--90", add
label define hes_overnight_k	3 	"90+", add
label values hes_overnight_k hes_overnight_k

cap drop hes_emergx
gen hes_emergx = round(hes_emergencies / (hes_admissions) * 100)
label var hes_emergx "Emergency hospital admissions (as % of overnight)"

egen hes_emergx_k = cut(hes_emergx), at(0,30,40,100) icodes
label var hes_emergx_k "Hospital emergency workload (percent)"
label define hes_emergx_k	0 	"0--30"
label define hes_emergx_k	1 	"30--40", add
label define hes_emergx_k	2 	"40+", add
label values hes_emergx_k hes_emergx_k

cap drop cmp_beds_perhesadmx
gen cmp_beds_perhesadmx = cmp_beds_max / hes_overnight * 10
label var cmp_beds_perhesadmx "Critical care beds per 10,000 admissions"

egen cmp_beds_peradmx_k = cut(cmp_beds_perhesadmx), at(0,2,4,100) icodes
label var cmp_beds_peradmx_k "Critical care beds per 10,000 admissions"
label define cmp_beds_peradmx_k 0 "0--2"
label define cmp_beds_peradmx_k 1 "2--4", add
label define cmp_beds_peradmx_k 2 "4+", add
label values cmp_beds_peradmx_k cmp_beds_peradmx_k

cap drop patients_perhesadmx
gen patients_perhesadmx = (count_patients / hes_admissions * 1000)
label var patients_perhesadmx "Standardised monthly ward referrals"
qui su patients_perhesadmx
gen patients_perhesadmx_c = patients_perhesadmx - r(mean)
label var patients_perhesadmx_c "Standardised monthly ward referrals (centred)"


xtile count_patients_q5 = count_patients, nq(5)


* ==================================================================================
* = Create study wide generic variables - that are not already made in python code =
* ==================================================================================
* Now inspect key variables by sample
gen time2icu = floor(hours(icu_admit - v_timestamp))
* TODO: 2012-10-02 - this should not be necessary!!
count if time2icu < 0
di as error "`=r(N)' patients found where ICU admission occured before ward visit"
replace time2icu = 0 if time2icu < 0
label var time2icu "Time to ICU (hrs)"

*  ==========================
*  = Patient flow variables =
*  ==========================
* What was recommended
tab v_ccmds_rec, miss
cap drop cc_recommended
gen cc_recommended = .
replace cc_recommended = 0 if inlist(v_ccmds,0,1)
replace cc_recommended = 1 if inlist(v_ccmds,2,3)
label values cc_recommended truefalse
tab cc_recommended

gen ccmds_delta = .
label var ccmds_delta "Recommended level of care"
replace ccmds_delta = 1 if v_ccmds_rec < v_ccmds
replace ccmds_delta = 2 if v_ccmds_rec == v_ccmds 
replace ccmds_delta = 3 if v_ccmds_rec > v_ccmds
label define ccmds_delta 1 "Downgrade"
label define ccmds_delta 2 "No change", add
label define ccmds_delta 3 "Upgrade", add
label values ccmds_delta ccmds_delta
tab ccmds_delta

* What decison was made
tab v_disp, miss
cap drop cc_decision
gen cc_decision = .
replace cc_decision = 0 if inlist(v_disposal,5,6)
replace cc_decision = 1 if inlist(v_disposal,1,2)
replace cc_decision = 2 if inlist(v_disposal,3,4)
label define cc_decision ///
	0 "No ward follow-up planned" ///
	1 "Ward follow-up planned" ///
	2 "Accepted to Critical care"
label values cc_decision cc_decision
tab cc_decision

tab cc_decision cc_recommended, col row

cap drop icucmp
gen icucmp = time2icu != .
label var icucmp "Admitted to ICU in CMP"
tab icucmp
tab loca
cap drop route_to_icu
gen route_to_icu = .
replace route_to_icu = .a if !missing(loca)
replace route_to_icu = 0 if loca == 2
replace route_to_icu = 1 if loca == 1
replace route_to_icu = 2 if loca == 6
replace route_to_icu = 3 if loca == 12
replace route_to_icu = 4 if inlist(loca,7,11,13,4)

* ICU admission pathway
label define route_to_icu ///
	.a "Other" ///
	0 "Direct from ward" ///
	1 "via theatre" ///
	2 "via scan/imaging" ///
	3 "via recovery as temporary critical care" ///
	4 "via other intermediate care bed"
label values route_to_icu route_to_icu
label var route_to_icu "ICU admission pathway"

* NOTE: 2012-09-27 - get more precise survival timing for those who die in ICU
* Add one hour though else ICU discharge and last_trace at same time
* this would mean these records being dropped by stset
* CHANGED: 2012-10-02 - changed to 23:59:00 from 23:59:59 because of rounding errors
gen double last_trace = cofd(date_trace) + hms(23,58,00)
replace last_trace = icu_discharge if dead_icu == 1 & !missing(icu_discharge)
format last_trace %tc
label var last_trace "Timestamp last event"

gen male=sex==1
label var male "Sex"
label define male 0 "Female" 1 "Male"
label values male male

gen sepsis_b = inlist(sepsis,3,4)
label var sepsis_b "Clinical sepsis"
label define sepsis_b 0 "Unlikely"
label define sepsis_b 1 "Likely", add
label values sepsis_b sepsis_b

cap drop sepsis_severity
gen sepsis_severity = sepsis2001
replace sepsis_severity = 4 if inlist(sepsis2001, 4,5,6)
label var sepsis_severity "Sepsis severity"
label copy sepsis2001 sepsis_severity
label define sepsis_severity 4 "Septic shock" 5 "" 6 "", modify
tab sepsis_severity

cap drop sepsis_dx
gen sepsis_dx = 0
replace sepsis_dx = 1 if sepsis_b
replace sepsis_dx = 2 if sepsis_b & sepsis_site == 5
replace sepsis_dx = 3 if sepsis_b & sepsis_site == 3
replace sepsis_dx = 4 if sepsis_b & sepsis_site == 1
label var sepsis_dx "Sepsis diagnosis"
label define sepsis_dx 0 "Not septic" 1 "Unspecified sepsis" 2 "GU sepsis" 3 "GI sepsis" 4 "Chest sepsis"
label values sepsis_dx sepsis_dx
tab sepsis_dx

cap drop periarrest
gen periarrest = v_arrest == 1
label values periarrest truefalse

cap drop vitals1
gen vitals1 = inlist(vitals,5,4)
label var vitals1 "Intensive ward obs"
label values vitals1 truefalse
tab vitals1
// Collapse vitals down into simple list
replace vitals = 3 if inlist(vitals,1,2)

gen rxlimits = inlist(v_disposal,2,6)
label var rxlimits "Treatment limits at visit end"
label values rxlimits truefalse

gen dead7 = (date_trace - dofc(v_timestamp) <= 7 & dead)
replace dead7 = . if missing(date_trace)
label var dead7 "7d mortality"
label values dead7 truefalse

gen dead28 = (date_trace - dofc(v_timestamp) <= 28 & dead)
replace dead28 = . if missing(date_trace)
label var dead28 "28d mortality"
label values dead28 truefalse

gen dead90 = (date_trace - dofc(v_timestamp) <= 90 & dead)
replace dead90 = . if missing(date_trace)
label var dead90 "90d mortality"
label values dead90 truefalse

cap drop icufree_days
tempvar icu_los days_alive
gen `days_alive' 	= date_trace - dofc(v_timestamp)
gen `icu_los' 		= dofc(icu_discharge) - dofc(icu_admit) ///
	if !missing(icu_admit, icu_discharge)
replace `icu_los' = 0 if `icu_los' == .
gen icufree_days = 28 ///
	- cond(`days_alive' <= 28, 28 - `days_alive', 0) ///
	- cond(`icu_los' <= 28, `icu_los', 28)
label var icufree_days "Days alive without ICU (of 1st 28)"
su icufree_days

* Flag patients where so much physiology missing that associated with badness
cap drop icnarc_miss
egen icnarc_miss = rowmiss(hrate bpsys temperature rrate pao2 abgfio2 rxfio2 ph urea creatinine sodium urine_vol urine_period wcc gcst)
tab icnarc_miss
gen icnarc0 = icnarc_score
replace icnarc0 = . if icnarc_miss > 10
label var icnarc0 "ICNARC score (removing abnormal zeros)"

xtile icnarc_q3 = icnarc0, nq(3)
label var icnarc_q3 "ICNARC acute physiology tertiles"
xtile icnarc_q4 = icnarc0, nq(4)
label var icnarc_q4 "ICNARC acute physiology quartiles"
xtile icnarc_q5 = icnarc0, nq(5)
label var icnarc_q5 "ICNARC acute physiology quintiles"
xtile icnarc_q10 = icnarc0, nq(10)
label var icnarc_q10 "ICNARC acute physiology deciles"

label values icnarc_q* quantiles

egen time2icu_cat = cut(time2icu), at(0,4,12,24,36,72,168,672) label
* CHANGED: 2013-02-08 - better to code this as per a spike at zero approach
* replace time2icu_cat = 999 if time2icu == .

gen abg = !missing(abgunit)
label var abg "Arterial blood gas measurement"
label values abg truefalse

gen 	rxcvs = 0 if rxcvs_sofa == 0
replace rxcvs = 1 if rxcvs_sofa == 1
replace rxcvs = 2 if inlist(rxcvs_sofa,2,3,4,5)
label var rxcvs "Cardiovascular support"
label define rxcvs 0 "None" 1 "Volume resusciation" 2 "Vasopressor/Inotrope"
label values rxcvs rxcvs

gen pf = round(pf_ratio / 7.6)
label var pf "PF ratio (kPa)"

gen rx_resp = 0
replace rx_resp = 1 if inlist(rxfio2,1,2,3)
replace rx_resp = 2 if inlist(rxfio2,4,5)
label var rx_resp "Respiratory support"
label define rx_resp 0 "None" 1 "Supplemental oxygen" 2 "NIV"
label values rx_resp rx_resp

*  =======================================
*  = Defer and delay indicator variables =
*  =======================================
gen early4 = time2icu < 4
label var early4 "Early admission to ICU"
label define early 0 "Deferred" 1 "Early"
label values early4 early

gen defer4 = time2icu > 4
gen defer12 = time2icu > 12
gen defer24 = time2icu > 24
label define defer 0 "Early" 1 "Deferred"
label values defer4 defer12 defer24 defer

gen delay4 = 0 if time2icu < 4
replace delay4 = 1 if time2icu > 4 & !missing(time2icu)
gen delay12 = 0 if time2icu < 12
replace delay12 = 1 if time2icu > 12 & !missing(time2icu)
gen delay24 = 0 if time2icu < 24
replace delay24 = 1 if time2icu > 24 & !missing(time2icu)
label define delay 0 "Early" 1 "Delayed"
label values delay4 delay12 delay24 delay

*  ========================
*  = Time and period vars =
*  ========================
cap drop visit_tod
gen visit_hour = hh(v_timestamp)
label var visit_hour "Visitg (hour of day)"
egen visit_tod = cut(visit_hour), at(0,4,8,12,16,20,24) icodes label
label var visit_tod "Visit (time of day)"
* tab visit_tod

cap drop visit_dow
gen visit_dow = dow(dofc(v_timestamp))
label var visit_dow "Visit day of week"
label define dow ///
	0 "Sun" ///
	1 "Mon" ///
	2 "Tue" ///
	3 "Wed" ///
	4 "Thu" ///
	5 "Fri" ///
	6 "Sat"
label values visit_dow dow
tab visit_dow

* NOTE: 2013-01-11 - not sure that can make much of this given incomplete annual data
cap drop visit_month
gen visit_month = month(dofC(v_timestamp))
label var visit_month "Visit month of year"
label define month ///
	1 	"Jan" ///
	2 	"Feb" ///
	3 	"Mar" ///
	4 	"Apr" ///
	5 	"May" ///
	6 	"Jun" ///
	7 	"Jul" ///
	8 	"Aug" ///
	9 	"Sep" ///
	10 	"Oct" ///
	11 	"Nov" ///
	12 	"Dec"
label values visit_month month
tab visit_month

cap drop weekend
gen weekend = inlist(visit_dow, 0, 6)
label var weekend "Day of week"
label define weekend 0 "Monday--Friday"
label define weekend 1 "Saturday--Sunday", add
label values weekend weekend


cap drop out_of_hours
gen out_of_hours = !(visit_hour > 7 & visit_hour < 19)
label var out_of_hours "Time of day"
label define out_of_hours 0 "8am--6pm"
label define out_of_hours 1 "6pm--8am", add
label values out_of_hours out_of_hours


*  ===============
*  = CCOT shifts =
*  ===============

* NOTE: 2012-10-05 - depends on working and sites so be careful about code order

* CHANGED: 2013-01-15 - commented out as merge now happens at beginning
* merge m:1 icode using ../data/sites.dta, ///
* 	keepusing(ccot ccot_days ccot_start ccot_hours ccot_shift_pattern)

* drop if _m != 3
* drop _m

* NOTE: 2012-10-05 - defaults to no ccot: seems sensible but a discussion point
gen ccot_on = 0
label var ccot_on "CCOT on-shift"
label values ccot_on truefalse

replace ccot_on = 1 if ccot_shift_pattern == 3
* dow 0 = Sunday, 6 = Saturday
replace ccot_on = 1 if ccot_days == 7 & hh(v_timestamp) >= ccot_start ///
	& hh(v_timestamp) < ccot_start + ccot_hours
replace ccot_on = 1 if ccot_days == 6 & hh(v_timestamp) >= ccot_start ///
	& hh(v_timestamp) < ccot_start + ccot_hours ///
	& dow(dofc(v_timestamp)) != 0
replace ccot_on = 1 if ccot_days == 5 & hh(v_timestamp) >= ccot_start ///
	& hh(v_timestamp) < ccot_start + ccot_hours ///
	& inlist(dow(dofc(v_timestamp)), 1, 2, 3, 4, 5)

tab ccot_shift_pattern ccot_on, row

/*
NOTE: 2013-01-14 - now work out if patient seen at beginning or end of CCOT provision
- only relevant for sites <24/7 with CCOT
*/

label define ccot_shift_early 0 "Last 2 hours of shift" 1 "First 2 hours of shift"

cap drop ccot_shift_early
gen ccot_shift_early = .
label var ccot_shift_early "Flag if visit at beginning or end of shift"
replace ccot_shift_early = 1 if inlist(ccot_shift_pattern,2) ///
	& (hh(v_timestamp) - ccot_start <= 2)
replace ccot_shift_early = 1 if inlist(ccot_shift_pattern,1) ///
	& (hh(v_timestamp) - ccot_start <= 2) & !inlist(visit_dow,0,6)
replace ccot_shift_early = 0 if inlist(ccot_shift_pattern,1,2) ///
	& ((ccot_start + ccot_hours) - hh(v_timestamp)  <= 2)
label values ccot_shift_early ccot_shift_early
tab ccot_shift_early


gen ccot_hrs_perweek = 0
label var ccot_hrs_perweek "CCOT hours covered per week (of 168)"
replace ccot_hrs_perweek = ccot_hours * ccot_days if ccot
su ccot_hrs_perweek, d

cap drop ccot_shift_start
gen ccot_shift_start = ccot_shift_early == 1
* NOTE: 2013-01-30 - explored the monday morning effect but v few pts

*  ========================
*  = Broad patient groups =
*  ========================

gen org_ok = sofa_score <= 1
gen healthy = org_ok & news_risk == 0 & v_ccmds_rec <= 1 & rxlimits == 0
cap drop pt_cat
gen pt_cat = .
replace pt_cat = 1 if rxlimits == 1 & pt_cat == .
replace pt_cat = 3 if healthy == 1 & pt_cat == .
replace pt_cat = 2 if pt_cat == .

label var pt_cat "Patient type"
label define pt_cat 1 "Treatment limits" 2 "At risk" 3 "Low risk"
label values pt_cat pt_cat
tab pt_cat

cap drop v_decision
gen v_decision = .
replace v_decision = 0 if inlist(v_disposal,5,6)
replace v_decision = 1 if inlist(v_disposal,1,2)
replace v_decision = 2 if inlist(v_disposal,3)
replace v_decision = 3 if inlist(v_disposal,4)
label var v_decision "Decision after bedside assessment"
label define v_decision ///
	0 "No review planned" ///
	1 "Ward review planned" ///
	2 "Accepted to Level 2 bed" ///
	3 "Accepted to Level 3 bed"
label values v_decision v_decision

gen icu_accept = inlist(v_disposal,3,4)
label var icu_accept "Accepted to critical care"
gen icu_recommend =  inlist(v_ccmds_rec,2,3)
label var icu_recommend "Recommended for critical care"

*  =============
*  = Occupancy =
*  =============

/*
Let's make the standard variable a 3 level var for full active beds
CHANGED: 2013-01-31 - need to tidy this up
NOTE: 2013-01-12 - makes sense to measure this as absolute beds not a percentage

gen open_beds_cmp_pct = (cmp_beds_max - occupancy_active) / cmp_beds_max * 100
label var open_beds_cmp_pct "Percent open beds with respect to CMP reported number"
gen full_physically0 = free_beds_cmp <= 0
label var full_physically0 "No available critical care beds"
gen full_physically1 = free_beds_cmp <= 1
label var full_physically1 "No more than 1 physically empty bed"
gen beds_none = open_beds_cmp <= 0
label var beds_none "Critical care beds"
label define beds_none 0 "Available or can be made available"
label define beds_none 1 "No empty beds and none pending discharge", add
gen full_active1 = open_beds_cmp <= 1
label var full_active1 "No more than 1 dischargeable patient"
*/
gen open_beds_cmp = (cmp_beds_max - occupancy_active)
label var open_beds_cmp "Open beds with respect to CMP reported number"

gen bed_pressure = .
label var bed_pressure "Available critical care beds"
replace bed_pressure = 2 if open_beds_cmp <= 0
replace bed_pressure = 1 if open_beds_cmp >= 1
replace bed_pressure = 0 if open_beds_cmp >= 2
label define bed_pressure 0 "2 or more beds"
label define bed_pressure 1 "1 bed only", add
label define bed_pressure 2 "No beds", add
label values bed_pressure bed_pressure


gen beds_none = open_beds_cmp <= 0
label var beds_none "Critical care unit full"
label values beds_none truefalse

*  ============================================
*  = Prep vars in standardised way for models =
*  ============================================
/*
As a general rule of thumb
	- var with suffix _c = centred
	- var with suffix _k = categorical version
	- var with suffix _b = binary version
	- var with suffix _q = quintiles (where q is followed by number)
*/
* Patient vars

egen age_k = cut(age), at(18,40,60,80,200) icodes
label var age_k "Age"
label define age_k 0 "18-39"
label define age_k 1 "40-59", add
label define age_k 2 "60-79", add
label define age_k 3 "80+", add
label values age_k age_k
gen age_c = age - 65
label var age_c "Age (centred at 65yrs)"

gen delayed_referral = !v_timely
label var delayed_referral "Delayed referral to ICU"
label define delayed_referral 0 "Timely" 1 "Delayed"
label values delayed_referral delayed_referral
drop v_timely

* Site vars
cap drop referrals_permonth
cap drop pickone_site
egen pickone_site = tag(icode)
bys icode: egen referrals_permonth = mean(count_patients)
replace referrals_permonth = round(referrals_permonth)
label var referrals_permonth "New ward referrals (per month)"

egen referrals_permonth_k = cut(referrals_permonth), at(0,25,50,75,200) icodes
label var referrals_permonth_k "New ward referrals (per month)"
label define referrals_permonth_k 	0 "0--24"
label define referrals_permonth_k 	1 "25--49", add
label define referrals_permonth_k 	2 "50--74", add
label define referrals_permonth_k 	3 "75+", add
label values referrals_permonth_k referrals_permonth_k

foreach var of varlist icnarc0 sofa_score news_score {
	su `var', meanonly
	gen `var'_c = `var' - r(mean)
}

su referrals_permonth, meanonly
gen referrals_permonth_c = referrals_permonth - r(mean)

su hes_overnight, meanonly
gen hes_overnight_c = hes_overnight - r(mean)

su hes_emergx, meanonly
gen hes_emergx_c = hes_emergx - r(mean)

su cmp_beds_max, meanonly
gen cmp_beds_max_c = cmp_beds_max - r(mean)


* Round all centred variables
foreach var of varlist * {
	if substr("`var'",-2,2) != "_c" {
		continue
	}
	di as result "Rounding `var' to 1 decimal place"
	replace `var' = round(`var', 0.1)
}

*  =========================
*  = Drop unused variables =
*  =========================
* drop modifiedat dob lite_open lite_close elgdate elgreport_heads ///
* 	elgreport_tails elgprotocol allreferrals possible_duplicate ///
* 	icnno adno response_tails_note response_heads response_heads_note ///
* 	notes_light daicu taicu withinsh ddicu tdicu _list_unusualchks ///
* 	_list_imposschks exclude3 included_sites included_months


cap drop __*
save ../data/working_postflight.dta, replace
