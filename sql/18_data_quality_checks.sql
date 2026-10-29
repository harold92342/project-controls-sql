-- 18. Data-quality checks.
-- OK = zero rows found. FIXED = rows found and already handled by a cleaning view
-- (v_man_hours_clean, v_incident_clean). REVIEW = rows found, needs a decision.
WITH ordered AS (
    SELECT project_id, month_end, pv_usd, ev_usd, ac_usd, status,
           LAG(pv_usd)    OVER w AS prev_pv,
           LAG(ev_usd)    OVER w AS prev_ev,
           LAG(ac_usd)    OVER w AS prev_ac,
           LAG(status)    OVER w AS prev_status,
           LAG(month_end) OVER w AS prev_month
    FROM   project_monthly
    WINDOW w AS (PARTITION BY project_id ORDER BY month_end)
),
checks AS (
    SELECT 'Cumulative PV, EV or AC decreases from one month to the next' AS check_name,
           (SELECT COUNT(*) FROM ordered
            WHERE pv_usd < prev_pv OR ev_usd < prev_ev OR ac_usd < prev_ac) AS issues
    UNION ALL
    SELECT 'EAC lower than actual cost to date',
           (SELECT COUNT(*) FROM project_monthly WHERE eac_usd < ac_usd)
    UNION ALL
    SELECT 'Gap of more than one month between two reports of a project',
           (SELECT COUNT(*) FROM ordered
            WHERE prev_month IS NOT NULL
              AND CAST(strftime('%m', month_end) AS INT) + 12 * CAST(strftime('%Y', month_end) AS INT)
                - CAST(strftime('%m', prev_month) AS INT) - 12 * CAST(strftime('%Y', prev_month) AS INT) > 1)
    UNION ALL
    SELECT 'Project reported again after being Completed',
           (SELECT COUNT(*) FROM ordered WHERE prev_status = 'Completed')
    UNION ALL
    SELECT 'Completed project below 100% complete',
           (SELECT COUNT(*) FROM project_monthly WHERE status = 'Completed' AND pct_complete < 0.999)
    UNION ALL
    SELECT 'Risk closed before it was raised, or due before it was raised',
           (SELECT COUNT(*) FROM risk
            WHERE mitigation_closed_date < date_raised OR mitigation_due_date < date_raised)
    UNION ALL
    SELECT 'Project without any monthly report',
           (SELECT COUNT(*) FROM dim_project
            WHERE project_id NOT IN (SELECT project_id FROM project_monthly))
    UNION ALL
    SELECT 'Man-hours booked after the project stopped reporting (removed by the fix)',
           (SELECT COUNT(*) FROM man_hours) - (SELECT COUNT(*) FROM v_man_hours_clean)
    UNION ALL
    SELECT 'Incidents booked after the project stopped reporting (removed by the fix)',
           (SELECT COUNT(*) FROM incident) - (SELECT COUNT(*) FROM v_incident_clean)
)
SELECT check_name, issues,
       CASE WHEN issues = 0 THEN 'OK'
            WHEN check_name LIKE '%(removed by the fix)' THEN 'FIXED'
            ELSE 'REVIEW' END AS status
FROM   checks;
