WITH cohorts As (SELECT
userid,
id as company_id,
MIN(DATE_TRUNC('MONTH',date_completed_localtime)) 
	OVER (PARTITION BY userid) as cohort_month,
EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH',date_completed_localtime), 
MIN(DATE_TRUNC('MONTH',date_completed_localtime)) 
		OVER (PARTITION BY userid))) * 12 
		+ EXTRACT(MONTHS FROM AGE(DATE_TRUNC('MONTH',date_completed_localtime),
		MIN(DATE_TRUNC('MONTH',date_completed_localtime)) 
		OVER (PARTITION BY userid))) AS retention_month
FROM vert1),

nominal AS (SELECT
		   cohort_month,
			retention_month,
			COUNT(DISTINCT userid) as number_of_customer
			FROM cohorts
			GROUP BY 1,2)


SELECT
to_char(cohort_month,'MM-YYYY') AS month,
retention_month,
ROUND(CAST(number_of_customer AS decimal) / 
	  FIRST_VALUE(number_of_customer) 
	  OVER (PARTITION BY cohort_month ORDER BY retention_month)*100,0)
	  FROM nominal
	  ORDER BY cohort_month ASC, retention_month ASC
