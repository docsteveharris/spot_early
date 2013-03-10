# Example and ?working version of running the SemiParBIVProbit
# Seems to work and to work well
# TODO: 2013-01-30 - re-run for other time outcomes
# TODO: 2013-01-30 - check for an interaction between the treatment and icnarc0
# TODO: 2013-01-30 - consider need/use of splines

rm(list = ls(all = TRUE)) #CLEAR WORKSPACE
# set the working directory
setwd("~/data/spot_early/vcode")
getwd()
library(foreign)
wkg_all = read.dta("../data/working_postflight.dta")
library(SemiParBIVProbit)

w <- data.frame(
		site = wkg_all$site,
		id = wkg_all$id,
		early4 = wkg_all$early4,
		early12 = ifelse(wkg_all$time2icu < 12, 1, 0),
		dead28 = wkg_all$dead28,
		rx = ifelse(wkg_all$early4 == "Early", 1, 0),
		age_b = ifelse(wkg_all$age_c > 80, 1, 0),
		age_c = wkg_all$age_c,
		male = wkg_all$male,
		periarrest = wkg_all$periarrest,
		sepsis_dx = wkg_all$sepsis_dx,
		sepsis1_b = wkg_all$sepsis1_b,
		icnarc0_c = wkg_all$icnarc0_c,
		v_ccmds = wkg_all$v_ccmds,
		cc_recommend = wkg_all$cc_recommend,
		beds_none = wkg_all$beds_none
		 )

nrow(w)
w.na <- na.omit(w)
nrow(w.na)
table(w.na$early4)
table(w.na$early12)

# NOTE: 2013-03-10 - improved models:
	# - expanded sepsis diagnosis
	# - added level of care (treatment at visit details)
	# - added visit recommendation
	# - added periarrest
	# - removed CCOT on

# Original specification (labelled as v1)
eqn1.v1 = early4 ~ icnarc0_c + age_b + beds_none + sepsis_dx
eqn1.no_inst.v1 = early4 ~ icnarc0_c + age_b + sepsis1_b
eqn2.v1 = dead28 ~ early4 + icnarc0_c + age_c + male + sepsis1_b

# Improved specification
eqn1            = early4 ~ icnarc0_c + age_b + male + beds_none + sepsis_dx + v_ccmds + cc_recommend + periarrest
eqn1.no_inst    = early4 ~ icnarc0_c + age_b + sepsis_dx + v_ccmds + cc_recommend + periarrest
eqn2            = dead28 ~ early4 + icnarc0_c + age_c + male + sepsis_dx + v_ccmds + cc_recommend + periarrest

# out = SemiParBIVProbit(eqn1, eqn2, data=working.sub.na)
# summary(out)
# Original
out.no_inst.v1 = SemiParBIVProbit(eqn1.no_inst.v1, eqn2.v1, data=w.na)
summary(out.no_inst.v1)
AT(out.no_inst.v1, eq=2, nm.bin = "early4")
# Improved
out.no_inst = SemiParBIVProbit(eqn1.no_inst, eqn2, data=w.na)
summary(out.no_inst)
AT(out.no_inst, eq=2, nm.bin = "early4")


# And with the instrument
out = SemiParBIVProbit(eqn1, eqn2, data=w.na)
summary(out)

# And with a longer (worse) delay
# Improved specification
eqn1.12           = early12 ~ icnarc0_c + age_b + male + beds_none + sepsis_dx + v_ccmds + cc_recommend + periarrest
eqn1.12.no_inst    = early12 ~ icnarc0_c + age_b + sepsis_dx + v_ccmds + cc_recommend + periarrest
eqn2.12            = dead28 ~ early12 + icnarc0_c + age_c + male + sepsis_dx + v_ccmds + cc_recommend + periarrest
out.12 = SemiParBIVProbit(eqn1.12, eqn2.12, data=w.na)
summary(out.12)




