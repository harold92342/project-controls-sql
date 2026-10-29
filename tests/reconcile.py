"""Check that the SQL results match the figures published in the Power BI dashboard
(github.com/harold92342/mining-pmo-dashboard, snapshot 30 Sep 2026).

Usage:  python tests/reconcile.py
Exit code 0 = every figure matches, 1 = at least one difference.
"""
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from build_db import DB_PATH, build  # noqa: E402


def one(con, sql):
    return con.execute(sql).fetchone()[0]


def main():
    build(DB_PATH)  # always test against a freshly built database
    con = sqlite3.connect(DB_PATH)
    run = lambda name: con.execute((ROOT / "sql" / name).read_text(encoding="utf-8")).fetchall()

    kpi = dict(zip(
        ["snapshot", "projects", "live", "bac", "pv", "ev", "ac", "eac", "cpi", "spi", "ovr_musd", "ovr_pct"],
        run("10_portfolio_kpis.sql")[0]))
    decisions = {row[0]: row[1] for row in run("12_decision_rule.sql")}
    corr = [row[2] for row in run("15_correlations.sql")]
    overdue = len(run("16_overdue_mitigations.sql"))
    trifr = {row[0]: row[6] for row in run("17_safety_by_contractor.sql")}

    expected = [
        # (what, value from SQL, value published in the dashboard)
        ("CPI",                              kpi["cpi"],                         0.80),
        ("SPI",                              kpi["spi"],                         0.87),
        ("Forecast overrun %",               kpi["ovr_pct"],                     24.7),
        ("Forecast overrun, USD millions",   round(kpi["ovr_musd"]),             141),
        ("Live projects",                    kpi["live"],                        15),
        ("Accelerate",                       decisions.get("Accelerate"),        3),
        ("Sustain",                          decisions.get("Sustain"),           1),
        ("Recover",                          decisions.get("Recover"),           4),
        ("Pause",                            decisions.get("Pause"),             4),
        ("Terminate",                        decisions.get("Terminate"),         3),
        ("Overdue mitigations",              overdue,                            15),
        ("TRIFR, all contractors",           trifr["ALL CONTRACTORS"],           15.8),
        ("TRIFR, Red Earth Mechanical",      trifr["Red Earth Mechanical"],      29.5),
        ("Man-hours rows after the fix",     one(con, "SELECT COUNT(*) FROM v_man_hours_clean"), 450),
        ("Incident rows after the fix",      one(con, "SELECT COUNT(*) FROM v_incident_clean"),  669),
        ("Correlation scope change vs overrun", corr[0],                         0.46),
        ("Correlation stop-work vs SPI",     corr[1],                            -0.41),
    ]

    failures = 0
    print(f"{'Figure':<38}{'SQL':>10}{'Dashboard':>12}  Result")
    for what, got, want in expected:
        ok = got is not None and abs(got - want) < 1e-9
        failures += not ok
        print(f"{what:<38}{got!s:>10}{want!s:>12}  {'OK' if ok else 'DIFFERENT'}")
    print(f"\n{len(expected) - failures}/{len(expected)} figures match the dashboard.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
