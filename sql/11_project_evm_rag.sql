-- 11. Earned value per live project, ranked by forecast overrun, with a RAG status
-- RAG rule (adjustable): Red   if CPI or SPI < 0.80
--                        Amber if CPI or SPI < 0.95
--                        Green otherwise
SELECT
    project_id,
    project_name,
    programme,
    status,
    ROUND(bac / 1e6, 1)                  AS bac_musd,
    ROUND(ac  / 1e6, 1)                  AS ac_musd,
    ROUND(eac / 1e6, 1)                  AS eac_musd,
    ROUND(cpi, 2)                        AS cpi,
    ROUND(spi, 2)                        AS spi,
    ROUND(forecast_overrun_usd / 1e6, 1) AS overrun_musd,
    ROUND(100 * forecast_overrun_pct, 1) AS overrun_pct,
    CASE WHEN cpi < 0.80 OR spi < 0.80 THEN 'Red'
         WHEN cpi < 0.95 OR spi < 0.95 THEN 'Amber'
         ELSE 'Green' END               AS rag
FROM   v_project_kpi
WHERE  status <> 'Completed'
ORDER  BY forecast_overrun_usd DESC;
