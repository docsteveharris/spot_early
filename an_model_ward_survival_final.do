*  =======================================================================
*  = Produce a table showing coefficients from final ward survival model =
*  =======================================================================

GenericSetupSteveHarris spot_early an_survival_ward, logon

/*
Consider the following models
- individual univariate hazard ratio estimates
- full model - ignoring frailty
- full model accounting for frailty
*/


*  ===================
*  = Model variables =
*  ===================
local patient_vars age_c male sepsis_b delayed_referral icnarc0_c i.v_ccmds
local timing_vars out_of_hours weekend beds_none
local site_vars ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c

*  ===============================================
*  = Model variables assembled into single macro =
*  ===============================================
local all_vars age_c male sepsis_b delayed_referral icnarc0_c i.v_ccmds ///
	out_of_hours weekend beds_none ///
	referrals_permonth_c ///
	ib3.ccot_shift_pattern ///
	hes_overnight_c ///
	hes_emergx_c ///
	cmp_beds_max_c



local clean_run 1
if `clean_run' == 1 {
	include cr_survival.do

	global table_name ward_survival_final_est
	use ../data/working_survival.dta, clear
	// NOTE: 2013-01-29 - cr_survival.do stsets @ 28 days by default

	local i 1
	// =====================================
	// = Run full model - ignoring frailty =
	// =====================================
	stcox age_c male sepsis_b delayed_referral ///
		icnarc0_c ///
		i.v_ccmds ///
		out_of_hours weekend beds_none ///
		referrals_permonth_c ///
		ib3.ccot_shift_pattern ///
		hes_overnight_c ///
		hes_emergx_c ///
		cmp_beds_max_c ///
		, ///
		nolog

	local model_name full no_frailty
	est store full1
	tempfile estimates_file
	parmest, ///
		eform ///
		label list(parm label estimate min* max* p) ///
		idnum(`i') idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		format(estimate min* max* %9.2f p %9.3f) ///
		saving(`estimates_file', replace)
	use `estimates_file', clear
	gen table_order = _n
	save ../outputs/tables/$table_name.dta, replace
	local ++i

	// ===============================================
	// = Run model with time-dependence for severity =
	// ===============================================
	use ../data/working_survival.dta, clear
	stsplit tb, at(1 3 7)
	label var tb "Analysis time blocks"
	stcox age_c male sepsis_b delayed_referral ///
		icnarc0_c ///
		i.v_ccmds ///
		out_of_hours weekend beds_none ///
		referrals_permonth_c ///
		ib3.ccot_shift_pattern ///
		hes_overnight_c ///
		hes_emergx_c ///
		cmp_beds_max_c ///
		i.tb#c.icnarc0_c ///
		, ///
		nolog

	local model_name full time_dependent
	est store full2
	tempfile estimates_file
	parmest, ///
		eform ///
		label list(parm label estimate min* max* p) ///
		idnum(`i') idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		format(estimate min* max* %9.2f p %9.3f) ///
		saving(`estimates_file', replace)
	use `estimates_file', clear
	gen table_order = _n
	save `estimates_file', replace
	use ../outputs/tables/$table_name.dta, clear
	append using `estimates_file'
	save ../outputs/tables/$table_name.dta, replace
	local ++i



	// ===============================
	// = Run full model with frailty =
	// ===============================
	use ../data/working_survival.dta, clear
	stsplit tb, at(1 3 7)
	label var tb "Analysis time blocks"
	stcox age_c male sepsis_b delayed_referral ///
		icnarc0_c ///
		i.v_ccmds ///
		out_of_hours weekend beds_none ///
		referrals_permonth_c ///
		ib3.ccot_shift_pattern ///
		hes_overnight_c ///
		hes_emergx_c ///
		cmp_beds_max_c ///
		i.tb#c.icnarc0_c ///
		, ///
		shared(site) ///
		nolog

	local model_name full_frailty
	est store full3
	estimates save ../data/survival_final, replace
	tempfile estimates_file
	parmest, ///
		eform ///
		label list(parm label estimate min* max* p) ///
		idnum(`i') idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		escal(theta se_theta) ///
		format(estimate min* max* %9.2f p %9.3f) ///
		saving(`estimates_file', replace)
	use `estimates_file', clear
	gen table_order = _n
	save `estimates_file', replace
	use ../outputs/tables/$table_name.dta, clear
	append using `estimates_file'
	save ../outputs/tables/$table_name.dta, replace
	local ++i

	// Univariate estimates
	local uni_vars age_c male sepsis_b delayed_referral ///
		icnarc0_c ///
		i.v_ccmds ///
		out_of_hours weekend beds_none ///
		referrals_permonth_c ///
		ib3.ccot_shift_pattern ///
		hes_overnight_c ///
		hes_emergx_c ///
		cmp_beds_max_c ///

	local table_order = 1
	foreach var of local uni_vars {
		use ../data/working_survival.dta, clear
		qui stcox `var'
		est store u_`i'
		local model_name: word 4 of `=e(datasignaturevars)'
		local model_name = "univariate `model_name'"
		parmest, ///
			eform ///
			label list(parm label estimate min* max* p) ///
			idnum(`i') idstr("`model_name'") ///
			stars(0.05 0.01 0.001) ///
			format(estimate min* max* %9.2f p %9.3f) ///
			saving(`estimates_file', replace)
		use `estimates_file', clear
		gen table_order = `table_order'
		local ++table_order
		save `estimates_file', replace
		use ../outputs/tables/$table_name.dta, clear
		append using `estimates_file'
		save ../outputs/tables/$table_name.dta, replace
		local ++i
	}

}

* Save a version of the data with a clean name
* so you don't need to re-run the models when debugging
save ../data/scratch/scratch.dta, replace

use ../data/scratch/scratch.dta, clear
cap drop varname model model_name var_level
* Now do a quick bit of variable tidying
gen varname = parm

gen model_name = .
replace model_name = 1 if idstr == "full no_frailty"
replace model_name = 2 if idstr == "full time_dependent"
replace model_name = 3 if idstr == "full_frailty"
replace model_name = 0 if word(idstr, 1) == "univariate"
cap label drop model_name
label define model_name 0 "Univariate"
label define model_name 1 "Multivariate", add
label define model_name 2 "Time-dependent", add
label define model_name 3 "Frailty", add
label values model_name model_name
decode model_name, gen(model)

replace varname = substr(parm, 1, length(parm) - 2) if substr(parm,-2,2) == "_c"
replace varname = substr(parm, 1, length(parm) - 2) if substr(parm,-2,2) == "_b"
replace varname = ///
	substr(parm, strpos(parm, ".") + 1, length(parm) - strpos(parm, ".") + 1) ///
	if strpos(parm, ".")
replace varname = "icnarc0" if strpos(parm,"icnarc0")
gen var_level = substr(parm,1,1) if strpos(parm, ".")
destring var_level, replace

* All this is so that you have appropriate blank rows in table
* for icnarc0 which has extra variables in 3rd and 4th model
bys model_name varname: egen table_pos_min = min(table_order)
replace var_level = -1 if varname == "icnarc0" & missing(var_level)


expand 2 if varname == "icnarc0" & inlist(model_name,2), gen(expanded_dummy1)
drop if var_level == -1 & expanded_dummy1
replace model_name = 0 if expanded_dummy1

expand 2 if varname == "icnarc0" & inlist(model_name,2), gen(expanded_dummy2)
drop if var_level == -1 & expanded_dummy2
replace model_name = 1 if expanded_dummy2

foreach var in stderr idstr parm label estimate z p stars min95 max95 es_1 es_2 model idstr {
	cap replace `var' = . if expanded_dummy == 1
	cap replace `var' = "" if expanded_dummy == 1
}
cap drop seq
bys model_name (table_pos_min var_level): egen seq = seq()
drop table_order
rename seq table_order

gen dummy = expanded_dummy1 | expanded_dummy2
cap drop expanded_dummy*

save ../outputs/tables/$table_name.dta, replace

*  ==========================================================
*  = Now merge in variable chararcteristics from dictionary =
*  ==========================================================

global table_name ward_survival_final_est
use ../outputs/tables/$table_name,clear
cap drop stataformat tablerowlabel unitlabel attributes_found

spot_label_table_vars

save ../outputs/tables/$table_name.dta, replace

*  ========================
*  = Produce LaTeX tables =
*  ========================
use ../outputs/tables/$table_name.dta, clear
local model_name Univariate Multivariate Multivariate(Frailty)

gen var_level_lab = ""
* CCMDS level of care
replace var_level_lab = "Level 0" if varname == "v_ccmds" & var_level ==0
replace var_level_lab = "Level 1" if varname == "v_ccmds" & var_level ==1
replace var_level_lab = "Level 2" if varname == "v_ccmds" & var_level ==2
replace var_level_lab = "Level 3" if varname == "v_ccmds" & var_level ==3

* CCOT shift pattern
replace var_level_lab = "No CCOT" if varname == "ccot_shift_pattern" & var_level ==0
replace var_level_lab = "Less than 7 days" if varname == "ccot_shift_pattern" & var_level == 1
replace var_level_lab = "7 days / week" if varname == "ccot_shift_pattern" & var_level == 2
replace var_level_lab = "24 hrs / 7 days" if varname == "ccot_shift_pattern" & var_level == 3

* Time-dependence of severity
replace var_level_lab = "Day 0 effect" if varname == "icnarc0" & var_level == -1
* Label these as effect modifiers
drop if varname == "icnarc0" & var_level == 0

* replace var_level_lab = "Day 0 modifier"  if varname == "icnarc0" & var_level == 0
replace var_level_lab = "Days 1--2 modifier"  if varname == "icnarc0" & var_level == 1
replace var_level_lab = "Days 3--7 modifier"  if varname == "icnarc0" & var_level == 3
replace var_level_lab = "Days 8+ modifier" if varname == "icnarc0" & var_level == 7

sort model_name table_order var_level
order model table_order parm tablerowlabel var_level var_level_lab estimate stars

local theta_est = es_1[_N]
local theta_se = es_2[_N]

gen est = estimate
sdecode estimate, format(%9.2fc) replace
replace stars = "\textsuperscript{" + stars + "}"
replace estimate = estimate + stars

replace estimate = "" if varname == "icnarc0" & var_level >= 0 & inlist(model_name,0,1)



drop idnum idstr  label stderr z stataformat ///
	attributes_found es_1 es_2 dummy table_pos_min model

chardef tablerowlabel estimate, ///
	char(varname) prefix("\textit{") suffix("}") ///
	values("Parameter" "Hazard ratio")

xrewide estimate stars est min95 max95 p , ///
	i(table_order) j(model_name) cjlabel(models) lxjk(nonrowvars)

*  ===================================
*  = Produce comparative model table =
*  ===================================

listtab_vars tablerowlabel `nonrowvars', rstyle(tabular) ///
	substitute(char varname) local(h1)

order table_order tablerowlabel estimate0 estimate1 estimate2 estimate3
ingap 5 9 17, gapindicator(gap)
gen seq = _n
replace tablerowlabel = tablerowlabel[_n+1] if missing(tablerowlabel)
replace tablerowlabel = var_level_lab if !missing(var_level_lab)
replace tablerowlabel =  "\hspace*{1em}{" + tablerowlabel + "}" ///
	if missing(var_level_lab)
replace tablerowlabel =  "\hspace*{2em}\smaller[1]{" + tablerowlabel + "}" ///
	if !missing(var_level_lab)

foreach var in estimate0 estimate1 estimate2 estimate3 {
	replace `var' = "--" if varname == "ccot_shift_pattern" & var_level == 3
	replace `var' = "--" if varname == "v_ccmds" & var_level == 0
}

di "`nonrowvars'"

* Other headings
ingap 1 15 18
replace tablerowlabel = "\textit{Patient parameters}" if _n == 1
replace tablerowlabel = "\textit{Timng parameters}" if _n == 16
replace tablerowlabel = "\textit{Site parameters}" if _n == 20

local obs = _N+1
set obs `obs'
di "`theta_est'"
local new = substr("`theta_est'",1,3)
local new "0`new'"
di "`new'"
replace tablerowlabel = "\textit{Site level variance $(\theta)$}" if _n == _N
replace estimate3 = "`new'\textsuperscript{***}" if _n == _N

local cols estimate0 estimate1 estimate2 estimate3
* local super_heading "& \multicolumn{2}{c}{Univariate} & \multicolumn{2}{c}{Multivariate} & \multicolumn{2}{c}{Multivariate(with frailty)} \\ "
local super_heading "& \multicolumn{4}{c}{Hazard ratio} \\"
local h1 "& Univariate & Multivariate & Time-dependent & Frailty \\ "
local justify lXXXX
local tablefontsize "\footnotesize"
local arraystretch 1.1
local taburowcolors 2{white .. white}

listtab tablerowlabel `cols' ///
	using ../outputs/tables/$table_name.tex, ///
	replace rstyle(tabular) ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\sffamily{" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`super_heading'" ///
		"\cmidrule(r){2-5}" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{$table_name} " ///
		"\normalfont" ///
		"\normalsize")

di as result "Created and exported $table_name (best)"

*  =========================
*  = Produce results table =
*  =========================
sdecode est3, format(%9.2fc) replace
sdecode min953, format(%9.2fc) replace
sdecode max953, format(%9.2fc) replace
sdecode p3, format(%9.3fc) replace
replace p3 = "<0.001" if p3 == "0.000"
replace est3 = "--" if varname == "ccot_shift_pattern" & var_level == 3
replace est3 = "--" if varname == "v_ccmds" & var_level == 0

cap drop bracket3
gen bracket3 = "(" + min953 + "--" + max953 + ")" if !missing(min953, max953)
replace est3 = estimate3 if _n == _N

local cols tablerowlabel est3 bracket3 p3
order `cols'

local h1 "Parameter & Hazard Ratio & (95\% CI) & p \\ "
local justify  X[5r]X[r]X[2r]X[r]
local tablefontsize "\footnotesize"
local arraystretch 1.1
local taburowcolors 2{white .. white}
local table_name $table_name


listtab tablerowlabel est3 bracket3 p3 ///
	using ../outputs/tables/`table_name'_best.tex, ///
	replace rstyle(tabular) ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\sffamily{" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu} } " ///
		"\label{`table_name'_best} " ///
		"\normalfont" ///
		"\normalsize")


di as result "Created and exported $table_name (best)"

*  =====================================
*  = Now inspect importance of frailty =
*  =====================================
est restore full3
est replay full3

* predict the random effects
cap drop site_re
predict site_re, effects
gsort +site_re
list icode dorisname site_re in 1/10
* NOTE: 2013-02-03 - musgrove park: best effect
gsort -site_re
list icode dorisname site_re in 1/10
* NOTE: 2013-02-03 - tameside worst effect

*  ======================================
*  = Plot the baseline survival frailty =
*  ======================================
cap restore, not
preserve

su site_re
local site_re_min = r(min)
local site_re_max = r(max)
stcurve, survival ///
 	outfile(../data/scratch/base_survival, replace)
use ../data/scratch/base_survival, clear
duplicates drop surv1 _t, force
rename surv1 base_surv_est
gen base_surv_max = base_surv_est^(exp(`site_re_max'))
gen base_surv_min = base_surv_est^(exp(`site_re_min'))

* Manually create the graph: beware 60k data points so draws very slowly
line base_surv_min base_surv_est base_surv_max _t ///
	, ///
	sort c(J J J) ///
	ylab(0(0.25)1, format(%9.2f) nogrid) ///
	yscale(noextend) ///
	ytitle("Survival (proportion)") ///
	xlab(0(7)28) ///
	xscale(noextend) ///
	xtitle("Days following assessment") ///
	legend( ///
		label(1 "Best site") ///
		label(2 "Mean survival") ///
		label(3 "Worst site") ///
		cols(1) position(4) ring(0) ///
		)
graph rename survival_reffects, replace
graph export ../outputs/figures/survival_reffects.pdf, ///
	name(survival_reffects) ///
	replace

restore


*  ================================
*  = Now draw the baseline hazard =
*  ================================
cap restore, not
preserve

su site_re
local site_re_min = r(min)
local site_re_max = r(max)
stcurve, hazard kernel(gaussian) ///
 	outfile(../data/scratch/base_hazard, replace)
use ../data/scratch/base_hazard, clear
rename haz1 base_haz_est
label var base_haz_est "Mean frailty hazard"
gen base_haz_min = base_haz_est * (exp(`site_re_min'))
gen base_haz_max = base_haz_est * (exp(`site_re_max'))

line base_haz_min base_haz_est base_haz_max _t ///
	, ///
	sort c(l l l) ///
	ylab(, format(%9.2f) nogrid) ///
	yscale(noextend) ///
	ytitle("Hazard rate" "(Deaths per site per day)") ///
	xlab(0(7)28) ///
	xscale(noextend) ///
	xtitle("Days following assessment") ///
	legend( ///
		order(3 2 1) ///
		label(1 "Best site") ///
		label(2 "Mean frailty hazard") ///
		label(3 "Worst site") ///
		cols(1) position(2) ring(0) ///
		)

graph rename survival_reffects_bhaz, replace
graph export ../outputs/figures/survival_reffects_bhaz.pdf, ///
	name(survival_reffects_bhaz) ///
	replace

restore


exit




