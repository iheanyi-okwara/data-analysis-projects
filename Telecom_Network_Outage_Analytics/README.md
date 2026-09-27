\# 📡 Telecom Network Outage \& Reliability Analytics



\## 📌 Project Overview



This project presents an end-to-end analysis of telecom network outage and operational performance across \*\*500 network sites, 5 vendors, and 12 UK regions\*\*.



The analysis evaluates \*\*5,000 network outage incidents\*\* alongside alarm logs, SLA performance, customer complaints, trouble tickets, and maintenance activity to identify the operational factors contributing to network disruption and service performance.



The project combines \*\*SQL, Power BI, DAX, data modelling, data validation, and business analysis\*\* to transform operational telecom data into actionable insights for network operations and vendor management.



\*\*Data Analyst:\*\* Iheanyi Okwara



\*\*Reporting Period:\*\* FY2024–FY2025



\---



\## 🎯 Business Problem



Network outages affect service availability, customer experience, operational costs, and SLA performance.



The analysis was designed to answer several key business questions:



\- What are the main causes of network outages?

\- Which regions and sites experience the greatest outage burden?

\- How does network reliability vary across vendors?

\- What factors contribute most to SLA non-compliance?

\- How effectively are network alarms detected and automatically resolved?

\- How are network reliability issues reflected in customer complaints and trouble tickets?

\- How effectively is maintenance activity supporting network reliability?

\- Where should operational improvement efforts be prioritised?



\---



\## 🗂️ Dataset



The analytical model contains multiple fact and dimension tables covering network operations.



| Dataset | Records |

|---|---:|

| Outage Incidents | 5,000 |

| Alarm Logs | 15,000 |

| SLA Assessments | 3,456 |

| Trouble Tickets | 3,000 |

| Customer Complaints | 2,000 |

| Maintenance Activities | 1,000 |

| Network Sites | 500 |

| Vendors | 5 |

| Root Causes | 9 |



The model also includes date, site, vendor, customer-segment, and root-cause dimensions.



\---



\## 🛠️ Tools \& Technologies



\- \*\*SQL / T-SQL\*\* – data validation, quality checks, KPI analysis and exploratory analysis

\- \*\*Power BI\*\* – dashboard development and interactive reporting

\- \*\*DAX\*\* – KPI calculations and analytical measures

\- \*\*Data Modelling\*\* – fact/dimension relationships and date modelling

\- \*\*PowerPoint\*\* – executive presentation and business recommendations

\- \*\*Git \& GitHub\*\* – version control and project documentation



\---



\## 🔍 Data Validation \& Quality Checks



Before dashboard development, the data was validated for:



\- Duplicate records

\- Orphan foreign keys

\- Missing dimension relationships

\- Invalid outage timestamps

\- Outage-duration inconsistencies

\- Date coverage

\- SLA status consistency

\- Alarm-to-incident relationships



No significant duplicate or orphan-key issues were identified in the primary analytical relationships.



The reporting analysis focuses on \*\*2024–2025\*\*, excluding the partial January 2026 period from comparative reporting.



\---



\# 📊 Executive Performance Overview



!\[Executive Overview](screenshots/01\_Executive\_Overview.png)



\### Key KPIs



| KPI | Result |

|---|---:|

| Total Outages | 5,000 |

| Avg. Outage Duration | 36.6 min |

| Total Downtime | 3,049.2 hrs |

| Aggregated Customer Impact | 1,082,653 |

| Incident-Level SLA Breach Rate | 19.58% |

| Avg. First Alarm Time | 9.64 min |



Outage volumes remained relatively stable throughout the reporting period, while differences between vendors became more apparent through restoration time and SLA performance rather than outage volume alone.



\---



\# 🔧 Root Cause Analysis



!\[Root Cause Analysis](screenshots/02\_Root\_Cause\_Analysis.png)



\*\*Hardware Failure\*\* emerged as the most significant network reliability issue.



It accounted for:



\- \*\*1,076 outages\*\*

\- \*\*826.5 hours of downtime\*\*

\- \*\*46.1 minutes average outage duration\*\*

\- Approximately \*\*229.1K aggregated customer impact\*\*

\- \*\*171 formal SLA non-compliant assessments\*\*



Hardware Failure therefore represents the strongest cross-metric operational improvement opportunity identified in the analysis.



The three largest outage causes — \*\*Hardware Failure, Power Failure, and Software Failure\*\* — account for approximately \*\*53% of all network outages\*\*.



\---



\# 🌍 Regional \& Site Performance



!\[Site \& Vendor Performance](screenshots/03\_Site\_Vendor\_Performance.png)



London recorded:



\- \*\*1,308 outages\*\*

\- Approximately \*\*827.5 hours of downtime\*\*

\- Around \*\*26% of all network outages\*\*

\- Around \*\*27% of total network downtime\*\*



This makes London a clear regional outlier requiring deeper investigation into potential contributing factors.



\### Site-Level Analysis



!\[Site-Level Analysis](screenshots/04\_Site\_Level\_Analysis.png)



Site performance also varied depending on the metric used.



\- \*\*Sco0142\*\* recorded the highest total downtime.

\- \*\*Wes0476\*\* recorded the highest aggregated customer impact.

\- \*\*Lon0136\*\* and \*\*Sco0052\*\* appeared on both the high-downtime and high-customer-impact leaderboards.



These sites provide useful candidates for targeted operational investigation.



\---



\# 🏢 Vendor Performance



Vendor outage volumes were relatively close, but reliability outcomes differed.



| Vendor | Avg. Outage Duration | Incident SLA Breach Rate |

|---|---:|---:|

| Ericsson | 38 min | 20.91% |

| Cisco | 37 min | 19.76% |

| ZTE | 37 min | 19.09% |

| Nokia | 36 min | 19.60% |

| Huawei | 36 min | 18.48% |



Ericsson recorded the longest average outage duration and highest incident-level SLA breach rate.



The analysis therefore demonstrates why vendor performance should be assessed using multiple reliability measures rather than outage volume alone.



\---



\# ⏱️ SLA \& Service Performance



!\[SLA Performance](screenshots/05\_SLA\_Service\_Performance.png)



Formal SLA assessments produced:



\- \*\*3,456 assessments\*\*

\- \*\*2,782 compliant assessments\*\*

\- \*\*674 non-compliant assessments\*\*

\- \*\*80.50% compliance rate\*\*

\- \*\*37.1 min average resolution time\*\*



Hardware Failure produced the largest number of formal SLA non-compliances at \*\*171\*\*.



> \*\*Important:\*\* Formal SLA assessment compliance and incident-level SLA breach rate are separate metrics with different denominators and should not be interpreted as the same KPI.



\---



\# 🚨 Alarm \& Detection Performance



!\[Alarm Performance](screenshots/07\_Alarm\_Detection\_Performance.png)



The network generated:



\- \*\*15,000 alarms\*\*

\- \*\*4,750 incidents with associated alarms\*\*

\- \*\*4,542 auto-resolved alarms\*\*

\- \*\*30.28% auto-resolution rate\*\*

\- \*\*9.64 min average first-alarm time\*\*



Critical alarms recorded the longest average first-alarm time:



| Severity | First Alarm Time |

|---|---:|

| Critical | 11.2 min |

| Major | 9.1 min |

| Minor | 7.7 min |

| Info | 6.6 min |



The metric is described as \*\*First Alarm Time\*\* rather than conventional MTTD because the available alarm data does not contain pre-incident alarms required to calculate a conventional pre-incident detection metric.



\---



\# 👥 Customer \& Service Impact



!\[Customer Service Impact](screenshots/09\_Customer\_Service\_Impact.png)



Customer-service records included:



\- \*\*2,000 complaints\*\*

\- \*\*1,691 resolved complaints\*\*

\- \*\*84.55% complaint resolution rate\*\*

\- \*\*3,000 trouble tickets\*\*

\- \*\*610 escalated tickets\*\*

\- \*\*20.33% escalation rate\*\*



\### Ticket Resolution Time



| Priority | Avg. Resolution Time |

|---|---:|

| High | 46.3 min |

| Medium-High | 22.6 min |

| Medium | 11.2 min |

| Low | 3.6 min |



High-priority tickets therefore required substantially more resolution time than lower-priority tickets.



Escalation rates, however, remained relatively close across priority groups, ranging from approximately \*\*18.9% to 20.9%\*\*.



\---



\# 🛠️ Maintenance \& Reliability



!\[Maintenance Analysis](screenshots/11\_Maintenance\_Reliability.png)



Maintenance performance included:



\- \*\*1,000 maintenance activities\*\*

\- \*\*947 completed activities\*\*

\- \*\*94.70% completion rate\*\*

\- Approximately \*\*£1.07M total maintenance cost\*\*

\- \*\*3.5 hours average maintenance duration\*\*

\- \*\*53 incomplete activities\*\*



Emergency maintenance recorded the lowest completion rate at \*\*91.8%\*\*, compared with \*\*95.1% for Planned\*\* and \*\*95.5% for Corrective maintenance\*\*.



Vendor maintenance performance also demonstrated that higher expenditure did not automatically correspond with higher completion rates.



\---



\# 💡 Key Business Insights



1\. \*\*Hardware Failure is the strongest reliability improvement opportunity\*\*, leading outage frequency, downtime, average duration, customer impact and formal SLA non-compliance.



2\. \*\*Network disruption is geographically concentrated\*\*, with London accounting for approximately one-quarter of outages and downtime.



3\. \*\*Vendor reliability cannot be judged by outage volume alone.\*\* Restoration time, SLA performance and maintenance outcomes provide important additional context.



4\. \*\*Alarm automation remains limited\*\*, with only 30.28% of alarms automatically resolved and Critical alarms recording the longest first-alarm time.



5\. \*\*High-priority trouble tickets require substantially longer resolution times\*\*, despite escalation rates remaining relatively similar across priority groups.



6\. \*\*Emergency maintenance has the weakest completion performance\*\*, creating an opportunity to investigate whether more work can be moved toward planned/preventive maintenance.



\---



\# 🎯 Recommendations



Based on the analysis, the following actions are recommended:



1\. \*\*Strengthen hardware reliability\*\* through targeted asset-condition assessment, preventive replacement and repeat-failure monitoring.



2\. \*\*Investigate London's outage concentration\*\* at site level before implementing targeted regional remediation.



3\. \*\*Introduce multi-KPI vendor scorecards\*\* covering restoration time, SLA compliance, maintenance completion, outage impact and cost efficiency.



4\. \*\*Improve Critical-alarm detection and automation\*\* through threshold review, event correlation, alert routing and automated triage.



5\. \*\*Investigate formal SLA non-compliance\*\*, particularly Hardware Failure and recorded violation reasons.



6\. \*\*Review high-priority ticket workflows\*\* to identify delays in assignment, escalation and specialist intervention.



7\. \*\*Improve emergency-maintenance readiness\*\* and identify suitable activities for conversion to planned/preventive maintenance.



8\. \*\*Measure maintenance outcomes alongside expenditure\*\* using metrics such as cost per completed activity and repeat failures.



\---



\# 🗺️ Implementation Roadmap



\### 0–3 Months — Diagnose \& Stabilise



\- Audit high-impact and repeat-offender sites

\- Review vendor SLA performance

\- Conduct detailed London root-cause investigation

\- Review Critical-alarm thresholds and routing



\### 3–9 Months — Pilot \& Improve



\- Pilot automated alarm triage and remediation

\- Introduce vendor performance scorecards

\- Pilot targeted preventive maintenance

\- Identify emergency work suitable for conversion to planned maintenance



\### 9–18 Months — Scale \& Optimise



\- Scale successful hardware-reliability interventions

\- Roll out vendor scorecards across the network

\- Expand proven alarm-automation processes

\- Re-baseline SLA and maintenance targets using post-intervention performance



\---



\# 📁 Repository Structure



```text

Telecom\_Network\_Outage\_Analytics/

├── README.md

├── data/

├── sql/

├── powerbi/

├── presentation/

└── screenshots/

```



\---



\# 📎 Project Deliverables



\- SQL analysis and data-quality validation

\- Power BI analytical dashboard

\- DAX KPI measures

\- Executive PowerPoint presentation

\- Business findings and recommendations

\- Implementation roadmap



\---



\## 👤 Data Analyst



\*\*Iheanyi Okwara\*\*



Data Analyst | SQL | Power BI | Python | Excel | Business Intelligence



\---



\## 📌 Project Status



\*\*Completed\*\*



The project demonstrates an end-to-end analytics workflow from \*\*data validation and modelling through dashboard development, analytical interpretation, business recommendations and executive communication\*\*.

