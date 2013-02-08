# Generic shell script to prepare all tables for spot_early

cd ~/data/spot_early/vcode
# First of all prepare all the tables you need
uuser="stevetm"
ppass=""
ddbase="spot_early"
/usr/local/bin/mysql --user=$uuser --pass=$ppass $ddbase  --local-infile=1 < cr_working.sql >  '../logs/log_cr_working.txt';

# Now run through the standard process of cleaning and tidying the tables
# tails
../ccode/import_sql.py spot_early tailsfinal_raw -replace
../ccode/index_table.py spot_early tailsfinal

# heads
../ccode/import_sql.py spot_early headsfinal_raw -replace
../ccode/index_table.py spot_early headsfinal

# monthly quality by unit
../ccode/import_sql.py spot_early lite_summ_monthly_raw -replace
../ccode/index_table.py spot_early lite_summ_monthly

# unitsFinal, sitesFinal, sites via directory
../ccode/import_sql.py spot_early unitsfinal_raw -replace
../ccode/index_table.py spot_early unitsfinal

../ccode/import_sql.py spot_early sitesfinal -source spot -replace
../ccode/index_table.py spot_early sitesfinal
../ccode/make_table.py spot_early sitesfinal


# NOTE: 2012-12-21 - the problem with using 'validated' data is with generating the CONSORT seq
../ccode/make_table.py spot_early tailsfinal -o validated
../ccode/make_table.py spot_early headsfinal -o validated
../ccode/make_table.py spot_early lite_summ_monthly -o validated
../ccode/make_table.py spot_early unitsfinal -o validated


# Finally ....

../ccode/make_table.py spot_early sites_within_cmpd -o clean
../ccode/make_table.py spot_early sites_within_hes -o clean
../ccode/make_table.py spot_early sites_early -o clean
# And the principal table
../ccode/make_table.py spot_early working_early -o clean



