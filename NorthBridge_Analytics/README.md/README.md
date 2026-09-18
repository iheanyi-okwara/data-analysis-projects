# NorthBridge Health Services — Support Performance Analytics

An end-to-end data analytics portfolio project analysing support ticket performance across a fictional UK healthcare administration and operational support organisation.

The project combines **SQL, Power BI, DAX, data modelling, KPI development, validation, and an interactive React/TypeScript web application** to transform operational support data into management-focused insights.

> **Portfolio Project:** NorthBridge Health Services is a fictional organisation and the dataset used in this project is synthetic. No real patient, clinical, employee, client, or operational data is included.

---

## Live Interactive Dashboard

Explore the complete interactive analytics application:

**[View NorthBridge Health Analytics Dashboard](https://northbridge-health-analytics.bolt.host/)**

The web application provides interactive views covering ticket demand, SLA performance, backlog ageing, escalations, agent workload, client activity, analytical findings, recommendations, and project methodology.

---

## Project Overview

NorthBridge Health Services Ltd is a fictional UK-based healthcare administration and operational support organisation used as the business context for this portfolio case study.

The objective of the project was to analyse support-ticket activity and develop a structured reporting solution that gives management visibility into:

- Ticket demand and operational workload
- Ticket status and priority distribution
- SLA performance
- Backlog volume and ageing
- Escalation patterns
- Agent workload
- Client activity
- Operational trends and areas requiring further investigation

The analysis covers the period **1 January 2023 to 31 March 2025**, with **31 March 2025** used as the reporting date.

---

## Dataset

The final analysis-ready dataset contains:

| Metric | Value |
|---|---:|
| Total tickets | 3,500 |
| Dataset columns | 46 |
| Unique Ticket IDs | 3,500 |
| Distinct agents | 114 |
| Distinct clients | 72 |
| Analysis period | Jan 2023 – Mar 2025 |
| Reporting date | 31 Mar 2025 |

The analytical grain is:

> **One row per support ticket**

Ticket IDs, Agent IDs and Client IDs are used as analytical keys, while descriptive names are retained as display labels.

This distinction was important because duplicate display names existed in the source data and could otherwise produce incorrect aggregations.

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| **SQL** | Data exploration, quality checks, transformation and analytical querying |
| **Power BI** | Data modelling, KPI development and interactive dashboard development |
| **DAX** | Measures and business calculations |
| **Power Query** | Data preparation and transformation within Power BI |
| **React / TypeScript** | Interactive portfolio web application |
| **Bolt** | Development and deployment of the web presentation layer |
| **Git / GitHub** | Version control and portfolio documentation |

---

## Analytical Workflow

The project followed an end-to-end analytics workflow:

1. **Business Understanding**
2. **Data Exploration**
3. **Data Quality Assessment**
4. **SQL Analysis**
5. **Data Modelling**
6. **KPI Development**
7. **Power BI Dashboard Development**
8. **Validation & Insights**
9. **Interactive Portfolio Presentation**

The analytical calculations were developed and validated before being presented through the web application.

---

## SQL Analysis

SQL was used to explore and analyse the support-ticket data before dashboard development.

The analysis was organised around six main areas:

### 1. Data Exploration & Quality
- Dataset structure
- Row counts
- Unique identifiers
- Missing values
- Duplicate checks
- Category distributions
- Data consistency

### 2. Ticket Performance
- Ticket volumes
- Status distribution
- Priority distribution
- Ticket categories
- Support channels
- Monthly trends

### 3. SLA & Backlog Performance
- SLA compliance
- SLA breaches
- Resolution performance
- Open tickets
- Tickets past SLA
- Backlog ageing

### 4. Escalation & Agent Analysis
- Escalated tickets
- Escalation rates
- Priority-level escalation
- Agent workload
- Hub-level activity

### 5. Client & Business Analysis
- Client ticket volumes
- SLA performance by client
- Escalation activity
- Contract-tier analysis
- Open-ticket activity

### 6. KPI Dataset & Power BI Preparation
- Analysis-ready fields
- KPI validation
- Reporting measures
- Dashboard preparation

---

## Key Performance Indicators

The project tracks several operational KPIs.

| KPI | Result |
|---|---:|
| Total Tickets | 3,500 |
| SLA Breaches | 754 |
| SLA Breach Rate | 21.54% |
| SLA Met Rate | 78.46% |
| Escalated Tickets | 464 |
| Escalation Rate | 13.26% |
| Operationally Open Tickets | 199 |
| Open Tickets Past SLA | 196 |
| Critical Open Backlog | 11 |
| Average First Response Time | 5.1 hours |
| Average Resolution Time | 40.9 hours |

Rates are calculated using the appropriate eligible population for each KPI rather than assuming a universal denominator.

---

## SLA & Backlog Analysis

The analysis identified **754 SLA breaches**, representing a **21.54% breach rate** across the dataset.

Of the **199 operationally open tickets**, **196 were past SLA** as of the reporting date.

Backlog ageing also showed:

- **170 of 199 open tickets** were aged 14 days or more
- This represents **85.43% of the open backlog**
- Average open-ticket age: **261.3 days**
- Median open-ticket age: **176.54 days**
- Critical open backlog: **11 tickets**

These results highlight areas for operational review without assuming causes that are not supported by the dataset.

---

## Ticket Demand

Ticket demand analysis showed that:

- **Appointment Change** was the largest ticket category with **1,200 tickets**
- This represented approximately **34.29%** of all tickets
- **Email** was the largest support channel with **1,221 tickets**
- Email represented approximately **34.89%** of total ticket volume
- **258 tickets** were classified as P1 Critical

The analysis provides visibility into where support demand is concentrated and where additional operational investigation may be useful.

---

## Escalation & Agent Analysis

The dataset contains **114 distinct agents**.

Key findings include:

- **464 tickets** were escalated
- Overall escalation rate: **13.26%**
- Average ticket volume per agent: **30.70**
- Highest ticket volume for an individual agent: **71 tickets**
- P1 Critical escalation rate: **18.22%**

Agent-level analysis uses **AssignedAgentID** as the grouping key rather than agent name.

This prevented two different agents sharing the display name **Parveen Campbell** from being incorrectly combined into one analytical record.

Agent workload and escalation measures are presented as operational indicators and are **not treated as employee performance ratings**.

---

## Client Analysis

The dataset contains **72 distinct Client IDs**.

Key client-level findings include:

- Average ticket volume per client: **48.61**
- Highest-volume client: **Bridgeway Private Hospital**
- Highest individual client ticket volume: **67 tickets**

Client analysis also uses **ClientID** as the analytical key because multiple Client IDs can share the same descriptive ClientName.

This prevents similarly named clients from being incorrectly aggregated.

---

## Contract Tier Analysis

Ticket activity was also analysed by contract tier.

| Contract Tier | Tickets | SLA Breach Rate | Escalation Rate | Open Tickets |
|---|---:|---:|---:|---:|
| Standard | 1,662 | 21.90% | 13.60% | 97 |
| Premium | 1,295 | 21.39% | 13.05% | 64 |
| Enterprise | 543 | 20.81% | 12.71% | 38 |

These figures describe observed differences in the synthetic dataset and should not be interpreted as evidence that contract tier itself caused the differences.

---

## Power BI Dashboard

Power BI was used to transform the analytical outputs into an interactive business intelligence dashboard.

The dashboard covers:

- Executive KPIs
- Ticket volume and distribution
- SLA performance
- Backlog analysis
- Agent workload
- Escalation analysis
- Client activity
- Operational trends

DAX measures were used to calculate and validate key business metrics while maintaining filter context across the report.

---

## Interactive Web Application

A separate interactive web application was developed as the presentation layer for the portfolio project using **React and TypeScript** and deployed using **Bolt**.

### Application Sections

1. Overview
2. Executive Dashboard
3. Ticket Analysis
4. SLA & Backlog
5. Agent & Escalation
6. Client Analysis
7. Insights & Recommendations
8. Methodology

### Live Application

**[Launch the NorthBridge Health Analytics Dashboard](https://northbridge-health-analytics.bolt.host/)**

The web application complements the Power BI analysis by presenting the project as an accessible interactive case study.

---

## Key Analytical Findings

Several findings emerged from the analysis:

- **21.54%** of tickets breached SLA.
- **98.49%** of the operationally open backlog was already past SLA at the reporting date.
- **85.43%** of open tickets were aged at least 14 days.
- P1 Critical tickets had an **18.22% escalation rate**.
- Appointment Change accounted for **34.29%** of ticket volume.
- Email accounted for **34.89%** of ticket volume.
- Manchester recorded the largest ticket volume among the operational hubs.
- Agent and client analysis required ID-based grouping to avoid errors caused by duplicate descriptive names.

These observations identify areas for further operational investigation rather than establishing unsupported causal relationships.

---

## Recommendations

Based on the observed patterns, the project proposes several areas for management consideration:

- Review the aged open-ticket backlog and prioritise tickets already beyond SLA.
- Investigate recurring causes associated with SLA breaches.
- Examine workflows surrounding high-volume ticket categories.
- Review escalation patterns, particularly for critical-priority tickets.
- Assess workload distribution across agents and operational hubs.
- Monitor high-volume clients and recurring support requirements.
- Maintain ID-based analytical models to protect reporting accuracy.
- Introduce regular KPI monitoring and backlog-ageing reviews.

These recommendations are analytical suggestions based on the synthetic dataset and are not intended as prescriptive operational decisions.

---

## Data Quality & Validation

Validation was an important part of the project.

Checks included:

- Confirming **3,500 rows**
- Confirming **3,500 unique Ticket IDs**
- Checking duplicate identifiers
- Reviewing missing values
- Validating status and priority distributions
- Confirming KPI calculations
- Checking SLA denominators
- Validating agent-level grouping
- Validating client-level grouping
- Reviewing backlog-age calculations
- Cross-checking dashboard values against analytical outputs

Missing values were handled according to analytical context. For example, tickets without valid response or resolution timestamps were excluded from the respective average-time calculations rather than being treated as zero.

---

## Repository Structure

```text
NorthBridge_Analytics/
│
├── data/
│   └── northbridge_ticket_analysis.csv
│
├── powerbi/
│   └── NorthBridge_Health_Services_Dashboard.pbix
│
├── screenshots/
│
├── sql/
│   └── NorthBridge_Health_Services_SQL_Analysis_Streamlined.sql
│
├── web-app/
│
└── README.md
```

---

## Screenshots

Dashboard screenshots will be included in the `screenshots/` directory to provide a quick visual overview of the analysis.

Recommended views include:

- Overview
- Executive Dashboard
- SLA & Backlog
- Agent & Escalation
- Client Analysis
- Insights & Recommendations

---

## Explore the Project

### Interactive Dashboard
**[NorthBridge Health Analytics](https://northbridge-health-analytics.bolt.host/)**

### SQL
See the [`sql/`](./sql/) directory for the SQL analysis.

### Dataset
See the [`data/`](./data/) directory for the analysis-ready portfolio dataset.

### Power BI
See the [`powerbi/`](./powerbi/) directory for the Power BI project file.

### Screenshots
See the [`screenshots/`](./screenshots/) directory for selected dashboard views.

---

## Limitations

This project has several important limitations:

- The organisation and dataset are fictional/synthetic.
- Results demonstrate analytical methodology rather than actual organisational performance.
- Observed relationships should not be interpreted as causal relationships.
- No external operational benchmarks were assumed.
- Recommendations would require further operational validation before implementation in a real organisation.
- The project does not contain real patient or clinical information.

---

## Author

**Iheanyi Okwara**

Data Analyst | SQL | Power BI | Python | Excel | Data Visualisation

---

*This project was developed for data analytics portfolio and learning purposes using synthetic data.*