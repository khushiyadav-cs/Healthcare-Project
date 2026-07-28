--silver scheme
use database health_db;
create or replace schema silver;
use schema silver;

show tables;
--creating 1st table patient dimenshin table
CREATE OR REPLACE TABLE patient_dim (
    patient_sk NUMBER AUTOINCREMENT PRIMARY KEY,
    patient_id VARCHAR,
    gender VARCHAR,
    birth_date DATE,
    age_band VARCHAR,
    insurance_tier VARCHAR,
    eff_from DATE,
    eff_to DATE,
    is_current BOOLEAN
);



SELECT * FROM patient_dim;

desc table patient_dim;





--creatin  2nd FACILITY dimension TABLE--


CREATE OR REPLACE TABLE facility_dim (
    facility_sk NUMBER AUTOINCREMENT PRIMARY KEY,
    provider_ccn VARCHAR,
    facility_name VARCHAR,
    state_code VARCHAR,
    type_of_control VARCHAR,
    number_of_beds NUMBER,
    eff_from DATE,
    eff_to DATE,
    is_current BOOLEAN
);



--creating  3rd   physician_dim

SELECT *
FROM health_db_BRONZE.drug_data --cheching data from drug_data
LIMIT 5;

CREATE OR REPLACE TABLE physician_dim (
    physician_sk NUMBER AUTOINCREMENT PRIMARY KEY,
    npi VARCHAR,
    prscrbr_name VARCHAR,
    prscrbr_type VARCHAR,
    prscrbr_state VARCHAR,
    eff_from DATE,
    is_current BOOLEAN
);
select * from  physician_dim ; 

--creting 4 th table 
CREATE OR REPLACE TABLE diagnosis_dim (
    diag_sk NUMBER AUTOINCREMENT PRIMARY KEY,
    icd10_code VARCHAR,
    description VARCHAR,
    chapter VARCHAR,
    severity_tier VARCHAR
);



-- creating 5 th table data dim 
CREATE OR REPLACE TABLE date_dim (
    date_sk NUMBER AUTOINCREMENT PRIMARY KEY,
    calendar_date DATE,
    year NUMBER,
    month NUMBER,
    quarter NUMBER,
    month_name VARCHAR,
    is_holiday BOOLEAN
);


                 --creating facts tables--


--creating 1st fact table facts_claims

use database health_db;
use schema silver;
SHOW SCHEMAS;
--creating fact table FACT_CLAIMS
CREATE OR REPLACE TABLE FACT_CLAIMS (

    claim_sk NUMBER AUTOINCREMENT PRIMARY KEY,
    claim_id VARCHAR,

    patient_sk NUMBER REFERENCES patient_dim(patient_sk),
    facility_sk NUMBER REFERENCES facility_dim(facility_sk),
    diag_sk NUMBER REFERENCES diagnosis_dim(diag_sk),
    date_sk NUMBER REFERENCES date_dim(date_sk),

    billed_amount NUMBER,
    paid_amount NUMBER,

    claim_decision VARCHAR
);

DESC TABLE FACT_CLAIMS;

--creatin 2nd fact table fact_drug_spend

CREATE OR REPLACE TABLE FACT_DRUG_SPEND (

    drug_spend_sk NUMBER AUTOINCREMENT PRIMARY KEY,

    physician_sk NUMBER REFERENCES physician_dim(physician_sk),

    facility_sk NUMBER REFERENCES facility_dim(facility_sk),

    date_sk NUMBER REFERENCES date_dim(date_sk),

    brand_name VARCHAR,

    generic_name VARCHAR,

    total_claims NUMBER,

    total_drug_cost NUMBER,

    total_benes NUMBER
);


desc TABLE FACT_DRUG_SPEND;

--creatnig 3 rd fact table 


CREATE OR REPLACE TABLE FACT_CAPACITY (

    capacity_sk NUMBER AUTOINCREMENT PRIMARY KEY,

    facility_sk NUMBER REFERENCES facility_dim(facility_sk),

    date_sk NUMBER REFERENCES date_dim(date_sk),

    ward_type VARCHAR,

    staffed_beds NUMBER,

    occupied_beds NUMBER,

    occupancy_pct NUMBER
);

DESC TABLE FACT_CAPACITY;


SELECT *
FROM patient_dim
LIMIT 20;

SELECT *
FROM facility_dim
LIMIT 20;

--cheaking 1st table 
SELECT
    patient_id,
    COUNT(*)
FROM patient_dim
GROUP BY patient_id
HAVING COUNT(*) > 1;

--cheaking 2nd table 

SELECT
    provider_ccn,
    COUNT(*)
FROM facility_dim
GROUP BY provider_ccn
HAVING COUNT(*) > 1;


--cheaking 3 rd tabel 
SELECT *
FROM physician_dim;

select npi, count(*)
from physician_dim
group by npi
having count(*) >1;

--cheaking 4th table
select* FROM diagnosis_dim;

select ICD10_CODE, count(*)
from diagnosis_dim
group by ICD10_CODE
having count(*) >1;

--cheaking 5 th table 
SELECT *
FROM date_dim
LIMIT 20;


SELECT
    calendar_date,
    COUNT(*)
FROM date_dim
GROUP BY calendar_date
HAVING COUNT(*) > 1;


use schema silver;



--extracting data from patient_raw

select
    f.value:resource:id::string as patient_id,
    f.value:resource:gender::string as gender,
    f.value:resource:birthDate::date as birth_data
from bronze.patient_raw,
lateral  flatten(input => complete_raw:entry) f
where f.value:resource:resourceType::STRING = 'Patient';

--extrating data facility_dim
select *from health_db_bronze.hospital_cost;

select
     provider_ccn,
    facility_name,
    state_code,
    type_of_control,
    TRY_TO_NUMBER(number_of_beds) AS number_of_beds
from health_db_bronze.hospital_cost;

--extracting data   physicain_dim
select* form health_db_bronze;

SELECT DISTINCT
    Prscrbr_NPI AS npi,

    CONCAT(
        Prscrbr_First_Name,
        ' ',
        Prscrbr_Last_Org_Name
    ) AS prscrbr_name,

    Prscrbr_Type AS prscrbr_type,

    Prscrbr_State_Abrvtn AS prscrbr_state

FROM health_db_BRONZE.drug_data;

--Extracting physician_dim
SELECT DISTINCT
    Prscrbr_NPI AS npi,

    CONCAT(
        Prscrbr_First_Name,
        ' ',
        Prscrbr_Last_Org_Name
    ) AS prscrbr_name,

    Prscrbr_Type AS prscrbr_type,

    Prscrbr_State_Abrvtn AS prscrbr_state

FROM health_db_BRONZE.drug_data;


--extracting DIAGNOSIS_DIM

SELECT
    icd_code AS icd10_code,

    description,

    LEFT(icd_code,1) AS chapter,

    CASE
        WHEN LEFT(icd_code,1) IN ('A','B','C') THEN 'HIGH'
        WHEN LEFT(icd_code,1) IN ('D','E','F','G','H') THEN 'MED'
        ELSE 'LOW'
    END AS severity_tier

FROM health_db_BRONZE.icd_codes;

--Extracting data_dim 
SELECT DISTINCT

    TO_DATE(fiscal_year_end_date,'MM/DD/YYYY') AS calendar_date,

    YEAR(TO_DATE(fiscal_year_end_date,'MM/DD/YYYY')) AS year,

    MONTH(TO_DATE(fiscal_year_end_date,'MM/DD/YYYY')) AS month,

    QUARTER(TO_DATE(fiscal_year_end_date,'MM/DD/YYYY')) AS quarter,

    MONTHNAME(TO_DATE(fiscal_year_end_date,'MM/DD/YYYY')) AS month_name,

    FALSE AS is_holiday

FROM health_db_BRONZE.hospital_cost;




--naya bucet 
--3folderbanane hai aur sari bronze meh 
--storage intergratin 
--stage integration 

DESC TABLE health_db_bronze.patient_raw;
