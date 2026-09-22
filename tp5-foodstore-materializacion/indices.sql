-- TP5 - Parte A: Indices
--

-- Indice para optimizar consulta 1 (índice trigram)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DROP INDEX IF EXISTS idx_producto_nombre_trgm;
CREATE INDEX idx_producto_nombre_trgm
    ON producto USING gin (nombre gin_trgm_ops)
    WHERE eliminado = FALSE;

-- El B-tree no sirve acá porque, al ser _ un comodín de LIKE, el prefijo fijo que puede podar se corta en Producto, 
-- y como las 50.000 filas empiezan con ese texto, el índice no descarta nada y el planner prefiere el Seq Scan. 
-- El índice trigram en cambio indexa los trigramas internos del literal (Pro, rod, _45, etc.), que sí son selectivos 
-- contra el resto de los Producto_#, logrando poda real y un Bitmap Index Scan en microsegundos.


-- Tiempos de ejecución de la consulta original 
--  Seq Scan on producto  (cost=0.00..1153.00 rows=5 width=32) (actual time=6.040..6.749 rows=1 loops=1)
--   Filter: ((NOT eliminado) AND ((nombre)::text ~~ 'Producto_45345%'::text))
--   Rows Removed by Filter: 49999
-- Planning Time: 0.232 ms
-- Execution Time: 6.781 ms
--(5 filas)

-- Tiempos de la ejecución con el índice
--  Bitmap Heap Scan on producto  (cost=99.66..118.26 rows=5 width=32) (actual time=2.224..2.225 rows=1 loops=1)
--   Recheck Cond: (((nombre)::text ~~ 'Producto_45345%'::text) AND (NOT eliminado))
--   Rows Removed by Index Recheck: 1
--   Heap Blocks: exact=2
--   ->  Bitmap Index Scan on idx_producto_nombre_trgm  (cost=0.00..99.66 rows=5 width=0) (actual time=2.197..2.197 rows=2 loops=1)
--         Index Cond: ((nombre)::text ~~ 'Producto_45345%'::text)
-- Planning Time: 2.247 ms
-- Execution Time: 2.387 ms
--(8 filas)


-- Índice para optimizar consulta 2 (covering index)
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_activo_cover
    ON pedido (fecha)
    INCLUDE (usuario_id, total)
    WHERE eliminado = FALSE;


-- Pasó de recorrer las 200.000 filas con Seq Scan (175 ms) a un Bitmap Index Scan que poda directo 
-- por rango de fechas (0.76 ms). El índice descarta rápidamente la mayoría de la tabla y solo lee 
-- los bloques de los últimos 7 días.


-- Tiempo de ejecución de la consulta original
-- Gather  (cost=1000.00..4532.72 rows=19 width=30) (actual time=169.775..174.359 rows=0 loops=1)
--    Workers Planned: 1
--    Workers Launched: 1
--    ->  Parallel Seq Scan on pedido  (cost=0.00..3530.82 rows=11 width=30) (actual time=53.162..53.163 rows=0 loops=2)
--          Filter: ((NOT eliminado) AND (fecha >= (now() - '7 days'::interval)))
--          Rows Removed by Filter: 100000
--  Planning Time: 8.436 ms
--  Execution Time: 175.084 ms
-- (8 filas)

-- Tiempo de ejecución con el índice
--  Bitmap Heap Scan on pedido  (cost=4.57..74.43 rows=19 width=30) (actual time=0.089..0.090 rows=0 loops=1)
--    Recheck Cond: ((fecha >= (now() - '7 days'::interval)) AND (NOT eliminado))
--    ->  Bitmap Index Scan on idx_pedido_fecha_activo_cover  (cost=0.00..4.57 rows=19 width=0) (actual time=0.076..0.076 rows=0 loops=1)
--          Index Cond: (fecha >= (now() - '7 days'::interval))
--  Planning Time: 2.216 ms
--  Execution Time: 0.759 ms
-- (6 filas)


-- Índice para optimizar consulta 3 (covering index)
CREATE INDEX idx_detalle_pedido_pedidoid_cover
    ON detalle_pedido (pedido_id)
    INCLUDE (id_detalle, producto_id, cantidad, subtotal)
    WHERE eliminado = FALSE;


-- Se eligió por ser un covering index: cubre todas las columnas de detalle_pedido del SELECT, logrando un Index Only Scan con 0 accesos al heap (Heap Fetches: 0), 
-- lo que eliminó el barrido de 200.000 filas y bajó el tiempo de 18.9 ms a 0.21 ms (~90×). Además combina el filtro por pedido_id con la poda parcial eliminado = FALSE, 
-- y el JOIN a producto se resuelve igual con su PK, quedando un plan mínimo: Index Only Scan + Index Scan por PK.


-- Tiempo de ejecución de la consulta original
-- Nested Loop  (cost=0.29..4180.31 rows=1 width=40) (actual time=14.755..18.825 rows=1 loops=1)
--    ->  Seq Scan on detalle_pedido dp  (cost=0.00..4172.00 rows=1 width=26) (actual time=14.704..18.774 rows=1 loops=1)
--          Filter: ((NOT eliminado) AND (pedido_id = 150000))
--          Rows Removed by Filter: 199999
--    ->  Index Scan using producto_pkey on producto pr  (cost=0.29..8.31 rows=1 width=22) (actual time=0.041..0.041 rows=1 loops=1)
--          Index Cond: (id_producto = dp.producto_id)
--  Planning Time: 19.853 ms
--  Execution Time: 18.901 ms
-- (8 filas)


-- Tiempo de ejecución con el índice
-- Nested Loop  (cost=0.71..16.75 rows=1 width=40) (actual time=0.184..0.185 rows=1 loops=1)
--    ->  Index Only Scan using idx_detalle_pedido_pedidoid_cover on detalle_pedido dp  (cost=0.42..8.44 rows=1 width=26) (actual time=0.173..0.174 rows=1 loops=1)
--          Index Cond: (pedido_id = 150000)
--          Heap Fetches: 0
--    ->  Index Scan using producto_pkey on producto pr  (cost=0.29..8.31 rows=1 width=22) (actual time=0.008..0.008 rows=1 loops=1)
--          Index Cond: (id_producto = dp.producto_id)
--  Planning Time: 2.294 ms
--  Execution Time: 0.212 ms
-- (8 filas)