-- Summary Home — Usuarios únicos por placement y granularidad
-- Placements: HOME, HOME_SEARCH, QA, Tabs, DA, RH, MS, THB
-- Identificador: uid (device-level)
-- Granos: day, week, month — calculados directamente en BQ para COUNT DISTINCT correcto
-- Plataforma: solo iOS y Android
-- Ventana: 2026-01-01 hasta fin de la última semana completa
-- HOME_SEARCH: usuarios que vinieron al home Y realizaron una búsqueda el mismo día

WITH

-- ─── Raw events por placement ─────────────────────────────────────────────────

raw_HOME AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'HOME'                       AS placement,
    usr.uid                      AS uid
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND bu = 'mercadolibre'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
    AND path = '/home'
    AND type = 'view'
),

raw_QA AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'QA'                         AS placement,
    usr.uid                      AS uid
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND path = '/home/tap'
    AND JSON_VALUE(event_data, '$.c_id') = '/home/quick-access'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
),

raw_TABS AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'Tabs'                       AS placement,
    usr.uid                      AS uid
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND path = '/home/tap'
    AND JSON_VALUE(event_data, '$.c_id') = '/home/tabs'
    AND JSON_EXTRACT_SCALAR(event_data, '$.tab.title') IS NOT NULL
    AND JSON_EXTRACT_SCALAR(event_data, '$.tab.title') != 'Todo'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
),

raw_DA AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'DA'                         AS placement,
    usr.uid                      AS uid
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND path = '/home/tap'
    AND JSON_VALUE(event_data, '$.c_id') = '/home/dynamic_access'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
),

raw_SEARCH AS (
  SELECT DISTINCT
    ds,
    usr.uid AS uid
  FROM `meli-bi-data.MELIDATA.TRACKS`
  WHERE ds BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND site = 'MLA'
    AND bu = 'mercadolibre'
    AND device.platform IN ('/mobile/ios', '/mobile/android')
    AND path = '/search'
    AND type = 'view'
),

raw_HOME_SEARCH AS (
  SELECT
    h.ds,
    h.week,
    h.month,
    'HOME_SEARCH' AS placement,
    h.uid
  FROM raw_HOME h
  INNER JOIN raw_SEARCH s ON s.ds = h.ds AND s.uid = h.uid
),

raw_RH AS (
  SELECT
    ds,
    DATE_TRUNC(ds, WEEK(MONDAY)) AS week,
    DATE_TRUNC(ds, MONTH)        AS month,
    'RH'                         AS placement,
    UID_ID                       AS uid
  FROM `meli-bi-data.WHOWNER.BT_RH_CARD_CLICKS`
  WHERE ds BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND SITE_ID = 'MLA'
    AND PLACEMENT_TYPE = 'HOME'
),

raw_MS_THB AS (
  SELECT
    DS_DT                                    AS ds,
    DATE_TRUNC(DS_DT, WEEK(MONDAY))          AS week,
    DATE_TRUNC(DS_DT, MONTH)                 AS month,
    CASE
      WHEN PLACEMENT IN ('MAIN-SLIDER_HOME_ANDROID', 'MAIN-SLIDER_HOME_IOS') THEN 'MS'
      WHEN PLACEMENT IN ('THB_HOME_ANDROID_1', 'THB_HOME_IOS_1')             THEN 'THB'
    END                                      AS placement,
    USER.USER_UID                            AS uid
  FROM `meli-bi-data.WHOWNER.BT_ADS_DISP_EVENTS`
  WHERE DS_DT BETWEEN '2026-01-01'
    AND DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 DAY)
    AND SIT_SITE_ID = 'MLA'
    AND EVENT_NAME = 'clicks'
    AND PLACEMENT IN (
      'MAIN-SLIDER_HOME_ANDROID', 'MAIN-SLIDER_HOME_IOS',
      'THB_HOME_ANDROID_1',       'THB_HOME_IOS_1'
    )
),

-- ─── Union de todos los placements ────────────────────────────────────────────

all_raw AS (
  SELECT * FROM raw_HOME
  UNION ALL SELECT * FROM raw_HOME_SEARCH
  UNION ALL SELECT * FROM raw_QA
  UNION ALL SELECT * FROM raw_TABS
  UNION ALL SELECT * FROM raw_DA
  UNION ALL SELECT * FROM raw_RH
  UNION ALL SELECT * FROM raw_MS_THB
),

-- ─── Agregación por granularidad ──────────────────────────────────────────────

daily AS (
  SELECT
    'day'                        AS grain,
    CAST(ds    AS STRING)        AS period,
    placement,
    COUNT(DISTINCT uid)          AS unique_users
  FROM all_raw
  GROUP BY 1, 2, 3
),

weekly AS (
  SELECT
    'week'                       AS grain,
    CAST(week  AS STRING)        AS period,
    placement,
    COUNT(DISTINCT uid)          AS unique_users
  FROM all_raw
  GROUP BY 1, 2, 3
),

monthly AS (
  SELECT
    'month'                      AS grain,
    CAST(month AS STRING)        AS period,
    placement,
    COUNT(DISTINCT uid)          AS unique_users
  FROM all_raw
  GROUP BY 1, 2, 3
)

-- ─── Output final ─────────────────────────────────────────────────────────────

SELECT * FROM daily
UNION ALL SELECT * FROM weekly
UNION ALL SELECT * FROM monthly
ORDER BY grain, placement, period
