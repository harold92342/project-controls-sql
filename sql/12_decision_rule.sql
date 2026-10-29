-- 12. Steering-committee decision rule (same rule as the Power BI dashboard)
--   Accelerate : value score >= 4 and CPI >= 0.9 and SPI >= 0.9
--   Terminate  : value score <= 3 and (CPI < 0.75 or SPI < 0.6)
--   Recover    : value score >= 4 (but not Accelerate)
--   Sustain    : CPI >= 0.85 and SPI >= 0.85
--   Pause      : everything else
-- Completed projects are shown as "Closed".
SELECT
    decision,
    COUNT(*)                                  AS projects,
    ROUND(SUM(bac) / 1e6, 1)                  AS bac_musd,
    ROUND(SUM(forecast_overrun_usd) / 1e6, 1) AS overrun_musd,
    ROUND(1.0 * SUM(ev) / SUM(ac), 2)         AS cpi,
    ROUND(1.0 * SUM(ev) / SUM(pv), 2)         AS spi,
    GROUP_CONCAT(project_id, ' ')             AS project_ids
FROM   v_project_kpi
GROUP  BY decision
ORDER  BY CASE decision
              WHEN 'Accelerate' THEN 1 WHEN 'Sustain'   THEN 2 WHEN 'Recover' THEN 3
              WHEN 'Pause'      THEN 4 WHEN 'Terminate' THEN 5 ELSE 6 END;
