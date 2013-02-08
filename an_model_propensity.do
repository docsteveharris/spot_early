*  ===========================================================
*  = Use propensity score data and estimate treatment effect =
*  ===========================================================
GenericSetupSteveHarris spot_early an_model_propensity, logon

local clean_run 0
if `clean_run' == 1 {
	clear
	include cr_propensity.do
}
* NOTE: 2013-02-05 - this is the full data (without matching)
use ../data/working_propensity_all.dta, clear


cap log off