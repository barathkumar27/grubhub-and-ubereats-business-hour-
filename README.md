# grubhub-and-ubereats-business-hour

SQL Query and Result for Grubhub and Ubereats Business Hours

**Description**
This repository contains a SQL query and its resulting Excel sheet for analyzing business hours of Grubhub and Ubereats.

**Files**
query.sql: The SQL query used to extract business hours data from Grubhub and Ubereats.
result.xlsx: The resulting Excel sheet containing the business hours data.

**Query Explanation**
The SQL query joins data from Grubhub and Ubereats to compare business hours. It calculates the total business minutes for each restaurant and categorizes them as "In Range", "Out of Range", or "Out of Range with 5 mins difference".

**Result Explanation**
The resulting Excel sheet contains the following columns:
grubhub_slug
grubhub_business_hours
ubereats_slug
ubereats_business_hours
is_out_range
