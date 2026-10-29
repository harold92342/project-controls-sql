-- Project Controls SQL: schema
-- SQLite 3.35+ (window functions and math functions are used in the queries).
-- Dates are stored as ISO text (YYYY-MM-DD), which sorts and compares correctly.

PRAGMA foreign_keys = ON;

DROP VIEW  IF EXISTS v_latest_report;
DROP VIEW  IF EXISTS v_project_kpi;
DROP VIEW  IF EXISTS v_man_hours_clean;
DROP VIEW  IF EXISTS v_incident_clean;
DROP TABLE IF EXISTS incident;
DROP TABLE IF EXISTS man_hours;
DROP TABLE IF EXISTS scope_change;
DROP TABLE IF EXISTS risk;
DROP TABLE IF EXISTS project_monthly;
DROP TABLE IF EXISTS dim_project;
DROP TABLE IF EXISTS dim_contractor;
DROP TABLE IF EXISTS dim_site;
DROP TABLE IF EXISTS params;

-- Reporting date used by every query. Change it with:  python run_queries.py --snapshot 2026-06-30
CREATE TABLE params (
    name  TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
INSERT INTO params (name, value) VALUES ('snapshot_date', '2026-09-30');

CREATE TABLE dim_site (
    site_id   TEXT PRIMARY KEY,
    site_name TEXT NOT NULL,
    site_area TEXT NOT NULL
);

CREATE TABLE dim_contractor (
    contractor_id   TEXT PRIMARY KEY,
    contractor_name TEXT NOT NULL,
    discipline      TEXT NOT NULL
);

CREATE TABLE dim_project (
    project_id              TEXT PRIMARY KEY,
    project_name            TEXT NOT NULL,
    programme               TEXT NOT NULL,
    site_id                 TEXT NOT NULL REFERENCES dim_site (site_id),
    category                TEXT NOT NULL,
    complexity              TEXT NOT NULL,
    priority                TEXT NOT NULL,
    contractor_id           TEXT NOT NULL REFERENCES dim_contractor (contractor_id),
    delivery_model          TEXT NOT NULL,
    strategic_alignment     INTEGER NOT NULL CHECK (strategic_alignment BETWEEN 1 AND 5),
    baseline_budget_usd     REAL NOT NULL CHECK (baseline_budget_usd > 0),
    planned_start           TEXT NOT NULL,
    planned_duration_months INTEGER NOT NULL,
    planned_finish          TEXT NOT NULL,
    planned_benefit_usd     REAL
);

-- One row per project and month: cumulative earned-value figures as reported.
CREATE TABLE project_monthly (
    project_id               TEXT NOT NULL REFERENCES dim_project (project_id),
    month_end                TEXT NOT NULL,
    status                   TEXT NOT NULL CHECK (status IN ('Active', 'On Hold', 'Completed')),
    current_budget_usd       REAL NOT NULL,   -- BAC after approved scope changes
    pv_usd                   REAL NOT NULL,   -- planned value (cumulative)
    ev_usd                   REAL NOT NULL,   -- earned value (cumulative)
    ac_usd                   REAL NOT NULL,   -- actual cost (cumulative)
    eac_usd                  REAL NOT NULL,   -- estimate at completion
    pct_complete             REAL NOT NULL CHECK (pct_complete BETWEEN 0 AND 1),
    forecast_finish          TEXT,
    scope_changes_in_month   INTEGER NOT NULL DEFAULT 0,
    overdue_mitigations      INTEGER NOT NULL DEFAULT 0,
    stop_work_days           INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (project_id, month_end)
);

CREATE TABLE risk (
    risk_id                 TEXT PRIMARY KEY,
    project_id              TEXT NOT NULL REFERENCES dim_project (project_id),
    site_id                 TEXT NOT NULL REFERENCES dim_site (site_id),
    risk_category           TEXT NOT NULL,
    likelihood              INTEGER NOT NULL CHECK (likelihood BETWEEN 1 AND 5),
    impact                  INTEGER NOT NULL CHECK (impact BETWEEN 1 AND 5),
    date_raised             TEXT NOT NULL,
    mitigation_due_date     TEXT NOT NULL,
    mitigation_closed_date  TEXT                -- NULL while the mitigation is open
);

CREATE TABLE scope_change (
    project_id         TEXT NOT NULL REFERENCES dim_project (project_id),
    change_date        TEXT NOT NULL,
    budget_change_usd  REAL NOT NULL,
    unfunded_cost_usd  REAL NOT NULL
);

CREATE TABLE man_hours (
    month_end     TEXT NOT NULL,
    project_id    TEXT NOT NULL REFERENCES dim_project (project_id),
    site_id       TEXT NOT NULL REFERENCES dim_site (site_id),
    contractor_id TEXT NOT NULL REFERENCES dim_contractor (contractor_id),
    man_hours     INTEGER NOT NULL CHECK (man_hours >= 0)
);

CREATE TABLE incident (
    incident_id    TEXT PRIMARY KEY,
    incident_date  TEXT NOT NULL,
    site_id        TEXT NOT NULL REFERENCES dim_site (site_id),
    project_id     TEXT NOT NULL REFERENCES dim_project (project_id),
    contractor_id  TEXT NOT NULL REFERENCES dim_contractor (contractor_id),
    incident_type  TEXT NOT NULL,
    lost_days      INTEGER NOT NULL,
    stop_work_days INTEGER NOT NULL
);

CREATE INDEX ix_monthly_month   ON project_monthly (month_end);
CREATE INDEX ix_risk_project    ON risk (project_id);
CREATE INDEX ix_scope_project   ON scope_change (project_id);
CREATE INDEX ix_hours_project   ON man_hours (project_id, month_end);
CREATE INDEX ix_incident_proj   ON incident (project_id, incident_date);
