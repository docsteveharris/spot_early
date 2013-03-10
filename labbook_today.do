*  ======================================================================
*  = Does the linear IV model have different effects at different times =
*  ======================================================================

/*
- severity as dependent var model
	- include occupancy in the model to demonstrate that there is *no* effect of occupancy on patient severity until *after* the visit
	- table of comparative models: effect of occupancy on 
		- severity at referral (all patients)
		- severity at referral (admitted patients): unadjusted
		- severity at referral (admitted patients): adjusted
		- severity at admission (admitted patients): unadjusted
		- severity at admission (admitted patients): adjusted
*/

*  =============================================================
*  = Set up the data so you have visit and admissions severity =
*  =============================================================

local clean_run 0
if `clean_run' == 1 {
    clear
    use ../data/working.dta
    include cr_preflight.do
    include cr_working_tails.do
}

use ../data/working_tails.dta, clear
tempfile 2merge
save `2merge', replace
use ../data/working_postflight.dta, clear
// double check that icnno and adno are unique
duplicates report icnno adno
merge m:1 icnno adno using `2merge'
drop _m
save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

*  ===============================================
*  = Model variables assembled into single macro =
*  ===============================================
local all_vars ///
	delayed_referral ///
	out_of_hours ///
	weekend ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c ///
	beds_none 

global model_vars `all_vars'

xtset site
xtreg icnarc0 $ivars_4model
xtreg icnarc0 $ivars_4model if !missing(imscore)


xtreg imscore $ivars_4model
