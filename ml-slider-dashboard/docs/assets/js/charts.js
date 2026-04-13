/* ─── ML Dashboard — Chart.js helpers ────────────────────────────────────── */

// ─── Shared defaults ──────────────────────────────────────────────────────────

export const COLORS = {
  cy:        '#3b5bdb',
  cy_fill:   'rgba(59,91,219,.08)',
  ly:        '#94a3b8',
  ly_fill:   'rgba(148,163,184,.06)',
  prints:    '#3b5bdb',
  clicks:    '#16a34a',
  gmv:       '#f59e0b',
  grid:      '#eaecf5',
  text:      '#888',
};

const BASE_FONT = {
  family: "'Proxima Nova','proxima-nova','Segoe UI',sans-serif",
  size: 11,
};

Chart.defaults.font          = BASE_FONT;
Chart.defaults.color         = COLORS.text;
Chart.defaults.plugins.legend.labels.boxWidth  = 10;
Chart.defaults.plugins.legend.labels.padding   = 16;
Chart.defaults.plugins.legend.labels.font      = { ...BASE_FONT, weight: '600' };
Chart.defaults.plugins.tooltip.backgroundColor = '#1a1a2e';
Chart.defaults.plugins.tooltip.padding         = 10;
Chart.defaults.plugins.tooltip.titleFont       = { ...BASE_FONT, weight: '700', size: 12 };
Chart.defaults.plugins.tooltip.bodyFont        = BASE_FONT;
Chart.defaults.plugins.tooltip.cornerRadius    = 6;

// ─── Trend line chart (CY vs LY, weekly) ─────────────────────────────────────

/**
 * Build a line chart comparing CY vs LY for a given metric.
 * @param {CanvasRenderingContext2D} ctx
 * @param {Object} params
 *   - labels:  string[]        (week labels for CY)
 *   - cyData:  number[]
 *   - lyData:  number[]        (aligned to same week-of-year, may be shorter)
 *   - metric:  'prints'|'clicks'|'ctr'|'gmv'
 *   - fmtFn:   function(n)     (formatter for tooltip/y-axis)
 * @returns Chart instance
 */
export function buildTrendChart(ctx, { labels, cyData, lyData, metric, fmtFn }) {
  const isCTR = metric === 'ctr';

  return new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'CY',
          data: cyData,
          borderColor: COLORS.cy,
          backgroundColor: COLORS.cy_fill,
          borderWidth: 2,
          pointRadius: 3,
          pointHoverRadius: 5,
          tension: 0.3,
          fill: true,
        },
        {
          label: 'LY',
          data: lyData,
          borderColor: COLORS.ly,
          backgroundColor: COLORS.ly_fill,
          borderWidth: 1.5,
          borderDash: [4, 3],
          pointRadius: 2,
          pointHoverRadius: 4,
          tension: 0.3,
          fill: false,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { position: 'top', align: 'end' },
        tooltip: {
          callbacks: {
            label: ctx => ` ${ctx.dataset.label}  ${fmtFn(ctx.parsed.y)}`,
          },
        },
      },
      scales: {
        x: {
          grid: { color: COLORS.grid },
          ticks: { maxRotation: 0, maxTicksLimit: 8 },
        },
        y: {
          grid: { color: COLORS.grid },
          ticks: {
            callback: v => fmtFn(v),
          },
          ...(isCTR ? { min: 0 } : {}),
        },
      },
    },
  });
}

/**
 * Update an existing trend chart with new data (avoid full re-render).
 * @param {Chart} chart
 * @param {Object} params - same shape as buildTrendChart params (minus ctx)
 */
export function updateTrendChart(chart, { labels, cyData, lyData, fmtFn }) {
  chart.data.labels            = labels;
  chart.data.datasets[0].data  = cyData;
  chart.data.datasets[1].data  = lyData;
  chart.options.scales.y.ticks.callback = v => fmtFn(v);
  chart.options.plugins.tooltip.callbacks.label =
    ctx => ` ${ctx.dataset.label}  ${fmtFn(ctx.parsed.y)}`;
  chart.update('active');
}
