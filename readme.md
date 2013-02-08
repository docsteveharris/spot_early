## Early versus deferred admissions to ICU

### Objective (PICO)
- Patients: All patients assessed on the ward for potential admission to critical care
- Intervention:
    - Admission within 4 hours
    - Admission timing as continuous variable
        - modelled linearly
        - modelled with a flexible funcitonal form
- Control: patients either not admitted or admitted after the timing threshold
- Outcome:
    - 28 day mortality
    - Organ support free day approach
    - 90 day survival - allow the exposure to effect to be time varying

### Models
- Ensemble approach to determining effect therefore plan on building a number of different models and collating the Average Treatment Effect (ATE) across all of them.

List of proposed models:

- Propensity score approach
    - Nearest neighbour with calipers and Mahalanobis into a cox or flexible parametric survival model
    - Optimal matching?
- Cox regression
- Flexible parametric survival modeldo sublime2stata.do

- Joint model

### Coding guidance
- There is a single master file which will produce all the analysis in a linear fashion. Running this will reproduce all necessary output.
- NOTE: Try and make as much of your code as re-usable as possible ... therefore write inline 'standalone' programs wherever you can
- TODO: Stata log files will be written so that they might be automatically converted to markdown formatted files (and hence easily shared)
