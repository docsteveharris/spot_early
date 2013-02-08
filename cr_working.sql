
-- Make up-to-date views of tailsFinal
DROP VIEW IF EXISTS spot_early.tailsFinal_raw;
CREATE VIEW spot_early.tailsFinal_raw AS
  SELECT *
FROM spot.tailsFinal
  WHERE icode IS NOT NULL;

-- Make up-to-date views of headsFinal
DROP VIEW IF EXISTS spot_early.headsFinal_raw;
CREATE VIEW spot_early.headsFinal_raw AS
  SELECT *
FROM spot.headsFinal;

-- Monthly quality (by unit)
DROP VIEW IF EXISTS spot_early.lite_summ_monthly_raw;
CREATE VIEW spot_early.lite_summ_monthly_raw AS
	SELECT
		icode,
		studymonth,
		icnno,
		dropflag,
		spottrue,
		cmp_admx_permonth,
		cmpd_month_miss,
		match_quality_by_month,
		match_quality_by_site,
		studymonth_allreferrals,
		studymonth_protocol_problem,
		site_quality_q1,
		site_quality_by_month,
		count_patients,
		count_all_eligible
	FROM spot.lite_summ_monthly;

-- Sites and units data
DROP VIEW IF EXISTS spot_early.sites_via_directory_raw;
CREATE VIEW spot_early.sites_via_directory_raw AS
	SELECT * FROM spot.sites_via_directory;
DROP VIEW IF EXISTS spot_early.sitesFinal_raw;
CREATE VIEW spot_early.sitesFinal_raw AS
	SELECT * FROM spot.sitesFinal;
DROP VIEW IF EXISTS spot_early.unitsFinal_raw;
CREATE VIEW spot_early.unitsFinal_raw AS
	SELECT * FROM spot.sitesFinal;
