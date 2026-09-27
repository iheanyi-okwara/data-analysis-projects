/*
================================================================================
TELECOM NETWORK OUTAGE ANALYTICS
Portfolio-Ready SQL Analysis
Platform: Microsoft SQL Server (T-SQL)

Purpose
-------
This is the clean analytical SQL file to use going forward for the Telecom
Network Outage Analytics project. It replaces the earlier development/workbench
script and is intentionally non-destructive: it does not drop, rebuild, or
overwrite the source tables.

Source tables
-------------
dim_customer_segment
dim_date
dim_root_cause
dim_site
dim_vendor
fact_alarm_log
fact_customer_complaint
fact_maintenance
fact_outage_incident
fact_sla_performance
fact_trouble_ticket

Important metric definitions
----------------------------
1. Total Outages = distinct Incident_ID in fact_outage_incident.
2. Total Downtime = sum of Duration_Minutes.
3. Average Outage Duration / MTTR = average Duration_Minutes.
4. Customer Impact = sum of Customers_Affected across incidents. This is NOT
   presented as unique customers because the same population can be affected
   by more than one incident.
5. Incident SLA Breach Rate uses fact_outage_incident.SLA_Breached.
6. SLA Assessment Compliance uses fact_sla_performance.SLA_Complied and has a
   different denominator from incident-level SLA metrics.
7. Average Time to First Alarm uses MIN(Alarm_Time) for each incident. It avoids
   incorrectly averaging every alarm generated during the same incident.
8. Conventional pre-incident MTTD is not reported because the supplied alarm
   data does not contain alarms before Incident_Start_Time.
================================================================================
*/

SET NOCOUNT ON;

-- ============================================================================
-- 00. SOURCE TABLE CHECKS
-- ============================================================================

SELECT 'dim_customer_segment' AS Table_Name, COUNT(*) AS Row_Count FROM dim_customer_segment
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'dim_root_cause', COUNT(*) FROM dim_root_cause
UNION ALL SELECT 'dim_site', COUNT(*) FROM dim_site
UNION ALL SELECT 'dim_vendor', COUNT(*) FROM dim_vendor
UNION ALL SELECT 'fact_alarm_log', COUNT(*) FROM fact_alarm_log
UNION ALL SELECT 'fact_customer_complaint', COUNT(*) FROM fact_customer_complaint
UNION ALL SELECT 'fact_maintenance', COUNT(*) FROM fact_maintenance
UNION ALL SELECT 'fact_outage_incident', COUNT(*) FROM fact_outage_incident
UNION ALL SELECT 'fact_sla_performance', COUNT(*) FROM fact_sla_performance
UNION ALL SELECT 'fact_trouble_ticket', COUNT(*) FROM fact_trouble_ticket
ORDER BY Table_Name;


-- ============================================================================
-- 01. DATA QUALITY & VALIDATION
-- ============================================================================

-- 01A. Duplicate primary/business IDs
SELECT 'fact_outage_incident.Incident_ID' AS Check_Name, COUNT(*) AS Duplicate_Groups
FROM (
    SELECT Incident_ID FROM fact_outage_incident
    GROUP BY Incident_ID HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'fact_alarm_log.Alarm_ID', COUNT(*)
FROM (
    SELECT Alarm_ID FROM fact_alarm_log
    GROUP BY Alarm_ID HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'fact_customer_complaint.Complaint_ID', COUNT(*)
FROM (
    SELECT Complaint_ID FROM fact_customer_complaint
    GROUP BY Complaint_ID HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'fact_maintenance.Maintenance_ID', COUNT(*)
FROM (
    SELECT Maintenance_ID FROM fact_maintenance
    GROUP BY Maintenance_ID HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'fact_sla_performance.SLA_ID', COUNT(*)
FROM (
    SELECT SLA_ID FROM fact_sla_performance
    GROUP BY SLA_ID HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'fact_trouble_ticket.Ticket_ID', COUNT(*)
FROM (
    SELECT Ticket_ID FROM fact_trouble_ticket
    GROUP BY Ticket_ID HAVING COUNT(*) > 1
) x;

-- 01B. Orphaned foreign keys
SELECT 'Outage -> Site' AS Relationship, COUNT(*) AS Orphan_Rows
FROM fact_outage_incident f
LEFT JOIN dim_site d ON f.Site_ID = d.Site_ID
WHERE d.Site_ID IS NULL
UNION ALL
SELECT 'Outage -> Vendor', COUNT(*)
FROM fact_outage_incident f
LEFT JOIN dim_vendor d ON f.Vendor_ID = d.Vendor_ID
WHERE d.Vendor_ID IS NULL
UNION ALL
SELECT 'Outage -> Root Cause', COUNT(*)
FROM fact_outage_incident f
LEFT JOIN dim_root_cause d ON f.Root_Cause_ID = d.Root_Cause_ID
WHERE d.Root_Cause_ID IS NULL
UNION ALL
SELECT 'Alarm -> Incident', COUNT(*)
FROM fact_alarm_log f
LEFT JOIN fact_outage_incident d ON f.Incident_ID = d.Incident_ID
WHERE d.Incident_ID IS NULL
UNION ALL
SELECT 'Alarm -> Site', COUNT(*)
FROM fact_alarm_log f
LEFT JOIN dim_site d ON f.Site_ID = d.Site_ID
WHERE d.Site_ID IS NULL
UNION ALL
SELECT 'Complaint -> Incident', COUNT(*)
FROM fact_customer_complaint f
LEFT JOIN fact_outage_incident d ON f.Incident_ID = d.Incident_ID
WHERE d.Incident_ID IS NULL
UNION ALL
SELECT 'Complaint -> Customer', COUNT(*)
FROM fact_customer_complaint f
LEFT JOIN dim_customer_segment d ON f.Customer_ID = d.Customer_ID
WHERE d.Customer_ID IS NULL
UNION ALL
SELECT 'Maintenance -> Site', COUNT(*)
FROM fact_maintenance f
LEFT JOIN dim_site d ON f.Site_ID = d.Site_ID
WHERE d.Site_ID IS NULL
UNION ALL
SELECT 'Maintenance -> Vendor', COUNT(*)
FROM fact_maintenance f
LEFT JOIN dim_vendor d ON f.Vendor_ID = d.Vendor_ID
WHERE d.Vendor_ID IS NULL
UNION ALL
SELECT 'SLA -> Incident', COUNT(*)
FROM fact_sla_performance f
LEFT JOIN fact_outage_incident d ON f.Incident_ID = d.Incident_ID
WHERE d.Incident_ID IS NULL
UNION ALL
SELECT 'Ticket -> Incident', COUNT(*)
FROM fact_trouble_ticket f
LEFT JOIN fact_outage_incident d ON f.Incident_ID = d.Incident_ID
WHERE d.Incident_ID IS NULL;

-- 01C. Validate stored outage duration against timestamps
SELECT
    COUNT(*) AS Duration_Mismatch_Rows
FROM fact_outage_incident
WHERE Duration_Minutes <>
      DATEDIFF(MINUTE, Incident_Start_Time, Incident_End_Time);

-- 01D. Invalid outage chronology
SELECT
    COUNT(*) AS Invalid_Outage_Time_Rows
FROM fact_outage_incident
WHERE Incident_End_Time < Incident_Start_Time;

-- 01E. Source date coverage versus date dimension coverage
SELECT
    MIN(CAST(Incident_Start_Time AS date)) AS Min_Incident_Date,
    MAX(CAST(Incident_Start_Time AS date)) AS Max_Incident_Date,
    (SELECT MIN(Full_Date) FROM dim_date) AS Min_Dim_Date,
    (SELECT MAX(Full_Date) FROM dim_date) AS Max_Dim_Date
FROM fact_outage_incident;

-- Incidents whose start date is not represented in dim_date
SELECT
    COUNT(*) AS Incident_Dates_Missing_From_Dim_Date
FROM fact_outage_incident o
LEFT JOIN dim_date d
    ON CAST(o.Incident_Start_Time AS date) = CAST(d.Full_Date AS date)
WHERE d.Date_ID IS NULL;

-- 01F. SLA coverage
SELECT
    COUNT(DISTINCT o.Incident_ID) AS Total_Incidents,
    COUNT(DISTINCT s.Incident_ID) AS Incidents_With_SLA_Assessment,
    COUNT(DISTINCT o.Incident_ID) - COUNT(DISTINCT s.Incident_ID)
        AS Incidents_Without_SLA_Assessment
FROM fact_outage_incident o
LEFT JOIN fact_sla_performance s
    ON o.Incident_ID = s.Incident_ID;

-- 01G. SLA violation reason completeness
SELECT
    SUM(CASE WHEN SLA_Complied = 0 THEN 1 ELSE 0 END) AS Non_Compliant_Assessments,
    SUM(CASE WHEN SLA_Complied = 0
              AND NULLIF(LTRIM(RTRIM(Violation_Reason)), '') IS NULL
             THEN 1 ELSE 0 END) AS Non_Compliant_Missing_Violation_Reason
FROM fact_sla_performance;

-- 01H. Alarm timing diagnostic
SELECT
    SUM(CASE WHEN a.Alarm_Time < o.Incident_Start_Time THEN 1 ELSE 0 END)
        AS Pre_Incident_Alarms,
    SUM(CASE WHEN a.Alarm_Time >= o.Incident_Start_Time THEN 1 ELSE 0 END)
        AS Alarms_At_Or_After_Incident_Start
FROM fact_alarm_log a
JOIN fact_outage_incident o
    ON a.Incident_ID = o.Incident_ID;


-- ============================================================================
-- 02. EXECUTIVE KPI SUMMARY
-- ============================================================================

;WITH FirstAlarm AS (
    SELECT
        Incident_ID,
        MIN(Alarm_Time) AS First_Alarm_Time
    FROM fact_alarm_log
    GROUP BY Incident_ID
),
OutageKPI AS (
    SELECT
        COUNT(DISTINCT Incident_ID) AS Total_Outages,
        SUM(CAST(Duration_Minutes AS bigint)) AS Total_Downtime_Minutes,
        AVG(CAST(Duration_Minutes AS decimal(18,2))) AS Avg_Outage_Duration_Minutes,
        SUM(CAST(Customers_Affected AS bigint)) AS Customer_Impact,
        SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breached_Outages,
        SUM(CASE WHEN Is_Resolved_Within_SLA = 1 THEN 1 ELSE 0 END)
            AS Outages_Resolved_Within_SLA,
        AVG(CAST(Business_Impact_Score AS decimal(18,2))) AS Avg_Business_Impact_Score
    FROM fact_outage_incident
),
AlarmKPI AS (
    SELECT
        COUNT(*) AS Total_Alarms,
        COUNT(DISTINCT Incident_ID) AS Incidents_With_Alarms,
        SUM(CASE WHEN Auto_Resolved = 1 THEN 1 ELSE 0 END) AS Auto_Resolved_Alarms
    FROM fact_alarm_log
),
FirstAlarmKPI AS (
    SELECT
        COUNT(*) AS Incidents_With_First_Alarm,
        AVG(CAST(DATEDIFF(SECOND, o.Incident_Start_Time, fa.First_Alarm_Time)
            AS decimal(18,2))) / 60.0 AS Avg_Time_To_First_Alarm_Minutes
    FROM FirstAlarm fa
    JOIN fact_outage_incident o
        ON fa.Incident_ID = o.Incident_ID
    WHERE fa.First_Alarm_Time >= o.Incident_Start_Time
),
TicketKPI AS (
    SELECT
        COUNT(*) AS Total_Tickets,
        SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END) AS Escalated_Tickets,
        AVG(CAST(DATEDIFF(SECOND, Ticket_Created_Time, Ticket_Resolved_Time)
            AS decimal(18,2))) / 60.0 AS Avg_Ticket_Resolution_Minutes
    FROM fact_trouble_ticket
),
ComplaintKPI AS (
    SELECT
        COUNT(*) AS Total_Complaints,
        SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END) AS Resolved_Complaints,
        SUM(CAST(Compensation_Amount AS decimal(18,2))) AS Total_Compensation_GBP
    FROM fact_customer_complaint
),
MaintenanceKPI AS (
    SELECT
        COUNT(*) AS Total_Maintenance_Records,
        SUM(CASE WHEN Is_Completed = 1 THEN 1 ELSE 0 END) AS Completed_Maintenance,
        SUM(CAST(Cost_GBP AS decimal(18,2))) AS Total_Maintenance_Cost_GBP
    FROM fact_maintenance
)
SELECT
    o.Total_Outages,
    o.Total_Downtime_Minutes,
    CAST(o.Total_Downtime_Minutes / 60.0 AS decimal(18,2)) AS Total_Downtime_Hours,
    CAST(o.Avg_Outage_Duration_Minutes AS decimal(18,2)) AS MTTR_Minutes,
    o.Customer_Impact,
    o.SLA_Breached_Outages,
    CAST(100.0 * o.SLA_Breached_Outages / NULLIF(o.Total_Outages,0)
        AS decimal(10,2)) AS Incident_SLA_Breach_Rate_Pct,
    o.Outages_Resolved_Within_SLA,
    CAST(100.0 * o.Outages_Resolved_Within_SLA / NULLIF(o.Total_Outages,0)
        AS decimal(10,2)) AS Incident_SLA_Resolution_Rate_Pct,
    CAST(o.Avg_Business_Impact_Score AS decimal(18,2)) AS Avg_Business_Impact_Score,
    a.Total_Alarms,
    a.Incidents_With_Alarms,
    a.Auto_Resolved_Alarms,
    CAST(100.0 * a.Auto_Resolved_Alarms / NULLIF(a.Total_Alarms,0)
        AS decimal(10,2)) AS Alarm_Auto_Resolution_Rate_Pct,
    CAST(fa.Avg_Time_To_First_Alarm_Minutes AS decimal(18,2))
        AS Avg_Time_To_First_Alarm_Minutes,
    t.Total_Tickets,
    t.Escalated_Tickets,
    CAST(100.0 * t.Escalated_Tickets / NULLIF(t.Total_Tickets,0)
        AS decimal(10,2)) AS Ticket_Escalation_Rate_Pct,
    CAST(t.Avg_Ticket_Resolution_Minutes AS decimal(18,2))
        AS Avg_Ticket_Resolution_Minutes,
    c.Total_Complaints,
    c.Resolved_Complaints,
    CAST(100.0 * c.Resolved_Complaints / NULLIF(c.Total_Complaints,0)
        AS decimal(10,2)) AS Complaint_Resolution_Rate_Pct,
    c.Total_Compensation_GBP,
    m.Total_Maintenance_Records,
    m.Completed_Maintenance,
    m.Total_Maintenance_Cost_GBP
FROM OutageKPI o
CROSS JOIN AlarmKPI a
CROSS JOIN FirstAlarmKPI fa
CROSS JOIN TicketKPI t
CROSS JOIN ComplaintKPI c
CROSS JOIN MaintenanceKPI m;


-- ============================================================================
-- 03. OUTAGE TREND ANALYSIS
-- ============================================================================

-- 03A. Monthly outage trend
SELECT
    DATEFROMPARTS(YEAR(Incident_Start_Time), MONTH(Incident_Start_Time), 1)
        AS Month_Start,
    COUNT(*) AS Total_Outages,
    SUM(Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(Customers_Affected) AS Customer_Impact,
    SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breaches,
    CAST(100.0 * SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Breach_Rate_Pct
FROM fact_outage_incident
GROUP BY
    DATEFROMPARTS(YEAR(Incident_Start_Time), MONTH(Incident_Start_Time), 1)
ORDER BY Month_Start;

-- 03B. Outages by severity
SELECT
    Severity_Level,
    COUNT(*) AS Total_Outages,
    SUM(Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(Customers_Affected) AS Customer_Impact,
    CAST(AVG(CAST(Business_Impact_Score AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Business_Impact_Score
FROM fact_outage_incident
GROUP BY Severity_Level
ORDER BY Total_Outages DESC;

-- 03C. Outages by element type
SELECT
    Element_Type,
    COUNT(*) AS Total_Outages,
    SUM(Duration_Minutes) AS Total_Downtime_Minutes,
    SUM(Customers_Affected) AS Customer_Impact,
    CAST(AVG(CAST(Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes
FROM fact_outage_incident
GROUP BY Element_Type
ORDER BY Total_Outages DESC;


-- ============================================================================
-- 04. ROOT CAUSE ANALYSIS
-- ============================================================================

SELECT
    r.Root_Cause_Category,
    r.Root_Cause_Description,
    r.Responsible_Team,
    COUNT(*) AS Total_Outages,
    SUM(o.Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(o.Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(o.Customers_Affected) AS Customer_Impact,
    SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breaches,
    CAST(100.0 * SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Breach_Rate_Pct,
    CAST(AVG(CAST(o.Business_Impact_Score AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Business_Impact_Score
FROM fact_outage_incident o
JOIN dim_root_cause r
    ON o.Root_Cause_ID = r.Root_Cause_ID
GROUP BY
    r.Root_Cause_Category,
    r.Root_Cause_Description,
    r.Responsible_Team
ORDER BY Total_Outages DESC;


-- ============================================================================
-- 05. SITE, REGION & TECHNOLOGY PERFORMANCE
-- ============================================================================

-- 05A. Regional performance
SELECT
    s.Region,
    COUNT(*) AS Total_Outages,
    SUM(o.Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(o.Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(o.Customers_Affected) AS Customer_Impact,
    SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breaches,
    CAST(100.0 * SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Breach_Rate_Pct
FROM fact_outage_incident o
JOIN dim_site s
    ON o.Site_ID = s.Site_ID
GROUP BY s.Region
ORDER BY Total_Outages DESC;

-- 05B. Technology performance
SELECT
    s.Technology,
    COUNT(*) AS Total_Outages,
    SUM(o.Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(o.Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(o.Customers_Affected) AS Customer_Impact
FROM fact_outage_incident o
JOIN dim_site s
    ON o.Site_ID = s.Site_ID
GROUP BY s.Technology
ORDER BY Total_Outages DESC;

-- 05C. Top 10 sites by outage count
SELECT TOP (10)
    s.Site_ID,
    s.Site_Name,
    s.Region,
    s.Technology,
    s.Site_Type,
    COUNT(*) AS Total_Outages,
    SUM(o.Duration_Minutes) AS Total_Downtime_Minutes,
    SUM(o.Customers_Affected) AS Customer_Impact,
    SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breaches
FROM fact_outage_incident o
JOIN dim_site s
    ON o.Site_ID = s.Site_ID
GROUP BY
    s.Site_ID, s.Site_Name, s.Region, s.Technology, s.Site_Type
ORDER BY Total_Outages DESC, Total_Downtime_Minutes DESC;

-- 05D. Top 10 sites by downtime
SELECT TOP (10)
    s.Site_ID,
    s.Site_Name,
    s.Region,
    s.Technology,
    COUNT(*) AS Total_Outages,
    SUM(o.Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(o.Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(o.Customers_Affected) AS Customer_Impact
FROM fact_outage_incident o
JOIN dim_site s
    ON o.Site_ID = s.Site_ID
GROUP BY s.Site_ID, s.Site_Name, s.Region, s.Technology
ORDER BY Total_Downtime_Minutes DESC;


-- ============================================================================
-- 06. VENDOR PERFORMANCE
-- ============================================================================

SELECT
    v.Vendor_Name,
    v.Vendor_Type,
    v.Reliability_Score,
    v.Failure_Rate,
    v.Contract_Status,
    COUNT(*) AS Total_Outages,
    SUM(o.Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(o.Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(o.Customers_Affected) AS Customer_Impact,
    SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breaches,
    CAST(100.0 * SUM(CASE WHEN o.SLA_Breached = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Breach_Rate_Pct,
    CAST(AVG(CAST(o.Business_Impact_Score AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Business_Impact_Score
FROM fact_outage_incident o
JOIN dim_vendor v
    ON o.Vendor_ID = v.Vendor_ID
GROUP BY
    v.Vendor_Name,
    v.Vendor_Type,
    v.Reliability_Score,
    v.Failure_Rate,
    v.Contract_Status
ORDER BY Total_Outages DESC;


-- ============================================================================
-- 07. ALARM & DETECTION ANALYSIS
-- ============================================================================

-- 07A. Alarm overview
SELECT
    COUNT(*) AS Total_Alarms,
    COUNT(DISTINCT Incident_ID) AS Incidents_With_Alarms,
    CAST(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT Incident_ID),0)
        AS decimal(18,2)) AS Avg_Alarms_Per_Alarmed_Incident,
    SUM(CASE WHEN Auto_Resolved = 1 THEN 1 ELSE 0 END) AS Auto_Resolved_Alarms,
    CAST(100.0 * SUM(CASE WHEN Auto_Resolved = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Auto_Resolution_Rate_Pct
FROM fact_alarm_log;

-- 07B. Average time from incident start to FIRST alarm
;WITH FirstAlarm AS (
    SELECT
        Incident_ID,
        MIN(Alarm_Time) AS First_Alarm_Time
    FROM fact_alarm_log
    GROUP BY Incident_ID
)
SELECT
    COUNT(*) AS Incidents_In_Metric,
    CAST(AVG(CAST(DATEDIFF(SECOND, o.Incident_Start_Time, fa.First_Alarm_Time)
        AS decimal(18,2))) / 60.0 AS decimal(18,2))
        AS Avg_Time_To_First_Alarm_Minutes
FROM FirstAlarm fa
JOIN fact_outage_incident o
    ON fa.Incident_ID = o.Incident_ID
WHERE fa.First_Alarm_Time >= o.Incident_Start_Time;

-- 07C. Alarm type and severity
SELECT
    Alarm_Type,
    Alarm_Severity,
    COUNT(*) AS Alarm_Count,
    SUM(CASE WHEN Auto_Resolved = 1 THEN 1 ELSE 0 END) AS Auto_Resolved,
    CAST(100.0 * SUM(CASE WHEN Auto_Resolved = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Auto_Resolution_Rate_Pct
FROM fact_alarm_log
GROUP BY Alarm_Type, Alarm_Severity
ORDER BY Alarm_Count DESC;

-- 07D. Alarm severity summary
SELECT
    Alarm_Severity,
    COUNT(*) AS Alarm_Count,
    COUNT(DISTINCT Incident_ID) AS Incidents,
    CAST(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM fact_alarm_log),0)
        AS decimal(10,2)) AS Share_Of_Alarms_Pct
FROM fact_alarm_log
GROUP BY Alarm_Severity
ORDER BY Alarm_Count DESC;

-- 07E. Incidents without any alarm record
SELECT
    COUNT(*) AS Incidents_Without_Alarm
FROM fact_outage_incident o
LEFT JOIN fact_alarm_log a
    ON o.Incident_ID = a.Incident_ID
WHERE a.Incident_ID IS NULL;


-- ============================================================================
-- 08. SLA PERFORMANCE
-- ============================================================================

-- IMPORTANT:
-- The next two analyses answer different questions.
-- 08A = incident-level SLA flag across all outage incidents.
-- 08B = formal SLA assessment records only.

-- 08A. Incident-level SLA performance
SELECT
    COUNT(*) AS Total_Incidents,
    SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breached_Incidents,
    SUM(CASE WHEN SLA_Breached = 0 THEN 1 ELSE 0 END) AS Non_Breached_Incidents,
    CAST(100.0 * SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Breach_Rate_Pct,
    SUM(CASE WHEN Is_Resolved_Within_SLA = 1 THEN 1 ELSE 0 END)
        AS Resolved_Within_SLA,
    CAST(100.0 * SUM(CASE WHEN Is_Resolved_Within_SLA = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Resolution_Within_SLA_Rate_Pct
FROM fact_outage_incident;

-- 08B. Formal SLA assessment performance
SELECT
    COUNT(*) AS SLA_Assessments,
    SUM(CASE WHEN SLA_Complied = 1 THEN 1 ELSE 0 END) AS Compliant_Assessments,
    SUM(CASE WHEN SLA_Complied = 0 THEN 1 ELSE 0 END) AS Non_Compliant_Assessments,
    CAST(100.0 * SUM(CASE WHEN SLA_Complied = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Compliance_Rate_Pct,
    CAST(AVG(CAST(Actual_Response_Time AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Response_Time_Minutes,
    CAST(AVG(CAST(Actual_Resolution_Time AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Resolution_Time_Minutes,
    CAST(AVG(CAST(Performance_Score AS decimal(18,4))) AS decimal(18,4))
        AS Avg_Performance_Score
FROM fact_sla_performance;

-- 08C. SLA performance by SLA type
SELECT
    SLA_Type,
    COUNT(*) AS SLA_Assessments,
    CAST(AVG(CAST(SLA_Target_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Target_Minutes,
    CAST(AVG(CAST(Actual_Response_Time AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Response_Time_Minutes,
    CAST(AVG(CAST(Actual_Resolution_Time AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Resolution_Time_Minutes,
    SUM(CASE WHEN SLA_Complied = 1 THEN 1 ELSE 0 END) AS Compliant,
    SUM(CASE WHEN SLA_Complied = 0 THEN 1 ELSE 0 END) AS Non_Compliant,
    CAST(100.0 * SUM(CASE WHEN SLA_Complied = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Compliance_Rate_Pct
FROM fact_sla_performance
GROUP BY SLA_Type
ORDER BY SLA_Assessments DESC;

-- 08D. Violation reasons (non-compliant assessments only)
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(Violation_Reason)), ''),
             'Reason Not Recorded') AS Violation_Reason,
    COUNT(*) AS Violation_Count
FROM fact_sla_performance
WHERE SLA_Complied = 0
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM(Violation_Reason)), ''),
                  'Reason Not Recorded')
ORDER BY Violation_Count DESC;


-- ============================================================================
-- 09. CUSTOMER IMPACT & COMPLAINT ANALYSIS
-- ============================================================================

-- 09A. Complaint overview
SELECT
    COUNT(*) AS Total_Complaints,
    SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END) AS Resolved_Complaints,
    SUM(CASE WHEN Is_Resolved = 0 THEN 1 ELSE 0 END) AS Unresolved_Complaints,
    CAST(100.0 * SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Complaint_Resolution_Rate_Pct,
    SUM(CAST(Compensation_Amount AS decimal(18,2))) AS Total_Compensation_GBP,
    CAST(AVG(CAST(Compensation_Amount AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Compensation_GBP
FROM fact_customer_complaint;

-- 09B. Complaints by customer segment
SELECT
    c.Customer_Segment,
    COUNT(*) AS Total_Complaints,
    SUM(CASE WHEN fc.Is_Resolved = 1 THEN 1 ELSE 0 END) AS Resolved_Complaints,
    CAST(100.0 * SUM(CASE WHEN fc.Is_Resolved = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Resolution_Rate_Pct,
    SUM(CAST(fc.Compensation_Amount AS decimal(18,2))) AS Compensation_GBP,
    CAST(AVG(CAST(c.Churn_Risk_Score AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Churn_Risk_Score
FROM fact_customer_complaint fc
JOIN dim_customer_segment c
    ON fc.Customer_ID = c.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY Total_Complaints DESC;

-- 09C. Complaints by channel
SELECT
    Complaint_Channel,
    COUNT(*) AS Total_Complaints,
    SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END) AS Resolved_Complaints,
    SUM(CAST(Compensation_Amount AS decimal(18,2))) AS Compensation_GBP
FROM fact_customer_complaint
GROUP BY Complaint_Channel
ORDER BY Total_Complaints DESC;

-- 09D. Complaints by severity
SELECT
    Complaint_Severity,
    COUNT(*) AS Total_Complaints,
    SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END) AS Resolved_Complaints,
    CAST(100.0 * SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Resolution_Rate_Pct,
    SUM(CAST(Compensation_Amount AS decimal(18,2))) AS Compensation_GBP
FROM fact_customer_complaint
GROUP BY Complaint_Severity
ORDER BY Total_Complaints DESC;

-- 09E. Root causes associated with complaints
SELECT
    r.Root_Cause_Category,
    COUNT(*) AS Complaint_Count,
    COUNT(DISTINCT c.Incident_ID) AS Incidents_With_Complaints,
    SUM(CAST(c.Compensation_Amount AS decimal(18,2))) AS Compensation_GBP
FROM fact_customer_complaint c
JOIN fact_outage_incident o
    ON c.Incident_ID = o.Incident_ID
JOIN dim_root_cause r
    ON o.Root_Cause_ID = r.Root_Cause_ID
GROUP BY r.Root_Cause_Category
ORDER BY Complaint_Count DESC;


-- ============================================================================
-- 10. TROUBLE TICKET ANALYSIS
-- ============================================================================

-- 10A. Ticket overview
SELECT
    COUNT(*) AS Total_Tickets,
    SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END) AS Escalated_Tickets,
    CAST(100.0 * SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Escalation_Rate_Pct,
    CAST(AVG(CAST(DATEDIFF(SECOND, Ticket_Created_Time, Ticket_Resolved_Time)
        AS decimal(18,2))) / 60.0 AS decimal(18,2))
        AS Avg_Ticket_Resolution_Minutes
FROM fact_trouble_ticket;

-- 10B. Ticket performance by priority
SELECT
    Priority,
    COUNT(*) AS Total_Tickets,
    SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END) AS Escalated_Tickets,
    CAST(100.0 * SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Escalation_Rate_Pct,
    CAST(AVG(CAST(DATEDIFF(SECOND, Ticket_Created_Time, Ticket_Resolved_Time)
        AS decimal(18,2))) / 60.0 AS decimal(18,2))
        AS Avg_Resolution_Minutes
FROM fact_trouble_ticket
GROUP BY Priority
ORDER BY Total_Tickets DESC;

-- 10C. Ticket performance by assigned team
SELECT
    Assigned_Team,
    COUNT(*) AS Total_Tickets,
    SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END) AS Escalated_Tickets,
    CAST(100.0 * SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Escalation_Rate_Pct,
    CAST(AVG(CAST(DATEDIFF(SECOND, Ticket_Created_Time, Ticket_Resolved_Time)
        AS decimal(18,2))) / 60.0 AS decimal(18,2))
        AS Avg_Resolution_Minutes
FROM fact_trouble_ticket
GROUP BY Assigned_Team
ORDER BY Total_Tickets DESC;

-- 10D. Ticket category
SELECT
    Ticket_Category,
    COUNT(*) AS Total_Tickets,
    SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END) AS Escalated_Tickets
FROM fact_trouble_ticket
GROUP BY Ticket_Category
ORDER BY Total_Tickets DESC;


-- ============================================================================
-- 11. MAINTENANCE ANALYSIS
-- ============================================================================

-- 11A. Maintenance overview
SELECT
    COUNT(*) AS Maintenance_Records,
    SUM(CASE WHEN Is_Completed = 1 THEN 1 ELSE 0 END) AS Completed_Maintenance,
    CAST(100.0 * SUM(CASE WHEN Is_Completed = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Completion_Rate_Pct,
    CAST(SUM(CAST(Duration_Hours AS decimal(18,2))) AS decimal(18,2))
        AS Total_Maintenance_Hours,
    SUM(CAST(Cost_GBP AS decimal(18,2))) AS Total_Maintenance_Cost_GBP,
    CAST(AVG(CAST(Cost_GBP AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Maintenance_Cost_GBP
FROM fact_maintenance;

-- 11B. Maintenance by type
SELECT
    Maintenance_Type,
    COUNT(*) AS Maintenance_Records,
    SUM(CASE WHEN Is_Completed = 1 THEN 1 ELSE 0 END) AS Completed,
    CAST(SUM(CAST(Duration_Hours AS decimal(18,2))) AS decimal(18,2))
        AS Maintenance_Hours,
    SUM(CAST(Cost_GBP AS decimal(18,2))) AS Maintenance_Cost_GBP
FROM fact_maintenance
GROUP BY Maintenance_Type
ORDER BY Maintenance_Records DESC;

-- 11C. Maintenance by vendor
SELECT
    v.Vendor_Name,
    COUNT(*) AS Maintenance_Records,
    SUM(CASE WHEN m.Is_Completed = 1 THEN 1 ELSE 0 END) AS Completed,
    CAST(SUM(CAST(m.Duration_Hours AS decimal(18,2))) AS decimal(18,2))
        AS Maintenance_Hours,
    SUM(CAST(m.Cost_GBP AS decimal(18,2))) AS Maintenance_Cost_GBP
FROM fact_maintenance m
JOIN dim_vendor v
    ON m.Vendor_ID = v.Vendor_ID
GROUP BY v.Vendor_Name
ORDER BY Maintenance_Cost_GBP DESC;

-- 11D. Site-level outage and maintenance context
;WITH OutageBySite AS (
    SELECT
        Site_ID,
        COUNT(*) AS Total_Outages,
        SUM(Duration_Minutes) AS Total_Downtime_Minutes,
        SUM(Customers_Affected) AS Customer_Impact
    FROM fact_outage_incident
    GROUP BY Site_ID
),
MaintenanceBySite AS (
    SELECT
        Site_ID,
        COUNT(*) AS Maintenance_Records,
        SUM(CAST(Cost_GBP AS decimal(18,2))) AS Maintenance_Cost_GBP
    FROM fact_maintenance
    GROUP BY Site_ID
)
SELECT
    s.Site_ID,
    s.Site_Name,
    s.Region,
    s.Technology,
    COALESCE(o.Total_Outages,0) AS Total_Outages,
    COALESCE(o.Total_Downtime_Minutes,0) AS Total_Downtime_Minutes,
    COALESCE(o.Customer_Impact,0) AS Customer_Impact,
    COALESCE(m.Maintenance_Records,0) AS Maintenance_Records,
    COALESCE(m.Maintenance_Cost_GBP,0) AS Maintenance_Cost_GBP
FROM dim_site s
LEFT JOIN OutageBySite o ON s.Site_ID = o.Site_ID
LEFT JOIN MaintenanceBySite m ON s.Site_ID = m.Site_ID
ORDER BY Total_Outages DESC, Total_Downtime_Minutes DESC;


-- ============================================================================
-- 12. MANAGEMENT / POWER BI ANALYTICAL DATASET
-- ============================================================================

-- One row per outage incident, enriched with dimensions and incident-level
-- counts. This is useful for validation, export, or as a reference dataset.
-- Aggregated child tables are joined first to prevent row multiplication.

;WITH AlarmAgg AS (
    SELECT
        Incident_ID,
        COUNT(*) AS Actual_Alarm_Count,
        MIN(Alarm_Time) AS First_Alarm_Time,
        SUM(CASE WHEN Auto_Resolved = 1 THEN 1 ELSE 0 END)
            AS Auto_Resolved_Alarm_Count
    FROM fact_alarm_log
    GROUP BY Incident_ID
),
TicketAgg AS (
    SELECT
        Incident_ID,
        COUNT(*) AS Ticket_Count,
        SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END)
            AS Escalated_Ticket_Count,
        AVG(CAST(DATEDIFF(SECOND, Ticket_Created_Time, Ticket_Resolved_Time)
            AS decimal(18,2))) / 60.0 AS Avg_Ticket_Resolution_Minutes
    FROM fact_trouble_ticket
    GROUP BY Incident_ID
),
ComplaintAgg AS (
    SELECT
        Incident_ID,
        COUNT(*) AS Complaint_Count,
        SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END)
            AS Resolved_Complaint_Count,
        SUM(CAST(Compensation_Amount AS decimal(18,2)))
            AS Compensation_GBP
    FROM fact_customer_complaint
    GROUP BY Incident_ID
),
SLAAgg AS (
    SELECT
        Incident_ID,
        COUNT(*) AS SLA_Assessment_Count,
        SUM(CASE WHEN SLA_Complied = 1 THEN 1 ELSE 0 END)
            AS SLA_Compliant_Assessment_Count,
        SUM(CASE WHEN SLA_Complied = 0 THEN 1 ELSE 0 END)
            AS SLA_Non_Compliant_Assessment_Count,
        AVG(CAST(Actual_Response_Time AS decimal(18,2)))
            AS Avg_SLA_Response_Time_Minutes,
        AVG(CAST(Actual_Resolution_Time AS decimal(18,2)))
            AS Avg_SLA_Resolution_Time_Minutes
    FROM fact_sla_performance
    GROUP BY Incident_ID
)
SELECT
    o.Incident_ID,
    CAST(o.Incident_Start_Time AS date) AS Incident_Date,
    o.Incident_Start_Time,
    o.Incident_End_Time,
    o.Duration_Minutes,
    o.Severity_Level,
    o.Element_ID,
    o.Element_Type,
    o.Customers_Affected,
    o.SLA_Breached,
    o.Is_Resolved_Within_SLA,
    o.Business_Impact_Score,

    s.Site_ID,
    s.Site_Name,
    s.Site_Type,
    s.Region,
    s.Technology,
    s.Customers_Served,
    s.Is_Active,

    v.Vendor_ID,
    v.Vendor_Name,
    v.Reliability_Score,
    v.Failure_Rate,
    v.Contract_Status,

    r.Root_Cause_ID,
    r.Root_Cause_Category,
    r.Responsible_Team,

    COALESCE(a.Actual_Alarm_Count,0) AS Actual_Alarm_Count,
    a.First_Alarm_Time,
    CASE
        WHEN a.First_Alarm_Time >= o.Incident_Start_Time
        THEN CAST(DATEDIFF(SECOND, o.Incident_Start_Time, a.First_Alarm_Time)
             / 60.0 AS decimal(18,2))
        ELSE NULL
    END AS Time_To_First_Alarm_Minutes,
    COALESCE(a.Auto_Resolved_Alarm_Count,0) AS Auto_Resolved_Alarm_Count,

    COALESCE(t.Ticket_Count,0) AS Ticket_Count,
    COALESCE(t.Escalated_Ticket_Count,0) AS Escalated_Ticket_Count,
    CAST(t.Avg_Ticket_Resolution_Minutes AS decimal(18,2))
        AS Avg_Ticket_Resolution_Minutes,

    COALESCE(c.Complaint_Count,0) AS Complaint_Count,
    COALESCE(c.Resolved_Complaint_Count,0) AS Resolved_Complaint_Count,
    COALESCE(c.Compensation_GBP,0) AS Compensation_GBP,

    COALESCE(sl.SLA_Assessment_Count,0) AS SLA_Assessment_Count,
    COALESCE(sl.SLA_Compliant_Assessment_Count,0)
        AS SLA_Compliant_Assessment_Count,
    COALESCE(sl.SLA_Non_Compliant_Assessment_Count,0)
        AS SLA_Non_Compliant_Assessment_Count,
    CAST(sl.Avg_SLA_Response_Time_Minutes AS decimal(18,2))
        AS Avg_SLA_Response_Time_Minutes,
    CAST(sl.Avg_SLA_Resolution_Time_Minutes AS decimal(18,2))
        AS Avg_SLA_Resolution_Time_Minutes

FROM fact_outage_incident o
LEFT JOIN dim_site s
    ON o.Site_ID = s.Site_ID
LEFT JOIN dim_vendor v
    ON o.Vendor_ID = v.Vendor_ID
LEFT JOIN dim_root_cause r
    ON o.Root_Cause_ID = r.Root_Cause_ID
LEFT JOIN AlarmAgg a
    ON o.Incident_ID = a.Incident_ID
LEFT JOIN TicketAgg t
    ON o.Incident_ID = t.Incident_ID
LEFT JOIN ComplaintAgg c
    ON o.Incident_ID = c.Incident_ID
LEFT JOIN SLAAgg sl
    ON o.Incident_ID = sl.Incident_ID
ORDER BY o.Incident_Start_Time;


-- ============================================================================
-- 13. FINAL VALIDATION QUERIES FOR POWER BI
-- ============================================================================

-- Use these figures to reconcile headline Power BI cards.
SELECT
    COUNT(*) AS Total_Outages,
    SUM(Duration_Minutes) AS Total_Downtime_Minutes,
    CAST(AVG(CAST(Duration_Minutes AS decimal(18,2))) AS decimal(18,2))
        AS Avg_Outage_Duration_Minutes,
    SUM(Customers_Affected) AS Customer_Impact,
    SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END) AS SLA_Breached_Outages,
    CAST(100.0 * SUM(CASE WHEN SLA_Breached = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS SLA_Breach_Rate_Pct,
    SUM(CASE WHEN Is_Resolved_Within_SLA = 1 THEN 1 ELSE 0 END)
        AS Resolved_Within_SLA,
    CAST(100.0 * SUM(CASE WHEN Is_Resolved_Within_SLA = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0) AS decimal(10,2)) AS Resolved_Within_SLA_Rate_Pct
FROM fact_outage_incident;

SELECT
    COUNT(*) AS Total_Alarms,
    COUNT(DISTINCT Incident_ID) AS Incidents_With_Alarms
FROM fact_alarm_log;

;WITH FirstAlarm AS (
    SELECT Incident_ID, MIN(Alarm_Time) AS First_Alarm_Time
    FROM fact_alarm_log
    GROUP BY Incident_ID
)
SELECT
    COUNT(*) AS Incidents_In_First_Alarm_Metric,
    CAST(AVG(CAST(DATEDIFF(SECOND, o.Incident_Start_Time, f.First_Alarm_Time)
        AS decimal(18,2))) / 60.0 AS decimal(18,2))
        AS Avg_Time_To_First_Alarm_Minutes
FROM FirstAlarm f
JOIN fact_outage_incident o
    ON f.Incident_ID = o.Incident_ID
WHERE f.First_Alarm_Time >= o.Incident_Start_Time;

SELECT
    COUNT(*) AS Total_Tickets,
    SUM(CASE WHEN Is_Escalated = 1 THEN 1 ELSE 0 END) AS Escalated_Tickets
FROM fact_trouble_ticket;

SELECT
    COUNT(*) AS Total_Complaints,
    SUM(CASE WHEN Is_Resolved = 1 THEN 1 ELSE 0 END) AS Resolved_Complaints
FROM fact_customer_complaint;

SELECT
    COUNT(*) AS SLA_Assessments,
    SUM(CASE WHEN SLA_Complied = 1 THEN 1 ELSE 0 END) AS Compliant_Assessments,
    SUM(CASE WHEN SLA_Complied = 0 THEN 1 ELSE 0 END) AS Non_Compliant_Assessments
FROM fact_sla_performance;

/*
================================================================================
END OF ANALYSIS

Recommended workflow:
1. Keep the original source tables unchanged.
2. Run Sections 01 and 02 first and confirm the validation/KPI outputs.
3. Use Sections 03-11 for analytical findings.
4. Use Section 12 as the incident-level management dataset/reference.
5. Use Section 13 to reconcile Power BI headline cards before presentation.
================================================================================
*/
