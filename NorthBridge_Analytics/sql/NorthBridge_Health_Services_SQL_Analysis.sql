/*
============================================================
NORTHBRIDGE HEALTH SERVICES LTD
Customer Service & SLA Optimisation Project
SQL Portfolio Analysis
Database: NORTHBRIDGE_DB
Platform: Microsoft SQL Server
Author: Iheanyi Okwara

STREAMLINED PORTFOLIO STRUCTURE
01. DATA EXPLORATION & QUALITY
02. TICKET PERFORMANCE
03. SLA & BACKLOG PERFORMANCE
04. ESCALATION & AGENT PERFORMANCE
05. CLIENT & BUSINESS ANALYSIS
06. KPI DATASET & POWER BI PREPARATION
07. POWER BI DASHBOARD & INSIGHTS


============================================================
*/

USE NORTHBRIDGE_DB;
GO

/* ============================================================
01. DATA EXPLORATION & QUALITY
============================================================ */

/* 01.1 — Database tables */
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;


/* 01.2 — Database structure */
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


/* 01.3 — Record counts */
SELECT
    (SELECT COUNT(*) FROM dbo.Tickets) AS TotalTickets,
    (SELECT COUNT(*) FROM dbo.Clients) AS TotalClients,
    (SELECT COUNT(*) FROM dbo.Agents) AS TotalAgents,
    (SELECT COUNT(*) FROM dbo.EscalationLog) AS TotalEscalations,
    (SELECT COUNT(*) FROM dbo.TicketAuditLog) AS TotalAuditRecords,
    (SELECT COUNT(*) FROM dbo.TicketCategories) AS TotalCategories,
    (SELECT COUNT(*) FROM dbo.PriorityLevels) AS TotalPriorities,
    (SELECT COUNT(*) FROM dbo.SLADefinitions) AS TotalSLADefinitions;


/* 01.4 — Dataset coverage */
SELECT
    MIN(CreatedAt) AS EarliestTicket,
    MAX(CreatedAt) AS LatestTicket,
    COUNT(*) AS TotalTickets,
    COUNT(DISTINCT ClientID) AS UniqueClients,
    COUNT(DISTINCT AssignedAgentID) AS AgentsHandlingTickets
FROM dbo.Tickets;


/* 01.5 — Ticket status distribution */
SELECT
    Status,
    COUNT(*) AS TicketCount,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfTickets
FROM dbo.Tickets
GROUP BY Status
ORDER BY TicketCount DESC;


/* 01.6 — Priority distribution */
SELECT
    p.PriorityID,
    p.PriorityLabel,
    COUNT(t.TicketID) AS TicketCount,
    CAST(
        COUNT(t.TicketID) * 100.0 / SUM(COUNT(t.TicketID)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfTickets
FROM dbo.PriorityLevels AS p
LEFT JOIN dbo.Tickets AS t
    ON p.PriorityID = t.PriorityID
GROUP BY p.PriorityID, p.PriorityLabel
ORDER BY p.PriorityID;


/* 01.7 — Category distribution */
SELECT
    c.CategoryID,
    c.CategoryName,
    COUNT(t.TicketID) AS TicketCount,
    CAST(
        COUNT(t.TicketID) * 100.0 / SUM(COUNT(t.TicketID)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfTickets
FROM dbo.TicketCategories AS c
LEFT JOIN dbo.Tickets AS t
    ON c.CategoryID = t.CategoryID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY TicketCount DESC;


/* 01.8 — Channel distribution */
SELECT
    Channel,
    COUNT(*) AS TicketCount,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfTickets
FROM dbo.Tickets
GROUP BY Channel
ORDER BY TicketCount DESC;


/* 01.9 — Duplicate Ticket IDs */
SELECT
    TicketID,
    COUNT(*) AS DuplicateCount
FROM dbo.Tickets
GROUP BY TicketID
HAVING COUNT(*) > 1;


/* 01.10 — Duplicate Ticket References */
SELECT
    TicketReference,
    COUNT(*) AS DuplicateCount
FROM dbo.Tickets
GROUP BY TicketReference
HAVING COUNT(*) > 1;


/* 01.11 — Duplicate master-data IDs */
SELECT 'Clients' AS TableName, ClientID AS ID, COUNT(*) AS RecordCount
FROM dbo.Clients
GROUP BY ClientID
HAVING COUNT(*) > 1

UNION ALL

SELECT 'Agents', AgentID, COUNT(*)
FROM dbo.Agents
GROUP BY AgentID
HAVING COUNT(*) > 1

UNION ALL

SELECT 'PriorityLevels', PriorityID, COUNT(*)
FROM dbo.PriorityLevels
GROUP BY PriorityID
HAVING COUNT(*) > 1

UNION ALL

SELECT 'TicketCategories', CategoryID, COUNT(*)
FROM dbo.TicketCategories
GROUP BY CategoryID
HAVING COUNT(*) > 1;


/* 01.12 — Missing critical ticket fields */
SELECT
    SUM(CASE WHEN TicketID IS NULL THEN 1 ELSE 0 END) AS MissingTicketID,
    SUM(CASE WHEN ClientID IS NULL THEN 1 ELSE 0 END) AS MissingClientID,
    SUM(CASE WHEN CategoryID IS NULL THEN 1 ELSE 0 END) AS MissingCategoryID,
    SUM(CASE WHEN PriorityID IS NULL THEN 1 ELSE 0 END) AS MissingPriorityID,
    SUM(CASE WHEN Status IS NULL THEN 1 ELSE 0 END) AS MissingStatus,
    SUM(CASE WHEN AssignedAgentID IS NULL THEN 1 ELSE 0 END) AS MissingAgentID,
    SUM(CASE WHEN CreatedAt IS NULL THEN 1 ELSE 0 END) AS MissingCreatedAt,
    SUM(CASE WHEN SLADueAt IS NULL THEN 1 ELSE 0 END) AS MissingSLADueAt,
    SUM(CASE WHEN SLABreached IS NULL THEN 1 ELSE 0 END) AS MissingSLABreached
FROM dbo.Tickets;


/* 01.13 — Invalid ticket dates */
SELECT
    TicketID,
    CreatedAt,
    FirstResponseAt,
    ResolvedAt,
    SLADueAt
FROM dbo.Tickets
WHERE FirstResponseAt < CreatedAt
   OR ResolvedAt < CreatedAt
   OR SLADueAt < CreatedAt;


/* 01.14 — First response after resolution */
SELECT
    TicketID,
    CreatedAt,
    FirstResponseAt,
    ResolvedAt
FROM dbo.Tickets
WHERE FirstResponseAt IS NOT NULL
  AND ResolvedAt IS NOT NULL
  AND FirstResponseAt > ResolvedAt;


/* 01.15 — Relationship validation summary */
SELECT
    'Tickets -> Clients' AS Relationship,
    COUNT(*) AS InvalidRecords
FROM dbo.Tickets AS t
LEFT JOIN dbo.Clients AS c
    ON t.ClientID = c.ClientID
WHERE c.ClientID IS NULL

UNION ALL

SELECT
    'Tickets -> Agents',
    COUNT(*)
FROM dbo.Tickets AS t
LEFT JOIN dbo.Agents AS a
    ON t.AssignedAgentID = a.AgentID
WHERE a.AgentID IS NULL

UNION ALL

SELECT
    'Tickets -> Categories',
    COUNT(*)
FROM dbo.Tickets AS t
LEFT JOIN dbo.TicketCategories AS c
    ON t.CategoryID = c.CategoryID
WHERE c.CategoryID IS NULL

UNION ALL

SELECT
    'Tickets -> Priorities',
    COUNT(*)
FROM dbo.Tickets AS t
LEFT JOIN dbo.PriorityLevels AS p
    ON t.PriorityID = p.PriorityID
WHERE p.PriorityID IS NULL

UNION ALL

SELECT
    'Escalations -> Tickets',
    COUNT(*)
FROM dbo.EscalationLog AS e
LEFT JOIN dbo.Tickets AS t
    ON e.TicketID = t.TicketID
WHERE t.TicketID IS NULL

UNION ALL

SELECT
    'AuditLog -> Tickets',
    COUNT(*)
FROM dbo.TicketAuditLog AS l
LEFT JOIN dbo.Tickets AS t
    ON l.TicketID = t.TicketID
WHERE t.TicketID IS NULL;


/* 01.16 — Agent capacity validation */
SELECT
    AgentID,
    FullName,
    DailyCapacity,
    IsActive
FROM dbo.Agents
WHERE DailyCapacity IS NULL
   OR DailyCapacity <= 0;


/* 01.17 — SLA definition coverage */
SELECT
    t.TicketID,
    t.ClientID,
    c.ContractTier,
    t.PriorityID
FROM dbo.Tickets AS t
INNER JOIN dbo.Clients AS c
    ON t.ClientID = c.ClientID
LEFT JOIN dbo.SLADefinitions AS s
    ON s.ContractTier = c.ContractTier
   AND s.PriorityID = t.PriorityID
WHERE s.SLAID IS NULL;


/* ============================================================
02. TICKET PERFORMANCE
============================================================ */

/* 02.1 — Overall ticket performance */
SELECT
    COUNT(*) AS TotalTickets,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN ResolvedAt IS NULL THEN 1 ELSE 0 END) AS UnresolvedTickets,
    SUM(CASE WHEN FirstResponseAt IS NULL THEN 1 ELSE 0 END) AS UnansweredTickets,
    CAST(
        SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS ResolutionRate
FROM dbo.Tickets;


/* 02.2 — Response and resolution time */
SELECT
    COUNT(FirstResponseAt) AS TicketsWithResponse,
    CAST(
        AVG(
            CASE
                WHEN FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        MIN(
            CASE
                WHEN FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS MinFirstResponseHours,
    CAST(
        MAX(
            CASE
                WHEN FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS MaxFirstResponseHours,
    COUNT(ResolvedAt) AS ResolvedTickets,
    CAST(
        AVG(
            CASE
                WHEN ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    CAST(
        MIN(
            CASE
                WHEN ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS MinResolutionHours,
    CAST(
        MAX(
            CASE
                WHEN ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS MaxResolutionHours
FROM dbo.Tickets;


/* 02.3 — Ticket performance by priority */
SELECT
    p.PriorityID,
    p.PriorityLabel,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    CAST(
        AVG(
            CASE
                WHEN t.FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN t.ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    CAST(
        SUM(CASE WHEN t.ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS ResolutionRate
FROM dbo.PriorityLevels AS p
LEFT JOIN dbo.Tickets AS t
    ON p.PriorityID = t.PriorityID
GROUP BY p.PriorityID, p.PriorityLabel
ORDER BY p.PriorityID;


/* 02.4 — Ticket performance by category */
SELECT
    c.CategoryID,
    c.CategoryName,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    CAST(
        AVG(
            CASE
                WHEN t.FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN t.ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.TicketCategories AS c
LEFT JOIN dbo.Tickets AS t
    ON c.CategoryID = t.CategoryID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY TotalTickets DESC;


/* 02.5 — Ticket performance by channel */
SELECT
    Channel,
    COUNT(*) AS TotalTickets,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    CAST(
        SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS ResolutionRate,
    CAST(
        AVG(
            CASE
                WHEN FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours
FROM dbo.Tickets
GROUP BY Channel
ORDER BY TotalTickets DESC;


/* 02.6 — Ticket volume by day */
SELECT
    CAST(CreatedAt AS DATE) AS ActivityDate,
    COUNT(*) AS TicketsCreated,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS TicketsResolved
FROM dbo.Tickets
GROUP BY CAST(CreatedAt AS DATE)
ORDER BY ActivityDate;


/* 02.7 — Longest-running resolved tickets */
SELECT TOP 20
    TicketID,
    TicketReference,
    ClientID,
    PriorityID,
    CreatedAt,
    ResolvedAt,
    DATEDIFF(HOUR, CreatedAt, ResolvedAt) AS ResolutionHours
FROM dbo.Tickets
WHERE ResolvedAt IS NOT NULL
ORDER BY ResolutionHours DESC;


/* ============================================================
03. SLA & BACKLOG PERFORMANCE
============================================================ */

/* 03.1 — Overall SLA performance */
SELECT
    COUNT(*) AS TotalTickets,
    SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreachedTickets,
    SUM(CASE WHEN SLABreached = 0 THEN 1 ELSE 0 END) AS SLACompliantTickets,
    CAST(
        SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    CAST(
        SUM(CASE WHEN SLABreached = 0 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS SLAComplianceRate
FROM dbo.Tickets;


/* 03.2 — SLA performance by priority */
SELECT
    p.PriorityID,
    p.PriorityLabel,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreachedTickets,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.PriorityLevels AS p
LEFT JOIN dbo.Tickets AS t
    ON p.PriorityID = t.PriorityID
GROUP BY p.PriorityID, p.PriorityLabel
ORDER BY SLABreachRate DESC;


/* 03.3 — SLA performance by contract tier */
SELECT
    c.ContractTier,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreachedTickets,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Clients AS c
LEFT JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
GROUP BY c.ContractTier
ORDER BY SLABreachRate DESC;


/* 03.4 — SLA performance matrix: contract tier × priority */
SELECT
    c.ContractTier,
    p.PriorityLabel,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreachedTickets,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    s.FirstResponseHours AS SLAFirstResponseHours,
    s.ResolutionHours AS SLAResolutionHours,
    s.EscalationTriggerHours
FROM dbo.Tickets AS t
INNER JOIN dbo.Clients AS c
    ON t.ClientID = c.ClientID
INNER JOIN dbo.PriorityLevels AS p
    ON t.PriorityID = p.PriorityID
INNER JOIN dbo.SLADefinitions AS s
    ON c.ContractTier = s.ContractTier
   AND t.PriorityID = s.PriorityID
GROUP BY
    c.ContractTier,
    p.PriorityLabel,
    s.FirstResponseHours,
    s.ResolutionHours,
    s.EscalationTriggerHours
ORDER BY c.ContractTier, p.PriorityLabel;


/* 03.5 — SLA flag reconciliation */
WITH SLAComparison AS
(
    SELECT
        t.TicketID,
        t.SLABreached AS RecordedSLABreached,
        CASE
            WHEN t.ResolvedAt IS NOT NULL
             AND t.ResolvedAt >
                 DATEADD(
                     MINUTE,
                     CAST(s.ResolutionHours * 60 AS INT),
                     t.CreatedAt
                 )
            THEN 1
            ELSE 0
        END AS CalculatedSLABreached
    FROM dbo.Tickets AS t
    INNER JOIN dbo.Clients AS c
        ON t.ClientID = c.ClientID
    INNER JOIN dbo.SLADefinitions AS s
        ON c.ContractTier = s.ContractTier
       AND t.PriorityID = s.PriorityID
    WHERE t.ResolvedAt IS NOT NULL
)
SELECT
    COUNT(*) AS ResolvedTickets,
    SUM(CASE WHEN RecordedSLABreached = 1 THEN 1 ELSE 0 END) AS RecordedBreaches,
    SUM(CASE WHEN CalculatedSLABreached = 1 THEN 1 ELSE 0 END) AS CalculatedBreaches,
    SUM(CASE WHEN RecordedSLABreached = CalculatedSLABreached THEN 1 ELSE 0 END) AS MatchingFlags,
    SUM(CASE WHEN RecordedSLABreached <> CalculatedSLABreached THEN 1 ELSE 0 END) AS MismatchedFlags,
    CAST(
        SUM(CASE WHEN RecordedSLABreached = CalculatedSLABreached THEN 1 ELSE 0 END)
        * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS FlagAgreementRate
FROM SLAComparison;


/* 03.6 — Overall backlog */
SELECT
    COUNT(*) AS TotalTickets,
    SUM(CASE WHEN ResolvedAt IS NULL THEN 1 ELSE 0 END) AS CurrentBacklog,
    CAST(
        SUM(CASE WHEN ResolvedAt IS NULL THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS BacklogRate,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND CreatedAt < DATEADD(DAY, -7, GETDATE())
            THEN 1 ELSE 0
        END
    ) AS BacklogOlderThan7Days,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND CreatedAt < DATEADD(DAY, -30, GETDATE())
            THEN 1 ELSE 0
        END
    ) AS BacklogOlderThan30Days,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND SLADueAt IS NOT NULL
             AND SLADueAt < GETDATE()
            THEN 1 ELSE 0
        END
    ) AS BacklogPastSLA,
    CAST(
        AVG(
            CASE
                WHEN ResolvedAt IS NULL
                THEN DATEDIFF(DAY, CreatedAt, GETDATE())
            END
        )
        AS DECIMAL(10,2)
    ) AS AvgBacklogAgeDays
FROM dbo.Tickets;


/* 03.7 — Backlog by priority */
SELECT
    p.PriorityID,
    p.PriorityLabel,
    COUNT(t.TicketID) AS BacklogTickets,
    CAST(
        COUNT(t.TicketID) * 100.0
        / SUM(COUNT(t.TicketID)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfBacklog
FROM dbo.Tickets AS t
INNER JOIN dbo.PriorityLevels AS p
    ON t.PriorityID = p.PriorityID
WHERE t.ResolvedAt IS NULL
GROUP BY p.PriorityID, p.PriorityLabel
ORDER BY BacklogTickets DESC;


/* 03.8 — Backlog age distribution */
SELECT
    CASE
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 1 THEN '0-1 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 3 THEN '2-3 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 7 THEN '4-7 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 14 THEN '8-14 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 30 THEN '15-30 Days'
        ELSE '30+ Days'
    END AS AgeBand,
    COUNT(*) AS BacklogTickets
FROM dbo.Tickets
WHERE ResolvedAt IS NULL
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 1 THEN '0-1 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 3 THEN '2-3 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 7 THEN '4-7 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 14 THEN '8-14 Days'
        WHEN DATEDIFF(DAY, CreatedAt, GETDATE()) <= 30 THEN '15-30 Days'
        ELSE '30+ Days'
    END
ORDER BY
    MIN(DATEDIFF(DAY, CreatedAt, GETDATE()));


/* 03.9 — Current tickets past SLA */
SELECT
    t.TicketID,
    t.TicketReference,
    t.ClientID,
    t.PriorityID,
    t.Status,
    t.CreatedAt,
    t.SLADueAt,
    t.AssignedAgentID,
    DATEDIFF(HOUR, t.SLADueAt, GETDATE()) AS HoursPastSLA
FROM dbo.Tickets AS t
WHERE t.ResolvedAt IS NULL
  AND t.SLADueAt IS NOT NULL
  AND t.SLADueAt < GETDATE()
ORDER BY HoursPastSLA DESC;


/* 03.10 — Current SLA risk summary */
SELECT
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND SLADueAt < GETDATE()
            THEN 1 ELSE 0
        END
    ) AS TicketsPastSLA,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND SLADueAt >= GETDATE()
             AND SLADueAt <= DATEADD(HOUR, 4, GETDATE())
            THEN 1 ELSE 0
        END
    ) AS TicketsDueWithin4Hours,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND SLADueAt > DATEADD(HOUR, 4, GETDATE())
            THEN 1 ELSE 0
        END
    ) AS TicketsWithMoreThan4HoursRemaining
FROM dbo.Tickets
WHERE ResolvedAt IS NULL
  AND SLADueAt IS NOT NULL;


/* 03.11 — Rules-based SLA risk monitoring */
SELECT
    TicketID,
    TicketReference,
    PriorityID,
    Status,
    CreatedAt,
    SLADueAt,
    DATEDIFF(HOUR, GETDATE(), SLADueAt) AS HoursUntilSLADue,
    CASE
        WHEN SLABreached = 1 THEN 'Breached'
        WHEN DATEDIFF(HOUR, GETDATE(), SLADueAt) <= 2 THEN 'Critical Risk'
        WHEN DATEDIFF(HOUR, GETDATE(), SLADueAt) <= 8 THEN 'High Risk'
        WHEN DATEDIFF(HOUR, GETDATE(), SLADueAt) <= 24 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS SLARiskLevel
FROM dbo.Tickets
WHERE ResolvedAt IS NULL;


/* 03.12 — Backlog by client */
SELECT TOP 20
    c.ClientID,
    c.ClientName,
    c.ContractTier,
    COUNT(t.TicketID) AS OpenTickets,
    SUM(
        CASE
            WHEN t.SLADueAt IS NOT NULL
             AND t.SLADueAt < GETDATE()
            THEN 1 ELSE 0
        END
    ) AS OpenTicketsPastSLA
FROM dbo.Clients AS c
INNER JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
WHERE t.ResolvedAt IS NULL
GROUP BY c.ClientID, c.ClientName, c.ContractTier
ORDER BY OpenTickets DESC;


/* 03.13 — Monthly demand, resolution and SLA trend */
SELECT
    YEAR(CreatedAt) AS TicketYear,
    MONTH(CreatedAt) AS TicketMonth,
    COUNT(*) AS TicketsCreated,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS TicketsResolved,
    SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches
FROM dbo.Tickets
GROUP BY YEAR(CreatedAt), MONTH(CreatedAt)
ORDER BY TicketYear, TicketMonth;


/* ============================================================
04. ESCALATION & AGENT PERFORMANCE
============================================================ */

/* 04.1 — Overall escalation summary */
SELECT
    COUNT(*) AS TotalEscalations,
    COUNT(DISTINCT TicketID) AS TicketsWithEscalations,
    CAST(
        COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT TicketID), 0)
        AS DECIMAL(10,2)
    ) AS AvgEscalationsPerEscalatedTicket
FROM dbo.EscalationLog;


/* 04.2 — Escalations by reason */
SELECT
    EscalationReason,
    COUNT(*) AS EscalationCount,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfEscalations
FROM dbo.EscalationLog
GROUP BY EscalationReason
ORDER BY EscalationCount DESC;


/* 04.3 — Manual vs automated escalations */
SELECT
    CASE
        WHEN AutomatedFlag = 1 THEN 'Automated'
        WHEN AutomatedFlag = 0 THEN 'Manual'
        ELSE 'Unknown'
    END AS EscalationType,
    COUNT(*) AS EscalationCount,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfEscalations
FROM dbo.EscalationLog
GROUP BY
    CASE
        WHEN AutomatedFlag = 1 THEN 'Automated'
        WHEN AutomatedFlag = 0 THEN 'Manual'
        ELSE 'Unknown'
    END
ORDER BY EscalationCount DESC;


/* 04.4 — Escalations and SLA breaches */
SELECT
    COUNT(*) AS TotalEscalations,
    COUNT(DISTINCT e.TicketID) AS EscalatedTickets,
    COUNT(DISTINCT CASE WHEN t.SLABreached = 1 THEN e.TicketID END) AS EscalatedTicketsWithSLABreach,
    COUNT(DISTINCT CASE WHEN t.ResolvedAt IS NULL THEN e.TicketID END) AS EscalatedOpenTickets
FROM dbo.EscalationLog AS e
INNER JOIN dbo.Tickets AS t
    ON e.TicketID = t.TicketID;


/* 04.5 — Escalation by priority */
SELECT
    p.PriorityID,
    p.PriorityLabel,
    COUNT(DISTINCT e.TicketID) AS EscalatedTickets,
    COUNT(e.EscalationID) AS EscalationEvents
FROM dbo.EscalationLog AS e
INNER JOIN dbo.Tickets AS t
    ON e.TicketID = t.TicketID
INNER JOIN dbo.PriorityLevels AS p
    ON t.PriorityID = p.PriorityID
GROUP BY p.PriorityID, p.PriorityLabel
ORDER BY EscalatedTickets DESC;


/* 04.6 — Escalation timing */
SELECT
    e.EscalationID,
    e.TicketID,
    e.EscalatedAt,
    t.CreatedAt,
    CAST(
        DATEDIFF(MINUTE, t.CreatedAt, e.EscalatedAt) / 60.0
        AS DECIMAL(10,2)
    ) AS HoursToEscalation,
    e.EscalationReason,
    e.AutomatedFlag
FROM dbo.EscalationLog AS e
INNER JOIN dbo.Tickets AS t
    ON e.TicketID = t.TicketID
ORDER BY HoursToEscalation DESC;


/* 04.7 — Multiple escalations per ticket */
SELECT
    TicketID,
    COUNT(*) AS EscalationCount
FROM dbo.EscalationLog
GROUP BY TicketID
HAVING COUNT(*) > 1
ORDER BY EscalationCount DESC;


/* 04.8 — Agent workload, capacity and performance */
WITH AgentEscalations AS
(
    SELECT
        TicketID,
        COUNT(*) AS EscalationCount
    FROM dbo.EscalationLog
    GROUP BY TicketID
)
SELECT
    a.AgentID,
    a.FullName,
    a.Role,
    a.Hub,
    a.TeamID,
    a.DailyCapacity,
    COUNT(t.TicketID) AS TotalAssignedTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    CAST(
        COUNT(t.TicketID) * 100.0
        / NULLIF(a.DailyCapacity, 0)
        AS DECIMAL(10,2)
    ) AS CapacityUtilisationPercent,
    CAST(
        AVG(
            CASE
                WHEN t.FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN t.ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    SUM(ISNULL(ae.EscalationCount, 0)) AS TotalEscalations
FROM dbo.Agents AS a
LEFT JOIN dbo.Tickets AS t
    ON a.AgentID = t.AssignedAgentID
LEFT JOIN AgentEscalations AS ae
    ON t.TicketID = ae.TicketID
GROUP BY
    a.AgentID,
    a.FullName,
    a.Role,
    a.Hub,
    a.TeamID,
    a.DailyCapacity
ORDER BY TotalAssignedTickets DESC;


/* 04.9 — Agent workload distribution */
WITH AgentWorkload AS
(
    SELECT
        a.AgentID,
        a.FullName,
        COUNT(t.TicketID) AS TotalAssignedTickets
    FROM dbo.Agents AS a
    LEFT JOIN dbo.Tickets AS t
        ON a.AgentID = t.AssignedAgentID
    GROUP BY a.AgentID, a.FullName
)
SELECT
    COUNT(*) AS TotalAgents,
    MIN(TotalAssignedTickets) AS MinimumTickets,
    MAX(TotalAssignedTickets) AS MaximumTickets,
    CAST(AVG(TotalAssignedTickets * 1.0) AS DECIMAL(10,2)) AS AverageTickets,
    CAST(STDEV(TotalAssignedTickets) AS DECIMAL(10,2)) AS WorkloadStdDeviation
FROM AgentWorkload;


/* ============================================================
05. CLIENT & BUSINESS ANALYSIS
============================================================ */

/* 05.1 — Client workload and SLA performance */
SELECT TOP 20
    c.ClientID,
    c.ClientName,
    c.ClientType,
    c.ContractTier,
    c.Region,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Clients AS c
LEFT JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
GROUP BY
    c.ClientID,
    c.ClientName,
    c.ClientType,
    c.ContractTier,
    c.Region
ORDER BY TotalTickets DESC;


/* 05.2 — Client SLA performance with minimum volume */
SELECT TOP 20
    c.ClientID,
    c.ClientName,
    c.ContractTier,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Clients AS c
INNER JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
GROUP BY c.ClientID, c.ClientName, c.ContractTier
HAVING COUNT(t.TicketID) >= 5
ORDER BY SLABreachRate DESC;


/* 05.3 — Contract tier business performance */
SELECT
    c.ContractTier,
    COUNT(DISTINCT c.ClientID) AS ClientCount,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Clients AS c
LEFT JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
GROUP BY c.ContractTier
ORDER BY TotalTickets DESC;


/* 05.4 — Client distribution by region */
SELECT
    Region,
    COUNT(*) AS ClientCount,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS PercentageOfClients
FROM dbo.Clients
GROUP BY Region
ORDER BY ClientCount DESC;


/* 05.5 — Ticket volume by category */
SELECT
    tc.CategoryID,
    tc.CategoryName,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.TicketCategories AS tc
LEFT JOIN dbo.Tickets AS t
    ON tc.CategoryID = t.CategoryID
GROUP BY tc.CategoryID, tc.CategoryName
ORDER BY TotalTickets DESC;


/* 05.6 — Ticket volume by hub */
SELECT
    a.Hub,
    COUNT(t.TicketID) AS TicketCount,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches
FROM dbo.Agents AS a
INNER JOIN dbo.Tickets AS t
    ON a.AgentID = t.AssignedAgentID
GROUP BY a.Hub
ORDER BY TicketCount DESC;


/* 05.7 — Ticket volume by team */
SELECT
    a.TeamID,
    COUNT(t.TicketID) AS TicketCount,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches
FROM dbo.Agents AS a
INNER JOIN dbo.Tickets AS t
    ON a.AgentID = t.AssignedAgentID
GROUP BY a.TeamID
ORDER BY TicketCount DESC;


/* ============================================================
06. KPI DATASET & POWER BI PREPARATION
============================================================ */

/* 06.1 — Executive KPI dataset */
SELECT
    COUNT(*) AS TotalTickets,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN FirstResponseAt IS NULL THEN 1 ELSE 0 END) AS UnansweredTickets,
    SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreachedTickets,
    CAST(
        SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS ResolutionRate,
    CAST(
        SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    CAST(
        AVG(
            CASE
                WHEN FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND SLADueAt IS NOT NULL
             AND SLADueAt < GETDATE()
            THEN 1 ELSE 0
        END
    ) AS OpenTicketsPastSLA
FROM dbo.Tickets;


/* 06.2 — Ticket-level Power BI fact dataset */
SELECT
    t.TicketID,
    t.TicketReference,

    t.ClientID,
    c.ClientName,
    c.ClientType,
    c.ContractTier,
    c.Region,

    t.CategoryID,
    tc.CategoryName,

    t.PriorityID,
    p.PriorityLabel,

    t.AssignedAgentID,
    a.FullName AS AgentName,
    a.Role AS AgentRole,
    a.Hub,
    a.TeamID,
    a.DailyCapacity,

    t.Status,
    t.Channel,

    t.CreatedAt,
    t.FirstResponseAt,
    t.ResolvedAt,
    t.SLADueAt,
    t.SLABreached,

    CAST(
        DATEDIFF(MINUTE, t.CreatedAt, t.FirstResponseAt) / 60.0
        AS DECIMAL(10,2)
    ) AS FirstResponseHours,

    CASE
        WHEN t.ResolvedAt IS NOT NULL
        THEN CAST(
            DATEDIFF(MINUTE, t.CreatedAt, t.ResolvedAt) / 60.0
            AS DECIMAL(10,2)
        )
    END AS ResolutionHours,

    CASE
        WHEN t.ResolvedAt IS NULL
        THEN DATEDIFF(DAY, t.CreatedAt, GETDATE())
    END AS CurrentBacklogAgeDays,

    CASE
        WHEN t.ResolvedAt IS NOT NULL THEN 'Resolved'
        ELSE 'Open'
    END AS ResolutionStatus,

    CASE
        WHEN t.ResolvedAt IS NULL
         AND t.SLADueAt < GETDATE()
        THEN 'Past SLA'
        WHEN t.ResolvedAt IS NULL
         AND t.SLADueAt <= DATEADD(HOUR, 4, GETDATE())
        THEN 'Due Within 4 Hours'
        WHEN t.ResolvedAt IS NULL
         AND t.SLADueAt IS NOT NULL
        THEN 'Within SLA'
        ELSE 'Not Applicable'
    END AS CurrentSLARisk
FROM dbo.Tickets AS t
LEFT JOIN dbo.Clients AS c
    ON t.ClientID = c.ClientID
LEFT JOIN dbo.TicketCategories AS tc
    ON t.CategoryID = tc.CategoryID
LEFT JOIN dbo.PriorityLevels AS p
    ON t.PriorityID = p.PriorityID
LEFT JOIN dbo.Agents AS a
    ON t.AssignedAgentID = a.AgentID;


/* 06.3 — Agent Power BI dataset */
WITH AgentEscalations AS
(
    SELECT
        TicketID,
        COUNT(*) AS EscalationCount
    FROM dbo.EscalationLog
    GROUP BY TicketID
)
SELECT
    a.AgentID,
    a.FullName,
    a.Role,
    a.Hub,
    a.TeamID,
    a.DailyCapacity,
    COUNT(t.TicketID) AS TotalAssignedTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    CAST(
        COUNT(t.TicketID) * 100.0
        / NULLIF(a.DailyCapacity, 0)
        AS DECIMAL(10,2)
    ) AS CapacityUtilisationPercent,
    CAST(
        AVG(
            CASE
                WHEN t.FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN t.ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    SUM(ISNULL(ae.EscalationCount, 0)) AS TotalEscalations
FROM dbo.Agents AS a
LEFT JOIN dbo.Tickets AS t
    ON a.AgentID = t.AssignedAgentID
LEFT JOIN AgentEscalations AS ae
    ON t.TicketID = ae.TicketID
GROUP BY
    a.AgentID,
    a.FullName,
    a.Role,
    a.Hub,
    a.TeamID,
    a.DailyCapacity;


/* 06.4 — Client Power BI dataset */
SELECT
    c.ClientID,
    c.ClientName,
    c.ClientType,
    c.ContractTier,
    c.Region,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Clients AS c
LEFT JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
GROUP BY
    c.ClientID,
    c.ClientName,
    c.ClientType,
    c.ContractTier,
    c.Region;


/* 06.5 — Monthly Power BI trend dataset */
SELECT
    DATEFROMPARTS(YEAR(CreatedAt), MONTH(CreatedAt), 1) AS MonthStart,
    COUNT(*) AS TicketsCreated,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS TicketsResolved,
    SUM(CASE WHEN ResolvedAt IS NULL THEN 1 ELSE 0 END) AS TicketsStillOpen,
    SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Tickets
GROUP BY DATEFROMPARTS(YEAR(CreatedAt), MONTH(CreatedAt), 1)
ORDER BY MonthStart;


/* ============================================================
07. POWER BI DASHBOARD & INSIGHTS
============================================================ */

/* 07.1 — Executive dashboard summary */
SELECT
    COUNT(*) AS TotalTickets,
    SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) AS ResolvedTickets,
    SUM(CASE WHEN ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreachedTickets,
    SUM(
        CASE
            WHEN ResolvedAt IS NULL
             AND SLADueAt IS NOT NULL
             AND SLADueAt < GETDATE()
            THEN 1 ELSE 0
        END
    ) AS OpenTicketsPastSLA,
    SUM(CASE WHEN FirstResponseAt IS NULL THEN 1 ELSE 0 END) AS UnansweredTickets,
    CAST(
        SUM(CASE WHEN SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    CAST(
        SUM(CASE WHEN ResolvedAt IS NOT NULL THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS ResolutionRate,
    CAST(
        AVG(
            CASE
                WHEN FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, CreatedAt, ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours
FROM dbo.Tickets;


/* 07.2 — Highest-risk priority segments */
SELECT TOP 10
    p.PriorityLabel,
    c.ContractTier,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets
FROM dbo.Tickets AS t
INNER JOIN dbo.Clients AS c
    ON t.ClientID = c.ClientID
INNER JOIN dbo.PriorityLevels AS p
    ON t.PriorityID = p.PriorityID
GROUP BY p.PriorityLabel, c.ContractTier
HAVING COUNT(t.TicketID) >= 5
ORDER BY SLABreachRate DESC;


/* 07.3 — Top operational bottlenecks by category */
SELECT TOP 10
    tc.CategoryName,
    COUNT(t.TicketID) AS TotalTickets,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    CAST(
        AVG(
            CASE
                WHEN t.FirstResponseAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.FirstResponseAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgFirstResponseHours,
    CAST(
        AVG(
            CASE
                WHEN t.ResolvedAt IS NOT NULL
                THEN DATEDIFF(MINUTE, t.CreatedAt, t.ResolvedAt)
            END
        ) / 60.0
        AS DECIMAL(10,2)
    ) AS AvgResolutionHours,
    CAST(
        SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(t.TicketID), 0)
        AS DECIMAL(10,2)
    ) AS SLABreachRate
FROM dbo.Tickets AS t
INNER JOIN dbo.TicketCategories AS tc
    ON t.CategoryID = tc.CategoryID
GROUP BY tc.CategoryName
ORDER BY SLABreachRate DESC;


/* 07.4 — Highest backlog concentration by client */
SELECT TOP 10
    c.ClientID,
    c.ClientName,
    c.ContractTier,
    COUNT(t.TicketID) AS OpenTickets,
    SUM(
        CASE
            WHEN t.SLADueAt IS NOT NULL
             AND t.SLADueAt < GETDATE()
            THEN 1 ELSE 0
        END
    ) AS OpenTicketsPastSLA
FROM dbo.Clients AS c
INNER JOIN dbo.Tickets AS t
    ON c.ClientID = t.ClientID
WHERE t.ResolvedAt IS NULL
GROUP BY c.ClientID, c.ClientName, c.ContractTier
ORDER BY OpenTickets DESC;


/* 07.5 — Agent capacity pressure */
SELECT TOP 20
    a.AgentID,
    a.FullName,
    a.Hub,
    a.TeamID,
    a.DailyCapacity,
    COUNT(t.TicketID) AS AssignedTickets,
    CAST(
        COUNT(t.TicketID) * 100.0
        / NULLIF(a.DailyCapacity, 0)
        AS DECIMAL(10,2)
    ) AS CapacityUtilisationPercent,
    SUM(CASE WHEN t.ResolvedAt IS NULL THEN 1 ELSE 0 END) AS OpenTickets,
    SUM(CASE WHEN t.SLABreached = 1 THEN 1 ELSE 0 END) AS SLABreaches
FROM dbo.Agents AS a
LEFT JOIN dbo.Tickets AS t
    ON a.AgentID = t.AssignedAgentID
GROUP BY
    a.AgentID,
    a.FullName,
    a.Hub,
    a.TeamID,
    a.DailyCapacity
ORDER BY CapacityUtilisationPercent DESC;
