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
		dead28 = wkg_all$dead28,
		rx = ifelse(wkg_all$early4 == "Early", 1, 0),
		age_b = ifelse(wkg_all$age_c > 80, 1, 0),
		age_c = wkg_all$age_c,
		male = wkg_all$male,
		periarrest = wkg_all$periarrest,
		sepsis_dx = wkg_all$sepsis_dx,
		icnarc0_c = wkg_all$icnarc0_c,
		v_ccmds = wkg_all$v_ccmds,
		cc_recommend = wkg_all$cc_recommend,
		beds_none = wkg_all$beds_none
		 )

nrow(w)
w.na <- na.omit(w)
nrow(w.na)

table(w.na$early4)
table(w.na$rx)
length(w.na$early4)
length(w.na$rx)
length(w.na$icnarc0_c)
length(w.na$age_b)

length(w.na$rx)
length(w.na$dead28)

eqn1            = early4 ~ icnarc0_c + age_b + male + beds_none + sepsis_dx + v_ccmds + cc_recommend + periarrest
eqn1.no_inst    = early4 ~ icnarc0_c + age_b + beds_none + sepsis_dx + v_ccmds + cc_recommend + periarrest
eqn2            = dead28 ~ early4 + icnarc0_c + age_c + male + sepsis_dx + v_ccmds + cc_recommend + periarrest

# out = SemiParBIVProbit(eqn1, eqn2, data=working.sub.na)
out.no_inst = SemiParBIVProbit(eqn1.no_inst, eqn2, data=w.na)
summary(out.no_inst)

AT(out.no_inst, eq=2, nm.bin = "early4")

