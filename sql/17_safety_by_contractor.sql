-- 17. Safety: TRIFR by contractor (after the data-quality fix)
-- TRIFR = recordable injuries x 1,000,000 / man-hours worked.
-- Recordable = Medical Treatment or Lost Time Injury.
WITH hours AS (
    SELECT contractor_id, SUM(man_hours) AS man_hours
    FROM   v_man_hours_clean
    GROUP  BY contractor_id
),
injuries AS (
    SELECT contractor_id,
           SUM(is_recordable)                                    AS recordables,
           SUM(incident_type = 'Lost Time Injury')               AS lost_time_injuries,
           SUM(stop_work_days)                                   AS stop_work_days
    FROM   v_incident_clean
    GROUP  BY contractor_id
)
SELECT c.contractor_name,
       c.discipline,
       h.man_hours,
       COALESCE(i.recordables, 0)                                AS recordables,
       COALESCE(i.lost_time_injuries, 0)                         AS lost_time_injuries,
       COALESCE(i.stop_work_days, 0)                             AS stop_work_days,
       ROUND(1e6 * COALESCE(i.recordables, 0) / h.man_hours, 1)  AS trifr
FROM   dim_contractor AS c
JOIN   hours AS h ON h.contractor_id = c.contractor_id
LEFT   JOIN injuries AS i ON i.contractor_id = c.contractor_id

UNION ALL
SELECT 'ALL CONTRACTORS', '',
       (SELECT SUM(man_hours) FROM v_man_hours_clean),
       (SELECT SUM(is_recordable) FROM v_incident_clean),
       (SELECT SUM(incident_type = 'Lost Time Injury') FROM v_incident_clean),
       (SELECT SUM(stop_work_days) FROM v_incident_clean),
       ROUND(1e6 * (SELECT SUM(is_recordable) FROM v_incident_clean)
                 / (SELECT SUM(man_hours) FROM v_man_hours_clean), 1)
ORDER  BY trifr DESC;
