-- 14. Scope changes and forecast overrun, all projects
-- Which projects added the most budget through scope changes, and how far over budget
-- do they forecast? Ranked by budget added. (The correlation is in query 15.)
SELECT
    k.project_id,
    k.project_name,
    k.status,
    COUNT(s.project_id)                                       AS scope_changes,
    ROUND(COALESCE(SUM(s.budget_change_usd), 0) / 1e6, 2)     AS budget_added_musd,
    ROUND(COALESCE(SUM(s.unfunded_cost_usd), 0) / 1e6, 2)     AS unfunded_musd,
    ROUND(100 * k.forecast_overrun_pct, 1)                    AS overrun_pct
FROM   v_project_kpi AS k
LEFT   JOIN scope_change AS s ON s.project_id = k.project_id
GROUP  BY k.project_id
ORDER  BY SUM(s.budget_change_usd) DESC;
