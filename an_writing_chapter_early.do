*  ======================================================
*  = Running do file for all numbers quoted in the text =
*  ======================================================

clear
cd ~/data/spot_early/vcode
use ../data/working.dta
qui include cr_preflight.do
count
