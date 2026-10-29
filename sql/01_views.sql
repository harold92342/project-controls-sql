-- Reusable views. Earned-value figures are cumulative, so summing months would
-- double count: every KPI reads each project's LATEST report on or before the
-- snapshot date (same logic as the DAX measures "EV (Latest)", "AC (Latest)"...).

-- 1. Latest report of every project at the snapshot date
CREATE VIEW v_latest_report AS
SELECT pm.*
FROM   project_monthly AS pm
JOIN  (SELECT project_id, MAX(month_end) AS last_month
       FROM   project_monthly
       WHERE  month_end <= (SELECT value FROM params WHERE name = 'snapshot_date')
       GROUP  BY project_id) AS l
  ON   l.project_id = pm.project_id
 AND   l.last_month = pm.month_end;

-- 2. KPIs and decision rule per project (mirrors the DAX "Decision Rule")
CREATE VIEW v_project_kpi AS
SELECT
    p.project_id,
    p.project_name,
    p.programme,
    p.contractor_id,
    p.strategic_alignment                              AS value_score,
    r.status,
    r.month_end                                        AS last_report,
    r.current_budget_usd                               AS bac,
    r.pv_usd                                           AS pv,
    r.ev_usd                                           AS ev,
    r.ac_usd                                           AS ac,
    r.eac_usd                                          AS eac,
    r.pct_complete,
    1.0 * r.ev_usd / NULLIF(r.ac_usd, 0)               AS cpi,
    1.0 * r.ev_usd / NULLIF(r.pv_usd, 0)               AS spi,
    r.eac_usd - r.current_budget_usd                   AS forecast_overrun_usd,
    (r.eac_usd - r.current_budget_usd) / r.current_budget_usd AS forecast_overrun_pct,
    CASE
        WHEN r.status = 'Completed'                                               THEN 'Closed'
        WHEN p.strategic_alignment >= 4 AND 1.0*r.ev_usd/r.ac_usd >= 0.9
                                        AND 1.0*r.ev_usd/r.pv_usd >= 0.9          THEN 'Accelerate'
        WHEN p.strategic_alignment <= 3 AND (1.0*r.ev_usd/r.ac_usd < 0.75
                                         OR  1.0*r.ev_usd/r.pv_usd < 0.6)         THEN 'Terminate'
        WHEN p.strategic_alignment >= 4                                           THEN 'Recover'
        WHEN 1.0*r.ev_usd/r.ac_usd >= 0.85 AND 1.0*r.ev_usd/r.pv_usd >= 0.85     THEN 'Sustain'
        ELSE 'Pause'
    END                                                AS decision
FROM   dim_project      AS p
JOIN   v_latest_report  AS r ON r.project_id = p.project_id;

-- 3. Data-quality fix: drop activity booked after a project stopped reporting
--    (same rule as the Power Query step "activity after project closure").
CREATE VIEW v_man_hours_clean AS
SELECT h.*
FROM   man_hours AS h
JOIN  (SELECT project_id, MAX(month_end) AS last_report
       FROM   project_monthly GROUP BY project_id) AS l
  ON   l.project_id = h.project_id
WHERE  h.month_end <= l.last_report;

CREATE VIEW v_incident_clean AS
SELECT i.*,
       CASE WHEN i.incident_type IN ('Medical Treatment', 'Lost Time Injury') THEN 1 ELSE 0 END AS is_recordable
FROM   incident AS i
JOIN  (SELECT project_id, MAX(month_end) AS last_report
       FROM   project_monthly GROUP BY project_id) AS l
  ON   l.project_id = i.project_id
WHERE  i.incident_date <= l.last_report;
