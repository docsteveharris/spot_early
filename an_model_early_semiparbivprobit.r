# Example and ?working version of running the SemiParBIVProbit
# Seems to work and to work well
# TODO: 2013-01-30 - re-run for other time outcomes
# TODO: 2013-01-30 - check for an interaction between the treatment and icnarc0
# TODO: 2013-01-30 - consider need/use of splines

library(foreign)
working = read.dta("/Volumes/phd/data-spot_early/working_postflight.dta")
library(SemiParBIVProbit)

working$age.b = ifelse(working$age > 80, 1, 0)

working.sub = data.frame(
		icnarc0 = working$icnarc0,
		icu4=working$icu4, 
		age.b=working$age.b, 
		beds_none=working$beds_none,
		ccot_on = working$ccot_on,
		patients_perhesadmx = working$patients_perhesadmx,
		sepsis_b = working$sepsis_b,
		dead28 = working$dead28,
		dead90 = working$dead90,
		age = working$age,
		male = working$male
		 )

working.sub.na = na.omit(working.sub)

eqn1 = icu4 ~ icnarc0 + age.b + beds_none + ccot_on  + sepsis_b
eqn1.no_inst = icu4 ~ icnarc0 + age.b + ccot_on + sepsis_b

eqn2 = dead90 ~ icu4 + icnarc0 + age + male + sepsis_b + ccot_on

# out = SemiParBIVProbit(eqn1, eqn2, data=working.sub.na)
out.no_inst = SemiParBIVProbit(eqn1.no_inst, eqn2, data=working.sub.na)

summary(out.no_inst)

AT(out, eq=2, nm.bin = "icu4")

