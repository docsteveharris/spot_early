*  ===========================================
*  = Stata do file for the spot-ward chapter =
*  ===========================================

* Created 1 Jan 2013
* Modified

*  ====================
*  = Data preparation =
*  ====================

/*
From the command line you need to run
- cr_working.sh
This in turn runs cr_working.sql
And then runs all the python scripts necessary to prepare all tables
*/

* NOTE: 2013-01-01 - the following includes cr_sites.do
do cr_working.do
do cr_preflight.do
/*
- produces working_raw.dta (data labelled and merged with site details)
- produces working_all.dta (all patients from participating sites flagged with include/exclude)
- produces working.dta

- produces the details for the CONSORT/STROBE diagram
*/

* do cr_working_sensitivity.do
/*
- keeps in sites that would have nearly made it (uses 70% instead of 80% cut-off)
- keeps in sites with known protocol problems
*/

*  =========================================
*  = Provision of CCOT and study variables =
*  =========================================

/*
Does CCOT provision affect the type of patient
- with respect to the severity of illness
- with respect to the number and pattern of visits

*/

do an_severity_and_site.do
do an_study_and_time.do

*  =============================================
*  = Understand what happens to study patients =
*  =============================================
do an_figure_pt_flow.do

*  ====================================
*  = Baseline tables of various forms =
*  ====================================
do an_tables_baseline_site_chars.do
do an_tables_baseline_site_study.do
do an_tables_baseline_pt_chars.do
do an_tables_baseline_pt_physiology.do
do an_tables_baseline_pt_visit.do

*  =================================
*  = External validity comparisons =
*  =================================

do an_external_validity.do

*  =============
*  = Modelling =
*  =============

/*
Inspect independent vars to make sure you are modelling them OK
*/
do an_describe_ind_vars.do

*  ===============================================
*  = Count the number of different patients seen =
*  ===============================================

/*
In order to get some estimate of how common these different cases are
*/

do an_model_count_news_risk.do
do an_model_count_severity.do
do an_model_count_sepsis.do


