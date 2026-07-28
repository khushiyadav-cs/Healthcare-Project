--bronze scheme 
use database health_db;

use schema health_db_bronze;
--creating file format 
create or replace file format csv_format
type=csv
skip_header=1
FIELD_OPTIONALLY_ENCLOSED_BY = '"';


   
    
    LIST @Healthcare_stage;
    CREATE OR REPLACE TABLE drug_data (
    
        Prscrbr_NPI STRING,
        Prscrbr_Last_Org_Name STRING,
        Prscrbr_First_Name STRING,
        Prscrbr_City STRING,
        Prscrbr_State_Abrvtn STRING,
        Prscrbr_State_FIPS STRING,
        Prscrbr_Type string,
        Prscrbr_Type_Src STRING,	
        Brnd_Name STRING,
        Gnrc_Name STRING,	
        Tot_Clms string,	
        Tot_30day_Fills string,
        Tot_Day_Suply  string,	
        Tot_Drug_Cst  string,
        Tot_Benes  string,	
        GE65_Sprsn_Flag string,	
        GE65_Tot_Clms string ,
        GE65_Tot_30day_Fills  string,
        GE65_Tot_Drug_Cst  string,
        GE65_Tot_Day_Suply string,
        GE65_Bene_Sprsn_Flag  string,	
        GE65_Tot_Benes  string,
    
        LOAD_TIME TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        SOURCE_FILE STRING
    );
    
    desc table drug_data;
    select * from drug_data;
    
    
    
    --creating a snow pile  
CREATE OR REPLACE PIPE drug_pipe
 AUTO_INGEST = TRUE
AS
COPY INTO drug_data
    (
        Prscrbr_NPI,
        Prscrbr_Last_Org_Name,
        Prscrbr_First_Name,
        Prscrbr_City,
        Prscrbr_State_Abrvtn,
        Prscrbr_State_FIPS,
        Prscrbr_Type,
        Prscrbr_Type_Src,
        Brnd_Name,
        Gnrc_Name,
        Tot_Clms,
        Tot_30day_Fills,
        Tot_Day_Suply,
        Tot_Drug_Cst,
        Tot_Benes,
        GE65_Sprsn_Flag,
        GE65_Tot_Clms,
        GE65_Tot_30day_Fills,
        GE65_Tot_Drug_Cst,
        GE65_Tot_Day_Suply,
        GE65_Bene_Sprsn_Flag,
        GE65_Tot_Benes,
        SOURCE_FILE
    )
    
    FROM
    (
        SELECT
            $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
            $11,$12,$13,$14,$15,$16,$17,$18,
            $19,$20,$21,$22,
    
            METADATA$FILENAME
    
        FROM @Healthcare_stage/MUP_CSV/
    )
    
    FILE_FORMAT = (FORMAT_NAME = csv_format)
    
    ON_ERROR = CONTINUE;
    
    

SHOW PIPES;
alter pipe drug_pipe refresh;
SELECT * FROM drug_data LIMIT 10;
SELECT SYSTEM$PIPE_STATUS('drug_pipe');


SELECT * FROM drug_data ;

SELECT SYSTEM$PIPE_STATUS('drug_pipe');

SELECT
    SOURCE_FILE,
    LOAD_TIME

FROM drug_data

ORDER BY LOAD_TIME DESC;

SELECT COUNT(*) FROM drug_data;



--create a new table name as table name >>= hostical_cost which  will have all the colomuns in the csv file
--three  additiaonal colloum 1.year function  ke throuw  phycal  Year End Date extrect karnah hai also  ---------create more coloums 2. load_time 3.source_time
--table given tablename icd_codes




--creating new stage for 2nd TABLE--


LIST @Healthcare_stage;
show stages;
--creating new table for new file 
CREATE OR REPLACE TABLE hospital_cost (
    rpt_rec_num STRING,
    provider_ccn STRING,
    facility_name STRING,
    street_address STRING,
    city STRING,
    state_code STRING,
    zip_code STRING,
    county STRING,
    medicare_cbsa_number STRING,
    rural_versus_urban STRING,

    fiscal_year_begin_date STRING,
    fiscal_year_end_date STRING,

    type_of_control STRING,
    number_of_beds STRING,
    total_bed_days_available STRING,
    total_days_title_xviii STRING,
    total_days_total STRING,
    total_discharges_title_xviii STRING,
    total_discharges_total STRING,

    inpatient_revenue STRING,
    outpatient_revenue STRING,
    total_patient_revenue STRING,
    less_contractual STRING,
    net_patient_revenue STRING,
    less_total_operating STRING,
    net_income_from_service STRING,
    net_income STRING,
    drg_amounts_other_than STRING,
    total_ime_payment STRING,
    allowable_dsh_percentage STRING,
    cost_to_charge_ratio STRING,

    -- Updated from 'year' to 'fiscal_year' to clear compiler bugs
    fiscal_year NUMBER,
    load_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_file STRING
);


SELECT * FROM hospital_cost ;
SELECT
$1,$2,$3,$4,$5,
$11,$12
FROM @Healthcare_stage/Cost_csv/
(FILE_FORMAT => csv_format);
--LIMIT 5;

SELECT
$12 AS fiscal_year_end_date,
YEAR(TO_DATE($12,'MM/DD/YYYY')) AS fiscal_year
FROM @Healthcare_stage/Cost_csv/
(FILE_FORMAT => csv_format);
--LIMIT 5;




UPDATE hospital_cost
SET fiscal_year =
YEAR(TO_DATE(fiscal_year_end_date,'MM/DD/YYYY'));


SELECT
fiscal_year_end_date,
fiscal_year,
source_file
FROM hospital_cost;

--creating snowpipe 
CREATE OR REPLACE PIPE hospital_cost_pipe
AUTO_INGEST = TRUE
AS

COPY INTO hospital_cost
(
    rpt_rec_num,
    provider_ccn,
    facility_name,
    street_address,
    city,
    state_code,
    zip_code,
    county,
    medicare_cbsa_number,
    rural_versus_urban,
    fiscal_year_begin_date,
    fiscal_year_end_date,
    type_of_control,
    number_of_beds,
    total_bed_days_available,
    total_days_title_xviii,
    total_days_total,
    total_discharges_title_xviii,
    total_discharges_total,
    inpatient_revenue,
    outpatient_revenue,
    total_patient_revenue,
    less_contractual,
    net_patient_revenue,
    less_total_operating,
    net_income_from_service,
    net_income,
    drg_amounts_other_than,
    total_ime_payment,
    allowable_dsh_percentage,
    cost_to_charge_ratio,
    fiscal_year,
    source_file
)
FROM
(
    SELECT
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
        $11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
        $21,$22,$23,$24,$25,$26,$27,$28,$29,$30,
        $31,
        NULL,
        METADATA$FILENAME
    FROM @Healthcare_stage/Cost_csv/
)
FILE_FORMAT = (FORMAT_NAME = csv_format)
ON_ERROR = CONTINUE;

SHOW PIPES;
SELECT SYSTEM$PIPE_STATUS('drug_pipe');
SELECT SYSTEM$PIPE_STATUS('hospital_cost_pipe');
 

SELECT SYSTEM$PIPE_STATUS('hospital_cost_pipe');

select*  from drug_data;
select*from hospital_cost;
--1 jesn  file leni hai ,,s3 per filebanani hai (pationt data ),,create a table name as jason_data in this ou will have one coloumn name as raw_coloumn (data type of this is varint ) fint out 3 things 
--1 resource id ,,2 birth date ,,3 gender ,,4 address


--charo folder meh snow pipe bane ga 



                        
                        --3 rd file -- 



--creating file foramt for 3 rd file ==>tab seperated file ke liye 
create or replace  file format tsv_format
type=csv
field_delimiter='\t'
skip_header=1;



list @Healthcare_stage;

select
    $1 AS icd_code,
    $2 AS description
from @Healthcare_stage/icd_text/
(FILE_FORMAT => tsv_format)
limit 10;

create or replace table icd_codes(
    icd_code string,
    description string,
    load_time timestamp default current_timestamp(),
    source_file string()

);




SELECT COUNT(*) FROM icd_codes;

--creating a snow pipe 
CREATE OR REPLACE PIPE icd_codes_pipe
AUTO_INGEST = TRUE
AS

COPY INTO icd_codes
(
    icd_code,
    description,
    source_file
)
FROM
(
    SELECT
        $1,
        $2,
        METADATA$FILENAME
    FROM @Healthcare_stage/icd_text/
)
FILE_FORMAT = (FORMAT_NAME = tsv_format)
ON_ERROR = CONTINUE;

SHOW PIPES;
alter pipe icd_codes_pipe refresh;
SELECT SYSTEM$PIPE_STATUS('icd_codes_pipe');
select * from icd_codes;
--4 th file --

--creating file format for 4 th file 

create or replace file format json_format
type =json;

--creating stage for json file 



list @Healthcare_stage;

SELECT
    $1:id,
    $1:resourceType
FROM @Healthcare_stage/json_file/
(FILE_FORMAT => json_format)
LIMIT 5;

--creating json table 
CREATE OR REPLACE TABLE json_data (
    raw_column VARIANT,
    load_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_file STRING
);

DESC TABLE json_data;

CREATE OR REPLACE PIPE json_data_pipe
AUTO_INGEST = TRUE
AS

COPY INTO json_data
(
    raw_column,
    source_file
)
FROM
(
    SELECT
        $1,
        METADATA$FILENAME
    FROM @Healthcare_stage/json_file/
)
FILE_FORMAT = (FORMAT_NAME = json_format);


SHOW PIPES;
alter pipe json_data_pipe refresh;

SELECT *
FROM json_data;
--LIMIT 5;

SELECT SYSTEM$PIPE_STATUS('json_data_pipe');

select* from json_data;

ALTER PIPE json_data_pipe REFRESH;


SELECT COUNT(*) FROM json_data;

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME=>'JSON_DATA',
        START_TIME=>DATEADD('hour',-24,CURRENT_TIMESTAMP())
    )
);


--select quesry meh= >> resourse type ,entry coloumn , lateral pattern laga ke dekh nah hai  
--creating patient_raw table 
show schemas;
USE DATABASE HEALTH_DB;
USE SCHEMA bronze;

CREATE OR REPLACE TABLE patient_raw (
    complete_raw VARIANT,
    patient_id STRING,
    resource_type STRING,
    entry_count NUMBER
);

--loading data 

INSERT INTO patient_raw
SELECT
    $1 AS complete_raw,
    $1:id::STRING AS patient_id,
    $1:resourceType::STRING AS resource_type,
    ARRAY_SIZE($1:entry) AS entry_count
FROM @Healthcare_stage/json_file/
(FILE_FORMAT => json_format);
--Lateral Flatten 
SELECT
    f.value:resource:id::STRING AS patient_id,
    f.value:resource:resourceType::STRING AS resource_type,
    f.value:resource:gender::STRING AS gender,
    f.value:resource:birthDate::STRING AS birth_date
FROM patient_raw,
LATERAL FLATTEN(INPUT => complete_raw:entry) f;
--LIMIT 20;
