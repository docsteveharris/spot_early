*  =========================
*  = Baseline patient data =
*  =========================

/*
spot_early version - also compares characteristics with spot_ward data

Patient
    Age
    Sex
    Level of care at assessment
    Clinically in extremis
    Referral timing
    Frequency of nursing observations

CHANGED: 2013-02-08 - now combined with visit outcome fields
    rx_visit
    rxlimits
    ccmds_delta
    v_decision

*/


*  =========================
*  = Define you table name =
*  =========================
GenericSetupSteveHarris spot_early an_tables_early_pt_chars, logon
global table_name early_pt_chars

/*
You will need the following columns
- sort order
- varname
- var_super (variable super category)
- value
- min
- max
*/

*  ==========================================================================
*  = Create an indicator variable to identify patients in the original data =
*  ==========================================================================
local clean_run 1
if `clean_run' == 1 {
    clear
    use ../data/working.dta
    qui include cr_preflight.do
}
* this is the spot_early cohort
use ../data/working_postflight.dta, clear
gen spot_sample = 1
tempfile 2merge
save `2merge', replace
* this is the spot_ward cohort
use ../../spot_ward/data/working_postflight, clear
gen spot_sample = 0
count
* deliberately merge so that there are no matches to create byable groups
merge 1:1 idvisit spot_sample using `2merge'
label var spot_sample "Study sample"
label define spot_sample 0 "All patients" 1 "Eligible patients"
label values spot_sample spot_sample
tab spot_sample


*  ======================================
*  = Define column categories or byvars =
*  ======================================
* NOTE: 2013-02-07 - dummy variable for the byvar loop that forces use of all patients

local byvar spot_sample
* Think of these as the gap row headings
local super_vars patient sepsis outcome

local patient age sex v_ccmds vitals delayed_referral
local sepsis sepsis
local outcome rx_visit rxlimits ccmds_delta v_decision

* This is the layout of your table by sections
local table_vars ///
    `patient' ///
    `sepsis' ///
    `outcome'

* Specify the type of variable
local norm_vars age
local skew_vars spo2 fio2_std uvol1h creatinine urea gcst ///
    hrate bpsys bpmap rrate temperature ///
    `laboratory'
local range_vars
local bin_vars
local cat_vars v_ccmds vitals sepsis rxcvs rx_resp avpu sepsis_site ///
    rx_visit ccmds_delta v_decision ///
    periarrest hsinus rxrrt ///
    sex rxlimits delayed_referral

*  ==============================
*  = Set up sparkline variables =
*  ==============================
* sparks = number of bars
local sparks 12
* sparkwidth = number of x widths for sparkline plot
local sparkwidth 8
global sparkspike_width 1.5
local sparkspike_vars ///
        age
* Use fat 2 point sparkline for horizontal bars (default 0.2pt)
local sparkhbar_width 3pt
local sparkhbar_vars ///
    sex v_ccmds vitals  delayed_referral sepsis rx_visit rxlimits  ///
        ccmds_delta v_decision

* CHANGED: 2013-02-05 - use the gap_here indicator to add gaps
* these need to be numbered as _1 etc
* Define the order of vars in the table
global table_order ///
    age gap_here ///
    sex gap_here ///
    delayed_referral gap_here ///
    sepsis gap_here ///
    vitals gap_here ///
    v_ccmds  gap_here ///
    rxlimits gap_here ///
    rx_visit gap_here ///
    ccmds_delta gap_here ///
    v_decision

* number the gaps
local i = 1
local table_order
foreach word of global table_order {
    if "`word'" == "gap_here" {
        local w `word'_`i'
        local ++i
    }
    else {
        local w `word'
    }
    local table_order `table_order' `w'
}
global table_order `table_order'

tempname pname
tempfile pfile
postfile `pname' ///
    int     bylevel ///
    int     table_order ///
    str32   var_type ///
    str32   var_super ///
    str32   varname ///
    str96   varlabel ///
    str64   var_sub ///
    int     var_level ///
    double  vcentral ///
    double  vmin ///
    double  vmax ///
    double  vother ///
    double  pvalue ///
    str244  sparkspike ///
    using `pfile' , replace


tempfile working
save `working', replace
levelsof `byvar', clean local(bylevels)

foreach lvl of local bylevels {
    use `working', clear
    // CHANGED: 2013-02-26 - swap to using iif instead of keep
    // keep if `byvar' == `lvl'
    local touse "`byvar' == `lvl'"
    local iftouse " if `byvar' == `lvl'"
    local lvl_label: label (`byvar') `lvl'
    local lvl_labels `lvl_labels' `lvl_label'
    count if `touse'
    local grp_sizes `grp_sizes' `=r(N)'
    local table_order 1
    local sparkspike = ""
    // assign an impossible value so you can pick up errors later
    local pvalue = .
    foreach var of local table_vars {
        local varname `var'
        local varlabel: variable label `var'
        local var_sub
        // CHANGED: 2013-02-05 - in theory you should not have negative value labels
        local var_level -1
        // Little routine to pull the super category
        local super_var_counter = 1
        foreach super_var of local super_vars {
            local check_in_super: list posof "`var'" in `super_var'
            if `check_in_super' {
                local var_super: word `super_var_counter' of `super_vars'
                continue, break
            }
            local var_super
            local super_var_counter = `super_var_counter' + 1
        }

        // Now assign values base on the type of variable
        local check_in_list: list posof "`var'" in norm_vars
        if `check_in_list' > 0 {
            local var_type  = "Normal"
            su `var'  if `touse'
            local vcentral  = r(mean)
            local vmin      = .
            local vmax      = .
            local vother    = r(sd)
            if wordcount("`bylevels'") == 2 {
                ttest `var', by(`byvar')
                local pvalue = r(p)
            }
        }

        local check_in_list: list posof "`var'" in bin_vars
        if `check_in_list' > 0 {
            local var_type  = "Binary"
            count if `var' == 1 & `touse'
            local vcentral  = r(N)
            local vmin      = .
            local vmax      = .
            if wordcount("`bylevels'") == 2 {
                prtest `var', by(`byvar')
                local pvalue = (1 - normal(abs(r(z)))) * 2
            }
            su `var' if `touse'
            local vother    = r(mean) * 100
            // sparkhbar routine
            local check_in_list: list posof "`var'" in sparkhbar_vars
            if `check_in_list' > 0 {
                local x : di %9.2f `=r(mean)'
                local x = trim("`x'")
                local sparkspike "\setlength{\sparklinethickness}{`sparkhbar_width'}\begin{sparkline}{`sparkwidth'}\spark 0.0 0.5 `x' 0.5 / \end{sparkline}\setlength{\sparklinethickness}{0.2pt}"
            }
        }

        local check_in_list: list posof "`var'" in skew_vars
        if `check_in_list' > 0 {
            local var_type  = "Skewed"
            su `var' if `touse', d
            local vcentral  = r(p50)
            local vmin      = r(p25)
            local vmax      = r(p75)
            local vother    = .
            if wordcount("`bylevels'") == 2 {
                ranksum `var', by(`byvar')
                local pvalue = (1 - normal(abs(r(z)))) * 2
            }
        }

        local check_in_list: list posof "`var'" in range_vars
        if `check_in_list' > 0 {
            local var_type  = "Range"
            su `var' if `touse', d
            local vcentral  = r(p50)
            local vmin      = r(min)
            local vmax      = r(max)
            local vother    = .
            if wordcount("`bylevels'") == 2 {
                ranksum `var', by(`byvar')
                local pvalue = (1 - normal(abs(r(z)))) * 2
            }
        }


        // sparkspike routine
        cap restore, not
        preserve
        keep if `touse'
        local check_in_list: list posof "`var'" in sparkspike_vars
        if `check_in_list' > 0 {
            local sparkspike = ""
            cap drop kd kx kx20 kdmedian
            kdensity `var', gen(kx kd) nograph
            // normalise over the [0,1] scale
            qui su kd
            replace kd = kd / r(max)
            egen kx20 = cut(kx), group(`sparks')
            replace kx20 = kx20 + 1
            bys kx20: egen kdmedian = median(kd)
            local sparkspike "\begin{sparkline}{`sparkwidth'}\renewcommand*{\do}[1]{\sparkspike #1 }\docsvlist{"
            forvalues k = 1/`sparks' {
                // hack to get the kdmedian value
                qui su kdmedian if kx20 == `k', meanonly
                local spike : di %9.2f `=r(mean)'
                local spike = trim("`spike'")
                local x = `k' / `sparks'
                local x : di %9.2f `x'
                local x = trim("`x'")
                local sparkspike "`sparkspike'{`x' `spike'}"
                // add a comma if not the end of the list
                if `k' != `sparks' local sparkspike "`sparkspike',"
            }
            local sparkspike "`sparkspike'}\end{sparkline}"
        }
        restore

        // now post the data and move on if not a cat-var ('cos you're done)
        local check_in_list: list posof "`var'" in cat_vars
        if `check_in_list' == 0 {
            post `pname' ///
                (`lvl') ///
                (`table_order') ///
                ("`var_type'") ///
                ("`var_super'") ///
                ("`varname'") ///
                ("`varlabel'") ///
                ("`var_sub'") ///
                (`var_level') ///
                (`vcentral') ///
                (`vmin') ///
                (`vmax') ///
                (`vother') ///
                (`pvalue') ///
                ("`sparkspike'")

            local table_order = `table_order' + 1
            continue
        }

        // Need a different approach for categorical variables
        // work out chi2 value before contracting data
        tab `var' `byvar', chi
        local pvalue = r(p)
        cap restore, not
        preserve
        // if touse here means you don't need it again
        contract `var' if `touse'
        rename _freq vcentral
        egen vother = total(vcentral)
        replace vother = vcentral / vother * 100
        decode `var', gen(var_sub)
        drop if missing(`var')
        local last = _N

        forvalues i = 1/`last' {
            local var_type  = "Categorical"
            local var_sub   = var_sub[`i']
            local var_level = `var'[`i']
            local vcentral  = vcentral[`i']
            local vmin      = .
            local vmax      = .
            local vother    = vother[`i']
            // sparkhbar routine
            local check_in_list: list posof "`var'" in sparkhbar_vars
            if `check_in_list' > 0 {
                local x = round(`vother' / 100, 0.01)
                local x : di %9.2f `x'
                local x = trim("`x'")
                local sparkspike "\setlength{\sparklinethickness}{`sparkhbar_width'}\begin{sparkline}{`sparkwidth'}\spark 0.0 0.5 `x' 0.5 / \end{sparkline}\setlength{\sparklinethickness}{0.2pt}"
            }

        post `pname' ///
            (`lvl') ///
            (`table_order') ///
            ("`var_type'") ///
            ("`var_super'") ///
            ("`varname'") ///
            ("`varlabel'") ///
            ("`var_sub'") ///
            (`var_level') ///
            (`vcentral') ///
            (`vmin') ///
            (`vmax') ///
            (`vother') ///
            (`pvalue') ///
            ("`sparkspike'")


        local table_order = `table_order' + 1
        }
        restore

    }
}
global lvl_labels `lvl_labels'
global grp_sizes `grp_sizes'
postclose `pname'
use `pfile', clear
qui compress
br

*  ===================================================================
*  = Now you need to pull in the table row labels, units and formats =
*  ===================================================================

spot_label_table_vars
save ../outputs/tables/$table_name.dta, replace
order bylevel tablerowlabel var_level var_level_lab

*  ===============================
*  = Now produce the final table =
*  ===============================
/*
Now you have a dataset that represents the table you want
- one row per table row
- each uniquely keyed

Now make your final table
All of the code below is generic except for the section that adds gaps
*/

use ../outputs/tables/$table_name.dta, clear
* CHANGED: 2013-02-25 - add in rxlimit true for early group else table is not symmetrical
expand 2 if varname == "rxlimits" & var_level == 1
replace bylevel = 1 if _n == _N
replace vcentral = . if _n == _N
replace vother = . if _n == _N
replace sparkspike = "" if _n == _N

gen var_label = tablerowlabel

* Define the table row order
local table_order $table_order

cap drop table_order
gen table_order = .
local i = 1
foreach var of local table_order {
    replace table_order = `i' if varname == "`var'"
    local ++i
}
* CHANGED: 2013-02-07 - try and reverse sort severity categories
gsort +bylevel +table_order -var_level
bys bylevel: gen seq = _n

* Now format all the values
cap drop vcentral_fmt
cap drop vmin_fmt
cap drop vmax_fmt
cap drop vother_fmt

gen vcentral_fmt = ""
gen vmin_fmt = ""
gen vmax_fmt = ""
gen vother_fmt = ""

*  ============================
*  = Format numbers correctly =
*  ============================
local lastrow = _N
local i = 1
while `i' <= `lastrow' {
    di varlabel[`i']
    local stataformat = stataformat[`i']
    di `"`stataformat'"'
    foreach var in vcentral vmin vmax vother {
        // first of all specific var formats
        local formatted : di `stataformat' `var'[`i']
        di `formatted'
        replace `var'_fmt = "`formatted'" ///
            if _n == `i' ///
            & !inlist(var_type[`i'],"Binary", "Categorical") ///
            & !missing(`var'[`i'])
        // now binary and categorical vars
        local format1 : di %9.0gc `var'[`i']
        local format2 : di %9.1fc `var'[`i']
        replace `var'_fmt = "`format1'" if _n == `i' ///
            & "`var'" == "vcentral" ///
            & inlist(var_type[`i'],"Binary", "Categorical") ///
            & !missing(`var'[`i'])
        replace `var'_fmt = "`format2'" if _n == `i' ///
            & "`var'" == "vother" ///
            & inlist(var_type[`i'],"Binary", "Categorical") ///
            & !missing(`var'[`i'])
    }
    local ++i
}
cap drop vbracket
gen vbracket = ""
replace vbracket = "(" + vmin_fmt + "--" + vmax_fmt + ")" if !missing(vmin_fmt, vmax_fmt)
replace vbracket = "(" + vother_fmt + ")" if !missing(vother_fmt)
replace vbracket = subinstr(vbracket," ","",.)
sdecode pvalue, format(%9.3f) gen(pvalue_fmt)
replace pvalue_fmt = "\textless0.001" if pvalue < 0.001

* Append units
* CHANGED: 2013-01-25 - test condition first because unitlabel may be numeric if all missing
cap confirm string var unitlabel
if _rc {
    tostring unitlabel, replace
    replace unitlabel = "" if unitlabel == "."
}
replace tablerowlabel = tablerowlabel + " (" + unitlabel + ")" if !missing(unitlabel)


order tablerowlabel vcentral_fmt vbracket
* NOTE: 2013-01-25 - This adds gaps in the table: specific to this table

br tablerowlabel vcentral_fmt vbracket


chardef tablerowlabel vcentral_fmt vbracket, ///
    char(varname) ///
    prefix("\textit{") suffix("}") ///
    values("Characteristic" "Value" "")

listtab_vars tablerowlabel vcentral_fmt vbracket, ///
    begin("") delimiter("&") end(`"\\"') ///
    substitute(char varname) ///
    local(h1)

*  ==============================
*  = Now convert to wide format =
*  ==============================
keep bylevel table_order tablerowlabel vcentral_fmt vbracket seq ///
    varname var_type var_label var_level_lab var_level sparkspike ///
    pvalue_fmt

chardef tablerowlabel vcentral_fmt, ///
    char(varname) prefix("\textit{") suffix("}") ///
    values("Parameter" "Value")


* Prepare sub-headings
* local sub_heading "Mean/Median/Count (SD/IQR/\%)"
* CHANGED: 2013-02-07 - drop parameter from column heading and leave blank
* - if needed then Characteristic is preferred
* local sub_heading "& \multicolumn{2}{c}{`sub_heading'} &  \multicolumn{2}{c}{`sub_heading'} \\"

xrewide vcentral_fmt vbracket sparkspike, ///
    i(seq) j(bylevel) ///
    lxjk(nonrowvars)

order seq tablerowlabel vcentral_fmt0 vbracket0 vcentral_fmt1 vbracket1 pvalue_fmt
cap br

// now drop repeated pvalue_fmt (occurs categorical variables)
bys varname (seq): replace pvalue_fmt = "" if _n != 1
sort seq

* Now add in gaps or subheadings
save ../data/scratch/scratch.dta, replace
clear
local table_order $table_order
local obs = wordcount("`table_order'")
set obs `obs'
gen design_order = .
gen varname = ""
local i 1
foreach var of local table_order {
    local word_pos: list posof "`var'" in table_order
    replace design_order = `i' if _n == `word_pos'
    replace varname = "`var'" if _n == `word_pos'
    local ++i
}

joinby varname using ../data/scratch/scratch.dta, unmatched(both)
gsort +design_order -var_level
drop seq _merge

*  ==================================================================
*  = Add a gap row before categorical variables using category name =
*  ==================================================================
local lastrow = _N
local i = 1
local gaprows
while `i' <= `lastrow' {
    // CHANGED: 2013-01-25 - changed so now copes with two different but contiguous categorical vars
    if varname[`i'] == varname[`i' + 1] ///
        & varname[`i'] != varname[`i' - 1] ///
        & var_type[`i'] == "Categorical" {
        local gaprows `gaprows' `i'
    }
    local ++i
}
di "`gaprows'"
ingap `gaprows', gapindicator(gaprow)
replace tablerowlabel = tablerowlabel[_n + 1] ///
    if gaprow == 1 & !missing(tablerowlabel[_n + 1])
replace tablerowlabel = var_level_lab if var_type == "Categorical"
replace table_order = _n

* Indent subcategories
* NOTE: 2013-01-28 - requires the relsize package
replace tablerowlabel =  "\hspace*{1em}\smaller[1]{" + tablerowlabel + "}" if var_type == "Categorical"
* CHANGED: 2013-02-07 - by default do not append statistic type
local append_statistic_type 0
if `append_statistic_type' {
    local median_iqr    "\smaller[1]{--- median (IQR)}"
    local n_percent     "\smaller[1]{--- N (\%)}"
    local mean_sd       "\smaller[1]{--- mean (SD)}"
    replace tablerowlabel = tablerowlabel + " `median_iqr'" if var_type == "Skewed"
    replace tablerowlabel = tablerowlabel + " `mean_sd'" if var_type == "Normal"
    replace tablerowlabel = tablerowlabel + " `n_percent'" if var_type == "Binary"
    replace tablerowlabel = tablerowlabel + " `n_percent'" if gaprow == 1
}


*  ==============================
*  = Prepare table and headings =
*  ==============================
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}

// super-categories
local j = 1
* NOTE: 2013-02-05 - you have an extra & at the beginning but this is OK as covers parameters
foreach word of global grp_sizes {
    local grp_size: word `j' of $grp_sizes
    local grp_size: di %9.0gc `grp_size'
    local grp_size_`j' "`grp_size'"
    local ++j
}

// display p-values?
local pvalue_on = 1
if `pvalue_on' {
    local pvalue_heading1 "& p value"
    local pvalue_heading0 "& "
    local pvalue_column "X[1.5r]"
}
local super_heading1 & \multicolumn{2}{c}{All study patients}  & \multicolumn{2}{c}{Assessed patients} `pvalue_heading1' \\
local super_heading2 & \multicolumn{2}{c}{`grp_size_1' patients}  & \multicolumn{2}{c}{`grp_size_2' patients} `pvalue_heading0' \\

// switch on sparklines?
local sparklines_on = 0
if `sparklines_on' {
    local nonrowvars `nonrowvars' pvalue_fmt
    local sparkspike_width "\renewcommand\sparkspikewidth{$sparkspike_width}"
    local justify "X[10l]X[r]X[2l]X[2l]X[r]X[2l]X[2l]X[r]`pvalue_column'"
    local sparkspike_colour "\definecolor{sparkspikecolor}{gray}{0.7}"
    local sparkline_colour "\definecolor{sparklinecolor}{gray}{0.7}"
    local super_heading1 & \multicolumn{3}{c}{All study patients}  & \multicolumn{3}{c}{Assessed patients}  `pvalue_heading1' \\
    local super_heading2 & \multicolumn{3}{c}{`grp_size_1' patients}  & \multicolumn{3}{c}{`grp_size_2' patients} `pvalue_heading0' \\
}
else {
    local nonrowvars vcentral_fmt0 vbracket0 vcentral_fmt1 vbracket1 pvalue_fmt
    local justify "X[6l]X[r]X[2l]X[r]X[2l]`pvalue_column'"
}

listtab tablerowlabel `nonrowvars'  ///
    using ../outputs/tables/$table_name.tex, ///
    replace rstyle(tabular) ///
    headlines( ///
        "`tablefontsize'" ///
        "\renewcommand{\arraystretch}{`arraystretch'}" ///
        "\taburowcolors `taburowcolors'" ///
        "`sparkspike_width'" ///
        "`sparkspike_colour'" ///
        "`sparkline_colour'" ///
        "\begin{tabu} to " ///
        "\textwidth {`justify'}" ///
        "\toprule" ///
        "`super_heading1'" ///
        "`super_heading2'" ///
        "\midrule" ) ///
    footlines( ///
        "\bottomrule" ///
        "\end{tabu} " ///
        "\label{tab:$table_name} ") ///

cap log off
