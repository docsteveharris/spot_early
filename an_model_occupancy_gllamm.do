/*
NOTE: 2013-02-22 - just a copy of the gllamm model in the main file
so can be run in batch mode from the console
and I can keep working
*/

*  =====================
*  = Run 3 level model =
*  =====================
cd /Users/steve/Data/spot_early/vcode
use ../data/working_occupancy.dta, clear
* sample 1
count
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
