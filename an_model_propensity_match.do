/*

 ## Match on the propensity score
_________________________
CreatedBy:	Steve Harris

CreatedAt:	120617
ModifiedAt:	120617

Filename:	cr_propensity_match.do
Project:	

## Description

### Nearest available Mahalanobis Metric Matching within calipers defined by the propensity score

- depends on a shared common support region (and if this fails then need to switch to optimal matching approach)
- Major advantage in that any form of multivariable analysis may be used subsequently
	- may be possible to build hierarchical model (see [@Smith:1997bc])
	- may be possible to specify time-varying hazard in the survival model

### Check balancing worked after matching
- before and after bivariate tests between the treatment groups and the matched pairs

### Standard regression diagnostics
Estimate the treatment effect models
- don't forget standard regression diagnositcs after specifying the models
	- look for multi-colinearlity
	- influential observations
	- other sensitivity analyses
	- check goodness of fit (GOF)

## File Dependencies

- propensity score data (i.e. that which has been created by cr_propensity_match.so)

____

*/


findit psmatch2
which psmatch2 // makes sure you are using the latest version
ssc install psmatch2, replace
/*
### Notes on using psmatch2
___________________________
- where a 1:1 match is requested several matches may be possible for each case but only the first one according to the current sort order of the file will be selected.  Therefore make sure you set a seed and then randomly sort the data so that you can reproduce your work.
- non-replacement is recommended when selecting matches but this option does not work for Mahalanobis matching in psmatch2.  You must implement this yourself
- pstest: compares covariares balance before and after matching
- psgraph: compares propensity score histogram by treatment status
*/

findit imbalance
ssc install imbalance
/*
### Notes on using imbalance
____________________________
- calculates the covariate imbalance statistics d_x and d_xm developed by Haviland see pp 172 [@Guo:2009vr]
*/
