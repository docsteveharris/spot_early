*  =========================================
*  = Generic programs used during analysis =
*  =========================================
/*
You could do the same by writing ado files but that would require correc syntax specification.
This is meant to be simpler for programs that do not need to check their variables.
Just add `qui include mtPrograms.do` at the beginning of your code
Try and label all programs mt_ so you can see them easily
*/


cap program drop mt_extract_varname_from_parm
program mt_extract_varname_from_parm
	cap drop model_order
	gen model_order = _n
	cap drop reference_cat
	cap drop var_type
	gen var_type = ""
	cap drop varname
	// extract the factor level from the stata parm notation
	cap drop var_level
	tempvar reverse_parm
	gen `reverse_parm' = reverse(parm)
	gen var_level = substr(`reverse_parm',strpos(`reverse_parm',".") + 1,.)  ///
		if strpos(`reverse_parm',".") != 0
	replace var_level = reverse(var_level)
	replace var_level = subinstr(var_level,"b","",.)
	gen reference_cat = 0
	replace reference_cat = 1 if substr(parm, strpos(parm,".") - 1,1) == "b" ///
		& strpos(parm,".") != 0
	// extract the varname
	gen varname = parm
	replace varname = substr(parm,strpos(parm,".") + 1,.) if strpos(parm,".") != 0
	// extra work for hand generated factor variables
	replace var_type = "Factor" ///
		if substr(parm, -2, 2) == "_f"
	replace var_level = regexs(1) if regexm(parm, "^[a-z0-9_]+_([0-9]+)_f$")
	replace varname = substr(varname, 1, length(varname) - 4) ///
		if var_type == "Factor"
	// back to sorting out varnames
	replace var_type = "Binary" ///
		if substr(parm, -2, 2) == "_b"
	replace varname = substr(varname, 1, length(varname) - 2) ///
		if substr(varname, -2, 2) == "_b"
	replace var_type = "Continuous" ///
		if substr(parm, -2, 2) == "_c"
	replace varname = substr(varname, 1, length(varname) - 2) ///
		if substr(varname, -2, 2) == "_c"
	replace var_type = "Categorical" ///
		if substr(parm, -2, 2) == "_k"
	replace varname = substr(varname, 1, length(varname) - 2) ///
		if substr(varname, -2, 2) == "_k"
	destring var_level, replace
	gsort model_order
end

// mt_extract_varname_from_parm

cap program drop mt_table_order
program mt_table_order
	// assumes there is a globar called table_order
	// this contains vars with gap_here to indicate spacing
	// simply adds numbers to the gap_here indicator
	// number the gaps
	local i = 1
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
	di "$table_order"
	global table_order `table_order'
	cap drop table_order
	gen table_order = .
	local i = 1
	foreach v of global table_order {
		replace table_order = `i' if varname == "`v'"
		sort varname var_level
		local ++i
	}
end


cap program drop mt_indent_categorical_vars
program mt_indent_categorical_vars
	// now add a gap row before categorical vars
	local lastrow = _N
	local i = 1
	local gaprows
	while `i' <= `lastrow' {
		// CHANGED: 2013-01-25 - changed so now copes with two different but contiguous categorical vars
		if varname[`i'] == varname[`i' + 1] ///
			& varname[`i'] != varname[`i' - 1] ///
			& var_level_lab[`i'] != "" {
			local gaprows `gaprows' `i'
		}
		local ++i
	}
	di "`gaprows'"
	ingap `gaprows', gapindicator(gaprow)
	replace tablerowlabel = tablerowlabel[_n + 1] ///
		if gaprow == 1 & !missing(tablerowlabel[_n + 1])
	replace tablerowlabel = var_level_lab if var_level_lab != ""
	replace table_order = _n
	* Indent subcategories
	* NOTE: 2013-01-28 - requires the relsize package
	replace tablerowlabel =  "\hspace*{1em}\smaller[1]{" + tablerowlabel + "}" ///
		if var_level_lab != ""
end

