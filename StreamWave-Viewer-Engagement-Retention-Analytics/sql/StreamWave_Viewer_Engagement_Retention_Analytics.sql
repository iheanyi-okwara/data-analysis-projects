/*=====================================================================
  STREAMWAVE ENTERTAINMENT
  VIEWER ENGAGEMENT & RETENTION ANALYTICS

  Analyst: Iheanyi Okwara
  Tools: SQL Server / T-SQL

  Source Tables:
      dbo.users
      dbo.subscriptions
      dbo.viewing_activity
      dbo.movie_list

  Purpose:
      Analyse viewer behaviour, content performance, engagement,
      completion, repeat viewing, subscriptions, cancellations
      and retention patterns.

  IMPORTANT:
      This script uses the actual column names from the StreamWave
      CSV datasets.
=====================================================================*/


/*=====================================================================
  1. DATA QUALITY & DATASET VALIDATION
=====================================================================*/

-- Row counts across source tables
SELECT 'Users' AS Dataset, COUNT(*) AS Total_Rows
FROM dbo.users

UNION ALL

SELECT 'Subscriptions', COUNT(*)
FROM dbo.subscriptions

UNION ALL

SELECT 'Viewing Activity', COUNT(*)
FROM dbo.viewing_activity

UNION ALL

SELECT 'Movie List', COUNT(*)
FROM dbo.movie_list;
GO


-- Check duplicate User IDs
SELECT
    User_ID,
    COUNT(*) AS Record_Count
FROM dbo.users
GROUP BY User_ID
HAVING COUNT(*) > 1;
GO


-- Check duplicate subscription records by user
SELECT
    User_ID,
    COUNT(*) AS Record_Count
FROM dbo.subscriptions
GROUP BY User_ID
HAVING COUNT(*) > 1;
GO


-- Check duplicate Content IDs in catalogue
SELECT
    Content_ID,
    COUNT(*) AS Record_Count
FROM dbo.movie_list
GROUP BY Content_ID
HAVING COUNT(*) > 1;
GO


-- Check viewing records that do not match a user
SELECT COUNT(*) AS Viewing_Records_Without_User
FROM dbo.viewing_activity v
LEFT JOIN dbo.users u
    ON v.User_ID = u.User_ID
WHERE u.User_ID IS NULL;
GO


-- Check viewing records that do not match catalogue content
SELECT COUNT(*) AS Viewing_Records_Without_Content
FROM dbo.viewing_activity v
LEFT JOIN dbo.movie_list m
    ON v.Content_ID = m.Content_ID
WHERE m.Content_ID IS NULL;
GO

/*=====================================================================
  0. DATABASE SETUP
=====================================================================*/

CREATE DATABASE StreamWave;
GO

USE StreamWave;
GO

-- Confirm that the StreamWave database exists
SELECT name
FROM sys.databases
WHERE name = 'StreamWave';
GO

/*=====================================================================
  2. CREATE CLEAN ANALYTICAL VIEW
=====================================================================*/

CREATE OR ALTER VIEW dbo.vw_StreamWave_Analytics
AS
SELECT
    v.User_ID,
    v.Content_ID,

    u.Age,
    u.Gender,
    u.Country,
    u.Subscription_Start_Date,
    u.Subscription_Status,

    s.Subscription_Tier,
    s.Monthly_Fee,
    s.Renewal_Status,
    s.Cancellation_Date,

    m.Title,
    m.Genre,
    m.Release_Year,
    m.Duration_minutes AS Content_Duration_Minutes,

    v.Watch_Date,
    v.Watch_Duration_minutes AS Watch_Duration_Minutes,

    -- Percentage of the content watched
    CASE
        WHEN m.Duration_minutes > 0
        THEN
            CAST(v.Watch_Duration_minutes AS decimal(10,2))
            / m.Duration_minutes * 100
        ELSE NULL
    END AS Completion_Percentage,

    -- Completed viewing session:
    -- at least 90% of the content duration watched
    CASE
        WHEN m.Duration_minutes > 0
             AND
             CAST(v.Watch_Duration_minutes AS decimal(10,2))
             / m.Duration_minutes >= 0.90
        THEN 1
        ELSE 0
    END AS Completed_View_Flag

FROM dbo.viewing_activity v

INNER JOIN dbo.users u
    ON v.User_ID = u.User_ID

INNER JOIN dbo.subscriptions s
    ON v.User_ID = s.User_ID

INNER JOIN dbo.movie_list m
    ON v.Content_ID = m.Content_ID;
GO

/*=====================================================================
  STREAMWAVE DATABASE RELATIONSHIPS
  Primary Keys and Foreign Keys
=====================================================================*/

USE StreamWave;
GO

/*=====================================================================
  3. DATABASE STRUCTURE & RELATIONSHIPS
=====================================================================*/




/*=====================================================================
  DATA TYPE OPTIMISATION
  Standardise Subscription Pricing
=====================================================================*/

-- Convert Monthly_Fee from FLOAT to DECIMAL for accurate monetary values
ALTER TABLE dbo.subscriptions
ALTER COLUMN Monthly_Fee DECIMAL(10,2);
GO

-- Verify subscription pricing
SELECT DISTINCT
    Subscription_Tier,
    Monthly_Fee
FROM dbo.subscriptions
ORDER BY Monthly_Fee;
GO


/*=====================================================================
  3.3 FOREIGN KEYS
=====================================================================*/

-- Connect subscriptions to users
ALTER TABLE dbo.subscriptions
ADD CONSTRAINT FK_subscriptions_users
FOREIGN KEY (User_ID)
REFERENCES dbo.users(User_ID);
GO


-- Connect viewing activity to users
ALTER TABLE dbo.viewing_activity
ADD CONSTRAINT FK_viewing_activity_users
FOREIGN KEY (User_ID)
REFERENCES dbo.users(User_ID);
GO


-- Connect viewing activity to movie catalogue
ALTER TABLE dbo.viewing_activity
ADD CONSTRAINT FK_viewing_activity_movie_list
FOREIGN KEY (Content_ID)
REFERENCES dbo.movie_list(Content_ID);
GO


/*=====================================================================
  3.4 INDEXES FOR ANALYTICAL PERFORMANCE
=====================================================================*/

CREATE INDEX IX_viewing_activity_User_ID
ON dbo.viewing_activity(User_ID);
GO

CREATE INDEX IX_viewing_activity_Content_ID
ON dbo.viewing_activity(Content_ID);
GO


/*=====================================================================
  3.5 VERIFY PRIMARY KEYS
=====================================================================*/

SELECT
    tc.TABLE_NAME,
    kcu.COLUMN_NAME,
    tc.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc

INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME

WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'

ORDER BY tc.TABLE_NAME;
GO


/*=====================================================================
  3.6 VERIFY FOREIGN KEYS
=====================================================================*/

SELECT
    fk.name AS Foreign_Key,
    OBJECT_NAME(fk.parent_object_id) AS Child_Table,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS Child_Column,
    OBJECT_NAME(fk.referenced_object_id) AS Parent_Table,
    COL_NAME(
        fkc.referenced_object_id,
        fkc.referenced_column_id
    ) AS Parent_Column

FROM sys.foreign_keys fk

INNER JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id

ORDER BY Child_Table;
GO

/*=====================================================================
  5. OVERALL PLATFORM KPIs
=====================================================================*/

SELECT
    COUNT(DISTINCT User_ID) AS Viewers,

    COUNT(*) AS Viewing_Sessions,

    COUNT(DISTINCT Content_ID) AS Content_Watched,

    COUNT(DISTINCT Genre) AS Genres_Watched,

    ROUND(
        AVG(CAST(Age AS decimal(10,2))),
        1
    ) AS Average_Viewer_Age,

    ROUND(
        AVG(CAST(Watch_Duration_Minutes AS decimal(10,2))),
        2
    ) AS Average_Watch_Duration_Minutes,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Completion_Percentage

FROM dbo.vw_StreamWave_Analytics;
GO


/*=====================================================================
  6. ACTIVE USER KPIs
=====================================================================*/

SELECT
    COUNT(*) AS Total_Users,

    SUM(
        CASE
            WHEN Subscription_Status = 'Active'
            THEN 1 ELSE 0
        END
    ) AS Active_Users,

    SUM(
        CASE
            WHEN Subscription_Status = 'Inactive'
            THEN 1 ELSE 0
        END
    ) AS Inactive_Users,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN Subscription_Status = 'Active'
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*),0),
        2
    ) AS Active_User_Percentage

FROM dbo.users;
GO


/*=====================================================================
  7. USER DEMOGRAPHICS
=====================================================================*/

-- Gender distribution
SELECT
    Gender,
    COUNT(*) AS Users,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS Percentage_of_Users

FROM dbo.users
GROUP BY Gender
ORDER BY Users DESC;
GO


-- Users by country
SELECT
    Country,
    COUNT(*) AS Users,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS Percentage_of_Users

FROM dbo.users
GROUP BY Country
ORDER BY Users DESC;
GO


-- Age distribution
SELECT
    CASE
        WHEN Age < 18 THEN 'Under 18'
        WHEN Age BETWEEN 18 AND 24 THEN '18-24'
        WHEN Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN Age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS Age_Group,

    COUNT(*) AS Users

FROM dbo.users
GROUP BY
    CASE
        WHEN Age < 18 THEN 'Under 18'
        WHEN Age BETWEEN 18 AND 24 THEN '18-24'
        WHEN Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN Age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END
ORDER BY Users DESC;
GO


/*=====================================================================
  8. SUBSCRIPTION TIER ANALYSIS
=====================================================================*/

SELECT
    Subscription_Tier,

    COUNT(*) AS Subscribers,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS Subscriber_Percentage,

    ROUND(
        AVG(Monthly_Fee),
        2
    ) AS Average_Monthly_Fee

FROM dbo.subscriptions
GROUP BY Subscription_Tier
ORDER BY Subscribers DESC;
GO


/*=====================================================================
  9. SUBSCRIPTION STATUS BY TIER
=====================================================================*/

SELECT
    s.Subscription_Tier,
    u.Subscription_Status,
    COUNT(*) AS Users

FROM dbo.subscriptions s

INNER JOIN dbo.users u
    ON s.User_ID = u.User_ID

GROUP BY
    s.Subscription_Tier,
    u.Subscription_Status

ORDER BY
    s.Subscription_Tier,
    Users DESC;
GO


/*=====================================================================
  10. GENRE POPULARITY
=====================================================================*/

SELECT
    Genre,

    COUNT(*) AS Viewing_Sessions,

    COUNT(DISTINCT User_ID) AS Unique_Viewers,

    COUNT(DISTINCT Content_ID) AS Titles_Watched,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS Percentage_of_Total_Views,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        AVG(CAST(Watch_Duration_Minutes AS decimal(10,2))),
        2
    ) AS Average_Watch_Minutes

FROM dbo.vw_StreamWave_Analytics

GROUP BY Genre

ORDER BY Viewing_Sessions DESC;
GO


/*=====================================================================
  11. GENRE RANKING
=====================================================================*/

WITH GenrePerformance AS
(
    SELECT
        Genre,
        COUNT(*) AS Viewing_Sessions,
        COUNT(DISTINCT User_ID) AS Unique_Viewers,
        SUM(Watch_Duration_Minutes) AS Total_Watch_Minutes
    FROM dbo.vw_StreamWave_Analytics
    GROUP BY Genre
)

SELECT
    Genre,

    Viewing_Sessions,

    Unique_Viewers,

    ROUND(
        Total_Watch_Minutes / 60.0,
        2
    ) AS Total_Watch_Hours,

    DENSE_RANK() OVER (
        ORDER BY Viewing_Sessions DESC
    ) AS Popularity_Rank

FROM GenrePerformance

ORDER BY Popularity_Rank;
GO


/*=====================================================================
  12. CONTENT PERFORMANCE
=====================================================================*/

SELECT
    Content_ID,
    Title,
    Genre,

    COUNT(*) AS Views,

    COUNT(DISTINCT User_ID) AS Unique_Viewers,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        AVG(CAST(Watch_Duration_Minutes AS decimal(10,2))),
        2
    ) AS Average_Watch_Minutes,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Completion_Percentage

FROM dbo.vw_StreamWave_Analytics

GROUP BY
    Content_ID,
    Title,
    Genre

ORDER BY Views DESC;
GO


/*=====================================================================
  13. TOP 10 MOST-WATCHED TITLES
=====================================================================*/

SELECT TOP 10

    Content_ID,
    Title,
    Genre,

    COUNT(*) AS Views,

    COUNT(DISTINCT User_ID) AS Unique_Viewers,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours

FROM dbo.vw_StreamWave_Analytics

GROUP BY
    Content_ID,
    Title,
    Genre

ORDER BY Views DESC;
GO


/*=====================================================================
  14. COMPLETION ANALYSIS BY GENRE

  Definition:
  A viewing session is considered completed when at least
  90% of the title duration was watched.
=====================================================================*/

SELECT
    Genre,

    COUNT(*) AS Viewing_Sessions,

    SUM(Completed_View_Flag) AS Completed_Views,

    ROUND(
        SUM(Completed_View_Flag) * 100.0 /
        NULLIF(COUNT(*),0),
        2
    ) AS Completion_Rate_Pct,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Percentage_Watched

FROM dbo.vw_StreamWave_Analytics

GROUP BY Genre

ORDER BY Completion_Rate_Pct DESC;
GO


/*=====================================================================
  15. OVERALL COMPLETION RATE
=====================================================================*/

SELECT
    COUNT(*) AS Viewing_Sessions,

    SUM(Completed_View_Flag) AS Completed_Views,

    ROUND(
        SUM(Completed_View_Flag) * 100.0 /
        NULLIF(COUNT(*),0),
        2
    ) AS Completion_Rate_Pct

FROM dbo.vw_StreamWave_Analytics;
GO


/*=====================================================================
  16. REPEAT VIEWING BY USER AND CONTENT
=====================================================================*/

WITH RepeatViewing AS
(
    SELECT
        User_ID,
        Content_ID,
        Title,
        Genre,
        COUNT(*) AS Times_Watched

    FROM dbo.vw_StreamWave_Analytics

    GROUP BY
        User_ID,
        Content_ID,
        Title,
        Genre
)

SELECT
    User_ID,
    Content_ID,
    Title,
    Genre,
    Times_Watched

FROM RepeatViewing

WHERE Times_Watched > 1

ORDER BY Times_Watched DESC;
GO


/*=====================================================================
  17. REPEAT VIEWING BY GENRE
=====================================================================*/

WITH UserContentViews AS
(
    SELECT
        User_ID,
        Content_ID,
        Genre,
        COUNT(*) AS Times_Watched

    FROM dbo.vw_StreamWave_Analytics

    GROUP BY
        User_ID,
        Content_ID,
        Genre
),

GenreRepeat AS
(
    SELECT
        Genre,

        COUNT(*) AS User_Content_Combinations,

        SUM(
            CASE
                WHEN Times_Watched > 1
                THEN 1 ELSE 0
            END
        ) AS Repeated_User_Content_Combinations,

        AVG(
            CAST(Times_Watched AS decimal(10,2))
        ) AS Average_Times_Watched

    FROM UserContentViews

    GROUP BY Genre
)

SELECT
    Genre,

    User_Content_Combinations,

    Repeated_User_Content_Combinations,

    ROUND(
        Repeated_User_Content_Combinations * 100.0 /
        NULLIF(User_Content_Combinations,0),
        2
    ) AS Repeat_View_Rate_Pct,

    ROUND(
        Average_Times_Watched,
        2
    ) AS Average_Times_Watched

FROM GenreRepeat

ORDER BY Repeat_View_Rate_Pct DESC;
GO


/*=====================================================================
  18. VIEWER ENGAGEMENT BY GENRE
=====================================================================*/

SELECT
    Genre,

    COUNT(*) AS Viewing_Sessions,

    COUNT(DISTINCT User_ID) AS Unique_Viewers,

    ROUND(
        AVG(CAST(Watch_Duration_Minutes AS decimal(10,2))),
        2
    ) AS Average_Watch_Minutes,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Percentage_Watched

FROM dbo.vw_StreamWave_Analytics

GROUP BY Genre

ORDER BY Total_Watch_Hours DESC;
GO


/*=====================================================================
  19. VIEWING ACTIVITY BY MONTH
=====================================================================*/

SELECT
    YEAR(Watch_Date) AS Watch_Year,
    MONTH(Watch_Date) AS Watch_Month,

    DATENAME(
        MONTH,
        Watch_Date
    ) AS Month_Name,

    COUNT(*) AS Viewing_Sessions,

    COUNT(DISTINCT User_ID) AS Active_Viewers,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Watch_Hours

FROM dbo.vw_StreamWave_Analytics

WHERE Watch_Date IS NOT NULL

GROUP BY
    YEAR(Watch_Date),
    MONTH(Watch_Date),
    DATENAME(MONTH, Watch_Date)

ORDER BY
    Watch_Year,
    Watch_Month;
GO


/*=====================================================================
  20. NEW SUBSCRIBERS BY MONTH
=====================================================================*/

SELECT
    YEAR(
        TRY_CONVERT(date, Subscription_Start_Date, 101)
    ) AS Subscription_Year,

    MONTH(
        TRY_CONVERT(date, Subscription_Start_Date, 101)
    ) AS Subscription_Month,

    DATENAME(
        MONTH,
        TRY_CONVERT(date, Subscription_Start_Date, 101)
    ) AS Month_Name,

    COUNT(*) AS New_Subscribers

FROM dbo.users

WHERE TRY_CONVERT(
    date,
    Subscription_Start_Date,
    101
) IS NOT NULL

GROUP BY

    YEAR(
        TRY_CONVERT(date, Subscription_Start_Date, 101)
    ),

    MONTH(
        TRY_CONVERT(date, Subscription_Start_Date, 101)
    ),

    DATENAME(
        MONTH,
        TRY_CONVERT(date, Subscription_Start_Date, 101)
    )

ORDER BY
    Subscription_Year,
    Subscription_Month;
GO


/*=====================================================================
  21. CANCELLATIONS BY MONTH
=====================================================================*/

SELECT
    YEAR(
        TRY_CONVERT(date, Cancellation_Date, 101)
    ) AS Cancellation_Year,

    MONTH(
        TRY_CONVERT(date, Cancellation_Date, 101)
    ) AS Cancellation_Month,

    DATENAME(
        MONTH,
        TRY_CONVERT(date, Cancellation_Date, 101)
    ) AS Month_Name,

    COUNT(*) AS Cancellations

FROM dbo.subscriptions

WHERE TRY_CONVERT(
    date,
    Cancellation_Date,
    101
) IS NOT NULL

GROUP BY

    YEAR(
        TRY_CONVERT(date, Cancellation_Date, 101)
    ),

    MONTH(
        TRY_CONVERT(date, Cancellation_Date, 101)
    ),

    DATENAME(
        MONTH,
        TRY_CONVERT(date, Cancellation_Date, 101)
    )

ORDER BY
    Cancellation_Year,
    Cancellation_Month;
GO


/*=====================================================================
  22. CANCELLATION RATE BY SUBSCRIPTION TIER
=====================================================================*/

SELECT
    Subscription_Tier,

    COUNT(*) AS Subscribers,

    SUM(
        CASE
            WHEN Renewal_Status = 'Canceled'
            THEN 1 ELSE 0
        END
    ) AS Cancellations,

    ROUND(
        SUM(
            CASE
                WHEN Renewal_Status = 'Canceled'
                THEN 1 ELSE 0
            END
        ) * 100.0 /
        NULLIF(COUNT(*),0),
        2
    ) AS Cancellation_Rate_Pct

FROM dbo.subscriptions

GROUP BY Subscription_Tier

ORDER BY Cancellation_Rate_Pct DESC;
GO


/*=====================================================================
  23. RENEWAL / RETENTION RATE
=====================================================================*/

SELECT
    COUNT(*) AS Total_Subscriptions,

    SUM(
        CASE
            WHEN Renewal_Status = 'Renewed'
            THEN 1 ELSE 0
        END
    ) AS Renewed_Subscriptions,

    SUM(
        CASE
            WHEN Renewal_Status = 'Canceled'
            THEN 1 ELSE 0
        END
    ) AS Canceled_Subscriptions,

    ROUND(
        SUM(
            CASE
                WHEN Renewal_Status = 'Renewed'
                THEN 1 ELSE 0
            END
        ) * 100.0 /
        NULLIF(COUNT(*),0),
        2
    ) AS Renewal_Rate_Pct,

    ROUND(
        SUM(
            CASE
                WHEN Renewal_Status = 'Canceled'
                THEN 1 ELSE 0
            END
        ) * 100.0 /
        NULLIF(COUNT(*),0),
        2
    ) AS Cancellation_Rate_Pct

FROM dbo.subscriptions;
GO


/*=====================================================================
  24. ENGAGEMENT: RENEWED VS CANCELLED USERS
=====================================================================*/

SELECT
    Renewal_Status,

    COUNT(DISTINCT User_ID) AS Users,

    COUNT(*) AS Viewing_Sessions,

    ROUND(
        COUNT(*) * 1.0 /
        NULLIF(COUNT(DISTINCT User_ID),0),
        2
    ) AS Average_Sessions_Per_User,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2)))
        / 60.0
        / NULLIF(COUNT(DISTINCT User_ID),0),
        2
    ) AS Average_Watch_Hours_Per_User,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Completion_Percentage

FROM dbo.vw_StreamWave_Analytics

GROUP BY Renewal_Status;
GO


/*=====================================================================
  25. USER-LEVEL ENGAGEMENT
=====================================================================*/

SELECT
    User_ID,

    COUNT(*) AS Viewing_Sessions,

    COUNT(DISTINCT Content_ID) AS Unique_Content_Watched,

    COUNT(DISTINCT Genre) AS Genres_Watched,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        AVG(CAST(Watch_Duration_Minutes AS decimal(10,2))),
        2
    ) AS Average_Watch_Minutes,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Completion_Percentage

FROM dbo.vw_StreamWave_Analytics

GROUP BY User_ID

ORDER BY Total_Watch_Hours DESC;
GO


/*=====================================================================
  26. ENGAGEMENT BY SUBSCRIPTION TIER
=====================================================================*/

SELECT
    Subscription_Tier,

    COUNT(DISTINCT User_ID) AS Viewers,

    COUNT(*) AS Viewing_Sessions,

    ROUND(
        COUNT(*) * 1.0 /
        NULLIF(COUNT(DISTINCT User_ID),0),
        2
    ) AS Average_Sessions_Per_User,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2)))
        / 60.0
        / NULLIF(COUNT(DISTINCT User_ID),0),
        2
    ) AS Average_Watch_Hours_Per_User,

    ROUND(
        AVG(Completion_Percentage),
        2
    ) AS Average_Completion_Percentage

FROM dbo.vw_StreamWave_Analytics

GROUP BY Subscription_Tier

ORDER BY Total_Watch_Hours DESC;
GO


/*=====================================================================
  27. MOST ENGAGED USERS
=====================================================================*/

SELECT TOP 20

    User_ID,

    COUNT(*) AS Viewing_Sessions,

    COUNT(DISTINCT Content_ID) AS Unique_Titles,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Total_Watch_Hours

FROM dbo.vw_StreamWave_Analytics

GROUP BY User_ID

ORDER BY Total_Watch_Hours DESC;
GO


/*=====================================================================
  28. GENRE PREFERENCE BY SUBSCRIPTION TIER
=====================================================================*/

SELECT
    Subscription_Tier,
    Genre,

    COUNT(*) AS Viewing_Sessions,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*))
        OVER (PARTITION BY Subscription_Tier),
        2
    ) AS Tier_View_Percentage

FROM dbo.vw_StreamWave_Analytics

GROUP BY
    Subscription_Tier,
    Genre

ORDER BY
    Subscription_Tier,
    Viewing_Sessions DESC;
GO


/*=====================================================================
  29. GENRE PREFERENCE BY GENDER
=====================================================================*/

SELECT
    Gender,
    Genre,

    COUNT(*) AS Viewing_Sessions,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*))
        OVER (PARTITION BY Gender),
        2
    ) AS Gender_View_Percentage

FROM dbo.vw_StreamWave_Analytics

GROUP BY
    Gender,
    Genre

ORDER BY
    Gender,
    Viewing_Sessions DESC;
GO


/*=====================================================================
  30. GENRE PREFERENCE BY AGE GROUP
=====================================================================*/

WITH AgeAnalysis AS
(
    SELECT
        CASE
            WHEN Age < 18 THEN 'Under 18'
            WHEN Age BETWEEN 18 AND 24 THEN '18-24'
            WHEN Age BETWEEN 25 AND 34 THEN '25-34'
            WHEN Age BETWEEN 35 AND 44 THEN '35-44'
            WHEN Age BETWEEN 45 AND 54 THEN '45-54'
            ELSE '55+'
        END AS Age_Group,

        Genre

    FROM dbo.vw_StreamWave_Analytics
)

SELECT
    Age_Group,
    Genre,

    COUNT(*) AS Viewing_Sessions,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*))
        OVER (PARTITION BY Age_Group),
        2
    ) AS Age_Group_View_Percentage

FROM AgeAnalysis

GROUP BY
    Age_Group,
    Genre

ORDER BY
    Age_Group,
    Viewing_Sessions DESC;
GO


/*=====================================================================
  31. MONTHLY VIEWING TREND BY GENRE
=====================================================================*/

SELECT
    YEAR(Watch_Date) AS Watch_Year,
    MONTH(Watch_Date) AS Watch_Month,
    Genre,

    COUNT(*) AS Viewing_Sessions,

    ROUND(
        SUM(CAST(Watch_Duration_Minutes AS decimal(18,2))) / 60,
        2
    ) AS Watch_Hours

FROM dbo.vw_StreamWave_Analytics

WHERE Watch_Date IS NOT NULL

GROUP BY
    YEAR(Watch_Date),
    MONTH(Watch_Date),
    Genre

ORDER BY
    Watch_Year,
    Watch_Month,
    Viewing_Sessions DESC;
GO


/*=====================================================================
  32. MONTH-OVER-MONTH VIEWING GROWTH
=====================================================================*/

WITH MonthlyViews AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(Watch_Date),
            MONTH(Watch_Date),
            1
        ) AS Month_Start,

        COUNT(*) AS Viewing_Sessions

    FROM dbo.vw_StreamWave_Analytics

    WHERE Watch_Date IS NOT NULL

    GROUP BY
        YEAR(Watch_Date),
        MONTH(Watch_Date)
),

PreviousMonth AS
(
    SELECT
        Month_Start,
        Viewing_Sessions,

        LAG(Viewing_Sessions)
        OVER (ORDER BY Month_Start) AS Previous_Month_Views

    FROM MonthlyViews
)

SELECT
    Month_Start,
    Viewing_Sessions,
    Previous_Month_Views,

    ROUND(
        (
            Viewing_Sessions - Previous_Month_Views
        ) * 100.0 /
        NULLIF(Previous_Month_Views,0),
        2
    ) AS Month_Over_Month_Growth_Pct

FROM PreviousMonth

ORDER BY Month_Start;
GO


/*=====================================================================
  33. MONTHLY SUBSCRIBER NET CHANGE

  New subscribers and cancellations are kept as separate event
  measures and then compared by calendar month.
=====================================================================*/

WITH NewSubs AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(date, Subscription_Start_Date, 101)),
            MONTH(TRY_CONVERT(date, Subscription_Start_Date, 101)),
            1
        ) AS Month_Start,

        COUNT(*) AS New_Subscribers

    FROM dbo.users

    WHERE TRY_CONVERT(
        date,
        Subscription_Start_Date,
        101
    ) IS NOT NULL

    GROUP BY
        YEAR(TRY_CONVERT(date, Subscription_Start_Date, 101)),
        MONTH(TRY_CONVERT(date, Subscription_Start_Date, 101))
),

Cancelled AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(TRY_CONVERT(date, Cancellation_Date, 101)),
            MONTH(TRY_CONVERT(date, Cancellation_Date, 101)),
            1
        ) AS Month_Start,

        COUNT(*) AS Cancellations

    FROM dbo.subscriptions

    WHERE TRY_CONVERT(
        date,
        Cancellation_Date,
        101
    ) IS NOT NULL

    GROUP BY
        YEAR(TRY_CONVERT(date, Cancellation_Date, 101)),
        MONTH(TRY_CONVERT(date, Cancellation_Date, 101))
),

Months AS
(
    SELECT Month_Start FROM NewSubs

    UNION

    SELECT Month_Start FROM Cancelled
)

SELECT
    m.Month_Start,

    COALESCE(n.New_Subscribers,0)
        AS New_Subscribers,

    COALESCE(c.Cancellations,0)
        AS Cancellations,

    COALESCE(n.New_Subscribers,0)
    -
    COALESCE(c.Cancellations,0)
        AS Net_Subscriber_Change

FROM Months m

LEFT JOIN NewSubs n
    ON m.Month_Start = n.Month_Start

LEFT JOIN Cancelled c
    ON m.Month_Start = c.Month_Start

ORDER BY m.Month_Start;
GO


/*=====================================================================
  34. VIEWER ACTIVITY FREQUENCY
=====================================================================*/

WITH UserActivity AS
(
    SELECT
        User_ID,
        COUNT(*) AS Viewing_Sessions

    FROM dbo.vw_StreamWave_Analytics

    GROUP BY User_ID
)

SELECT
    CASE
        WHEN Viewing_Sessions < 25
            THEN 'Low Activity'

        WHEN Viewing_Sessions BETWEEN 25 AND 60
            THEN 'Medium Activity'

        ELSE 'High Activity'
    END AS Activity_Level,

    COUNT(*) AS Users,

    ROUND(
        AVG(CAST(Viewing_Sessions AS decimal(10,2))),
        2
    ) AS Average_Sessions

FROM UserActivity

GROUP BY
    CASE
        WHEN Viewing_Sessions < 25
            THEN 'Low Activity'

        WHEN Viewing_Sessions BETWEEN 25 AND 60
            THEN 'Medium Activity'

        ELSE 'High Activity'
    END

ORDER BY Average_Sessions DESC;
GO


/*=====================================================================
  35. ENGAGEMENT AND CANCELLATION

  Descriptive analysis only:
  This identifies association between engagement and cancellation.
  It does NOT establish that engagement causes cancellation.
=====================================================================*/

WITH UserEngagement AS
(
    SELECT
        User_ID,

        COUNT(*) AS Viewing_Sessions,

        COUNT(DISTINCT Content_ID)
            AS Unique_Content_Watched,

        SUM(Watch_Duration_Minutes)
            AS Total_Watch_Minutes

    FROM dbo.vw_StreamWave_Analytics

    GROUP BY User_ID
)

SELECT
    s.Renewal_Status,

    COUNT(*) AS Users,

    ROUND(
        AVG(CAST(e.Viewing_Sessions AS decimal(10,2))),
        2
    ) AS Average_Viewing_Sessions,

    ROUND(
        AVG(
            CAST(e.Unique_Content_Watched AS decimal(10,2))
        ),
        2
    ) AS Average_Unique_Content,

    ROUND(
        AVG(
            CAST(e.Total_Watch_Minutes AS decimal(18,2))
        ) / 60,
        2
    ) AS Average_Watch_Hours

FROM UserEngagement e

INNER JOIN dbo.subscriptions s
    ON e.User_ID = s.User_ID

GROUP BY s.Renewal_Status;
GO


/*=====================================================================
  36. CONTENT CATALOGUE UTILISATION
=====================================================================*/

SELECT
    COUNT(*) AS Catalogue_Titles,

    SUM(
        CASE
            WHEN v.Content_ID IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS Titles_With_Views,

    SUM(
        CASE
            WHEN v.Content_ID IS NULL
            THEN 1 ELSE 0
        END
    ) AS Titles_Without_Views,

    ROUND(
        SUM(
            CASE
                WHEN v.Content_ID IS NOT NULL
                THEN 1 ELSE 0
            END
        ) * 100.0 /
        NULLIF(COUNT(*),0),
        2
    ) AS Catalogue_Utilisation_Pct

FROM dbo.movie_list m

LEFT JOIN
(
    SELECT DISTINCT Content_ID
    FROM dbo.viewing_activity
) v
    ON m.Content_ID = v.Content_ID;
GO


/*=====================================================================
  37. UNUSED CATALOGUE CONTENT
=====================================================================*/

SELECT
    m.Content_ID,
    m.Title,
    m.Genre,
    m.Release_Year,
    m.Duration_minutes AS Duration_Minutes

FROM dbo.movie_list m

LEFT JOIN dbo.viewing_activity v
    ON m.Content_ID = v.Content_ID

WHERE v.Content_ID IS NULL

ORDER BY
    m.Genre,
    m.Title;
GO


/*=====================================================================
  38. EXECUTIVE GENRE PERFORMANCE TABLE

  Useful as a Power BI source table.
=====================================================================*/

WITH RepeatData AS
(
    SELECT
        User_ID,
        Content_ID,
        Genre,
        COUNT(*) AS Times_Watched

    FROM dbo.vw_StreamWave_Analytics

    GROUP BY
        User_ID,
        Content_ID,
        Genre
),

RepeatSummary AS
(
    SELECT
        Genre,

        SUM(
            CASE
                WHEN Times_Watched > 1
                THEN 1 ELSE 0
            END
        ) AS Repeat_Combinations,

        COUNT(*) AS User_Content_Combinations

    FROM RepeatData

    GROUP BY Genre
),

GenreSummary AS
(
    SELECT
        Genre,

        COUNT(*) AS Viewing_Sessions,

        COUNT(DISTINCT User_ID) AS Unique_Viewers,

        COUNT(DISTINCT Content_ID) AS Titles_Watched,

        SUM(Watch_Duration_Minutes)
            AS Total_Watch_Minutes,

        AVG(
            CAST(Watch_Duration_Minutes AS decimal(18,2))
        ) AS Average_Watch_Minutes,

        AVG(Completion_Percentage)
            AS Average_Completion_Percentage,

        SUM(Completed_View_Flag)
            AS Completed_Views

    FROM dbo.vw_StreamWave_Analytics

    GROUP BY Genre
)

SELECT
    g.Genre,

    g.Viewing_Sessions,

    g.Unique_Viewers,

    g.Titles_Watched,

    ROUND(
        g.Total_Watch_Minutes / 60.0,
        2
    ) AS Total_Watch_Hours,

    ROUND(
        g.Average_Watch_Minutes,
        2
    ) AS Average_Watch_Minutes,

    ROUND(
        g.Average_Completion_Percentage,
        2
    ) AS Average_Percentage_Watched,

    ROUND(
        g.Completed_Views * 100.0 /
        NULLIF(g.Viewing_Sessions,0),
        2
    ) AS Completion_Rate_Pct,

    ROUND(
        r.Repeat_Combinations * 100.0 /
        NULLIF(r.User_Content_Combinations,0),
        2
    ) AS Repeat_View_Rate_Pct,

    DENSE_RANK() OVER (
        ORDER BY g.Viewing_Sessions DESC
    ) AS Popularity_Rank

FROM GenreSummary g

LEFT JOIN RepeatSummary r
    ON g.Genre = r.Genre

ORDER BY Popularity_Rank;
GO


/*=====================================================================
  39. FINAL EXECUTIVE KPI SUMMARY
=====================================================================*/

SELECT

    (SELECT COUNT(*)
     FROM dbo.users)
        AS Total_Registered_Users,

    (SELECT COUNT(*)
     FROM dbo.users
     WHERE Subscription_Status = 'Active')
        AS Active_Users,

    (SELECT COUNT(DISTINCT User_ID)
     FROM dbo.viewing_activity)
        AS Users_With_Viewing_Activity,

    (SELECT COUNT(*)
     FROM dbo.viewing_activity)
        AS Total_Viewing_Sessions,

    (SELECT COUNT(DISTINCT Content_ID)
     FROM dbo.viewing_activity)
        AS Content_Watched,

    (SELECT COUNT(*)
     FROM dbo.movie_list)
        AS Catalogue_Size,

    (SELECT COUNT(DISTINCT Genre)
     FROM dbo.vw_StreamWave_Analytics)
        AS Genres_Watched,

    (
        SELECT ROUND(
            SUM(CAST(Watch_Duration_Minutes AS decimal(18,2)))
            / 60,
            2
        )
        FROM dbo.vw_StreamWave_Analytics
    ) AS Total_Watch_Hours,

    (
        SELECT ROUND(
            AVG(CAST(Watch_Duration_Minutes AS decimal(10,2))),
            2
        )
        FROM dbo.vw_StreamWave_Analytics
    ) AS Average_Watch_Minutes,

    (
        SELECT ROUND(
            SUM(Completed_View_Flag) * 100.0 /
            NULLIF(COUNT(*),0),
            2
        )
        FROM dbo.vw_StreamWave_Analytics
    ) AS Completion_Rate_Pct,

    (
        SELECT ROUND(
            SUM(
                CASE
                    WHEN Renewal_Status = 'Renewed'
                    THEN 1 ELSE 0
                END
            ) * 100.0 /
            NULLIF(COUNT(*),0),
            2
        )
        FROM dbo.subscriptions
    ) AS Renewal_Rate_Pct,

    (
        SELECT ROUND(
            SUM(
                CASE
                    WHEN Renewal_Status = 'Canceled'
                    THEN 1 ELSE 0
                END
            ) * 100.0 /
            NULLIF(COUNT(*),0),
            2
        )
        FROM dbo.subscriptions
    ) AS Cancellation_Rate_Pct;
GO



/*=====================================================================
  DATABASE STRUCTURE ENHANCEMENT
  Add Unique Identifier to Viewing Activity
=====================================================================*/

-- Add a unique identifier for each viewing event
ALTER TABLE dbo.viewing_activity
ADD Viewing_ID INT IDENTITY(1,1) NOT NULL;
GO

-- Set Viewing_ID as the primary key
ALTER TABLE dbo.viewing_activity
ADD CONSTRAINT PK_viewing_activity
PRIMARY KEY (Viewing_ID);
GO

-- Verify Viewing_ID
SELECT TOP 10 *
FROM dbo.viewing_activity;
GO

/*=====================================================================
  END OF STREAMWAVE ANALYSIS
=====================================================================*/
