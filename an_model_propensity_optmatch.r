#  =========================================
#  = Run the optimal matching routine in R =
#  =========================================

rm(list = ls(all = TRUE)) #CLEAR WORKSPACE
# set the working directory
setwd("~/data/spot_early/vcode")
getwd()

# Load the optimal matching library
# install.packages("optmatch")
library("optmatch")

# Import library foreign so you can use stata files
library(foreign)
wkg_all = read.dta("../data/working_propensity_all.dta")

# Now R does not handle missing values in the same way as stata
# You need to exclude these?
# Best then to be fussy and only use columns that do not have problems
# pr1 - excludes cc_recommend
# pr2 - includes cc_recommend
w <- data.frame(
		site = wkg_all$site,
		id = wkg_all$id,
		pr2_p = wkg_all$pr2_p,
		early4 = wkg_all$early4,
		rx = ifelse(wkg_all$early4 == "Early", 1, 0),
		age_c = wkg_all$age_c,
		male = wkg_all$male,
		periarrest = wkg_all$periarrest,
		sepsis1_b = wkg_all$sepsis1_b,
		icnarc0_c = wkg_all$icnarc0_c,
		v_ccmds = wkg_all$v_ccmds,
		cc_recommend = wkg_all$cc_recommend,
		icnarc_q10 = wkg_all$icnarc_q10,
		weekend = wkg_all$weekend,
		out_of_hours = wkg_all$out_of_hours,
		hes_overnight_k = wkg_all$hes_overnight_k,
		hes_emergx_k = wkg_all$hes_emergx_k,
		patients_perhesadmx_k = wkg_all$patients_perhesadmx_k,
		ccot_shift_pattern = wkg_all$ccot_shift_pattern,
		small_unit = wkg_all$small_unit
		)
# drop missing values cw = casewise deletion
nrow(w)
w.cw <- na.omit(w)
nrow(w.cw)
# w.small <- w.cw[1:5000,]

# attach the data: beware that this is not always recommended
attach(w)

# inspect distributions
library(lattice)
densityplot(icnarc0, groups = early4)
table(cc_recommend, early4)
table(v_ccmds, early4)
table(site, early4)


# Set up distances using the GLM of the propensity model
# Use deciles of ICNARC score instead of the precise score
# This then defines the strata for the distances and full match step
# Propensity model - uses deciles of ICNARC score
model.pr2 <- glm(rx ~ age_c + male + periarrest + sepsis1_b + v_ccmds 
	+ cc_recommend
	+ icnarc0_c
	+ site
	+ weekend + out_of_hours,
	family = binomial, data = w )

summary(model.pr2)

distances.pr2.strata <- mdist(model.pr2, structure.fmla = ~ site)
matches.pr2.strata <- fullmatch(distances.pr2.strata, data = w)
# this takes about 5 mins to run

# now examine the model output
summary(matches.pr2.strata)
library(RItools)
summary(matches.pr2.strata, propensity.model = model.pr2)
stratumStructure(matches.pr2.strata)

# now save the model
write.table (matches.pr2.strata, quote=FALSE, sep=",", col.names=FALSE, file="~/data/optmatch_pr2_strata.dat")



