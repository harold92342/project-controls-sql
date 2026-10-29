-- 10. Portfolio KPIs at the snapshot date
-- Question: is the portfolio on budget and on time?
-- CPI = EV / AC (cost efficiency)   SPI = EV / PV (schedule efficiency)
-- Forecast overrun = EAC - BAC, where BAC is the budget after approved scope changes.
SELECT
    (SELECT value FROM params WHERE name = 'snapshot_date')          AS snapshot_date,
    COUNT(*)                                                         AS projects,
    SUM(status <> 'Completed')                                       AS live_projects,
    ROUND(SUM(bac) / 1e6, 1)                                         AS bac_musd,
    ROUND(SUM(pv)  / 1e6, 1)                                         AS pv_musd,
    ROUND(SUM(ev)  / 1e6, 1)                                         AS ev_musd,
    ROUND(SUM(ac)  / 1e6, 1)                                         AS ac_musd,
    ROUND(SUM(eac) / 1e6, 1)                                         AS eac_musd,
    ROUND(1.0 * SUM(ev) / SUM(ac), 2)                                AS cpi,
    ROUND(1.0 * SUM(ev) / SUM(pv), 2)                                AS spi,
    ROUND(SUM(eac - bac) / 1e6, 1)                                   AS forecast_overrun_musd,
    ROUND(100.0 * SUM(eac - bac) / SUM(bac), 1)                      AS forecast_overrun_pct
FROM v_project_kpi;
