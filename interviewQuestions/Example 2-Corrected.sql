USE [CQI]
GO

/****** Object:  StoredProcedure [NYFNET\David.Bernard].[Automate_DD_DocumentationCompliance]    Script Date: 5/12/2021 5:49:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [NYFNET\David.Bernard].[Automate_DD_DocumentationCompliance]
WITH EXEC AS CALLER
AS

DECLARE @StartDate DATE = DATEFROMPARTS(YEAR(DATEADD(MM, -12, GETDATE())), MONTH(DATEADD(MM, -12, GETDATE())), 1);

--NullDate is used to move all null dates to the bottom we can assume
DECLARE @NullDate DATE = CAST('1/1/2099' AS DATE);

--#################################################################################################################################
--#################################################### DROP TABLES IF THEY EXIST ##################################################
--#################################################################################################################################

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_IP') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_IP
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_MM') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_MM
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_PV') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_PV
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_RH') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_RH
END


IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_DH') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_DH
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_CH') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_CH
END


IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_ICF') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_ICF
END


IF(OBJECT_ID('CQI.[NYFNET\David.Bernard].DD_DocumentationCompliance') IS NOT NULL)
BEGIN
  DROP TABLE CQI.[NYFNET\David.Bernard].DD_DocumentationCompliance
END;


--#################################################################################################################################
--############################################### PUT THE DOCUMENTS IN A TEMP TABLE FOR LATER #####################################
--#################################################################################################################################



SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], 
  CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  GP.other_description AS [Plan Type],
  
  --I AM DOING THESE DENSE RANK CASE-WHENS BECAUSE EITHER THERE ARE MULTIPLE SERVICES FOR THE SAME THING OR AN INITIAL AND REVIEW
  --AND I NEED ALL THE SERVICES TO PARTITION BY THE SAME THING
  DENSE_RANK() OVER (PARTITION BY EL.people_id, CASE 
                                                  WHEN EL.event_definition_id = 'f4a77ada-3c90-46c1-8dae-8e8d251e9994' THEN '982cf3e6-88fb-4dfd-ac9b-8baf23e5de3f' --LIFE PLANS
                                                  WHEN EL.event_definition_id = '98be8edc-de07-eb11-b81b-00505681b967' THEN '99be8edc-de07-eb11-b81b-00505681b967' --ICF DEVELOPMENT PLANS
                                                  ELSE EL.event_definition_id END ORDER BY EL.actual_date DESC) AS RN,
  DENSE_RANK() OVER (PARTITION BY EL.people_id, CASE 
                                                  WHEN EL.event_definition_id = 'f4a77ada-3c90-46c1-8dae-8e8d251e9994' THEN '982cf3e6-88fb-4dfd-ac9b-8baf23e5de3f' --LIFE PLANS
                                                  WHEN EL.event_definition_id = '98be8edc-de07-eb11-b81b-00505681b967' THEN '99be8edc-de07-eb11-b81b-00505681b967' --ICF DEVELOPMENT PLANS
                                                  ELSE EL.event_definition_id END ORDER BY CASE WHEN GP.other_description LIKE '%Initial%' OR GP.other_description LIKE '%Annual%' THEN 1 ELSE 0 END DESC, EL.actual_date DESC) AS RN_AN,
  DENSE_RANK() OVER (PARTITION BY EL.people_id, CASE 
                                                  WHEN EL.event_definition_id = 'f4a77ada-3c90-46c1-8dae-8e8d251e9994' THEN '982cf3e6-88fb-4dfd-ac9b-8baf23e5de3f' --LIFE PLANS
                                                  WHEN EL.event_definition_id = '98be8edc-de07-eb11-b81b-00505681b967' THEN '99be8edc-de07-eb11-b81b-00505681b967' --ICF DEVELOPMENT PLANS
                                                  ELSE EL.event_definition_id END ORDER BY CASE WHEN GP.other_description LIKE '%Semi%' THEN 1 ELSE 0 END DESC, EL.actual_date DESC) AS RN_SM
    
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].gp_requirements GP ON EL.event_log_id = GP.event_log_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('274d253a-ce28-410e-be01-1c078274d143', '2c0794d8-d073-4ae3-811e-f9a73a2e171d', '7a444d3b-8edb-4486-99ff-7319ae93c408', '2c0794d8-d073-4ae3-811e-f9a73a2e171d', '0a88fb62-8fb3-4c6c-b783-2d9917c99931', '4e665c52-b0e6-454d-b2b5-226b5e2cbeb0', '274d253a-ce28-410e-be01-1c078274d143', 'f4a77ada-3c90-46c1-8dae-8e8d251e9994', '06797268-08ef-444e-8d46-689b3561d15b', 'dbf1c78c-8843-4899-8190-97c562a1fd91', '4dd02f89-019b-45c3-9940-0cb9e04573bf', 'b793abbc-ed45-48ee-9e70-e573651c67e5', '6925ef6a-e598-4cea-8de4-f92930d427cf', 'f631f972-005b-43fb-a90b-0544808df0f3', 'ffc2014e-8e99-43de-bb64-d180ab2c31a4', '982cf3e6-88fb-4dfd-ac9b-8baf23e5de3f')
 ;




--#################################################################################################################################
--################################################### PUT IPOP DATA INTO TEMP TABLE ###############################################
--#################################################################################################################################

SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_IP

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('16322ab1-6cbb-45cb-95ad-6dce74d2c64c', 'a23fb734-95d1-432b-97da-2da9c598b1f6')
;



--#################################################################################################################################
--################################## PUT MONEY MANAGEMENT ASSESSMENT DATA INTO TEMP TABLE #########################################
--#################################################################################################################################

SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  CASE WHEN EL.event_definition_id = 'b1c216fd-89b5-4ac3-9dd5-79d4131f7ee8' THEN 'Other' ELSE 'Money' END AS FormType,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_MM

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].gp_requirements GP ON EL.event_log_id = GP.event_log_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE (EL.event_definition_id IN ('4ead36d2-321a-4adf-b59e-c4e5405fdfa2', 'b5de24a9-1f8e-4699-a351-197dc5169fd3', '42ed4379-1893-4daa-9d76-35ebfd9b3136')
  OR (EL.event_definition_id = 'b1c216fd-89b5-4ac3-9dd5-79d4131f7ee8' AND GP.other_description LIKE 'Money%'))
  AND (PI.program_name IS NULL OR PI.program_name IN ('DD Community Habilitation', 'DD Community Habilitation(ISS)', 'DD IRA - Supervised', 'DD Day Habilitation', 'DD IRA - Supportive', 'DD PREVOC', 'DD ICF'))
  
;



--#################################################################################################################################
--######################################### PUT RES HAB ACTION PLANS INTO TEMP TABLE ##############################################
--#################################################################################################################################


SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_ICF

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('98be8edc-de07-eb11-b81b-00505681b967', '99be8edc-de07-eb11-b81b-00505681b967')
ORDER BY EL.people_id, EL.event_definition_id;

 
 

--#################################################################################################################################
--######################################### PUT RES HAB ACTION PLANS INTO TEMP TABLE ##############################################
--#################################################################################################################################

SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_RH

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('3e21c0ae-2fc3-4705-8c16-65d47165b0db', '91ebe2e8-cf9d-4319-b803-cd8e839b933f')
ORDER BY EL.people_id, EL.event_definition_id;




--#################################################################################################################################
--######################################### PUT COM HAB ACTION PLANS INTO TEMP TABLE ##############################################
--#################################################################################################################################

SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_CH

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('e2c90471-103a-459f-b4a5-170bce3dfbb5', 'f14deb6c-8f6e-475d-a8af-fdec178bfa39')
ORDER BY EL.people_id, EL.event_definition_id;



--#################################################################################################################################
--######################################### PUT DAY HAB ACTION PLANS INTO TEMP TABLE ##############################################
--#################################################################################################################################

SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_DH

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('2dcdeebe-cd6a-43a7-932e-e59f623196a7', 'ed7225ef-ae5a-444e-a706-c36cea1ca618')
ORDER BY EL.people_id, EL.event_definition_id;



--#################################################################################################################################
--############################################# PUT PREVOC PLANS INTO TEMP TABLE ##################################################
--#################################################################################################################################

SELECT EL.people_id AS CLIENT_PEOPLE_ID, EL.event_definition_id, PI.program_name AS Program, ED.event_name AS [Plan Name], CAST(EL.actual_date AS DATE) AS [Plan Date], 
  CASE WHEN EL.expiration_date IS NULL THEN DATEADD(MM, 12, CAST(EL.actual_date AS DATE)) ELSE CAST(EL.expiration_date AS DATE) END AS [Expiration Date],
  CASE WHEN P2.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P2.last_name, ', ', P2.first_name) END AS [Approved By],
  CASE WHEN EL.approved_date IS NULL THEN @NullDate ELSE CAST(EL.approved_date AS DATE) END AS [Approved Date],
  CASE WHEN P.last_name IS NULL THEN 'NO DATA' ELSE CONCAT(P.last_name, ', ', P.first_name) END AS Staff,
  ROW_NUMBER() OVER (PARTITION BY EL.people_id ORDER BY EL.actual_date DESC) AS RN
  
INTO #TEMP_DD_DOCUMENTATION_COMPLIANCE_PV

FROM [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_log EL 
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].event_definition ED ON EL.event_definition_id = ED.event_definition_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S ON EL.staff_id = S.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P ON S.people_id = P.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].staff S2 ON EL.approved_by = S2.staff_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].people P2 ON S2.people_id = P2.people_id
  LEFT OUTER JOIN [MYEVOLVNYFRPT.NETSMARTCLOUD.COM].[evolv_cs].[dbo].program_info PI ON EL.program_providing_service = PI.program_info_id
WHERE EL.event_definition_id IN ('d7fdce81-1c13-4fd7-9118-5d83fd616402', '2cae7d46-499a-4e47-b8d8-fc8ea420c799')
ORDER BY EL.people_id, EL.event_definition_id;




--#################################################################################################################################
--############################################################ MAIN QUERY #########################################################
--#################################################################################################################################

SELECT * 

INTO CQI.[NYFNET\David.Bernard].DD_DocumentationCompliance

FROM (

  SELECT DISTINCT CR.CLIENT_PEOPLE_ID, CR.Child AS Client, CR.CIN, CR.Age, 
    CR.Program, CR.[Program Start], CR.[Program End], CR.Region, CR.Facility,
    
    CASE
      WHEN LC.[Plan Date] IS NULL THEN 'Missing'
      WHEN LC.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      ELSE 'Overdue'
    END AS [LCED Status],
    
    COALESCE(LC.[Plan Date], @NullDate) AS [Last LCED], 
    COALESCE(LC.[Expiration Date], @NullDate) AS [LCED Expir.], 
    COALESCE(LC.[Approved By], 'NO DATA') AS [LCED Approved By], 
    COALESCE(LC.[Approved Date], @NullDate) AS [LCED Approved], 
    COALESCE(LC.Staff, 'NO DATA') AS [LCED Staff],
    
    CASE
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation', 'DD ICF') THEN 'N/A'
      WHEN IP.[Plan Date] IS NULL THEN 'Missing'
      WHEN IP.[Expiration Date] > GETDATE() AND IP.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), IP.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN IP.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN DATEDIFF(DD, IP.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [IPOP Status],
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation', 'DD ICF') THEN @NullDate
      ELSE COALESCE(IP.[Plan Date], @NullDate) 
    END AS [Last IPOP], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation', 'DD ICF') THEN @NullDate
      ELSE COALESCE(IP.[Expiration Date], @NullDate) 
    END AS [IPOP Expir.], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation', 'DD ICF') THEN 'N/A'
      ELSE COALESCE(IP.[Approved By], 'NO DATA') 
    END AS [IPOP Approved By], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation', 'DD ICF') THEN @NullDate
      ELSE COALESCE(IP.[Approved Date], @NullDate) 
    END AS [IPOP Approved], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation', 'DD ICF') THEN 'N/A'
      ELSE COALESCE(IP.Staff, 'NO DATA') 
    END AS [IPOP Staff],
    
    CASE
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation') THEN 'N/A'
      WHEN MM.[Plan Date] IS NULL THEN 'Missing'
      WHEN MM.FormType = 'Money' AND MM.[Expiration Date] > GETDATE() AND MM.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), MM.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN MM.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN DATEDIFF(DD, MM.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [Money Mgmt. Status],
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation') THEN @NullDate
      ELSE COALESCE(MM.[Plan Date], @NullDate) 
    END AS [Last Money Mgmt.], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation') THEN @NullDate
      ELSE COALESCE(MM.[Expiration Date], @NullDate) 
    END AS [Money Mgmt. Expir.], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation') THEN 'N/A'
      ELSE COALESCE(MM.[Approved By], 'NO DATA') 
    END AS [Money Mgmt. Approved By], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation') THEN @NullDate
      ELSE COALESCE(MM.[Approved Date], @NullDate) 
    END AS [Money Mgmt. Approved], 
    
    CASE 
      WHEN CR.Program IN ('DD Community Habilitation(ISS)', 'DD Community Habilitation', 'DD Day Habilitation') THEN 'N/A'
      ELSE COALESCE(MM.Staff, 'NO DATA') 
    END AS [Money Mgmt. Staff],
    
    CASE WHEN (LP_SM.[Plan Date] IS NULL OR LP_SM.[Plan Date] < LP_AN.[Plan Date]) THEN 1 ELSE 0 END AS [SM < AN],
    
    LP_SM.[Plan Date] AS [SM LP], LP_AN.[Plan Date] AS [AN LP],
    
    CASE
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN LP_AN.[Plan Date] IS NULL THEN 'Missing'
      WHEN DATEDIFF(MM, GETDATE(), DATEADD(MM, 12, LP_AN.[Plan Date])) BETWEEN 0 AND 5 
        AND (LP_SM.[Plan Date] IS NULL OR LP_SM.[Plan Date] <= LP_AN.[Plan Date]) THEN 'Semi-Annual Due'
      WHEN DATEDIFF(MM, GETDATE(), DATEADD(MM, 12, LP_AN.[Plan Date])) BETWEEN 0 AND 12 THEN 'Compliant'
      WHEN DATEDIFF(DD, LP_AN.[Plan Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [Life Plan Status],
    
    CASE
      WHEN LP_AN.[Plan Date] IS NULL THEN 0
      WHEN CR.[Program End] <> @NullDate THEN 99
      WHEN DATEADD(MM, 12, LP_AN.[Plan Date]) < GETDATE() THEN 0
      ELSE DATEDIFF(MM, GETDATE(), DATEADD(MM, 12, LP_AN.[Plan Date]))
    END AS [Months to Next Annual LP],
    
    COALESCE(LP_AN.[Plan Date], @NullDate) AS [Last Annual Life Plan], 
    CASE WHEN LP_SM.[Plan Date] IS NULL OR LP_AN.[Plan Date] = LP_SM.[Plan Date] THEN @NullDate ELSE LP_SM.[Plan Date] END AS [Last Semi-Annual Life Plan], 
    COALESCE(LP_AN.[Approved By], 'NO DATA') AS [Life Plan Approved By], 
    COALESCE(LP_AN.[Approved Date], @NullDate) AS [Life Plan Approved], 
    COALESCE(LP_AN.Staff, 'NO DATA') AS [Life Plan Staff],
    
    CASE
      WHEN CR.Program <> 'DD PREVOC' THEN 'N/A'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN PV.[Plan Date] IS NULL THEN 'Missing'
      WHEN PV.[Expiration Date] > GETDATE() AND PV.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), PV.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN PV.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN DATEDIFF(DD, PV.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [Prevoc Action Plan Status],
    
   
    COALESCE(PV.[Plan Date], @NullDate) AS [Last Prevoc Action Plan], 
    COALESCE(PV.[Expiration Date], @NullDate) AS [Prevoc Action Plan Expir.], 
    COALESCE(PV.[Approved By], 'NO DATA') AS [Prevoc Action Plan Approved By], 
    COALESCE(PV.[Approved Date], @NullDate) AS [Prevoc Action Plan Approved], 
    COALESCE(PV.Staff, 'NO DATA') AS [Prevoc Action Plan Staff],
    
     
    CASE
      WHEN CR.Program NOT LIKE 'DD ICF%' THEN 'N/A'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN ICF.[Plan Date] IS NULL THEN 'Missing'
      WHEN ICF.[Expiration Date] > GETDATE() AND ICF.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), ICF.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN ICF.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN DATEDIFF(DD, ICF.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [ICF Development Plan Status], 
    
    
    COALESCE(ICF.[Plan Date], @NullDate) AS [Last ICF Development Plan], 
    COALESCE(ICF.[Expiration Date], @NullDate) AS [ICF Development Plan Expir.], 
    COALESCE(ICF.[Approved By], 'NO DATA') AS [ICF Development Plan Approved By], 
    COALESCE(ICF.[Approved Date], @NullDate) AS [ICF Development Plan Approved], 
    COALESCE(ICF.Staff, 'NO DATA') AS [ICF Development Plan Staff],
    
    
    
    CASE
      WHEN CR.Program NOT LIKE 'DD IRA%' THEN 'N/A'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN RH.[Plan Date] IS NULL THEN 'Missing'
      WHEN RH.[Expiration Date] > GETDATE() AND RH.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), RH.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN RH.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN DATEDIFF(DD, RH.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [Res Hab Action Plan Status],
    
    COALESCE(RH.[Plan Date], @NullDate) AS [Last Res Hab Action Plan], 
    COALESCE(RH.[Expiration Date], @NullDate) AS [Res Hab Action Plan Expir.], 
    COALESCE(RH.[Approved By], 'NO DATA') AS [Res Hab Action Plan Approved By], 
    COALESCE(RH.[Approved Date], @NullDate) AS [Res Hab Action Plan Approved], 
    COALESCE(RH.Staff, 'NO DATA') AS [Res Hab Action Plan Staff],
    
    CASE
      WHEN CR.Program NOT LIKE 'DD Community Hab%' THEN 'N/A'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN CH.[Plan Date] IS NULL THEN 'Missing'
      WHEN CH.[Expiration Date] > GETDATE() AND CH.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), CH.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN CH.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN DATEDIFF(DD, CH.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [Com Hab Action Plan Status],
    
    COALESCE(CH.[Plan Date], @NullDate) AS [Last Com Hab Action Plan], 
    COALESCE(CH.[Expiration Date], @NullDate) AS [Com Hab Action Plan Expir.], 
    COALESCE(CH.[Approved By], 'NO DATA') AS [Com Hab Action Plan Approved By], 
    COALESCE(CH.[Approved Date], @NullDate) AS [Com Hab Action Plan Approved], 
    COALESCE(CH.Staff, 'NO DATA') AS [Com Hab Action Plan Staff],
    
    
    CASE
      WHEN CR.Program NOT LIKE 'DD Day Hab%' THEN 'N/A'
      WHEN CR.[Program End] <> @NullDate THEN 'N/A Discharged'
      WHEN DH.[Plan Date] IS NULL THEN 'Missing'
      WHEN DH.[Expiration Date] > GETDATE() AND DH.[Approved By] = 'NO DATA' THEN 'Incomplete'
      WHEN DATEDIFF(MM, GETDATE(), DH.[Expiration Date]) BETWEEN 0 AND 5 THEN 'Compliant < 6 Months'
      WHEN DH.[Expiration Date] > GETDATE() THEN 'Compliant'
      WHEN DATEDIFF(DD, DH.[Expiration Date], GETDATE()) BETWEEN 1 AND 59 THEN 'Overdue < 60 Days'
      ELSE 'Overdue'
    END AS [Day Hab Action Plan Status],
    
    COALESCE(DH.[Plan Date], @NullDate) AS [Last Day Hab Action Plan], 
    COALESCE(DH.[Expiration Date], @NullDate) AS [Day Hab Action Plan Expir.], 
    COALESCE(DH.[Approved By], 'NO DATA') AS [Day Hab Action Plan Approved By], 
    COALESCE(DH.[Approved Date], @NullDate) AS [Day Hab Action Plan Approved], 
    COALESCE(DH.Staff, 'NO DATA') AS [Day Hab Action Plan Staff],
    
    CASE
      WHEN NO.[Plan Date] IS NULL THEN 'Missing'
      ELSE 'Compliant'
    END AS [NOD Status],
    
    COALESCE(NO.[Plan Date], @NullDate) AS [NOD], 
    COALESCE(NO.[Approved By], 'NO DATA') AS [NOD Approved By], 
    COALESCE(NO.[Approved Date], @NullDate) AS [NOD Approved], 
    COALESCE(NO.Staff, 'NO DATA') AS [NOD Staff],
      
    CASE
      WHEN PAP.[Plan Date] IS NULL THEN 'Missing'
      ELSE 'Compliant'
    END AS [Pre-Admis. Packet Status],
    
    COALESCE(PAP.[Plan Date], @NullDate) AS [Pre-Admis. Packet],  
    COALESCE(PAP.[Approved By], 'NO DATA') AS [Pre-Admis. Packet Approved By], 
    COALESCE(PAP.[Approved Date], @NullDate) AS [Pre-Admis. Packet Approved], 
    COALESCE(PAP.Staff, 'NO DATA') AS [Pre-Admis. Packet Staff]
    

  FROM CQI.[NYFNET\David.Bernard].Client_Roster CR 
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE C 
      WHERE C.[Plan Name] = 'Level of Care Eligibility Determination (LCED)' 
        AND C.RN = 1
        
    ) LC ON CR.CLIENT_PEOPLE_ID = LC.CLIENT_PEOPLE_ID
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_IP C 
        WHERE C.RN = 1
        
    ) IP ON CR.CLIENT_PEOPLE_ID = IP.CLIENT_PEOPLE_ID
    
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_MM C 
        WHERE C.RN = 1
        
    ) MM ON CR.CLIENT_PEOPLE_ID = MM.CLIENT_PEOPLE_ID
    
    
    LEFT OUTER JOIN ( 
    
      --ANNUAL OR INITIAL LIFE PLANS
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE C 
      WHERE C.[Plan Name] IN ('DD Life Plan', '(DD) Life Plan', 'Comprehensive Functional Assessment')
        AND C.RN_AN = 1
        
    ) LP_AN ON CR.CLIENT_PEOPLE_ID = LP_AN.CLIENT_PEOPLE_ID
    
    LEFT OUTER JOIN ( 
    
      --SEMI-ANNUAL LIFE PLANS
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE C 
      WHERE C.[Plan Name] IN ('DD Life Plan', '(DD) Life Plan', 'Comprehensive Functional Assessment')
        AND C.RN_SM = 1
        
    ) LP_SM ON CR.CLIENT_PEOPLE_ID = LP_SM.CLIENT_PEOPLE_ID
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_PV C 
      WHERE C.RN = 1
        
    ) PV ON CR.CLIENT_PEOPLE_ID = PV.CLIENT_PEOPLE_ID AND CR.Program = PV.Program
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_RH C 
      WHERE C.RN = 1
        
    ) RH ON CR.CLIENT_PEOPLE_ID = RH.CLIENT_PEOPLE_ID AND CR.Program = RH.Program
   
    
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_ICF C 
      WHERE C.RN = 1
        
    ) ICF ON CR.CLIENT_PEOPLE_ID = ICF.CLIENT_PEOPLE_ID AND CR.Program = ICF.Program
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_CH C 
      WHERE C.RN = 1
        
    ) CH ON CR.CLIENT_PEOPLE_ID = CH.CLIENT_PEOPLE_ID AND CR.Program = CH.Program
      
      
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE_DH C 
      WHERE C.RN = 1
        
    ) DH ON CR.CLIENT_PEOPLE_ID = DH.CLIENT_PEOPLE_ID AND CR.Program = DH.Program
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE C 
      WHERE C.[Plan Name] = 'Notice of Decision (NOD)' 
        AND C.RN = 1
        
    ) NO ON CR.CLIENT_PEOPLE_ID = NO.CLIENT_PEOPLE_ID
    
    
    LEFT OUTER JOIN ( 
    
      SELECT C.* FROM #TEMP_DD_DOCUMENTATION_COMPLIANCE C 
      WHERE C.[Plan Name] = 'Pre Admission Packet' 
        AND C.RN = 1
        
    ) PAP ON CR.CLIENT_PEOPLE_ID = PAP.CLIENT_PEOPLE_ID
    
    
  WHERE CR.Program IN ('DD ICF', 'DD Community Habilitation', 'DD Community Habilitation(ISS)', 'DD IRA - Supervised', 'DD Day Habilitation', 'DD IRA - Supportive', 'DD PREVOC')
    AND CR.[Program End] >= @StartDate
    
) A;
    
    
    


--#################################################################################################################################
--#################################################### DROP TABLES IF THEY EXIST ##################################################
--#################################################################################################################################

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_IP') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_IP
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_MM') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_MM
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_PV') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_PV
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_RH') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_RH
END


IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_DH') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_DH
END

IF(OBJECT_ID('tempdb..#TEMP_DD_DOCUMENTATION_COMPLIANCE_CH') IS NOT NULL)
BEGIN
  DROP TABLE #TEMP_DD_DOCUMENTATION_COMPLIANCE_CH
END
;
GO