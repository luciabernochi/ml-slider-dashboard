-- Summary Home — Clicks por placement
-- Placements: QA, Tabs, DA, RH, MS, THB
-- Granularidad: día, semana, mes
-- Plataforma: solo iOS y Android (excepto RH: solo existe en esas plataformas)
-- Ventana: 2026-01-01 hasta fin de la última semana completa

WITH

taps_QA AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'QA'                         AS placement,
    COUNT(usr.uid)               AS clicks
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
                AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND path = '/home/tap'
    AND JSON_VALUE(event_data, '$.c_id') = '/home/quick-access'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
  GROUP BY 1, 2, 3, 4
),

taps_TABS AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'Tabs'                       AS placement,
    COUNT(usr.uid)               AS clicks
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
                AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND path = '/home/tap'
    AND JSON_VALUE(event_data, '$.c_id') = '/home/tabs'
    AND JSON_EXTRACT_SCALAR(event_data, '$.tab.title') IS NOT NULL
    AND JSON_EXTRACT_SCALAR(event_data, '$.tab.title') != 'Todo'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
  GROUP BY 1, 2, 3, 4
),

taps_DA AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'DA'                         AS placement,
    COUNT(usr.uid)               AS clicks
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
                AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND path = '/home/tap'
    AND JSON_VALUE(event_data, '$.c_id') = '/home/dynamic_access'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
  GROUP BY 1, 2, 3, 4
),

clicks_RH AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'RH'                         AS placement,
    COUNT(*)                     AS clicks
  FROM `meli-bi-data.WHOWNER.BT_RH_CARD_CLICKS`
  WHERE ds BETWEEN '2026-01-01'
                AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND SITE_ID = 'MLA'
    AND PLACEMENT_TYPE = 'HOME'
  GROUP BY 1, 2, 3, 4
),

clicks_MS AS (
  SELECT
    EVENT_LOCAL_DT               AS ds,
    DATE_TRUNC(EVENT_LOCAL_DT, WEEK(MONDAY)) AS week,
    DATE_TRUNC(EVENT_LOCAL_DT, MONTH)        AS month,
    'MS'                         AS placement,
    SUM(CLICKS_QTY)              AS clicks
  FROM `meli-bi-data.WHOWNER.BT_ADS_DISP_METRICS_DAILY`
  WHERE EVENT_LOCAL_DT BETWEEN '2026-01-01'
                           AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND SIT_SITE_ID = 'MLA'
    AND PLACEMENT LIKE '%MAIN-SLIDER_HOME%'
    AND DEVICE_PLATFORM IN ('/mobile/ios', '/mobile/android')
  GROUP BY 1, 2, 3, 4
),

clicks_THB AS (
  SELECT
    EVENT_LOCAL_DT               AS ds,
    DATE_TRUNC(EVENT_LOCAL_DT, WEEK(MONDAY)) AS week,
    DATE_TRUNC(EVENT_LOCAL_DT, MONTH)        AS month,
    'THB'                        AS placement,
    SUM(CLICKS_QTY)              AS clicks
  FROM `meli-bi-data.WHOWNER.BT_ADS_DISP_METRICS_DAILY`
  WHERE EVENT_LOCAL_DT BETWEEN '2026-01-01'
                           AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND SIT_SITE_ID = 'MLA'
    AND PLACEMENT LIKE '%THB%'
    AND DEVICE_PLATFORM IN ('/mobile/ios', '/mobile/android')
  GROUP BY 1, 2, 3, 4
)

SELECT * FROM taps_QA
UNION ALL
SELECT * FROM taps_TABS
UNION ALL
SELECT * FROM taps_DA
UNION ALL
SELECT * FROM clicks_RH
UNION ALL
SELECT * FROM clicks_MS
UNION ALL
SELECT * FROM clicks_THB
ORDER BY placement, ds
