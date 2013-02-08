* labbook running
* keep a running archive of code snippets you don't want to lose

* 130207
* code snippets from deriving strobe diagram for working_early
tab route_to_icu all_cc_in_cmp, col
tab route_to_icu simple_site, col

// so it more likely you go to the CMP monitored unit at a simple site
tabstat icucmp , by(simple_site) s(n mean sd q) format(%9.3g)
// do you get there more quickly (and therefore by a less round about route)
tabstat tails_othercc, by(simple_site) s(n mean sd q) format(%9.3g)
tabstat time2icu, by(simple_site) s(n mean sd q) format(%9.3g)

cap drop route_via_theatre
gen route_via_theatre = route_to_icu == 1
label var route_via_theatre "Admitted to ICU via theatre"
label values route_via_theatre truefalse

tabstat time2icu, by(route_via_theatre) s(n mean sd q) format(%9.3g)
ttest time2icu, by(route_via_theatre)

// add these as 2 extra exclusions
count if simple_site == 0
count if route_via_theatre == 1
drop if simple_site == 0
drop if route_via_theatre == 1

count
count if pickone_site
egen pickone_month = tag(icode studymonth)
count if pickone_month

