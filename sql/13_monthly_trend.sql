-- 13. Portfolio trend by month (window functions)
-- For every month, each project contributes its latest report up to that month,
-- then the portfolio PV / EV / AC are added up. Window functions give the monthly
-- spend (change in cumulative AC) and a 3-month moving average of CPI.
WITH months AS (
    SELECT DISTINCT month_end
    FROM   project_monthly
    WHERE  month_end <= (SELECT value FROM params WHERE name = 'snapshot_date')
),
as_of AS (
    SELECT m.month_end AS as_of_month, pm.pv_usd, pm.ev_usd, pm.ac_usd
    FROM   months AS m
    JOIN   project_monthly AS pm
      ON   pm.month_end = (SELECT MAX(x.month_end)
                           FROM   project_monthly AS x
                           WHERE  x.project_id = pm.project_id
                             AND  x.month_end <= m.month_end)
),
portfolio AS (
    SELECT as_of_month, SUM(pv_usd) AS pv, SUM(ev_usd) AS ev, SUM(ac_usd) AS ac
    FROM   as_of
    GROUP  BY as_of_month
)
SELECT
    as_of_month                                                         AS month_end,
    ROUND(pv / 1e6, 1)                                                  AS pv_musd,
    ROUND(ev / 1e6, 1)                                                  AS ev_musd,
    ROUND(ac / 1e6, 1)                                                  AS ac_musd,
    ROUND((ac - LAG(ac) OVER (ORDER BY as_of_month)) / 1e6, 1)          AS spend_in_month_musd,
    ROUND(1.0 * ev / ac, 2)                                             AS cpi,
    ROUND(1.0 * ev / pv, 2)                                             AS spi,
    ROUND(AVG(1.0 * ev / ac) OVER (ORDER BY as_of_month
                                   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS cpi_3m_avg,
    ROUND(AVG(1.0 * ev / pv) OVER (ORDER BY as_of_month
                                   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS spi_3m_avg
FROM   portfolio
ORDER  BY as_of_month;
