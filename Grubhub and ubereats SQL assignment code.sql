CREATE TEMP FUNCTION jsonObjectKeys(input STRING)
RETURNS Array<String>
LANGUAGE js AS """
return Object.keys(JSON.parse(input));
""";

WITH ranked_data AS (
SELECT
*,
ROW_NUMBER() OVER (PARTITION BY b_name, vb_name) AS row_num
FROM
`arboreal-vision-339901.take_home_v2.virtual_kitchen_grubhub_hours`
),
first_rows AS (
SELECT
b_name,
vb_name,
slug AS grubhub_slug,
JSON_EXTRACT_ARRAY(response, '$.availability_by_catalog.STANDARD_DELIVERY.schedule_rules') AS schedule_rules
FROM
ranked_data
WHERE
row_num = 1
),
grubhub_business_hours AS (
SELECT
b_name,
vb_name,
grubhub_slug,
SUM(
CASE
WHEN JSON_EXTRACT_SCALAR(schedule_rule, '$.from') < JSON_EXTRACT_SCALAR(schedule_rule, '$.to')
THEN TIMESTAMP_DIFF(
TIMESTAMP("2001-08-27 " || JSON_EXTRACT_SCALAR(schedule_rule, '$.to')),
TIMESTAMP("2001-08-27 " || JSON_EXTRACT_SCALAR(schedule_rule, '$.from')),
MINUTE
)
ELSE TIMESTAMP_DIFF(
TIMESTAMP("2001-08-28 " || JSON_EXTRACT_SCALAR(schedule_rule, '$.to')),
TIMESTAMP("2001-08-27 " || JSON_EXTRACT_SCALAR(schedule_rule, '$.from')),
MINUTE
)
END
) AS total_business_minutes
FROM
first_rows,
UNNEST(schedule_rules) AS schedule_rule
GROUP BY
b_name,
vb_name,
grubhub_slug
),
keys AS (
SELECT
TO_JSON_STRING(response.data.menus) AS menu_string,
response.data.menus as JSON_format,
b_name,
vb_name,
ARRAY_TO_STRING(jsonObjectKeys(TO_JSON_STRING(response.data.menus)), '') AS key,
slug AS ubereats_slug
FROM
`arboreal-vision-339901.take_home_v2.virtual_kitchen_ubereats_hours`
WHERE response.data.menus IS NOT NULL
),
ubereats_business_hours AS (
SELECT
b_name,
vb_name,
ubereats_slug,
(
((
CAST(SPLIT(IF(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$') = '00:00', '24:00', JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$')), ':')[OFFSET(0)] AS INT64) * 60 +
CAST(SPLIT(IF(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$') = '00:00', '24:00', JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$')), ':')[OFFSET(1)] AS INT64) -
CAST(SPLIT(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].startTime, '$'), ':')[OFFSET(0)] AS INT64) * 60 -
CAST(SPLIT(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].startTime, '$'), ':')[OFFSET(1)] AS INT64)
)
+ IF(
(
CAST(SPLIT(IF(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$') = '00:00', '24:00', JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$')), ':')[OFFSET(0)] AS INT64) * 60 +
CAST(SPLIT(IF(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$') = '00:00', '24:00', JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].endTime, '$')), ':')[OFFSET(1)] AS INT64) -
CAST(SPLIT(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].startTime, '$'), ':')[OFFSET(0)] AS INT64) * 60 -
CAST(SPLIT(JSON_EXTRACT_SCALAR(JSON_FORMAT[key].sections[0].regularHours[0].startTime, '$'), ':')[OFFSET(1)] AS INT64)
) *
(SELECT COUNT(*) FROM UNNEST(JSON_EXTRACT_ARRAY(JSON_FORMAT[key].sections[0].regularHours[0].daysBitArray)) AS day WHERE JSON_EXTRACT_SCALAR(day, '$') = 'true')
< 0,
24*60,
0
)) * (SELECT COUNT(*) FROM UNNEST(JSON_EXTRACT_ARRAY(JSON_FORMAT[key].sections[0].regularHours[0].daysBitArray)) AS day WHERE JSON_EXTRACT_SCALAR(day, '$') = 'true')
) as weekly_business_hours_in_minutes
FROM keys
)
SELECT
-- g.b_name,
-- g.vb_name,
g.grubhub_slug,
g.total_business_minutes AS grubhub_business_hours,
u.ubereats_slug,
u.weekly_business_hours_in_minutes AS ubereats_business_hours,
CASE
  WHEN g.total_business_minutes = u.weekly_business_hours_in_minutes THEN 'In Range'
  WHEN ABS(g.total_business_minutes - u.weekly_business_hours_in_minutes) <= 5 THEN 'Out of Range with 5 mins difference'
  ELSE 'Out of Range'
END AS is_out_range
FROM
grubhub_business_hours g
JOIN
ubereats_business_hours u
ON
g.b_name = u.b_name AND g.vb_name = u.vb_name
GROUP BY g.grubhub_slug,grubhub_business_hours,u.ubereats_slug,ubereats_business_hours, is_out_range