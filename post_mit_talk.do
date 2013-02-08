include cr_survival.do
stset dt1, id(id) origin(dt0) failure(dead) exit(time dt0+28)
sts list, at(28 30)

su time2icu if ppsample, d
gen icu_ever = time2icu != .
tab icu_ever if ppsample

cap drop time2icu_cat
egen time2icu_cat = cut(time2icu), at(0,4,12,24,36,72,168,672) label
replace time2icu_cat = 999 if time2icu == .
* replace time2icu_cat = 999 if time2icu / 24 > `origin'
tab time2icu_cat if ppsample & _st == 1



gen early4 = time2icu<4
replace early4 = . if time2icu == .
label var early4 "Early ICU"
label define early4 0 "Delayed" 1 "Early"
label values early4 early4
tab early4
sts graph, by(early4) ///
	plot1opts(lcolor(black) lpattern(solid)) ///
	plot2opts(lcolor("9 142 155") lpattern(solid)) ///
	xtitle("Days") ///
	legend(pos(3) label(1 "Delayed") label(2 "Early") order(2 1))

gen early4_all = time2icu < 4
tab early4_all
sts graph, by(early4_all) ///
	plot1opts(lcolor(black) lpattern(solid)) ///
	plot2opts(lcolor("9 142 155") lpattern(solid)) ///
	xtitle("Days") ///
	legend(pos(3) label(1 "Wait & see") label(2 "Early") order(2 1))


* NOTE: 2012-11-26 - icnarc tertiles
cap drop icnarc_q3
xtile icnarc_q3 = icnarc_score, nq(3)
label var icnarc_q3 "ICNARC score tertiles"
tab icnarc_q3
forvalues i = 1/3 {
	sts graph if icnarc_q3 == `i', by(early4_all) ///
	plot1opts(lcolor(black) lpattern(solid)) ///
	plot2opts(lcolor("9 142 155") lpattern(solid)) ///
	xtitle("Days") ///
	title("Severity tertile (`i')", size(medsmall)) ///
	name(plot`i', replace) ///
	legend(pos(6) label(1 "Wait & see") label(2 "Early") order(1 2))
}
graph combine plot1 plot2 plot3 , rows(1) xcommon ycommon ///
	name(survival_by_icnarc_q3, replace)
graph export ../logs/survival_by_icnarc_q3.pdf, replace



