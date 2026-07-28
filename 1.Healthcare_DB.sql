create or replace database health_db;
use health_db;

create schema health_db_bronze;

CREATE OR REPLACE STAGE Healthcare_stage
URL ='s3://healthcare-2026-project'
CREDENTIALS = ( AWS_KEY_ID =''
AWS_SECRET_KEY ='');

LIST @Healthcare_stage;

create or replace file format csv_format
type=csv
skip_header=1
FIELD_OPTIONALLY_ENCLOSED_BY = '"';

create or replace  file format tsv_format
type=csv
field_delimiter='\t'
skip_header=1;

--Silver
create or replace schema health_db_silver;
