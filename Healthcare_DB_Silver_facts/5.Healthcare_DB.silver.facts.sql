use database health_db;
use schema silver;


-- inserting data  into fact claims table 

INSERT INTO SILVER.fact_claims (
    claim_id,
    patient_sk,
    facility_sk,
    diag_sk,
    date_sk,
    billed_amount,
    paid_amount,
    claim_decision
)

WITH flat_claims AS (
    SELECT
        e.value:resource:id::STRING AS claim_id,
        REPLACE(
            e.value:resource:patient:reference::STRING,
            'urn:uuid:',
            ''
        ) AS patient_id_raw,
        TRY_TO_DATE(LEFT(e.value:resource:created::STRING, 10)) AS claim_date,
        e.value:resource:total:value::NUMBER(14,2) AS billed_amount,
        e.value:resource:status::STRING AS claim_status
    FROM health_db_BRONZE.patient_raw b,
         LATERAL FLATTEN(INPUT => b.complete_raw:entry) e
    WHERE e.value:resource:resourceType::STRING = 'Claim'
      AND e.value:resource:id::STRING IS NOT NULL
      AND e.value:resource:total:value::NUMBER(14,2) > 0
)

SELECT
    fc.claim_id,
    dp.patient_sk,
    0 AS facility_sk,
    0 AS diag_sk,
    dat.date_sk,

    fc.billed_amount,

    CASE fc.claim_status
        WHEN 'active' THEN ROUND(fc.billed_amount * 0.85, 2)
        WHEN 'cancelled' THEN 0
        ELSE 0
    END AS paid_amount,

    CASE fc.claim_status
        WHEN 'active' THEN 'APPROVED'
        WHEN 'cancelled' THEN 'DENIED'
        ELSE 'PENDING'
    END AS claim_decision

FROM flat_claims fc

LEFT JOIN SILVER.patient_dim dp
    ON dp.patient_id = fc.patient_id_raw
   AND dp.is_current = TRUE

LEFT JOIN SILVER.date_dim dat
    ON dat.calendar_date = fc.claim_date;

--cheaking 
SELECT
    COUNT(*) AS total_claims,
    COUNT(patient_sk) AS claims_with_patient,
    COUNT(facility_sk) AS claims_with_facility,
    COUNT(diag_sk) AS claims_with_diagnosis,
    COUNT(date_sk) AS claims_with_date
FROM SILVER.fact_claims;




             -- inserting data into 2nd fact

--checking resource 


-- =========================================
-- FACT_DRUG_SPEND
-- =========================================

INSERT INTO SILVER.FACT_DRUG_SPEND (
    physician_sk,
    facility_sk,
    date_sk,
    brand_name,
    generic_name,
    total_claims,
    total_drug_cost,
    total_benes
)

SELECT
    p.physician_sk,
    0 AS facility_sk,   -- UNKNOWN (since no mapping available)
    dte.date_sk,

    d.Brnd_Name AS brand_name,
    d.Gnrc_Name AS generic_name,
    TRY_TO_NUMBER(d.Tot_Clms) AS total_claims,
    TRY_TO_NUMBER(d.Tot_Drug_Cst) AS total_drug_cost,
    TRY_TO_NUMBER(d.Tot_Benes) AS total_benes

FROM health_db_BRONZE.drug_data d

LEFT JOIN SILVER.physician_dim p
    ON d.Prscrbr_NPI = p.npi
   AND p.is_current = TRUE

LEFT JOIN SILVER.date_dim dte
    ON dte.calendar_date = CURRENT_DATE();
--cheking
SELECT
    COUNT(*) AS total_rows,
    COUNT(physician_sk) AS mapped_physicians,
    COUNT(date_sk) AS mapped_dates
FROM SILVER.FACT_DRUG_SPEND;



                             --3rd fact table  FACT_CAPACI


INSERT INTO SILVER.FACT_CAPACITY (
    facility_sk,
    date_sk,
    ward_type,
    staffed_beds,
    occupied_beds,
    occupancy_pct
)

SELECT
    f.facility_sk,
    d.date_sk,

    'GENERAL' AS ward_type,

    TRY_TO_NUMBER(h.number_of_beds) AS staffed_beds,

    ROUND(TRY_TO_NUMBER(h.number_of_beds) * 0.75) AS occupied_beds,

    ROUND(
        (ROUND(TRY_TO_NUMBER(h.number_of_beds) * 0.75)
        / NULLIF(TRY_TO_NUMBER(h.number_of_beds), 0)) * 100,
        2
    ) AS occupancy_pct

FROM health_db_BRONZE.hospital_cost h

LEFT JOIN SILVER.facility_dim f
    ON h.provider_ccn = f.provider_ccn
   AND f.is_current = TRUE

LEFT JOIN SILVER.date_dim d
    ON d.calendar_date = TO_DATE(h.fiscal_year_end_date, 'MM/DD/YYYY')

WHERE TRY_TO_NUMBER(h.number_of_beds) IS NOT NULL;

                             
---cheaking 

SELECT
    COUNT(*) AS total_rows,
    COUNT(facility_sk) AS mapped_facility,
    COUNT(date_sk) AS mapped_date,
    COUNT(staffed_beds) AS valid_staffed,
    COUNT(occupied_beds) AS valid_occupied
FROM SILVER.FACT_CAPACITY;
                             
                             --testing-- 
SELECT 'patient_dim' AS table_name, COUNT(*) AS row_count FROM SILVER.patient_dim
UNION ALL
SELECT 'facility_dim', COUNT(*) FROM SILVER.facility_dim
UNION ALL
SELECT 'physician_dim', COUNT(*) FROM SILVER.physician_dim
UNION ALL
SELECT 'diagnosis_dim', COUNT(*) FROM SILVER.diagnosis_dim
UNION ALL
SELECT 'date_dim', COUNT(*) FROM SILVER.date_dim
UNION ALL
SELECT 'fact_claims', COUNT(*) FROM SILVER.fact_claims
UNION ALL
SELECT 'fact_drug_spend', COUNT(*) FROM SILVER.fact_drug_spend
UNION ALL
SELECT 'fact_capacity', COUNT(*) FROM SILVER.fact_capacity;



SELECT COUNT(*) AS patient_source_count
FROM BRONZE.patient_raw,
LATERAL FLATTEN(INPUT => complete_raw:entry) f
WHERE f.value:resource:resourceType::STRING = 'Patient';


SELECT 'patient_dim' AS table_name, COUNT(*) AS duplicate_count
FROM (
    SELECT patient_id
    FROM SILVER.patient_dim
    WHERE is_current = TRUE
    GROUP BY patient_id
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT 'facility_dim', COUNT(*)
FROM (
    SELECT provider_ccn
    FROM SILVER.facility_dim
    WHERE is_current = TRUE
    GROUP BY provider_ccn
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT 'physician_dim', COUNT(*)
FROM (
    SELECT npi
    FROM SILVER.physician_dim
    WHERE is_current = TRUE
    GROUP BY npi
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT 'diagnosis_dim', COUNT(*)
FROM (
    SELECT icd10_code
    FROM SILVER.diagnosis_dim
    GROUP BY icd10_code
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT 'date_dim', COUNT(*)
FROM (
    SELECT calendar_date
    FROM SILVER.date_dim
    GROUP BY calendar_date
    HAVING COUNT(*) > 1
);




SELECT
    provider_ccn,
    COUNT(*) AS cnt
FROM SILVER.facility_dim
WHERE is_current = TRUE
GROUP BY provider_ccn
HAVING COUNT(*) > 1
ORDER BY cnt DESC, provider_ccn;



--tesing 2nd 
-- row counts across all Silver tables
SELECT 'PATIENT_DIM' AS tbl, COUNT(*) AS total_rows,
       COUNT_IF(IS_CURRENT) AS current_rows FROM SILVER.PATIENT_DIM
UNION ALL
SELECT 'FACILITY_DIM', COUNT(*), COUNT_IF(IS_CURRENT) FROM SILVER.FACILITY_DIM
UNION ALL
SELECT 'PHYSICIAN_DIM', COUNT(*), COUNT_IF(IS_CURRENT) FROM SILVER.PHYSICIAN_DIM
UNION ALL
SELECT 'DIAGNOSIS_DIM', COUNT(*), NULL FROM SILVER.DIAGNOSIS_DIM
UNION ALL
SELECT 'DATE_DIM', COUNT(*), NULL FROM SILVER.DATE_DIM
UNION ALL
SELECT 'FACT_CLAIMS', COUNT(*), NULL FROM SILVER.FACT_CLAIMS
UNION ALL
SELECT 'FACT_DRUG_SPEND', COUNT(*), NULL FROM SILVER.FACT_DRUG_SPEND
UNION ALL
SELECT 'FACT_CAPACITY', COUNT(*), NULL FROM SILVER.FACT_CAPACITY
ORDER BY tbl;








SELECT 'PATIENT_DIM' AS tbl,
       COUNT(*) AS total_rows,
       COUNT_IF(is_current = TRUE) AS current_rows
FROM SILVER.PATIENT_DIM

UNION ALL

SELECT 'FACILITY_DIM',
       COUNT(*),
       COUNT_IF(is_current = TRUE)
FROM SILVER.FACILITY_DIM

UNION ALL

SELECT 'PHYSICIAN_DIM',
       COUNT(*),
       COUNT_IF(is_current = TRUE)
FROM SILVER.PHYSICIAN_DIM

UNION ALL

SELECT 'DIAGNOSIS_DIM',
       COUNT(*),
       NULL
FROM SILVER.DIAGNOSIS_DIM

UNION ALL

SELECT 'DATE_DIM',
       COUNT(*),
       NULL
FROM SILVER.DATE_DIM

UNION ALL

SELECT 'FACT_CAPACITY',
       COUNT(*),
       NULL
FROM SILVER.FACT_CAPACITY

UNION ALL

SELECT 'FACT_CLAIMS',
       COUNT(*),
       NULL
FROM SILVER.FACT_CLAIMS;

SELECT * FROM SILVER.FACT_CAPACITY;
