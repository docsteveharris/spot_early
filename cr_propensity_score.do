/*

 ## Estimate propensity scores for E vs D model
_______________________________________________
CreatedBy:	Steve Harris

CreatedAt:	120617
ModifiedAt:	120617

Filename:	cr_propensity_score.do
Project:

## Description

- model building for the selection model
- consider a Hirano and Imbens approach to model building so that multiple models with different stepwise cutoff thresholds are built and a table of effects constructed with all different models
- consider different methods to estimate the propensity score
- consider different propensity or selection targets
	- admission to critical care within 4 hours
	- admission to critical care as an emergency medical admission
	- use of mechanical ventilation within 24 hours / 1 day
	- use of renal replacement therapy within 1 day
- consider different methods to estimate propensity score
	- logistic regression
	- boosted regression

## Dependencies

- placeholder file list

____

*/