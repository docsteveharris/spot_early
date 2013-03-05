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

# Set up distances
# Euclidean distance
distances <- list()
distances.stratified <- mdist(rx ~ age_c | icnarc_q10, data = w)

# Propensity model
model.pr2 <- glm(rx ~ age_c + male + periarrest + sepsis1_b + v_ccmds 
	+ icnarc0_c + weekend + out_of_hours + hes_overnight_k + hes_emergx_k
	+ patients_perhesadmx_k + ccot_shift_pattern + small_unit,
	family = binomial, data = w )

# distances.strat.propensity <- mdist(
# 		rx ~ age_c | icnarc_q10, data = w.small)
# distances.euclid <- match_on(early4 ~ age_c + icnarc0_c, data = w.small, method = "euclidean")




# define the each rows 'rank'
# pr2rank <- rank(pr2_p)

# attache the ID's to the rank
# names(pr2rank) <- id
# pr2rank[1]

# now define the distance between each pair of values
# and produce a matrix that contains all possible distances
# rows = all treated cases
# cols = all control cases
# cells will be the distance ... this then becomes the basis for the optmatch
# pr2distance <- outer(pr2rank[rx == 1], pr2rank[rx == 0], "-")
# pr2distance <- abs(pr2distance)
# dim(pr2distance)

# optmatch_full <- fullmatch(pr2distance)
# NOTE: 2013-03-04 - so this fails (matrix too big)

# Try now using the syntax in the example code
# This sues match_on and may(?) handle large matrices better
# ppty <- glm(early4 ~ age_c + male + icnarc0_c + v_ccmds, family=binomial(), data=w)



# mhd <- match_on(rx ~ age_c + male + icnarc0_c, data = w)
# fm1 <- fullmatch(mhd, data = w)
# summary(fm1)


