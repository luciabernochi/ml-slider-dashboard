/* ─── ML Dashboard — Utils ────────────────────────────────────────────────── */

/** Format large numbers: 1234567 → "1.2M", 12345 → "12.3K" */
export function fmtNum(n) {
  if (n == null || isNaN(n)) return '—';
  if (n >= 1e6)  return (n / 1e6).toFixed(1).replace('.', ',') + 'M';
  if (n >= 1e3)  return (n / 1e3).toFixed(1).replace('.', ',') + 'K';
  return n.toLocaleString('es-AR');
}

/** Format as percentage with 2 decimals: 0.05123 → "5,12%" */
export function fmtPct(n) {
  if (n == null || isNaN(n)) return '—';
  return (n * 100).toFixed(2).replace('.', ',') + '%';
}

/** Format currency: 12345.67 → "USD 12.3K" */
export function fmtUSD(n) {
  if (n == null || isNaN(n)) return '—';
  if (n >= 1e6)  return 'USD ' + (n / 1e6).toFixed(2).replace('.', ',') + 'M';
  if (n >= 1e3)  return 'USD ' + (n / 1e3).toFixed(1).replace('.', ',') + 'K';
  return 'USD ' + n.toFixed(2).replace('.', ',');
}

/** Delta percentage between current and previous week.
 *  Returns { pct: number, dir: 'up'|'dn'|'neutral' } */
export function calcDelta(curr, prev) {
  if (!prev || prev === 0) return { pct: null, dir: 'neutral' };
  const pct = (curr - prev) / prev;
  return { pct, dir: pct > 0 ? 'up' : pct < 0 ? 'dn' : 'neutral' };
}

/** Render an HTML badge string for a delta */
export function deltaBadge(delta) {
  if (delta.pct == null) return '<span class="badge neutral">—</span>';
  const sign  = delta.pct > 0 ? '+' : '';
  const label = sign + (delta.pct * 100).toFixed(1).replace('.', ',') + '%';
  const arrow = delta.dir === 'up' ? '▲' : delta.dir === 'dn' ? '▼' : '';
  return `<span class="badge ${delta.dir}">${arrow} ${label}</span>`;
}

/** Parse "YYYY-MM-DD" date string to a display label: "31 Mar" */
export function fmtWeekLabel(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('es-AR', { day: '2-digit', month: 'short' });
}

/** Format ISO datetime for freshness: "2026-04-10T14:30:00" → "10/04 14:30" */
export function fmtRefreshed(isoStr) {
  if (!isoStr) return '—';
  const d = new Date(isoStr.replace('T', ' ') + ' GMT-3');
  return d.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' })
       + ' ' + d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' });
}

// ─── Data aggregation ─────────────────────────────────────────────────────────

/**
 * Aggregate raw rows into weekly totals.
 * @param {Array} rows   - raw rows from data.json
 * @param {Object} filter - { segmentation: 'NO SEGMENTADO'|'SEGMENTADO'|null, type: string|null }
 * @returns {Map<string, {prints, clicks, gmv, ctr}>} keyed by WEEK date string
 */
export function aggregateByWeek(rows, filter = {}) {
  const map = new Map();

  for (const r of rows) {
    if (filter.segmentation && r.SEGMENTATION !== filter.segmentation) continue;
    if (filter.type          && r.CAMPAING_TYPE !== filter.type)        continue;

    const key = r.WEEK;
    if (!map.has(key)) map.set(key, { prints: 0, clicks: 0, gmv: 0, year: r.YEAR_FROM_WEEK });
    const acc = map.get(key);
    acc.prints += Number(r.MKTPLACE_PRINTS) || 0;
    acc.clicks += Number(r.MKTPLACE_CLICKS) || 0;
    acc.gmv    += Number(r.MKTPLACE_GMV)    || 0;
    acc.year    = r.YEAR_FROM_WEEK;
  }

  // Compute CTR for each week
  map.forEach(v => { v.ctr = v.prints ? v.clicks / v.prints : 0; });

  return map;
}

/**
 * Get sorted weeks (ascending) filtered by YEAR_FROM_WEEK.
 * @param {Map} weekMap
 * @param {string} yearTag - 'CY' or 'LY'
 * @returns {Array<string>} sorted week date strings
 */
export function getWeeks(weekMap, yearTag = 'CY') {
  return [...weekMap.entries()]
    .filter(([, v]) => v.year === yearTag)
    .map(([k]) => k)
    .sort();
}

/**
 * Get KPIs for the last complete week and the one before it.
 * @param {Map} weekMap  - result of aggregateByWeek
 * @returns {{ curr, prev }} - each is { prints, clicks, gmv, ctr, week }
 */
export function getWeeklyKPIs(weekMap) {
  const cyWeeks = getWeeks(weekMap, 'CY');
  if (!cyWeeks.length) return { curr: null, prev: null };

  const currWeek = cyWeeks[cyWeeks.length - 1];
  const prevWeek = cyWeeks.length > 1 ? cyWeeks[cyWeeks.length - 2] : null;

  return {
    curr: { ...weekMap.get(currWeek), week: currWeek },
    prev: prevWeek ? { ...weekMap.get(prevWeek), week: prevWeek } : null,
  };
}

/**
 * Aggregate rows into per-campaign totals for the table.
 * @param {Array} rows
 * @param {Object} filter
 * @param {string} weekFilter - optional WEEK date string to limit to one week
 * @returns {Array<Object>}
 */
export function aggregateByCampaign(rows, filter = {}, weekFilter = null) {
  const map = new Map();

  for (const r of rows) {
    if (filter.segmentation && r.SEGMENTATION !== filter.segmentation) continue;
    if (filter.type          && r.CAMPAING_TYPE !== filter.type)        continue;
    if (weekFilter           && r.WEEK !== weekFilter)                  continue;

    const key = `${r.CAMPAIGN_NAME}|||${r.LINE_ITEM_NAME}`;
    if (!map.has(key)) {
      map.set(key, {
        campaign:    r.CAMPAIGN_NAME,
        lineItem:    r.LINE_ITEM_NAME,
        type:        r.CAMPAING_TYPE,
        segmentation: r.SEGMENTATION,
        prints: 0, clicks: 0, gmv: 0,
      });
    }
    const acc = map.get(key);
    acc.prints += Number(r.MKTPLACE_PRINTS) || 0;
    acc.clicks += Number(r.MKTPLACE_CLICKS) || 0;
    acc.gmv    += Number(r.MKTPLACE_GMV)    || 0;
  }

  return [...map.values()].map(r => ({
    ...r,
    ctr: r.prints ? r.clicks / r.prints : 0,
  }));
}
