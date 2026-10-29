-- 16. Risk mitigations that are overdue at the snapshot date (items to escalate)
-- Overdue = raised on or before the snapshot, due before the snapshot,
--           and not closed (or closed only after the snapshot).
SELECT
    r.risk_id,
    r.project_id,
    p.project_name,
    r.risk_category,
    r.likelihood * r.impact                                         AS risk_score,
    r.mitigation_due_date,
    CAST(julianday((SELECT value FROM params WHERE name = 'snapshot_date'))
         - julianday(r.mitigation_due_date) AS INTEGER)             AS days_overdue
FROM   risk AS r
JOIN   dim_project AS p ON p.project_id = r.project_id
WHERE  r.date_raised          <= (SELECT value FROM params WHERE name = 'snapshot_date')
  AND  r.mitigation_due_date  <  (SELECT value FROM params WHERE name = 'snapshot_date')
  AND (r.mitigation_closed_date IS NULL
       OR r.mitigation_closed_date > (SELECT value FROM params WHERE name = 'snapshot_date'))
ORDER  BY risk_score DESC, days_overdue DESC;
