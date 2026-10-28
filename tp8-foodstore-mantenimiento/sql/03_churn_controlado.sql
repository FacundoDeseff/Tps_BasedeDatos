-- =====================================================================
-- 03_churn_controlado.sql
-- TP Unidad 6 - Mantenimiento, respaldo y recuperacion (Food Store)
--
-- Objetivo: generar tuplas muertas REALES en foodstore para demostrar que
-- el health check las detecta y que maintenance.sql las resuelve.
--
-- Por que con UPDATE y no con DELETE: un UPDATE no borra la fila vieja,
-- la deja como version muerta hasta que VACUUM la recupere. Es el patron
-- real de una tabla operativa (pedidos que se corrigen, stock que se
-- ajusta) y no rompe ninguna restriccion logica del TP:
--   * pedido.fecha se desplaza un dia  -> no afecta pedido.total.
--   * producto.stock se incrementa     -> sigue cumpliendo stock >= 0.
-- NO se toca detalle_pedido.subtotal justamente para no romper el
-- invariante pedido.total = SUM(detalle_pedido.subtotal) que valida la
-- Parte 4 (restauracion).
--
-- Es un script de LABORATORIO: no forma parte de la rutina diaria y no
-- debe ejecutarse contra la base principal en produccion.
--
-- Uso:
--   psql -h localhost -p 5432 -U postgres -d foodstore \
--        -v ON_ERROR_STOP=1 -f sql/03_churn_controlado.sql
-- =====================================================================

\set ON_ERROR_STOP on
\pset pager off
\pset border 2

-- 40 % de las filas por pasada, 2 pasadas => ~160.000 tuplas muertas en
-- pedido sobre 200.000 vivas (~44 %), muy por encima del umbral de 10 %.
\set pct_filas 40
\set pasadas 2

\echo ''
\echo '==============================================================================='
\echo ' CHURN CONTROLADO - generacion de tuplas muertas (laboratorio)'
\echo '==============================================================================='

\echo ''
\echo '--- Estado ANTES del churn ----------------------------------------------------'
SELECT relname        AS tabla,
       n_live_tup     AS tuplas_vivas,
       n_dead_tup     AS tuplas_muertas,
       round(100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1), 2) AS muertas_pct
FROM pg_stat_user_tables
WHERE relname IN ('pedido', 'producto')
ORDER BY relname;

\echo ''
\echo '--- Aplicando churn ------------------------------------------------------------'

DO $churn$
DECLARE
    v_pasadas int := 2;
    v_pct     int := 40;
    v_rows    bigint;
    i         int;
BEGIN
    FOR i IN 1..v_pasadas LOOP
        UPDATE pedido
           SET fecha = fecha - interval '1 day'
         WHERE id_pedido % 100 < v_pct;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        RAISE NOTICE 'pedido   pasada %/%: % filas actualizadas', i, v_pasadas, v_rows;

        UPDATE producto
           SET stock = stock + 1
         WHERE id_producto % 100 < v_pct;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        RAISE NOTICE 'producto pasada %/%: % filas actualizadas', i, v_pasadas, v_rows;
    END LOOP;
END
$churn$;

-- Se espera a que el recolector de estadisticas publique los contadores;
-- sin esto el health check inmediato podria leer n_dead_tup viejo.
SELECT pg_sleep(1) AS espera_estadisticas;

\echo ''
\echo '--- Estado DESPUES del churn ---------------------------------------------------'
SELECT relname        AS tabla,
       n_live_tup     AS tuplas_vivas,
       n_dead_tup     AS tuplas_muertas,
       round(100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1), 2) AS muertas_pct
FROM pg_stat_user_tables
WHERE relname IN ('pedido', 'producto')
ORDER BY relname;

\echo ''
\echo '--- Integridad intacta tras el churn (debe dar todo 0) -------------------------'
SELECT (SELECT count(*) FROM producto WHERE stock < 0 OR precio_lista <= 0)       AS productos_invalidos,
       (SELECT count(*) FROM detalle_pedido WHERE cantidad <= 0 OR subtotal < 0)   AS detalles_invalidos,
       (SELECT count(*) FROM pedido p
         JOIN (SELECT pedido_id, sum(subtotal) s
                 FROM detalle_pedido GROUP BY pedido_id) x
           ON x.pedido_id = p.id_pedido
        WHERE p.total <> x.s)                                                      AS totales_descuadrados;
