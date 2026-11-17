DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id bigint PRIMARY KEY,
    tenant_id integer NOT NULL,
    status text NOT NULL,
    created_at timestamptz NOT NULL,
    amount numeric(10,2) NOT NULL
);

INSERT INTO orders (order_id, tenant_id, status, created_at, amount)
SELECT g,
       ((g - 1) % 100) + 1,
       CASE WHEN g % 5 = 0 THEN 'paid'
            WHEN g % 5 = 1 THEN 'pending'
            WHEN g % 5 = 2 THEN 'shipped'
            WHEN g % 5 = 3 THEN 'cancelled'
            ELSE 'refunded' END,
       timestamptz '2024-01-01 UTC' + ((g % 730)::text || ' days')::interval
           + ((g % 86400)::text || ' seconds')::interval,
       round((10 + ((g * 37) % 99000) / 100.0)::numeric, 2)
FROM generate_series(1, 1000000) AS s(g);

ANALYZE orders;
