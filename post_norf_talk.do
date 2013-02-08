include cr_survival.do

stset dt1, id(id) origin(dt0) failure(dead) exit(time dt0+90)
sts list, at(0 1 2 3 7 14 21 28 30 60 90) 
sts graph, xscale(noextend) ci ///
	xlabel(0 30 60 90) yscale(noextend) /// 
	xtitle("Days following referral") /// 
	ylabel(0 "0" .25 "25%" .5 "50%" .75 "75%" 1 "100%") ///
	ytitle("Survival") title("")


stset dt1, id(id) origin(dt0) failure(dead) exit(time dt0+28)
sts list, at(0 1 2 3 7 14 21 28)
sts graph, xscale(noextend) ci ///
	xlabel(0 7 14 21 28) yscale(noextend) /// 
	xtitle("Days following referral") /// 
	ylabel(0 "0" .25 "25%" .5 "50%" .75 "75%" 1 "100%") ///
	ytitle("Survival") title("")


sts graph, xscale(noextend) ci by(pt_cat) ///
	xlabel(0 7 14 21 28) yscale(noextend) /// 
	xtitle("Days following referral") /// 
	ylabel(0 "0" .25 "25%" .5 "50%" .75 "75%" 1 "100%") ///
	ytitle("Survival") title("") ///
	legend(off) ///
	ttext(.85 18 "Low risk", placement(e)) ///
	ttext(.65 18 "At risk", placement(e)) ///
	ttext(.40 18 "Treatment limits", placement(e)) ///
	scheme(tufte)