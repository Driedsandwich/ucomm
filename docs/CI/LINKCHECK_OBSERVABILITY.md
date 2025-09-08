# Link Check Observability (Daily)
- Runs daily on `main`, stores `{date, ok, errors}` snapshots under `docs/reports/metrics/linkcheck/`.
- Goal: quantify flakiness, validate ignore/retry tuning.
- Non-gating; used for trend analysis.
