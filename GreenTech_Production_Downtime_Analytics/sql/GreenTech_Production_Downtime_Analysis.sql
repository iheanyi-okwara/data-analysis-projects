/*
===============================================================================
GREENTECH MANUFACTURING ANALYTICS
Production Bottlenecks Through Downtime Analysis
Prepared by: Iheanyi Okwara | Data Analyst

Purpose
-------
This script replaces the original exploratory SQL with a single, portfolio-ready
analysis file. It:
  1. Audits the source tables
  2. Creates reusable analytical views
  3. Validates headline KPIs
  4. Analyses downtime frequency and duration
  5. Analyses products, root causes and operators
  6. Analyses multiple-batch scheduling without implying causation

Source tables
-------------
dbo.downtime_factors
dbo.line_downtime
dbo.line_productivity_batches
dbo.products

Validated dashboard KPIs
------------------------
Total Batches              645
Delayed Batches            363
Delay Rate                 56.3%
Downtime Events            885
Distinct Downtime Factors   13
Days Lost                  21.74

Operator Scheduling page (MultipleBatchPerDay = TRUE)
------------------------------------------------------
Distinct Multiple-Batch Days   51
Distinct Batches               109
Downtime Events                131

Notes
-----
- A "Downtime Event" is one non-null factor occurrence after unpivoting the
  13 factor columns in line_downtime.
- A "Delayed Batch" is a distinct Batch_ID with at least one downtime event.
- Frequency and duration are intentionally analysed separately.
- Multiple-batch scheduling results show association, not proof of causation.
===============================================================================
*/

USE greentech;
GO

SET NOCOUNT ON;
GO

/*=============================================================================
  01. SOURCE DATA AUDIT
=============================================================================*/

-- Source row counts
SELECT 'downtime_factors' AS Table_Name, COUNT(*) AS Row_Count
FROM dbo.downtime_factors
UNION ALL
SELECT 'line_downtime', COUNT(*)
FROM dbo.line_downtime
UNION ALL
SELECT 'line_productivity_batches', COUNT(*)
FROM dbo.line_productivity_batches
UNION ALL
SELECT 'products', COUNT(*)
FROM dbo.products;
GO

-- Duplicate Batch_ID check in production data
SELECT
    Batch_ID,
    COUNT(*) AS Row_Count
FROM dbo.line_productivity_batches
GROUP BY Batch_ID
HAVING COUNT(*) > 1
ORDER BY Row_Count DESC, Batch_ID;
GO

-- Null-factor assessment
SELECT
    COUNT(*) AS Downtime_Source_Rows,
    SUM(CASE WHEN Factor_1 IS NULL THEN 1 ELSE 0 END) AS Factor_1_Nulls,
    SUM(CASE WHEN Factor_2 IS NULL THEN 1 ELSE 0 END) AS Factor_2_Nulls,
    SUM(
        CASE
            WHEN COALESCE(
                Factor_1, Factor_2, Factor_3, Factor_4, Factor_5,
                Factor_6, Factor_7, Factor_8, Factor_9, Factor_10,
                Factor_11, Factor_12, Factor_13
            ) IS NULL THEN 1
            ELSE 0
        END
    ) AS Rows_With_No_Downtime_Factor
FROM dbo.line_downtime;
GO

-- Validate that the production Date agrees with the date portion of Start_Time
SELECT
    Batch_ID,
    [Date] AS Production_Date,
    CAST(Start_Time AS date) AS Start_Time_Date
FROM dbo.line_productivity_batches
WHERE [Date] <> CAST(Start_Time AS date);
GO


/*=============================================================================
  02. ANALYTICAL VIEWS
=============================================================================*/

-- Unpivot the 13 downtime-factor columns into one event-level table.
-- Each returned row represents one downtime factor occurrence for a batch.
CREATE OR ALTER VIEW dbo.downtimes
AS
SELECT
    Batch_ID,
    TRY_CONVERT(int, REPLACE(Factor, 'Factor_', '')) AS Factor_ID,
    Minutes
FROM
(
    SELECT
        Batch_ID,
        Factor_1,
        Factor_2,
        Factor_3,
        Factor_4,
        Factor_5,
        Factor_6,
        Factor_7,
        Factor_8,
        Factor_9,
        Factor_10,
        Factor_11,
        Factor_12,
        Factor_13
    FROM dbo.line_downtime
) AS src
UNPIVOT
(
    Minutes FOR Factor IN
    (
        Factor_1,
        Factor_2,
        Factor_3,
        Factor_4,
        Factor_5,
        Factor_6,
        Factor_7,
        Factor_8,
        Factor_9,
        Factor_10,
        Factor_11,
        Factor_12,
        Factor_13
    )
) AS u;
GO

-- Production-level analytical view.
-- Duration is calculated in minutes first to avoid loss of precision from
-- DATEDIFF(HOUR), then converted to decimal hours.
CREATE OR ALTER VIEW dbo.batch_pd
AS
SELECT
    lpb.[Date] AS Start_Date,
    lpb.Product_ID,
    lpb.Batch_ID,
    lpb.Operator,
    CAST(lpb.Start_Time AS time) AS Start_Time,
    CAST(lpb.End_Time AS date) AS End_Date,
    CAST(lpb.End_Time AS time) AS End_Time,
    lpb.Planned_Min_Batch_Hours,

    DATEDIFF(MINUTE, lpb.Start_Time, lpb.End_Time) AS Actual_Duration_Minutes,

    CAST(
        DATEDIFF(MINUTE, lpb.Start_Time, lpb.End_Time) / 60.0
        AS decimal(10,2)
    ) AS Actual_Duration_Hours,

    CAST(
        (DATEDIFF(MINUTE, lpb.Start_Time, lpb.End_Time) / 60.0)
        - lpb.Planned_Min_Batch_Hours
        AS decimal(10,2)
    ) AS Extra_Time_Hours,

    COUNT(*) OVER
    (
        PARTITION BY lpb.Operator, lpb.[Date]
    ) AS Operator_Batches_Per_Day,

    CASE
        WHEN COUNT(*) OVER
             (PARTITION BY lpb.Operator, lpb.[Date]) > 1
        THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS MultipleBatchPerDay
FROM dbo.line_productivity_batches AS lpb;
GO

-- Enriched downtime event view for reusable analysis.
CREATE OR ALTER VIEW dbo.vw_downtime_analysis
AS
SELECT
    d.Batch_ID,
    d.Factor_ID,
    df.Factor_Name,
    df.Description,
    df.Operator_Error,
    d.Minutes,
    CAST(d.Minutes / 60.0 AS decimal(10,2)) AS Hours,
    CAST(d.Minutes / 1440.0 AS decimal(10,4)) AS Days,
    b.Start_Date,
    b.Start_Time,
    b.End_Time,
    b.Product_ID,
    p.Product_Name,
    b.Operator,
    b.Planned_Min_Batch_Hours,
    b.Actual_Duration_Hours,
    b.Extra_Time_Hours,
    b.Operator_Batches_Per_Day,
    b.MultipleBatchPerDay
FROM dbo.downtimes AS d
INNER JOIN dbo.downtime_factors AS df
    ON d.Factor_ID = df.Factor_ID
INNER JOIN dbo.batch_pd AS b
    ON d.Batch_ID = b.Batch_ID
INNER JOIN dbo.products AS p
    ON b.Product_ID = p.Product_ID;
GO


/*=============================================================================
  03. KPI VALIDATION
=============================================================================*/

-- Portfolio/dashboard headline KPIs
SELECT
    COUNT(DISTINCT b.Batch_ID) AS Total_Batches,
    COUNT(DISTINCT d.Batch_ID) AS Delayed_Batches,
    CAST(
        100.0 * COUNT(DISTINCT d.Batch_ID)
        / NULLIF(COUNT(DISTINCT b.Batch_ID), 0)
        AS decimal(10,1)
    ) AS Delay_Rate_Pct,
    COUNT(d.Factor_ID) AS Downtime_Events,
    COUNT(DISTINCT d.Factor_ID) AS Distinct_Downtime_Factors,
    CAST(SUM(d.Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours,
    CAST(SUM(d.Minutes) / 1440.0 AS decimal(10,2)) AS Days_Lost
FROM dbo.batch_pd AS b
LEFT JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID;
GO

-- Maximum number of downtime factors recorded against a single batch
WITH BatchFactorCounts AS
(
    SELECT
        Batch_ID,
        COUNT(Factor_ID) AS Downtime_Events_Per_Batch
    FROM dbo.downtimes
    GROUP BY Batch_ID
)
SELECT
    MAX(Downtime_Events_Per_Batch) AS Max_Downtime_Events_Per_Batch
FROM BatchFactorCounts;
GO

-- Validate downtime minutes against production overrun at batch level
SELECT
    b.Batch_ID,
    b.Product_ID,
    b.Operator,
    b.Planned_Min_Batch_Hours,
    b.Actual_Duration_Hours,
    b.Extra_Time_Hours,
    SUM(d.Minutes) AS Accounted_Downtime_Minutes,
    CAST(SUM(d.Minutes) / 60.0 AS decimal(10,2)) AS Accounted_Downtime_Hours
FROM dbo.batch_pd AS b
INNER JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID
GROUP BY
    b.Batch_ID,
    b.Product_ID,
    b.Operator,
    b.Planned_Min_Batch_Hours,
    b.Actual_Duration_Hours,
    b.Extra_Time_Hours
ORDER BY b.Batch_ID;
GO


/*=============================================================================
  04. ROOT CAUSE ANALYSIS — FREQUENCY VS IMPACT
=============================================================================*/

-- Downtime events and duration by root cause
SELECT
    Factor_ID,
    Factor_Name,
    COUNT(*) AS Downtime_Events,
    COUNT(DISTINCT Batch_ID) AS Delayed_Batches,
    SUM(Minutes) AS Downtime_Minutes,
    CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours,
    CAST(SUM(Minutes) / 1440.0 AS decimal(10,2)) AS Downtime_Days
FROM dbo.vw_downtime_analysis
GROUP BY
    Factor_ID,
    Factor_Name
ORDER BY Downtime_Events DESC, Downtime_Hours DESC;
GO

-- Operator-related vs non-operator-related causes
SELECT
    CASE
        WHEN Operator_Error = 1 THEN 'Operator-related'
        WHEN Operator_Error = 0 THEN 'Non-operator'
        ELSE 'Unclassified'
    END AS Cause_Type,
    COUNT(*) AS Downtime_Events,
    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()
        AS decimal(10,2)
    ) AS Event_Share_Pct,
    CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours,
    CAST(SUM(Minutes) / 1440.0 AS decimal(10,2)) AS Downtime_Days,
    CAST(
        100.0 * SUM(Minutes) / NULLIF(SUM(SUM(Minutes)) OVER (), 0)
        AS decimal(10,2)
    ) AS Duration_Share_Pct
FROM dbo.vw_downtime_analysis
GROUP BY Operator_Error
ORDER BY Downtime_Events DESC;
GO

-- Operator-related root causes
SELECT
    Factor_Name,
    Description,
    COUNT(*) AS Downtime_Events,
    CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours
FROM dbo.vw_downtime_analysis
WHERE Operator_Error = 1
GROUP BY Factor_Name, Description
ORDER BY Downtime_Hours DESC;
GO

-- Non-operator root causes
SELECT
    Factor_Name,
    Description,
    COUNT(*) AS Downtime_Events,
    CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours
FROM dbo.vw_downtime_analysis
WHERE Operator_Error = 0
GROUP BY Factor_Name, Description
ORDER BY Downtime_Hours DESC;
GO


/*=============================================================================
  05. PRODUCT ANALYSIS
=============================================================================*/

-- Product production volume, delayed batches, event frequency and time lost
SELECT
    b.Product_ID,
    p.Product_Name,
    COUNT(DISTINCT b.Batch_ID) AS Total_Batches,
    COUNT(DISTINCT d.Batch_ID) AS Delayed_Batches,
    CAST(
        100.0 * COUNT(DISTINCT d.Batch_ID)
        / NULLIF(COUNT(DISTINCT b.Batch_ID), 0)
        AS decimal(10,2)
    ) AS Delay_Rate_Pct,
    COUNT(d.Factor_ID) AS Downtime_Events,
    COUNT(DISTINCT d.Factor_ID) AS Distinct_Factors,
    CAST(COALESCE(SUM(d.Minutes), 0) / 60.0 AS decimal(10,2)) AS Downtime_Hours
FROM dbo.batch_pd AS b
INNER JOIN dbo.products AS p
    ON b.Product_ID = p.Product_ID
LEFT JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID
GROUP BY
    b.Product_ID,
    p.Product_Name
ORDER BY Downtime_Hours DESC;
GO

-- Planned vs actual average production duration by product
SELECT
    b.Product_ID,
    p.Product_Name,
    CAST(AVG(CAST(b.Planned_Min_Batch_Hours AS decimal(10,2))) AS decimal(10,2))
        AS Avg_Planned_Hours,
    CAST(AVG(b.Actual_Duration_Hours) AS decimal(10,2))
        AS Avg_Actual_Hours,
    CAST(
        AVG(b.Actual_Duration_Hours)
        - AVG(CAST(b.Planned_Min_Batch_Hours AS decimal(10,2)))
        AS decimal(10,2)
    ) AS Avg_Overrun_Hours
FROM dbo.batch_pd AS b
INNER JOIN dbo.products AS p
    ON b.Product_ID = p.Product_ID
GROUP BY
    b.Product_ID,
    p.Product_Name
ORDER BY Avg_Overrun_Hours DESC;
GO

-- Top 5 downtime root causes within each product
WITH ProductFactorRank AS
(
    SELECT
        Product_ID,
        Product_Name,
        Factor_Name,
        COUNT(*) AS Downtime_Events,
        CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours,
        ROW_NUMBER() OVER
        (
            PARTITION BY Product_ID
            ORDER BY SUM(Minutes) DESC, COUNT(*) DESC
        ) AS Root_Cause_Rank
    FROM dbo.vw_downtime_analysis
    GROUP BY
        Product_ID,
        Product_Name,
        Factor_Name
)
SELECT
    Product_ID,
    Product_Name,
    Root_Cause_Rank,
    Factor_Name,
    Downtime_Events,
    Downtime_Hours
FROM ProductFactorRank
WHERE Root_Cause_Rank <= 5
ORDER BY Product_ID, Root_Cause_Rank;
GO


/*=============================================================================
  06. MONTHLY TREND ANALYSIS
=============================================================================*/

-- Monthly downtime event frequency and duration
SELECT
    DATEFROMPARTS(YEAR(Start_Date), MONTH(Start_Date), 1) AS Month_Start,
    DATENAME(MONTH, Start_Date) AS Month_Name,
    COUNT(*) AS Downtime_Events,
    COUNT(DISTINCT Batch_ID) AS Delayed_Batches,
    CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours,
    CAST(SUM(Minutes) / 1440.0 AS decimal(10,2)) AS Downtime_Days
FROM dbo.vw_downtime_analysis
GROUP BY
    DATEFROMPARTS(YEAR(Start_Date), MONTH(Start_Date), 1),
    DATENAME(MONTH, Start_Date)
ORDER BY Month_Start;
GO


/*=============================================================================
  07. OPERATOR PERFORMANCE ANALYSIS
=============================================================================*/

-- Operator production volume, delayed-batch rate, event frequency and duration
SELECT
    b.Operator,
    COUNT(DISTINCT b.Batch_ID) AS Total_Batches,
    COUNT(DISTINCT d.Batch_ID) AS Delayed_Batches,
    CAST(
        100.0 * COUNT(DISTINCT d.Batch_ID)
        / NULLIF(COUNT(DISTINCT b.Batch_ID), 0)
        AS decimal(10,2)
    ) AS Delayed_Batch_Rate_Pct,
    COUNT(d.Factor_ID) AS Downtime_Events,
    CAST(COALESCE(SUM(d.Minutes), 0) / 60.0 AS decimal(10,2)) AS Downtime_Hours,
    COUNT(DISTINCT b.Product_ID) AS Products_Handled
FROM dbo.batch_pd AS b
LEFT JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID
GROUP BY b.Operator
ORDER BY Downtime_Hours DESC;
GO

-- Root causes by operator: one reusable query replaces separate Paul/James/etc queries
SELECT
    Operator,
    Factor_Name,
    COUNT(*) AS Downtime_Events,
    CAST(SUM(Minutes) / 60.0 AS decimal(10,2)) AS Downtime_Hours
FROM dbo.vw_downtime_analysis
GROUP BY
    Operator,
    Factor_Name
ORDER BY
    Operator,
    Downtime_Hours DESC;
GO


/*=============================================================================
  08. MULTIPLE-BATCH SCHEDULING ANALYSIS
=============================================================================*/

-- IMPORTANT:
-- This section examines production records where an operator handled more than
-- one batch on the same production date. Results demonstrate association with
-- downtime; they do not establish that multiple-batch scheduling caused downtime.

-- Validate scheduling-page headline KPIs
SELECT
    COUNT(DISTINCT b.Start_Date) AS Days_With_Multiple_Batches,
    COUNT(DISTINCT b.Batch_ID) AS Batches,
    COUNT(d.Factor_ID) AS Downtime_Events
FROM dbo.batch_pd AS b
LEFT JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID
WHERE b.MultipleBatchPerDay = 1;
GO

-- Multiple-batch days and downtime events by operator
SELECT
    b.Operator,
    COUNT(DISTINCT b.Start_Date) AS Multiple_Batch_Days,
    COUNT(DISTINCT b.Batch_ID) AS Batches,
    COUNT(d.Factor_ID) AS Downtime_Events,
    CAST(COALESCE(SUM(d.Minutes), 0) / 60.0 AS decimal(10,2)) AS Downtime_Hours
FROM dbo.batch_pd AS b
LEFT JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID
WHERE b.MultipleBatchPerDay = 1
GROUP BY b.Operator
ORDER BY Multiple_Batch_Days DESC, Downtime_Events DESC;
GO

-- Detail table supporting the Operator Scheduling dashboard page
SELECT
    b.Operator,
    b.Start_Date,
    b.Start_Time,
    b.Product_ID,
    p.Product_Name,
    b.Batch_ID,
    b.Operator_Batches_Per_Day
FROM dbo.batch_pd AS b
INNER JOIN dbo.products AS p
    ON b.Product_ID = p.Product_ID
WHERE b.MultipleBatchPerDay = 1
ORDER BY
    b.Operator,
    b.Start_Date,
    b.Start_Time,
    b.Batch_ID;
GO

-- Compare multiple-batch vs single-batch operator-days.
-- This is descriptive comparison only; do not interpret it as causal evidence.
SELECT
    CASE
        WHEN b.MultipleBatchPerDay = 1 THEN 'Multiple-batch operator-day'
        ELSE 'Single-batch operator-day'
    END AS Scheduling_Context,
    COUNT(DISTINCT b.Batch_ID) AS Total_Batches,
    COUNT(DISTINCT d.Batch_ID) AS Delayed_Batches,
    CAST(
        100.0 * COUNT(DISTINCT d.Batch_ID)
        / NULLIF(COUNT(DISTINCT b.Batch_ID), 0)
        AS decimal(10,2)
    ) AS Delay_Rate_Pct,
    COUNT(d.Factor_ID) AS Downtime_Events,
    CAST(COALESCE(SUM(d.Minutes), 0) / 60.0 AS decimal(10,2)) AS Downtime_Hours
FROM dbo.batch_pd AS b
LEFT JOIN dbo.downtimes AS d
    ON b.Batch_ID = d.Batch_ID
GROUP BY b.MultipleBatchPerDay
ORDER BY b.MultipleBatchPerDay DESC;
GO


/*=============================================================================
  09. PORTFOLIO SUMMARY OUTPUT
=============================================================================*/

-- Compact executive summary for validation/documentation
SELECT
    (SELECT COUNT(DISTINCT Batch_ID) FROM dbo.batch_pd) AS Total_Batches,
    (SELECT COUNT(DISTINCT Batch_ID) FROM dbo.downtimes) AS Delayed_Batches,
    CAST(
        100.0 * (SELECT COUNT(DISTINCT Batch_ID) FROM dbo.downtimes)
        / NULLIF((SELECT COUNT(DISTINCT Batch_ID) FROM dbo.batch_pd), 0)
        AS decimal(10,1)
    ) AS Delay_Rate_Pct,
    (SELECT COUNT(*) FROM dbo.downtimes) AS Downtime_Events,
    (SELECT COUNT(DISTINCT Factor_ID) FROM dbo.downtimes) AS Distinct_Factors,
    CAST(
        (SELECT SUM(Minutes) FROM dbo.downtimes) / 1440.0
        AS decimal(10,2)
    ) AS Days_Lost,
    (
        SELECT COUNT(DISTINCT Start_Date)
        FROM dbo.batch_pd
        WHERE MultipleBatchPerDay = 1
    ) AS Multiple_Batch_Days,
    (
        SELECT COUNT(DISTINCT Batch_ID)
        FROM dbo.batch_pd
        WHERE MultipleBatchPerDay = 1
    ) AS Multiple_Batch_Batches,
    (
        SELECT COUNT(d.Factor_ID)
        FROM dbo.batch_pd AS b
        LEFT JOIN dbo.downtimes AS d
            ON b.Batch_ID = d.Batch_ID
        WHERE b.MultipleBatchPerDay = 1
    ) AS Multiple_Batch_Downtime_Events;
GO

/*
===============================================================================
END OF GREENTECH MANUFACTURING ANALYTICS SQL
===============================================================================
*/
