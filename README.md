# Collections Analytics & Data Architecture

## Project Overview

This project focuses on designing a data architecture for collections analytics, transforming raw operational data into reliable, business-ready insights to support recovery performance analysis and strategic decision-making.

The architecture follows a seven-layer data pipeline, with data quality and governance checks applied throughout the process. The final output is a Power BI executive dashboard designed to help leadership evaluate recovery trends, collection strategies, channel performance, and a proposed ₹10 crore investment allocation.

## Data Architecture

The pipeline consists of seven layers:

1. **Raw Ingestion** — Stores source data such as accounts, calls, payments, campaigns, digital activity, field data, and Promise-to-Pay (PTP) records in their original form.

2. **Staging & Validation** — Validates schemas, data types, mandatory fields, and referential integrity while preserving the original raw data.

3. **Data Cleaning** — Handles duplicate payments and calls, resolves account and agent IDs, standardizes timestamps to the Asia/Kolkata timezone, manages missing values, and applies historical corrections.

4. **Golden Data (Canonical Layer)** — Establishes a trusted source of truth for accounts, customers, agents, deduplicated payments, and account-month facts.

5. **Feature Engineering** — Creates business-ready features related to risk, days past due (DPD), campaigns, channels, agents, contacts, PTPs, targeting, and portfolio attributes.

6. **Metrics & Aggregations** — Produces analytical measures such as recovery, recovery per targeted account, contact rate, recovery per call, PTP creation rate, channel conversion, strategy performance, and return on investment (ROI).

7. **Power BI Dashboard** — Presents executive-level insights into recovery trends, performance drivers, collection strategies, channel effectiveness, data quality, and the ₹10 crore investment decision.

## Data Quality & Governance

Data quality and governance operate across every layer of the pipeline through:

- **Data Contracts:** Schema, data type, mandatory field, and acceptance-rule validation.
- **Keys & Integrity:** Primary and foreign key checks, referential integrity, and uniqueness validation.
- **Data Quality Checks:** Duplicate detection, missing-value checks, and range and format validation.
- **Lineage & Audit:** End-to-end data lineage, audit trails, and change tracking.
- **Incremental Processing:** Daily incremental loads, watermarking, and handling of late-arriving data.
- **Backfills & Corrections:** Historical backfills, reprocessing, and versioning.
- **Monitoring & Alerts:** Pipeline monitoring, data quality alerts, anomaly detection, and SLA monitoring.

## Feedback Loop

Insights from the executive dashboard feed back into collection targeting, strategy refinement, and data quality improvements. This creates a continuous improvement cycle across analytics, operations, and governance.

## Business Objectives

- Establish a trusted and consistent source of collections data.
- Improve the reliability of recovery and operational performance metrics.
- Evaluate collection strategies and channel effectiveness.
- Support data-driven resource allocation and investment decisions.
- Provide leadership with actionable insights through executive reporting.

## Architecture Flow

**Raw → Staging & Validation → Clean → Golden → Feature → Metrics & Aggregations → Power BI Dashboard**

Data quality and governance span all layers, while dashboard insights inform ongoing improvements to the pipeline and collection strategies.

## Tools & Technologies

- **Power BI** — Executive dashboard and business reporting.
- **SQL and Python** — Relevant for implementing data transformation, validation, and analytical workflows where included in the project implementation.

## Project Deliverable

The primary deliverable documented here is the collections analytics data architecture, describing the movement of data from raw ingestion to decision-ready reporting.

Refer to `Collections_Analytics_Data_Architecture.pdf` for the architecture document.

---

*This project demonstrates a structured approach to data architecture, data quality, analytical metric design, and business-focused reporting for collections analytics.*
