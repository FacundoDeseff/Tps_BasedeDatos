-- TP5 - Parte A: Indices
--

-- Indice para optimizar consulta 1 (índice trigram)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DROP INDEX IF EXISTS idx_producto_nombre_trgm;
CREATE INDEX idx_producto_nombre_trgm
    ON producto USING gin (nombre gin_trgm_ops)
    WHERE eliminado = FALSE;

-- El B-tree no sirve acá porque, al ser _ un comodín de LIKE, el prefijo fijo que puede podar se corta en Producto, y como las 50.000 filas empiezan con ese texto, el índice no descarta nada y el planner prefiere el Seq Scan. El índice trigram en cambio indexa los trigramas internos del literal (Pro, rod, _45, etc.), que sí son selectivos contra el resto de los Producto_#, logrando poda real y un Bitmap Index Scan en microsegundos.

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