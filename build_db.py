"""Build the SQLite database from the CSV files in data/.

Usage:  python build_db.py            # creates project_controls.db
Only the Python standard library is needed.
"""
import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).parent
DB_PATH = ROOT / "project_controls.db"

# CSV file -> (table, CSV column order matches the table column order below)
LOADS = [
    ("Dim_Site.csv", "dim_site",
     ["SiteID", "SiteName", "SiteArea"]),
    ("Dim_Contractor.csv", "dim_contractor",
     ["ContractorID", "ContractorName", "Discipline"]),
    ("Dim_Project.csv", "dim_project",
     ["ProjectID", "ProjectName", "Programme", "SiteID", "Category", "Complexity", "Priority",
      "ContractorID", "DeliveryModel", "StrategicAlignment", "BaselineBudget_USD",
      "PlannedStart", "PlannedDurationMonths", "PlannedFinish", "PlannedBenefit_USD"]),
    ("Fact_ProjectMonthly.csv", "project_monthly",
     ["ProjectID", "MonthEnd", "Status", "CurrentBudget_USD", "PV_USD", "EV_USD", "AC_USD",
      "EAC_USD", "PctComplete", "ForecastFinish", "ScopeChangesInMonth", "OverdueMitigations",
      "StopWorkDays"]),
    ("Fact_Risk.csv", "risk",
     ["RiskID", "ProjectID", "SiteID", "RiskCategory", "Likelihood", "Impact", "DateRaised",
      "MitigationDueDate", "MitigationClosedDate"]),
    ("Fact_ScopeChange.csv", "scope_change",
     ["ProjectID", "ChangeDate", "BudgetChange_USD", "UnfundedCost_USD"]),
    ("Fact_ManHours.csv", "man_hours",
     ["MonthEnd", "ProjectID", "SiteID", "ContractorID", "ManHours"]),
    ("Fact_SafetyIncident.csv", "incident",
     ["IncidentID", "IncidentDate", "SiteID", "ProjectID", "ContractorID", "IncidentType",
      "LostDays", "StopWorkDays"]),
]


def read_rows(path, columns):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # empty text becomes NULL (for example an open risk mitigation)
            yield tuple((row[c] if row[c] != "" else None) for c in columns)


def build(db_path=DB_PATH):
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.execute("PRAGMA foreign_keys = ON")
    con.executescript((ROOT / "sql" / "00_schema.sql").read_text(encoding="utf-8"))
    for csv_name, table, columns in LOADS:
        marks = ",".join("?" * len(columns))
        con.executemany(f"INSERT INTO {table} VALUES ({marks})",
                        read_rows(ROOT / "data" / csv_name, columns))
    con.executescript((ROOT / "sql" / "01_views.sql").read_text(encoding="utf-8"))
    con.commit()
    for _, table, _ in LOADS:
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table:<16} {n:>5} rows")
    con.close()
    print(f"Database ready: {db_path.name}")


if __name__ == "__main__":
    build()
