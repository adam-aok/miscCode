SELECT ppl.people_id,
       ppl.medicaid_number,
       jev.INVOICE_NUMBER AS BATCH,
       jev.GL_CODE,
       B2.GL_CODE AS REV_GL,
       B2.ACCOUNT_DESCRIPTION,
       B2.GL_CODE2 AS REV_GL2,
       B2.ACCOUNT_DESCRIPTION2,
       jev.JE_NUM_SHORT,
       jev.LINE_NUMBER,
       B2.COST_CENTER,
       ppl.agency_id_no AS EVOLV_ID,
       LTRIM(RTRIM(CONCAT(ppl.last_name, ', ', ppl.first_name, ' ', ppl.middle_name))) AS CHILD,
       B2.DEP,
       B2.PROGRAM,
       jev.MONTH_ORDER AS GL_MONTH,
       jev.YEAR AS GL_YEAR,
       MONTH(jev.INVOICE_from_date) AS SERV_MONTH,
       YEAR(jev.INVOICE_from_date) AS SERV_YEAR,
       CASE
           WHEN jev.DEBIT_AMOUNT IS NULL
                AND jev.CREDIT_AMOUNT IS NOT NULL THEN
               0 - jev.CREDIT_AMOUNT
           WHEN jev.CREDIT_AMOUNT IS NULL
                AND jev.DEBIT_AMOUNT IS NOT NULL THEN
               jev.DEBIT_AMOUNT
           WHEN jev.DEBIT_AMOUNT IS NULL
                AND jev.CREDIT_AMOUNT IS NULL THEN
               0
           ELSE
               jev.DEBIT_AMOUNT - jev.CREDIT_AMOUNT
       END AS GL_AMOUNT,
       CAST(jev.INVOICE_from_date AS DATE) AS EVOLV_SERVICE_DATE,
       cv.procedure_code AS PROC_CODE,
       inv.UNITS,
       YEAR(DATEADD(MONTH, 6, jev.INVOICE_from_date)) AS FY,
       YEAR(DATEADD(MONTH, 6, jev.month_end)) AS FY_JE,
       cv.PLAN_NAME,
       v.vendor_name,
       v.VENDOR_UNITS
FROM CQI.dbo.journal_entries_view jev
    LEFT OUTER JOIN CQI.dbo.claims_view cv
        ON jev.invoice_id = cv.invoice_id
    LEFT OUTER JOIN CQI.dbo.invoice inv
        ON jev.invoice_id = inv.invoice_id
    -- moved to use local table - or bring table in
    LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people ppl
        ON jev.people_id = ppl.people_id
    LEFT OUTER JOIN
    ( - why NOT ON invoice_id
        SELECT *
        FROM
        (
            SELECT ROW_NUMBER() OVER (PARTITION BY PV.vendor_name,
                                                   inv.invoice_number,
                                                   inv.units
                                      ORDER BY PV.payor_vendor_id DESC
                                     ) AS RN,
                   PV.vendor_name,
                   inv.invoice_number,
                   inv.units AS VENDOR_UNITS
            FROM CQI.dbo.invoice inv
                INNER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].group_profile GP
                    ON inv.service_facility = GP.group_profile_id
                INNER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].payor_vendor PV
                    ON GP.payor_vendor_id = PV.payor_vendor_id
        ) v1
        WHERE v1.RN = 1
    ) v
        ON cv.invoice_number = v.invoice_number
    LEFT OUTER JOIN
    --  SINCE THE AR ACCOUNT DOES NOT HAVE THE DEP OR PROGRAM (COST CENTER) INFO, I NEED TO JOIN THAT INFO ON BATCH ID (INVOICE#) TO GET THE AR
    (
        SELECT ROW_NUMBER() OVER (PARTITION BY a.INVOICE_NUMBER,
                                               c.agency_id_no
                                  ORDER BY a.GL_CODE ASC
                                 ) AS RN,
               a.GL_CODE,
               a.ACCOUNT_DESCRIPTION,
               LAG(a.GL_CODE, 1) OVER (PARTITION BY a.INVOICE_NUMBER,
                                                    c.agency_id_no
                                       ORDER BY a.GL_CODE DESC
                                      ) AS GL_CODE2,
               LAG(a.ACCOUNT_DESCRIPTION, 1) OVER (PARTITION BY a.INVOICE_NUMBER,
                                                                c.agency_id_no
                                                   ORDER BY a.GL_CODE DESC
                                                  ) AS ACCOUNT_DESCRIPTION2,
               a.INVOICE_NUMBER AS BATCH,
               REPLACE(a.cost_center_code, '-', '') AS COST_CENTER,
               c.agency_id_no AS EVOLV_ID,
               RIGHT(RTRIM(a.cost_center_code), 3) AS DEP,
               a.cost_center_description AS PROGRAM
        FROM CQI.dbo.journal_entries_view a
            LEFT OUTER JOIN CQI.dbo.claims_view b
                ON a.invoice_id = b.invoice_id
            LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people c
                ON a.people_id = c.people_id
        WHERE a.gl_code IN ( '5070', '5080', '5040', '5010', '5050', '5150', '5100' )
              AND CAST(a.INVOICE_from_date AS DATE) >= '01/01/2016'
    ) B2
        ON jev.INVOICE_NUMBER = B2.BATCH
           AND ppl.agency_id_no = B2.EVOLV_ID
WHERE CAST(jev.INVOICE_from_date AS DATE) >= '01/01/2016'
      AND jev.gl_code IN ( '1527', '1993' )
      AND
      (
          B2.RN = 1
          OR B2.RN IS NULL
      )
UNION
SELECT c.people_id AS PEOPLE_ID,
       c.medicaid_number AS MEDICAID_NUMBER,
       a.INVOICE_NUMBER AS BATCH,
       a.GL_CODE AS GL_CODE,
       a.GL_CODE AS REV_GL,
       a.ACCOUNT_DESCRIPTION,
       NULL AS REV_GL2,
       NULL AS ACCOUNT_DESCRIPTION2,
       a.JE_NUM_SHORT,
       a.LINE_NUMBER,
       REPLACE(a.cost_center_code, '-', '') AS COST_CENTER,
       c.agency_id_no AS EVOLV_ID,
       LTRIM(RTRIM(CONCAT(c.last_name, ', ', c.first_name, ' ', c.middle_name))) AS CHILD,
       RIGHT(RTRIM(a.cost_center_code), 3) AS DEP,
       a.cost_center_description AS PROGRAM,
       a.MONTH_ORDER AS GL_MONTH,
       a.YEAR AS GL_YEAR,
       MONTH(a.INVOICE_from_date) AS SERV_MONTH,
       YEAR(a.INVOICE_from_date) AS SERV_YEAR,
       CASE
           WHEN a.DEBIT_AMOUNT IS NULL
                AND a.CREDIT_AMOUNT IS NOT NULL THEN
               0 - a.CREDIT_AMOUNT
           WHEN a.CREDIT_AMOUNT IS NULL
                AND a.DEBIT_AMOUNT IS NOT NULL THEN
               a.DEBIT_AMOUNT
           WHEN a.DEBIT_AMOUNT IS NULL
                AND a.CREDIT_AMOUNT IS NULL THEN
               0
           ELSE
               a.DEBIT_AMOUNT - a.CREDIT_AMOUNT
       END AS GL_AMOUNT,
       CAST(a.INVOICE_from_date AS DATE) AS EVOLV_SERVICE_DATE,
       b.procedure_code AS PROC_CODE,
       i.UNITS,
       YEAR(DATEADD(MONTH, 6, a.INVOICE_from_date)) AS FY,
       YEAR(DATEADD(MONTH, 6, a.month_end)) AS FY_JE,
       b.PLAN_NAME,
       v.vendor_name,
       v.VENDOR_UNITS
FROM CQI.dbo.journal_entries_view a
    LEFT OUTER JOIN CQI.dbo.claims_view b
        ON a.invoice_id = b.invoice_id
    LEFT OUTER JOIN CQI.dbo.invoice i
        ON a.invoice_id = i.invoice_id
    LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people c
        ON a.people_id = c.people_id
    LEFT OUTER JOIN
    (
        SELECT *
        FROM
        (
            SELECT ROW_NUMBER() OVER (PARTITION BY PV.vendor_name,
                                                   i.invoice_number,
                                                   i.units
                                      ORDER BY PV.payor_vendor_id DESC
                                     ) AS RN,
                   PV.vendor_name,
                   i.invoice_number,
                   i.units AS VENDOR_UNITS
            FROM CQI.dbo.invoice i
                INNER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].group_profile GP
                    ON i.service_facility = GP.group_profile_id
                INNER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].payor_vendor PV
                    ON GP.payor_vendor_id = PV.payor_vendor_id
        ) v1
        WHERE v1.RN = 1
    ) v
        ON b.invoice_number = v.invoice_number
WHERE CAST(a.INVOICE_from_date AS DATE) >= '01/01/2016'
      AND a.GL_CODE IN ( '5070', '5080', '5040', '5010', '5050', '5150', '5100' );