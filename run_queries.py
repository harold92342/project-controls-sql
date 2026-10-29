"""Run every query in sql/1x_*.sql, print the result and save it as CSV in results/.

Usage:
    python run_queries.py                       # snapshot 2026-09-30
    python run_queries.py --snapshot 2026-06-30 # any month end in the data
    python run_queries.py --only 10 12          # only some queries
"""
import argparse
import csv
import sqlite3
from pathlib import Path

from build_db import DB_PATH, build

ROOT = Path(__file__).parent


def print_table(columns, rows, limit=25):
    shown = rows[:limit]
    text = [[("" if v is None else str(v)) for v in r] for r in shown]
    widths = [max(len(c), *(len(r[i]) for r in text)) if text else len(c)
              for i, c in enumerate(columns)]
    print("  ".join(c.ljust(w) for c, w in zip(columns, widths)))
    print("  ".join("-" * w for w in widths))
    for r in text:
        print("  ".join(v.ljust(w) for v, w in zip(r, widths)))
    if len(rows) > limit:
        print(f"... {len(rows) - limit} more rows (full result in results/)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", default=None, help="reporting date, e.g. 2026-09-30")
    parser.add_argument("--only", nargs="*", help="query numbers to run, e.g. 10 12")
    args = parser.parse_args()

    if not DB_PATH.exists():
        build()
    con = sqlite3.connect(DB_PATH)
    # Every run starts from the latest month in the data unless --snapshot is given,
    # so a date used in a previous run never stays active by accident.
    snapshot = args.snapshot or con.execute("SELECT MAX(month_end) FROM project_monthly").fetchone()[0]
    con.execute("UPDATE params SET value = ? WHERE name = 'snapshot_date'", (snapshot,))
    con.commit()

    (ROOT / "results").mkdir(exist_ok=True)
    for path in sorted((ROOT / "sql").glob("1[0-9]_*.sql")):
        number = path.name[:2]
        if args.only and number not in args.only:
            continue
        cur = con.execute(path.read_text(encoding="utf-8"))
        columns = [d[0] for d in cur.description]
        rows = cur.fetchall()
        print(f"\n=== {path.name}  (snapshot {snapshot}) ===")
        print_table(columns, rows)
        with open(ROOT / "results" / f"{path.stem}.csv", "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(columns)
            writer.writerows(rows)
    con.close()


if __name__ == "__main__":
    main()
