CREATE DATABASE Horizon_BedDemand;
GO
USE Horizon_BedDemand;
GO


-- Step 1 - Build your dimension tables
-- 1. Dim_Ward

CREATE TABLE dbo.Dim_Ward (
    Ward_Key INT IDENTITY(1,1) PRIMARY KEY,
    Ward NVARCHAR(100)
);

INSERT INTO dbo.Dim_Ward (Ward)
SELECT DISTINCT ward
FROM dbo.staffing
UNION
SELECT DISTINCT ward
FROM dbo.bed_inventory
UNION
SELECT DISTINCT ward
FROM dbo.admissions;


-- 2. Dim_StaffRole
CREATE TABLE dbo.Dim_StaffRole (
    StaffRole_Key INT IDENTITY(1,1) PRIMARY KEY,
    Staff_Role NVARCHAR(100)
);

INSERT INTO dbo.Dim_StaffRole (Staff_Role)
SELECT DISTINCT staff_role
FROM dbo.staffing;


-- 3. Dim_Hospital
CREATE TABLE dbo.Dim_Hospital (
    Hospital_Key INT IDENTITY(1,1) PRIMARY KEY,
    Hospital_Name NVARCHAR(200)
);

INSERT INTO dbo.Dim_Hospital (Hospital_Name)
SELECT DISTINCT hospital
FROM dbo.staffing
UNION
SELECT DISTINCT hospital
FROM dbo.bed_inventory
UNION
SELECT DISTINCT hospital
FROM dbo.admissions;


-- 4. Dim_Date
-- You need a date dimension for all three datasets.

CREATE TABLE dbo.Dim_Date (
    Date_Key INT PRIMARY KEY,
    Full_Date DATE
);

INSERT INTO dbo.Dim_Date (Date_Key, Full_Date)
SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), date, 112)),
    date
FROM dbo.staffing

UNION

SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), datetime, 112)),
    CAST(datetime AS DATE)
FROM dbo.bed_inventory

UNION

SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), admission_datetime, 112)),
    CAST(admission_datetime AS DATE)
FROM dbo.admissions;


-- Step 2 — Build your fact tables
-- 1. Fact_Staffing
CREATE TABLE dbo.Fact_Staffing (
    Staffing_Key INT IDENTITY(1,1) PRIMARY KEY,
    Date_Key INT,
    Ward_Key INT,
    StaffRole_Key INT,
    Hospital_Key INT,
    planned_staff INT,
    actual_staff INT,
    safe_ratio_met BIT
);

INSERT INTO dbo.Fact_Staffing (
    Date_Key, Ward_Key, StaffRole_Key, Hospital_Key,
    planned_staff, actual_staff, safe_ratio_met
)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), s.date, 112)),
    w.Ward_Key,
    r.StaffRole_Key,
    h.Hospital_Key,
    s.planned_staff,
    s.actual_staff,
    CASE WHEN s.safe_ratio_met = 'YES' THEN 1 ELSE 0 END
FROM dbo.staffing s
JOIN dbo.Dim_Ward w ON s.ward = w.Ward
JOIN dbo.Dim_StaffRole r ON s.staff_role = r.Staff_Role
JOIN dbo.Dim_Hospital h ON s.hospital = h.Hospital_Name;


-- 2. Fact_BedInventory
CREATE TABLE dbo.Fact_BedInventory (
    BedInv_Key INT IDENTITY(1,1) PRIMARY KEY,
    Date_Key INT,
    Ward_Key INT,
    Hospital_Key INT,
    bed_type NVARCHAR(50),
    total_beds INT,
    staffed_beds INT,
    occupied_beds INT,
    closed_beds INT
);

INSERT INTO dbo.Fact_BedInventory (
    Date_Key, Ward_Key, Hospital_Key, bed_type,
    total_beds, staffed_beds, occupied_beds, closed_beds
)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), datetime, 112)),
    w.Ward_Key,
    h.Hospital_Key,
    b.bed_type,
    b.total_beds,
    b.staffed_beds,
    b.occupied_beds,
    b.closed_beds
FROM dbo.bed_inventory b
JOIN dbo.Dim_Ward w ON b.ward = w.Ward
JOIN dbo.Dim_Hospital h ON b.hospital = h.Hospital_Name;


-- 3, Fact_Admissions

CREATE TABLE dbo.Fact_Admissions (
    Admission_Key INT IDENTITY(1,1) PRIMARY KEY,
    Admission_ID VARCHAR(50),
    Patient_ID VARCHAR(50),
    Date_Key INT,
    Ward_Key INT,
    Hospital_Key INT,
    admission_type NVARCHAR(50),
    specialty NVARCHAR(100),
    length_of_stay_hours INT
);


INSERT INTO dbo.Fact_Admissions (
    Admission_ID, Patient_ID, Date_Key, Ward_Key, Hospital_Key,
    admission_type, specialty, length_of_stay_hours
)
SELECT
    a.admission_id,
    a.patient_id,
    CONVERT(INT, CONVERT(CHAR(8), a.admission_datetime, 112)),
    w.Ward_Key,
    h.Hospital_Key,
    a.admission_type,
    a.specialty,
    a.length_of_stay_hours
FROM dbo.admissions a
JOIN dbo.Dim_Ward w ON a.ward = w.Ward
JOIN dbo.Dim_Hospital h ON a.hospital = h.Hospital_Name;


-- Step 3 — Load to your Power BI

-- Dealing with missing values?
-- Step 1 — Identify which key is failing
-- 1. Check Ward_Key mismatches
SELECT DISTINCT b.ward
FROM dbo.bed_inventory b
LEFT JOIN dbo.Dim_Ward w ON b.ward = w.Ward
WHERE w.Ward IS NULL;


-- 2. Check Hospital_Key mismatches
SELECT DISTINCT b.hospital
FROM dbo.bed_inventory b
LEFT JOIN dbo.Dim_Hospital h ON b.hospital = h.Hospital_Name
WHERE h.Hospital_Name IS NULL;


-- 3. Check Date_Key mismatches
SELECT DISTINCT CONVERT(INT, CONVERT(CHAR(8), b.datetime, 112)) AS Date_Key
FROM dbo.bed_inventory b
LEFT JOIN dbo.Dim_Date d ON CONVERT(INT, CONVERT(CHAR(8), b.datetime, 112)) = d.Date_Key
WHERE d.Date_Key IS NULL;



-- Step 2 — Fix the missing dimension values
-- Add missing wards
INSERT INTO dbo.Dim_Ward (Ward)
SELECT DISTINCT ward
FROM dbo.bed_inventory
WHERE ward NOT IN (SELECT Ward FROM dbo.Dim_Ward);


-- Add missing hospitals
INSERT INTO dbo.Dim_Hospital (Hospital_Name)
SELECT DISTINCT hospital
FROM dbo.bed_inventory
WHERE hospital NOT IN (SELECT Hospital_Name FROM dbo.Dim_Hospital);


-- Add missing dates
INSERT INTO dbo.Dim_Date (Date_Key, Full_Date)
SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), datetime, 112)),
    CAST(datetime AS DATE)
FROM dbo.bed_inventory
WHERE CONVERT(INT, CONVERT(CHAR(8), datetime, 112))
      NOT IN (SELECT Date_Key FROM dbo.Dim_Date);


-- Step 3 — Refresh Power BI
-- After fixing the dimension tables:
-- Refresh Power BI
-- The relationships will match
-- The error will disappear
-- Fact_BedInventory will load successfully