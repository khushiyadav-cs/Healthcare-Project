use database health_db;
use schema silver;



                  
                  --PATIENT_DIM--
                  
SELECT
    f.value:resource:id::STRING AS patient_id,
    f.value:resource:gender::STRING AS gender,
    TRY_TO_DATE(f.value:resource:birthDate::STRING) AS birth_date

FROM health_db_BRONZE.patient_raw,

LATERAL FLATTEN(INPUT => complete_raw:entry) f

WHERE f.value:resource:resourceType::STRING='Patient';

LIMIT 10;

--merging 1 st table 

MERGE INTO SILVER.patient_dim T

USING (

SELECT

f.value:resource:id::STRING AS patient_id,

f.value:resource:gender::STRING AS gender,

TRY_TO_DATE(f.value:resource:birthDate::STRING) AS birth_date


FROM health_db_BRONZE.patient_raw,

LATERAL FLATTEN(INPUT=>complete_raw:entry) f

WHERE f.value:resource:resourceType::STRING='Patient'

) S


ON T.patient_id=S.patient_id

AND T.is_current=TRUE


WHEN MATCHED

AND (

T.gender IS DISTINCT FROM S.gender

OR

T.birth_date IS DISTINCT FROM S.birth_date

)


THEN UPDATE SET


T.eff_to=CURRENT_DATE()-1,

T.is_current=FALSE;


--insert new rows 
INSERT INTO SILVER.patient_dim
(

patient_id,
gender,
birth_date,
age_band,
insurance_tier,

eff_from,
eff_to,

is_current

)

SELECT


S.patient_id,

S.gender,

S.birth_date,


CASE

WHEN DATEDIFF(YEAR,S.birth_date,CURRENT_DATE())<18

THEN '0-17'


WHEN DATEDIFF(YEAR,S.birth_date,CURRENT_DATE())<40

THEN '18-39'


WHEN DATEDIFF(YEAR,S.birth_date,CURRENT_DATE())<60

THEN '40-59'


ELSE '60+'

END,



'STANDARD',


CURRENT_DATE(),

'9999-12-31'::DATE,

TRUE


FROM


(

SELECT


f.value:resource:id::STRING patient_id,


f.value:resource:gender::STRING gender,


TRY_TO_DATE(f.value:resource:birthDate::STRING)

birth_date



FROM health_db_BRONZE.patient_raw,


LATERAL FLATTEN(INPUT=>complete_raw:entry) f



WHERE

f.value:resource:resourceType::STRING='Patient'

)S


LEFT JOIN patient_dim T


ON T.patient_id=S.patient_id

AND T.is_current=TRUE



WHERE


T.patient_sk IS NULL


OR


T.gender IS DISTINCT FROM S.gender


OR


T.birth_date IS DISTINCT FROM S.birth_date;



SELECT *
FROM patient_dim;

--checking from hospital_cost 
SELECT

provider_ccn,
facility_name,
state_code,
type_of_control,
TRY_TO_NUMBER(number_of_beds) AS number_of_beds

FROM health_db_BRONZE.hospital_cost;

--LIMIT 10;

------ merging-----
MERGE INTO SILVER.facility_dim T

USING (

SELECT

provider_ccn,
facility_name,
state_code,
type_of_control,
TRY_TO_NUMBER(number_of_beds) AS number_of_beds

FROM health_db_BRONZE.hospital_cost

) S


ON T.provider_ccn=S.provider_ccn

AND T.is_current=TRUE


WHEN MATCHED

AND (

T.type_of_control IS DISTINCT FROM S.type_of_control

OR

T.number_of_beds IS DISTINCT FROM S.number_of_beds

)


THEN UPDATE SET


T.eff_to=CURRENT_DATE()-1,

T.is_current=FALSE;

--inserting into facility_dim 
INSERT INTO SILVER.facility_dim
(

provider_ccn,
facility_name,
state_code,
type_of_control,
number_of_beds,

eff_from,
eff_to,

is_current

)

SELECT

S.provider_ccn,

S.facility_name,

S.state_code,

S.type_of_control,

S.number_of_beds,


CURRENT_DATE(),

'9999-12-31'::DATE,

TRUE


FROM

(

SELECT

provider_ccn,

facility_name,

state_code,

type_of_control,

TRY_TO_NUMBER(number_of_beds) AS number_of_beds


FROM health_db_BRONZE.hospital_cost

) S


LEFT JOIN facility_dim T


ON T.provider_ccn = S.provider_ccn

AND T.is_current = TRUE



WHERE


T.facility_sk IS NULL


OR


T.type_of_control IS DISTINCT FROM S.type_of_control


OR


T.number_of_beds IS DISTINCT FROM S.number_of_beds;



SELECT *
FROM facility_dim
LIMIT 10;


                         -- ========= FOR the PHYSCIAN =====

SELECT

Prscrbr_NPI,

CONCAT(Prscrbr_First_Name,' ',Prscrbr_Last_Org_Name) AS prscrbr_name,

Prscrbr_Type,

Prscrbr_State_Abrvtn

FROM health_db_BRONZE.drug_data;

--LIMIT 10;

--merging 
MERGE INTO SILVER.physician_dim T

USING (

SELECT DISTINCT

Prscrbr_NPI AS npi,

CONCAT(Prscrbr_First_Name,' ',Prscrbr_Last_Org_Name) AS prscrbr_name,

Prscrbr_Type AS prscrbr_type,

Prscrbr_State_Abrvtn AS prscrbr_state

FROM BRONZE.drug_data

)S


ON T.npi=S.npi

AND T.is_current=TRUE


WHEN MATCHED

AND (

T.prscrbr_type IS DISTINCT FROM S.prscrbr_type

OR

T.prscrbr_state IS DISTINCT FROM S.prscrbr_state

)


THEN UPDATE SET


T.is_current=FALSE;


--inserting newrecords 
INSERT INTO SILVER.physician_dim
(

npi,
prscrbr_name,
prscrbr_type,
prscrbr_state,

eff_from,

is_current

)

SELECT


S.npi,

S.prscrbr_name,

S.prscrbr_type,

S.prscrbr_state,


CURRENT_DATE(),

TRUE



FROM

(

SELECT DISTINCT


Prscrbr_NPI AS npi,


CONCAT(Prscrbr_First_Name,' ',Prscrbr_Last_Org_Name)

AS prscrbr_name,


Prscrbr_Type AS prscrbr_type,


Prscrbr_State_Abrvtn AS prscrbr_state



FROM health_db_BRONZE.drug_data


)S


LEFT JOIN physician_dim T


ON T.npi=S.npi


AND T.is_current=TRUE



WHERE


T.physician_sk IS NULL


OR


T.prscrbr_type IS DISTINCT FROM S.prscrbr_type


OR


T.prscrbr_state IS DISTINCT FROM S.prscrbr_state;


SELECT *
FROM physician_dim;
--LIMIT 10;



                          --3rd --DIAGNOSIS_DIM--

--Check source first
SELECT



f.value:resource:id::STRING AS condition_id,



f.value:resource:code:coding[0]:code::STRING AS diagnosis_code,



f.value:resource:code:text::STRING AS description



FROM health_db_BRONZE.patient_raw,



LATERAL FLATTEN(INPUT=>complete_raw:entry) f



WHERE f.value:resource:resourceType='Condition';



--LIMIT 20;


desc table  diagnosis_dim ;
--merging 
-- ============================================================
-- DIAGNOSIS_DIM  — STEP 1: MERGE (update existing rows)
-- ============================================================

MERGE INTO SILVER.diagnosis_dim T
USING (
    SELECT
        TRIM(icd_code)        AS icd10_code,
        TRIM(description)     AS description,
        LEFT(icd_code, 1)     AS chapter,
        CASE
            WHEN LEFT(icd_code, 1) IN ('I','R','J') THEN 'HIGH'     -- Circulatory / Symptoms / Respiratory
            WHEN LEFT(icd_code, 1) IN ('E','K','M') THEN 'MEDIUM'   -- Metabolic / Digestive / Musculoske
            ELSE 'LOW'
        END                    AS severity_tier
    FROM health_db_BRONZE.icd_codes
    WHERE icd_code IS NOT NULL
) S
ON  T.icd10_code = S.icd10_code        -- natural key match
WHEN MATCHED AND (
    T.description    IS DISTINCT FROM S.description OR     -- NULL-safe compare
    T.chapter        IS DISTINCT FROM S.chapter OR
    T.severity_tier  IS DISTINCT FROM S.severity_tier
) THEN UPDATE SET
    T.description   = S.description,
    T.chapter        = S.chapter,
    T.severity_tier  = S.severity_tier;


-- ============================================================
-- DIAGNOSIS_DIM  — STEP 2: INSERT (new codes only)
-- ============================================================

INSERT INTO SILVER.diagnosis_dim (icd10_code, description, chapter, severity_tier)
SELECT
    S.icd10_code, S.description, S.chapter, S.severity_tier
FROM (
    SELECT
        TRIM(icd_code)        AS icd10_code,
        TRIM(description)     AS description,
        LEFT(icd_code, 1)     AS chapter,
        CASE
            WHEN LEFT(icd_code, 1) IN ('I','R','J') THEN 'HIGH'
            WHEN LEFT(icd_code, 1) IN ('E','K','M') THEN 'MEDIUM'
            ELSE 'LOW'
        END                    AS severity_tier
    FROM health_db_BRONZE.icd_codes
    WHERE icd_code IS NOT NULL
) S
LEFT JOIN SILVER.diagnosis_dim T
    ON T.icd10_code = S.icd10_code
WHERE T.diag_sk IS NULL;

                             
                             
                            --4th --date_dim 

INSERT INTO SILVER.date_dim (
    calendar_date,
    year,
    month,
    quarter,
    month_name,
    is_holiday
)
SELECT DISTINCT
    claim_date AS calendar_date,
    YEAR(claim_date) AS year,
    MONTH(claim_date) AS month,
    QUARTER(claim_date) AS quarter,
    MONTHNAME(claim_date) AS month_name,
    FALSE AS is_holiday
FROM (
    SELECT
        TRY_TO_DATE(LEFT(e.value:resource:created::STRING, 10)) AS claim_date
    FROM health_db_BRONZE.patient_raw b,
    LATERAL FLATTEN(INPUT => b.complete_raw:entry) e
    WHERE e.value:resource:resourceType::STRING = 'Claim'
      AND e.value:resource:id::STRING IS NOT NULL
      AND e.value:resource:total:value::NUMBER(14,2) > 0
) c
LEFT JOIN SILVER.date_dim d
    ON d.calendar_date = c.claim_date
WHERE c.claim_date IS NOT NULL
  AND d.date_sk IS NULL;
