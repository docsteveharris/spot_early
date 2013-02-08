*  ===================
*  = Visits by month =
*  ===================

use ../data/working.dta, clear
contract studymonth
rename _freq v
su v
replace v=round(v/r(max)*100)
gen i=1
reshape wide v, i(i) j(studymonth)
br
exit

example from run on 26 Sep 2012 pasted below

i	v1	v2	v3	v4	v5	v6	v7	v8	v9	v10	v11	v12
1	100+96+76+83+72+79+77+60+48+35+27+19




*  ===========================
*  = Visits by month by site =
*  ===========================
* Deteriorating ward patients
* run the following code and then copy paste into a text editior
* replace spaces with + signs
* split into two columns
* then paste into omnigraffle and use chartwell bars

use ../data/working.dta, clear
gen v=1
collapse (firstnm) dorisname  site_qm=site_quality_by_month ///
	(median) fields=filled_fields_count (count) v , by(icode studymonth) 
su v
replace v=v/r(max)*100
encode dorisname, gen(sitename)
replace v=round(v)
reshape wide v site_qm fields, i(sitename) j(studymonth)
forvalues i= 1/12 {
replace v`i'=0 if v`i'==.
}
gen jjj="jjj"
order jjj, after(sitename)
egen v_median = rowmedian(v*)
egen site_hnt_pct=rowmean(site_qm*)
egen median_fields=rowmedian(fields*)
drop fields*
su median_fields
replace median_fields=round(median_fields/r(max)*100)
replace site_hnt_pct=round(site_hnt_pct)
drop site_qm*
label var site_hnt_pct "Site Heads'n'Tails %"
gsort -v_median
replace v_median = round(v_median)
br
merge 1:1 icode using ../data/sites.dta
keep if _m==3
gsort -v_median

preserve
keep icode
gen order=_n
label var order "... by visits"
save ../data/sites_ordered_by_visits.dta, replace
restore

exit
example from run on 26 Sep 2012 pasted below

sitename	jjj	v1	v2	v3	v4	v5	v6	v7	v8	v9	v10	v11	v12
royal berkshire hospital
harrogate district hospital
medway maritime hospital
st james's university hospital
pilgrim hospital
huddersfield royal infirmary
watford general hospital
maidstone hospital
bradford royal infirmary
the christie hospital
the queen elizabeth hospital, king's lynn
the royal liverpool university hospital
southend university hospital
royal victoria hospital
tameside general hospital
royal hampshire county hospital
royal glamorgan general hospital
derriford hospital
poole hospital
whipps cross university hospital
kettering general hospital
queen elizabeth hospital gateshead
west cumberland hospital
ulster hospital
wexham park hospital
northampton general hospital
lister hospital
barnsley hospital
warrington hospital
royal preston hospital
dewsbury and district hospital
homerton hospital
royal surrey county hospital
william harvey hospital
worcestershire royal hospital
musgrove park hospital
wycombe hospital
the ipswich hospital
southampton general hospital
pinderfields hospital

99+85+100+86+89+82+98+91+74+83+0+58
45+68+75+59+87+58+56+0+42+53+56+56
61+62+56+54+52+44+44+42+41+0+0+0
39+49+38+48+44+39+45+48+50+0+0+0
35+37+38+39+53+41+53+42+27+37+40+0
30+38+39+24+28+35+40+43+36+0+0+0
40+35+19+35+26+26+28+38+25+35+46+0
31+32+30+32+27+27+32+30+30+0+27+20
44+46+32+30+32+28+23+23+12+11+8+3
26+24+20+32+25+34+35+30+24+0+0+0
23+28+25+32+28+32+25+0+20+0+0+0
28+21+23+0+28+23+0+30+23+30+1+0
40+38+0+19+25+24+21+22+17+33+15+26
38+25+29+28+21+37+26+0+0+0+0+0
0+38+0+25+0+33+31+0+0+23+26+22
19+19+18+15+19+21+15+17+21+21+14+0
21+15+19+25+28+23+19+10+0+0+0+0
0+15+20+19+18+24+19+18+15+0+0+0
20+19+15+15+13+15+17+14+17+9+0+0
21+12+17+12+13+12+21+15+15+13+21+18
21+12+14+16+16+16+11+8+15+10+16+12
28+17+15+11+10+16+18+17+11+13+0+0
33+36+0+40+0+33+28+0+0+0+34+0
25+20+17+15+23+15+10+0+0+0+0+0
58+27+22+15+16+11+5+12+6+0+0+0
22+17+19+14+13+16+5+6+9+8+0+0
7+14+12+10+9+13+9+0+11+11+7+0
6+7+7+7+7+12+5+0+7+0+0+0
24+17+0+14+0+0+0+9+9+10+0+0
23+24+0+0+28+28+23+7+0+0+0+0
23+16+23+0+0+0+23+28+0+0+0+0
54+43+7+0+0+0+0+0+0+0+0+0
15+15+0+19+0+0+0+0+0+0+0+0
0+19+23+30+23+9+0+0+0+0+0+0
26+19+19+23+0+0+16+0+0+0+0+0
0+0+0+0+0+54+91+94+0+0+0+0
8+9+13+11+11+0+0+0+0+0+0+0
32+18+25+30+0+18+0+0+0+0+0+0
72+65+62+67+0+0+0+0+0+0+0+0
26+18+0+21+23+19+0+0+0+0+0+0