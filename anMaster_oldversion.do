/*
## Early versus deferred admission to critical care
____________________________________________________

CreatedBy:	Steve Harris

CreatedAt:	120617
ModifiedAt:	120617

Filename:	anMaster.do
Project:	spot_early

## Description

Try to keep the text descriptions brief in the body of this file so that it reads OK.  Move the detailed notes to the include files.

## Dependencies

- empty list for now

____
*/

/*
## Define the working data for this analysis
____________________________________________
*/
include cr_define_working.do

/*
## Define strata and subgroup membership

- define these early on so you can inspect variables and distributions with reference to these
*/
include cr_define_strata.do

/*
## Estimate the propensity score
________________________________
*/

include cr_propensity_score.do

/*
## Match on the propensity score
__________________________

*/
include an_propensity_match.do

/*
## Optimal matching approach
____________________________

- needs to be implemented in R with the [optmatch package](http://cran.r-project.org/web/packages/optmatch/)
- matching strategies (try each)
	- pair matching
	- matching using a variable ratio
	- full matching _probably _ the best method
- after matching then analysis is either by 
	- Hodges-Lehman aligned rank test
	- Post-pair matching analysis using regression of difference scores
*/
include an_optimal_matching.do

/*
## Heckman treatment selection model
____________________________________
*/
include an_heckman.do

/*
## Sensitivity analyses
_______________________
*/

/*
### Hirano & Imbens approach
_____________________________

- see [@Hirano:2001ij]
- used a propensity weighting approach - hence not directly applicable to regression after propensity matching but it would be possible to use this concept as an approach to the sensitivity analysis
*/

/*
### Rosenbaum
_____________
- stata programs
	- rbounds
	- mhbounds

*/