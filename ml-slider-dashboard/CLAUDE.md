# ML Slider Dashboard — Contexto del Proyecto

## Qué es esto
Dashboard ejecutivo estático para seguimiento de métricas de placements publicitarios de MercadoLibre.
Repo GitHub: `Nikocan96/ml-slider-dashboard` · GitHub Pages sirve desde `/docs`.

## Stack
- HTML/CSS/JS puro (sin frameworks, sin build tools)
- Chart.js 4.4.0 (líneas, tendencia semanal)
- Font: Proxima Nova (CDN)
- ES Modules nativos (`type="module"`)
- Para desarrollo local: Live Server (VS Code extension, botón "Go Live")

## Arquitectura de datos
```
n8n (cada 29 min) → BigQuery → Base64 JSON → docs/data.json → GitHub Pages → Dashboard
```
- El workflow n8n está en `n8n-workflow.json` (raíz del repo)
- El dashboard hace `fetch('../data.json')` al cargar y se auto-refresca cada 5 min
- **⚠️ Reemplazar `{{YOUR_GITHUB_TOKEN}}` en n8n-workflow.json con un token válido**

## Estructura de archivos
```
ml-slider-dashboard/
├── CLAUDE.md
├── n8n-workflow.json               ← workflow n8n (importar y configurar token)
└── docs/
    ├── index.html                  ← home con cards de los 6 placements
    ├── data.json                   ← escrito por n8n; placeholder de muestra incluido
    ├── assets/
    │   ├── css/styles.css          ← design system completo (variables CSS, componentes)
    │   └── js/
    │       ├── utils.js            ← formatters (fmtNum, fmtPct, fmtUSD), agregación semanal
    │       └── charts.js           ← buildTrendChart / updateTrendChart (CY vs LY)
    └── placements/
        ├── main-sliders.html       ← ✅ funcional
        ├── landings.html           ← placeholder
        ├── containers.html         ← placeholder
        ├── rabbit-hole.html        ← placeholder
        ├── placement-pers.html     ← placeholder
        └── tabs.html               ← placeholder
```

## Design system (styles.css)
| Variable         | Valor        | Uso                    |
|------------------|--------------|------------------------|
| `--bg`           | `#f0f1f7`    | Fondo de página        |
| `--card`         | `#ffffff`    | Fondo de cards         |
| `--border`       | `#e2e4ef`    | Bordes                 |
| `--accent`       | `#3b5bdb`    | Links activos, sorted  |
| `--up`           | `#16a34a`    | Delta positivo         |
| `--dn`           | `#dc2626`    | Delta negativo         |
| `--text-muted`   | `#888`       | Labels, subtítulos     |

Componentes disponibles: `.kpi-card`, `.kpi-grid`, `.badge.up/.dn`, `.card`, `.card-header`,
`.card-body`, `.data-table`, `.toggle-group`, `.filter-select`, `.chip.mktplace/.play/.ads`,
`.freshness`, `.top-nav`, `.page-header`, `.content-grid`

## utils.js — funciones disponibles
| Función                              | Descripción                                  |
|--------------------------------------|----------------------------------------------|
| `fmtNum(n)`                          | 1234567 → "1,2M"                             |
| `fmtPct(n)`                          | 0.0512 → "5,12%"                             |
| `fmtUSD(n)`                          | 12345 → "USD 12,3K"                          |
| `calcDelta(curr, prev)`              | → `{ pct, dir: 'up'|'dn'|'neutral' }`        |
| `deltaBadge(delta)`                  | → HTML string con badge coloreado            |
| `fmtWeekLabel(dateStr)`              | "2026-03-31" → "31 mar"                      |
| `fmtRefreshed(isoStr)`               | ISO → "10/04 14:30"                          |
| `aggregateByWeek(rows, filter)`      | → Map<weekStr, {prints,clicks,gmv,ctr}>      |
| `getWeeks(weekMap, 'CY'|'LY')`       | → string[] semanas ordenadas                 |
| `getWeeklyKPIs(weekMap)`             | → `{ curr, prev }` última y anteúltima semana|
| `aggregateByCampaign(rows, filter, weekFilter)` | → array para tabla              |

## Schema de data.json (Main Sliders)
```json
{
  "data": [
    {
      "site":           "MLA",
      "YEAR_FROM_WEEK": "CY",          // "CY" o "LY"
      "MONTH":          "2026-03-01",
      "Q":              "Q1-2026",
      "WEEK":           "2026-03-31",  // lunes de la semana
      "WEEK_NUMBER":    14,
      "DAY":            "2026-04-07",
      "CAMPAIGN_NAME":  "MS_MELI_Brand_ROS",
      "SEGMENTATION":   "NO SEGMENTADO",  // o "SEGMENTADO"
      "LINE_ITEM_NAME": "LI_MS_MELI_Brand",
      "CAMPAING_TYPE":  "MKTPLACE",        // "MKTPLACE" | "PLAY" | "ADS"
      "MKTPLACE_CLICKS":  5000,
      "MKTPLACE_PRINTS":  200000,          // IMPRESSION_VIEWS_QTY
      "MKTPLACE_GMV":     95000.00,
      "source":           "ads"
    }
  ],
  "refreshed_at": "2026-04-10T14:30:00"
}
```
> CTR se calcula en el frontend: `MKTPLACE_CLICKS / MKTPLACE_PRINTS`

## Query BigQuery — Main Sliders
- Fuente: `BT_ADS_DISP_METRICS_DAILY` + JOINs a `LK_ADS_LINE_ITEMS`, `LK_ADS_ACCOUNTS`, `LK_ADS_CAMPAIGNS`
- Filtro placement: `LIKE '%MAIN-SLIDER_HOME%'`
- Ventana rolling: últimas 13 semanas (`DATE_SUB(CURRENT_DATE(), INTERVAL 13 WEEK)`)
- Sites: MLA, MLB, MLM, MLC, MLU, MCO, MPE
- Excluye campañas: MS_A_HS_Cont_ID, MS_B_HS_Cont_ID, MS_AcqHS, MS_EngHS, MS_HS_*, etc.
- La query devuelve `data_b64` (Base64 del JSON completo) para que n8n lo commitee directo a GitHub

## Cómo agregar un placement nuevo
1. Obtener la query de BigQuery para el placement
2. En `n8n-workflow.json`: agregar un nuevo nodo BQ con la query + nodos Get SHA / Push para un nuevo archivo (ej. `docs/data-landings.json`)
3. Copiar `placements/main-sliders.html` como base
4. Ajustar:
   - `fetch('../data-landings.json')` en el script
   - Campos del schema según la nueva query
   - Filtros UI relevantes para ese placement
   - Lógica de agregación si difiere del schema actual
5. Activar la card en `index.html` (cambiar clase `soon` → `ready`)
6. Actualizar el nodo `BQ Main Sliders` → renombrar/duplicar según corresponda

## Placements pendientes
| Placement              | Archivo                     | Estado       |
|------------------------|-----------------------------|--------------|
| Main Sliders           | placements/main-sliders.html| ✅ Funcional |
| Landings               | placements/landings.html    | ⏳ Pendiente query |
| Containers             | placements/containers.html  | ⏳ Pendiente query |
| Rabbit Hole            | placements/rabbit-hole.html | ⏳ Pendiente query |
| Placement Pers.        | placements/placement-pers.html | ⏳ Pendiente query |
| Tabs                   | placements/tabs.html        | ⏳ Pendiente query |

## Notas importantes
- El token de GitHub en el workflow original quedó expuesto — **siempre usar tokens nuevos**
- Los módulos JS usan `import/export` → requieren servidor local (Live Server) para desarrollar
- Al agregar nuevos sites a la query de BQ, agregarlos también al `<select id="filter-site">` en el HTML
- El gráfico alinea LY por índice de semana (posición 0,1,2... de cada año) — puede ajustarse si se necesita alineación por número de semana exacto
