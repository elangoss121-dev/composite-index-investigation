\timing on
\pset pager off
SET track_io_timing = on;
DROP INDEX IF EXISTS idx_orders_created_tenant_status;
DROP INDEX IF EXISTS idx_orders_tenant_status_created;
ANALYZE orders;

SELECT 'BASELINE' AS experiment;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON)
SELECT order_id, created_at, amount
FROM orders
WHERE tenant_id = 40 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50;

CREATE INDEX idx_orders_created_tenant_status
    ON orders (created_at DESC, tenant_id, status);
ANALYZE orders;
SELECT 'INCORRECT_ORDER' AS experiment;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON)
SELECT order_id, created_at, amount
FROM orders
WHERE tenant_id = 40 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50;

DROP INDEX idx_orders_created_tenant_status;
CREATE INDEX idx_orders_tenant_status_created
    ON orders (tenant_id, status, created_at DESC);
ANALYZE orders;
SELECT 'CORRECT_ORDER' AS experiment;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON)
SELECT order_id, created_at, amount
FROM orders
WHERE tenant_id = 40 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50;
