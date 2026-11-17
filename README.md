# Composite Index Investigation

This repository demonstrates why the order of columns in a PostgreSQL composite index matters. The original challenge URL supplied for this exercise currently returns GitHub 404, so the experiment is self-contained and uses an equivalent multi-column workload: filter by `tenant_id` and `status`, then return the newest matching rows.

## Reproduce

The scripts target PostgreSQL 14+ and use only built-in SQL functions. Run them as a database user that can create a database:

```bash
createdb index_order_lab
psql -d index_order_lab -f sql/setup.sql
psql -d index_order_lab -f sql/experiment.sql
```

`setup.sql` creates one million deterministic rows and the query under test. `experiment.sql` runs the baseline, creates an intentionally wrong index, captures its plan, removes it, creates the corrected index, and captures the final plan. The measured timings depend on hardware and cache state; the important evidence is the scan type and index condition.

## Query under test

```sql
SELECT order_id, created_at, amount
FROM orders
WHERE tenant_id = 42
  AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50;
```

See [`Changes.md`](Changes.md) for the investigation and the left-most prefix explanation.
