-- ============================================================
-- Consigna 3.c - Comprobaciones del code review con IA
-- Se ejecuta en psql, sobre la base foodstore (SOLO LECTURA).
--
--   & "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h localhost -p 5432 `
--       -U postgres -X -d foodstore -f docs\verificaciones_consigna3.sql
--
-- La salida real está en docs/evidencia_consigna3.txt.
--
-- Nota sobre 2.a: la vista v_snapshot_movil se crea en la copia
-- foodstore_u8; en foodstore puede no existir. El conteo 0 no es un error:
-- la consulta de abajo reproduce el SELECT de la vista sobre foodstore.
-- ============================================================

\pset pager off

\echo '== CONSIGNA 2.a: SELECT de v_snapshot_movil sobre foodstore (8 filas) =='
SELECT count(*) AS vistas_creadas_en_la_base
FROM pg_views WHERE viewname = 'v_snapshot_movil';

SELECT p.id_producto                         AS id,
       p.nombre                              AS nombre,
       round(p.precio_lista * 100)::bigint   AS precio_centavos,
       p.stock                               AS stock,
       (p.stock > 0 AND NOT p.eliminado)     AS disponible,
       p.eliminado                           AS eliminado,
       now()::date                           AS fecha_copia
FROM producto p
WHERE p.id_producto IN (1, 3, 4, 5, 6, 7, 8, 10)
ORDER BY p.id_producto;

\echo '== F1: distribucion de productos por categoria =='
SELECT id_categoria, count(*) AS productos
FROM producto
GROUP BY id_categoria
ORDER BY id_categoria;

SELECT count(DISTINCT id_categoria) AS categorias_distintas,
       count(*) FILTER (WHERE id_categoria = 3) AS productos_categoria_3,
       count(*) AS total_productos
FROM producto;

\echo '== F2: pedido.fecha es timestamp, no date (TP6 usa fecha = CURRENT_DATE) =='
-- CURRENT_DATE compararia un timestamp contra la medianoche. Se usa el
-- ultimo dia con datos para que la diferencia se vea con datos reales.
SELECT max(fecha)::date AS ultimo_dia_con_datos,
       count(*) FILTER (WHERE fecha::date = (SELECT max(fecha)::date FROM pedido)) AS pedidos_por_dia,
       count(*) FILTER (WHERE fecha = (SELECT max(fecha)::date FROM pedido))        AS pedidos_por_medianoche
FROM pedido;

SELECT 'agrupando por timestamp' AS agrupacion, count(*) AS filas FROM (
    SELECT c.nombre, ped.fecha, sum(dp.subtotal) AS total
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.producto_id
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    JOIN pedido ped ON ped.id_pedido = dp.pedido_id
    WHERE dp.eliminado = FALSE AND ped.eliminado = FALSE
    GROUP BY c.nombre, ped.fecha
) x
UNION ALL
SELECT 'agrupando por dia', count(*) FROM (
    SELECT c.nombre, ped.fecha::date, sum(dp.subtotal) AS total
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.producto_id
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    JOIN pedido ped ON ped.id_pedido = dp.pedido_id
    WHERE dp.eliminado = FALSE AND ped.eliminado = FALSE
    GROUP BY c.nombre, ped.fecha::date
) y;

\echo '== F2b: la vista materializada del TP6 existe en la base? =='
SELECT matviewname FROM pg_matviews WHERE matviewname = 'mv_top_categorias_diarias';

\echo '== F3: facturacion historica con y sin filtro pr.eliminado =='
SELECT sum(dp.subtotal)                                        AS total_sin_filtro,
       sum(dp.subtotal) FILTER (WHERE NOT pr.eliminado)        AS total_solo_vigentes,
       sum(dp.subtotal) FILTER (WHERE pr.eliminado)            AS total_productos_eliminados,
       round(100.0 * sum(dp.subtotal) FILTER (WHERE pr.eliminado)
             / sum(dp.subtotal), 2)                            AS pct_excluido
FROM pedido pe
JOIN detalle_pedido dp ON pe.id_pedido = dp.pedido_id
JOIN producto pr ON dp.producto_id = pr.id_producto
WHERE pe.eliminado = FALSE AND dp.eliminado = FALSE;

SELECT count(*) AS pedidos_con_productos_eliminados
FROM pedido pe
WHERE pe.eliminado = FALSE
  AND EXISTS (
      SELECT 1
      FROM detalle_pedido dp
      JOIN producto pr ON pr.id_producto = dp.producto_id
      WHERE dp.pedido_id = pe.id_pedido AND dp.eliminado = FALSE AND pr.eliminado
  );

\echo '== F7: subtotal generado vs precio_lista del producto =='
SELECT count(*) AS detalles_totales,
       count(*) FILTER (WHERE abs(d.subtotal / d.cantidad - p.precio_lista) > 0.01) AS detalles_incoherentes
FROM detalle_pedido d
JOIN producto p ON p.id_producto = d.producto_id;

SELECT d.id_detalle, d.cantidad, d.subtotal,
       round(d.subtotal / d.cantidad, 2) AS precio_implicito,
       p.precio_lista
FROM detalle_pedido d
JOIN producto p ON p.id_producto = d.producto_id
WHERE d.id_detalle = 1;

\echo '== F12: equivalencias del TP3 (0 = equivalentes) =='
SELECT 'comprobacion A' AS comprobacion, count(*) AS diferencias FROM (
    (
        SELECT c.nombre, COUNT(p.id_producto) AS total_productos
        FROM categoria c
        LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.eliminado = FALSE
        WHERE c.eliminado = FALSE
        GROUP BY c.id_categoria, c.nombre
    )
    EXCEPT
    (
        SELECT c.nombre,
               (SELECT COUNT(*) FROM producto p
                WHERE p.id_categoria = c.id_categoria AND p.eliminado = FALSE) AS total_productos
        FROM categoria c
        WHERE c.eliminado = FALSE
    )
) a
UNION ALL
SELECT 'comprobacion B', count(*) FROM (
    (
        SELECT id_pedido, fecha, total FROM pedido
        WHERE eliminado = FALSE
          AND total > (SELECT AVG(total) FROM pedido WHERE eliminado = FALSE)
    )
    EXCEPT
    (
        WITH promedio AS (SELECT AVG(total) AS prom FROM pedido WHERE eliminado = FALSE)
        SELECT p.id_pedido, p.fecha, p.total
        FROM pedido p, promedio
        WHERE p.eliminado = FALSE AND p.total > promedio.prom
    )
) b;

\echo '== F12b: categorias sin productos (COUNT(column) debe dar 0) =='
SELECT count(*) AS categorias_vacias FROM (
    SELECT c.id_categoria, COUNT(p.id_producto) AS total_productos
    FROM categoria c
    LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.eliminado = FALSE
    WHERE c.eliminado = FALSE
    GROUP BY c.id_categoria, c.nombre
) x
WHERE total_productos = 0;
