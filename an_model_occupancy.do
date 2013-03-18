*  ===================================
*  = Model determinants of occupancy =
*  ===================================

/*

Use the full occupancy data set as this produces your dependent variable
Merge in site level characteristics

- unit size
- severity of illness at admission
- CCOT provision
- HES admissions
- HES case mix

*/

clear
// pull the original data (hour level)
use ../../spot_study/data/working_occupancy24.dta
// CHANGED: 2013-03-18 - stay with four hour blocks for computational reasons
use ../../spot_study/data/working_occupancy.dta


replace icnno = lower(icnno)
replace icode = lower(icode)
count


// code copied from cr_preflight.do 130219
// because this file is off the 'working' stream then it is not possible to
// use the preflight do files
// hence manually copied these definitions over: beware changes
// TODO: 2013-02-22 - factor out these definitions from pre-flight or
	// or use a try/except structure in pre-flight

gen open_beds_cmp = (cmp_beds_max - occupancy_active)
label var open_beds_cmp "Open beds with respect to CMP reported number"

gen beds_none = open_beds_cmp <= 0
label var beds_none "Critical care unit full"
label values beds_none truefalse

gen beds_blocked = cmp_beds_max - occupancy <= 0
label var beds_blocked "Critical care unit unable to discharge"
label values beds_blocked truefalse

cap drop bed_pressure
gen bed_pressure = 0
label var bed_pressure "Bed pressure"
replace bed_pressure = 1 if beds_blocked == 1
replace bed_pressure = 2 if beds_none == 1
label define bed_pressure 0 "Beds available"
label define bed_pressure 1 "No beds but discharges pending", add
label define bed_pressure 2 "No beds and no discharges pending", add
label values bed_pressure bed_pressure

// try using the variables generated at the site level via cr_preflight
// should help make sure this remains uptodate

tempfile working
save `working', replace

use ../data/working_all_sensitivity.dta, clear
// make sure you use the above data and not working.dta fr cr_preflight
global debug = 0
include cr_preflight.do
duplicates drop icode, force
keep icode cmp_beds_persite hes_admissions hes_daycase hes_emergencies ///
	ccot ccot_days ccot_start ccot_hours all_cc_in_cmp ///
	studydays tails_all_percent tails_othercc cmp_patients_permonth ///
	ccot_shift_pattern hes_overnight hes_overnight_k hes_overnight_c ///
	hes_emergx hes_emergx_c hes_emergx_k cmp_beds_perhesadmx cmp_beds_peradmx_k ///
	patients_perhesadmx patients_perhesadmx_c

tempfile 2merge
save `2merge', replace
use `working', clear
merge m:1 icode using `2merge'
keep if _m == 3
drop _m

// now merge in key cmp characterisitcs
tempfile working
save `working', replace

* Now pull the tailsfinal data
local ddsn mysqlspot
local uuser stevetm
local ppass ""
* odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose
clear
odbc load, exec("SELECT * FROM spot_early.tailsfinal")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
count
bys icnno studymonth: egen admx_count = count(adno)

gen admx_elsurg_b = pa_v3 == "s"
label var admx_elsurg_b "Planned surgical admission"
collapse 	(median) imscore_p50 = imscore ///
			admx_p50 = admx_count ///
			(mean) admx_elsurg = admx_elsurg_b , ///
		 	by(icnno)
tempfile 2merge
save `2merge', replace
use `working', clear
merge m:1 icnno using `2merge'
cap drop _merge
label var imscore_p50 "Median ICNARC score at site"
label var admx_p50 "Median monthly CMP admissions at site"
label var admx_elsurg "Mean elective surgical admissions at site"

// finally count the number of cmp units per site
tempfile working
save `working', replace
contract icode icnno
bys icode: gen cmp_units = _N
label var cmp_units "Number of CMP units at site"
keep icnno cmp_units
tempfile 2merge
save `2merge', replace
use `working', clear
merge m:1 icnno using `2merge'
cap drop _merge


// final variable preparation
gen month = month(dofc(otimestamp))
label var month "Month of year"
cap label drop month
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
label values month month
tab month

cap drop tofd
gen tofd = 0
replace tofd = 1 if inlist(hh(otimestamp),5,6,7,8,9)
replace tofd = 2 if inlist(hh(otimestamp),15,16,17,18,19)
label var tofd "Time of day"
cap label drop tofd
label define tofd 0 "Reference"
label define tofd 1 "Early shift", modify
label define tofd 2 "Late shift", modify
label values tofd tofd
tab tofd

cap drop dow
gen dow = dow(dofc(otimestamp))
label var dow "Day of week"
cap label drop dow
label define dow ///
	0 "Sun" ///
	1 "Mon" ///
	2 "Tue" ///
	3 "Wed" ///
	4 "Thu" ///
	5 "Fri" ///
	6 "Sat"
label values dow dow
tab dow
cap drop weekend
gen weekend = inlist(dow, 0, 6)
label var weekend "Day of week"
label define weekend 0 "Monday--Friday"
label define weekend 1 "Saturday--Sunday", add
label values weekend weekend

egen pickone_site = tag(icode)
egen pickone_unit = tag(icnno)

encode icode, gen(site)
encode icnno, gen(unit)

// the following vars were all designed during univariate inspection
// moved here so easier to re-use scratch data
gen admx_low = admx_p50 < 50
label var admx_low "<50 CMP admissions per month"
gen imscore_p50_high = imscore_p50 >= 18
label var imscore_p50_high "4th quartile median ICNARC score"
gen admx_elsurg_low = admx_elsurg < 0.1
label var admx_elsurg_low "<10% elective surgical case mix"
gen small_unit = cmp_beds_max < 10
label var small_unit "<10 beds"
gen satsunmon = inlist(dow,0,1,6)
label var satsunmon "Sat-Sun-Mon"
gen decjanfeb = inlist(month,11,12,1)
label var decjanfeb "Dec-Jan-Feb"


// indicator var for hour of the week
cap drop hofw
gen hofw = (24 * dow) + hhC(otimestamp)
cap drop hour
gen hour = hhC(otimestamp)
cap drop imscore_p50_k
egen imscore_p50_k = cut(imscore_p50), at(0,15,18,100) label

// CHANGED: 2013-03-17 - run only for sites in sample
tempfile 2merge working
save `working', replace
use ../data/working.dta, clear
contract icode
drop _freq
save `2merge', replace
use `working', clear
merge m:1 icode using `2merge'
drop if _merge != 3
drop _merge

count if pickone_site
count if pickone_unit

duplicates report unit otimestamp
duplicates drop otimestamp unit, force
// TODO: 2013-03-12 - work out why you have dups
xtset unit otimestamp, delta(1 hours)

save ../data/scratch/scratch.dta, replace

*  =========================
*  = Now prepare the model =
*  =========================
/*
dependent var is beds_none
	- and later repeat for beds_blocked
	- or run as multinomial
independent vars
site level
	- CCOT provision
	- HES overnight
	- HES emergency case mix
	- patients_perhesadmx
unit level
	- median number of admissions
	- median severity of illness at admission
	- proportion of admissions that are elective surgical
	- unit size: cmp beds
time level
	- hour of the day
		parameterise as early am, late afternoon and other
	- day of the week
	- month of the year

Model form: random effects logistic
1. Start off just working with sites with a single unit
2. Then add in the third level and the remaining sites (expect much slower commands)
*/

use ../data/scratch/scratch.dta, clear
// set this up as panel data (within units not sites - how to handle this?)

// drop sites with multiple units for now
tab cmp_units if pickone_site
keep if cmp_units == 1

// univariate inspection
local inspect_univ = 0
if `inspect_univ' {
	tabstat beds_none, by(ccot_shift_pattern) s(n mean sd) format(%9.3g)

	tabstat beds_none, by(hes_overnight_k) s(n mean sd) format(%9.3g)
	running beds_none hes_overnight
	// NOTE: 2013-02-19 - non-linear: enter as categorical
	// also looks like this is being driven by a handful of specific hospitals

	tabstat beds_none, by(hes_emergx_k) s(n mean sd) format(%9.3g)
	running beds_none hes_emergencies
	// also enter as categorical

	running beds_none admx_p50
	// clear bump at the bottomr
	* gen admx_low = admx_p50 < 50
	* label var admx_low "<50 CMP admissions per month"
	tabstat beds_none, by(admx_low) s(n mean sd) format(%9.3g)

	running beds_none imscore_p50
	// NOTE: 2013-02-19 - flat to 15 then increasing
	// maybe best fit as fracpoly but this will be slow / tricky multilevel
	// categorise for now
	su imscore_p50, d
	// cut at 2,3rd quartile ... but no difference between 1-2 and 3
	// just pick out the top quartile

	tabstat beds_none, by(imscore_p50_k) s(n mean sd) format(%9.3g)
	* cap drop imscore_p50_high
	* gen imscore_p50_high = imscore_p50 >= 18
	* label var imscore_p50_high "4th quartile median ICNARC score"
	tabstat beds_none, by(imscore_p50_high) s(n mean sd) format(%9.3g)

	running beds_none admx_elsurg
	// NOTE: 2013-02-19 - no clear signal but maybe higher when low
	su admx_elsurg if pickone_site, d
	* gen admx_elsurg_low = admx_elsurg < 0.1
	* label var admx_elsurg_low "<10% elective surgical case mix"

	running beds_none cmp_beds_max
	// NOTE: 2013-02-19 - very interesting: decr risk but flat after 20
	// clear policy implicaton: don't have units smaller than 15-20 beds
	su cmp_beds_max if pickone_site, d
	* gen small_unit = cmp_beds_max < 10
	* label var small_unit "<10 beds"
	tabstat beds_none, by(small_unit) s(n mean sd) format(%9.3g)

	tabstat beds_none, by(tofd) s(n mean sd) format(%9.3g)
	// categorical

	tabstat beds_none, by(dow) s(n mean sd) format(%9.3g)
	* gen satsunmon = inlist(dow,0,1,6)
	* label var satsunmon "Sat-Sun-Mon"

	tabstat beds_none, by(month) s(n mean sd) format(%9.3g)
	* gen decjanfeb = inlist(month,11,12,1)
	* label var decjanfeb "Dec-Jan-Feb"
}

*  =====================
*  = Now run the model =
*  =====================

use ../data/scratch/scratch.dta, clear
// CHANGED: 2013-03-18 - just work within sites in early arm with one unit

count
count if pickone_site
count if pickone_unit

// CHANGED: 2013-03-18 - although not perfect use same variable spec as in other models
// use weekend instead of sat-sun-mon
// cmp_beds_max instead of smallunit
local ivars ///
	hes_overnight_c ///
	hes_emergx_c ///
	patients_perhesadmx_c ///
	cmp_beds_max ///
	ib3.ccot_shift_pattern ///
	admx_p50 ///
	admx_elsurg ///
	imscore_p50 ///
	decjanfeb ///
	weekend ///
	i.hour

global ivars `ivars'

// parsimonious form
local parsimonious = 0
if `parsimonious' == 1 {
	local ivars ///
		ib3.ccot_shift_pattern ///
		i.hes_overnight_k ///
		i.hes_emergx_k ///
		admx_low ///
		ib0.tofd ///
		imscore_p50_high ///
		admx_elsurg_low ///
		small_unit ///
		satsunmon ///
		decjanfeb

	global ivars `ivars'
}

local debug = 0
if `debug' == 1 {
	keep if site <= 30
	keep if month(dofC(otimestamp)) == 3
	count
}

set matsize 10000
*  ========================
*  = Estimate using xtgee =
*  ========================
/*
- robust standard errors given you have units within the same site
- ar 1 correlation
*/
xtgee beds_none $ivars, family(binomial 1) link(logit) corr(ar 1) vce(robust)

* logistic beds_none $ivars, vce(robust)
* xtset site
* xtlogit beds_none $ivars, or
estimates save ../data/estimates/occupancy_2level.ster, replace

*  ============================================
*  = Produce a model results table for thesis =
*  ============================================
use ../data/scratch/scratch.dta, clear
qui include mt_Programs
estimates use ../data/estimates/occupancy_2level.ster
estimates esample: ///
	hes_overnight_c hes_emergx_c patients_perhesadmx_c cmp_beds_max ///
	ccot_shift_pattern admx_p50 admx_elsurg imscore_p50 ///
	decjanfeb weekend hour

// replay
// NOTE: 2013-03-18 - note groups = 48 with 45 sites b/c 3 sites have 2 units
xtgee
tempfile temp1
parmest , ///
	eform ///
	label list(parm label estimate min* max* p) ///
	format(estimate min* max* %8.3f p %8.3f) ///
	saving(`temp1', replace)
use `temp1', clear
// now label varname
mt_extract_varname_from_parm
// now get tablerowlabels
spot_label_table_vars
// now produce table order
global table_order ///
	hes_overnight hes_emergx patients_perhesadmx ccot_shift_pattern ///
	gap_here ///
	cmp_beds_max admx_p50 admx_elsurg imscore_p50 ///
	gap_here ///
	decjanfeb weekend hour
mt_table_order
sort table_order var_level
// indent categorical variables
mt_indent_categorical_vars

ingap 1 9 13
replace tablerowlabel = "\textit{Site factors}" if _n == 1
replace tablerowlabel = "\textit{Unit factors}" if _n == 10
replace tablerowlabel = "\textit{Timing factors}" if _n == 15


sdecode estimate, format(%9.2fc) gen(est)
sdecode min95, format(%9.2fc) replace
sdecode max95, format(%9.2fc) replace
sdecode p, format(%9.2fc) replace
replace p = "<0.001" if p == "0.000"
gen est_ci95 = "(" + min95 + "--" + max95 + ")" if !missing(min95, max95)
replace est = "--" if reference_cat == 1
replace est_ci95 = "" if reference_cat == 1

* now write the table to latex
order tablerowlabel var_level_lab est est_ci95 p
local cols tablerowlabel est est_ci95 p
order `cols'
cap br

local table_name occupancy_2level
local h1 "Parameter & Odds ratio & (95\% CI) & p \\ "
local justify lrll
* local justify X[5l] X[1l] X[2l] X[1r]
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}
local rho: di %9.3fc `=e(rho)'
local f1 "Intraclass correlation & `rho' &&} \\"
di "`f1'"

listtab `cols' ///
	using ../outputs/tables/`table_name'.tex ///
	if parm != "_cons", ///
	replace ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\sffamily{" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} to " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\midrule" ///
		"`f1'" ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{`table_name'} " ///
		"\normalfont" ///
		"\normalsize")


di as result "Created and exported `table_name'"


*  =====================
*  = Run 3 level model =
*  =====================
// CHANGED: 2013-03-18 - this does not account for the AR1 structure
// and it takes days to fit
exit
use ../data/working_occupancy.dta, clear
* NOTE: 2013-02-19 - see p.447 Rabe-Hesketh and Skrondal
* the ordering of the vars in i is important (goes up the levels)

tab ccot_shift_pattern, gen(ccot_)
tab hes_overnight_k, gen(hes_o_)
tab hes_emergx_k, gen(hes_e_)
tab tofd, gen(tofd_)

local ivars_long ///
	ccot_1 ccot_2 ccot_3 ///
	hes_o_2 hes_o_3 hes_o_4 ///
	hes_e_2 hes_e_3 ///
	tofd_1 tofd_2 ///
	imscore_p50_high ///
	admx_elsurg_low ///
	small_unit ///
	satsunmon ///
	decjanfeb

// NOTE: 2013-02-22 - use only 5 quadrature points b/c this is slow
// and ordinary quadrature
// then take the estimates from this to run the default spec
// which is 8 points and adaptive quadrature
global ivars_long `ivars_long'
gllamm beds_none $ivars_long ///
	, ///
	family(binomial) ///
	link(logit) ///
	i(unit site) ///
	nip(5) ///
	eform

estimates save ../data/estimates/occupancy_3level_step1.ster, replace

matrix a = e(b)
gllamm beds_none $ivars_long ///
	, ///
	family(binomial) ///
	link(logit) ///
	i(unit site) ///
	nip(8) ///
	eform ///
	from(a) adapt

estimates save ../data/estimates/occupancy_3level.ster, replace
*  ========================================
*  = Now output model as table for thesis =
*  ========================================

