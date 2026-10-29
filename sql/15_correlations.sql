-- 15. Two relationships behind the dashboard's "Why?" panel
-- Pearson correlation computed directly in SQL from sums (no extension needed).
-- A correlation shows that two things move together, not that one causes the other.
WITH scope_vs_overrun AS (
    SELECT k.project_id,
           COALESCE((SELECT SUM(s.budget_change_usd) FROM scope_change AS s
                     WHERE s.project_id = k.project_id), 0)  AS x,   -- budget added by scope changes
           k.forecast_overrun_pct                             AS y    -- forecast overrun
    FROM   v_project_kpi AS k
),
stopwork_vs_spi AS (
    SELECT k.project_id,
           COALESCE((SELECT SUM(i.stop_work_days) FROM v_incident_clean AS i
                     WHERE i.project_id = k.project_id), 0)  AS x,   -- safety stop-work days
           k.spi                                              AS y    -- schedule performance
    FROM   v_project_kpi AS k
    WHERE  k.spi < 1                                                 -- projects behind schedule
),
pairs AS (
    SELECT 1 AS rel, x, y FROM scope_vs_overrun
    UNION ALL
    SELECT 2, x, y FROM stopwork_vs_spi
)
SELECT
    CASE rel WHEN 1 THEN 'Budget added by scope changes vs forecast overrun % (all projects)'
             ELSE        'Stop-work days vs SPI (projects behind schedule)' END AS relationship,
    COUNT(*)                                                                    AS projects,
    ROUND((COUNT(*) * SUM(x * y) - SUM(x) * SUM(y))
          / (sqrt(COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
           * sqrt(COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))), 2)                 AS pearson_r
FROM   pairs
GROUP  BY rel
ORDER  BY rel;
