# Changes

## Scope note

The supplied starter URL (`kalviumcommunity/Project-Engineering/.../Index%20Order%20Matters`) was unavailable during implementation: GitHub returned a 404 page and the GitHub API returned `Not Found`. Because the source README and its exact query could not be retrieved, this submission contains a deterministic PostgreSQL reproduction of the stated challenge. It uses the same behavior the task asks us to investigate: a query with two equality filters and a timestamp sort.

## Query and baseline

The test query is:

```sql
SELECT order_id, created_at, amount
FROM orders
WHERE tenant_id = 42
  AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50;
```

With no suitable index, PostgreSQL must inspect the table to find rows for both predicates. The baseline plan is expected to contain a `Seq Scan` followed by filtering and, depending on the planner's choices, a sort or top-N operation.

## Incorrect index experiment

The intentionally incorrect index is:

```sql
CREATE INDEX idx_orders_created_tenant_status
    ON orders (created_at DESC, tenant_id, status);
```

The query does not constrain the leading `created_at` column. PostgreSQL can only use a B-tree index efficiently from its left edge. Since the first index key is unconstrained, the index cannot directly narrow the search to `tenant_id = 42 AND status = 'paid'`. The planner therefore normally prefers a sequential scan because scanning a large timestamp-ordered index and checking the remaining predicates would be more expensive than reading the table.

The timestamp-first index is not useless for every query. It can help a query that restricts a time range, or one that wants the newest rows without filtering on other columns. It is simply the wrong shape for this filtering pattern.

## Corrected index

The corrected index is:

```sql
CREATE INDEX idx_orders_tenant_status_created
    ON orders (tenant_id, status, created_at DESC);
```

Now the two equality predicates are the leading keys. PostgreSQL can seek directly to the contiguous index range for tenant 42 and paid orders. The third key is already ordered descending, so PostgreSQL can return the newest 50 rows in index order and stop early because of `LIMIT 50`.

The corrected plan is expected to show an `Index Scan` or `Index Only Scan`, with index conditions for both `tenant_id` and `status`. The exact node and timing can vary with PostgreSQL version, cache state, and visibility-map coverage; the structural improvement is the important result.

## Left-most prefix rule

For a B-tree index on `(tenant_id, status, created_at)`, the useful prefix begins at `tenant_id` and continues as long as the query constrains the next indexed column. A predicate on `tenant_id` can use the first key. Predicates on `tenant_id` and `status` can use the first two keys. A predicate on `status` alone cannot skip over the unconstrained `tenant_id` key and get the same lookup benefit.

This rule does not mean later columns are ignored completely. PostgreSQL may still apply them as index filters or use them for ordering, but it cannot use a gap in the leading prefix to perform the same narrow seek. Index design should therefore put the columns that most directly define the lookup range first, followed by columns that support ordering or additional filtering.

## Files

- `sql/setup.sql` creates the table, data, query helper settings, and statistics.
- `sql/experiment.sql` runs the baseline, wrong-index, and corrected-index plans.
- `plans/` contains captured output from one local PostgreSQL run.

## Result summary

The experiment demonstrates three states:

1. **Baseline:** no matching composite index, so PostgreSQL scans the table.
2. **Wrong order:** `(created_at, tenant_id, status)` does not match the leading filter pattern, so PostgreSQL still favors a sequential scan.
3. **Correct order:** `(tenant_id, status, created_at DESC)` supports both equality lookups and the requested ordering, allowing an index-driven plan and early stop at 50 rows.
