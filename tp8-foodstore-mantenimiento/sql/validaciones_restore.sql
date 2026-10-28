-- =====================================================================
-- validaciones_restore.sql
-- TP Unidad 6 - Simulacro de restauracion (Parte 4)
--
-- Reporte detallado de las validaciones minimas sobre la base restaurada.
-- Solo lectura: no modifica nada.
--
-- Uso:
--   psql -w -h localhost -p 5432 -U postgres -d foodstore_restore_test ^
--        -v ON_ERROR_STOP=1 -f sql\validaciones_restore.sql
--
-- Adaptacion al esquema real del proyecto (SPEC_U6.md seccion 5):
--   la consigna usa cliente / producto.precio / detalle_pedido.precio_unitario;
--   el esquema integrador usa usuario / producto.precio_lista / detalle_pedido.subtotal.
--
-- Cantidades esperadas = snapshot previo al respaldo del 2026-10-28 20:08.
-- =====================================================================
\set ON_ERROR_STOP on

\echo ''
\echo '=============================================================='
\echo 'VALIDACIONES DE RESTAURACION - foodstore_restore_test'
\echo '=============================================================='

\echo ''
\echo '--- 1. CONTEOS POR TABLA (observado vs. esperado pre-respaldo) ---'
SELECT tabla,
       observado,
       esperado,
       CASE WHEN observado = esperado THEN 'OK' ELSE 'ALERTA' END AS estado
FROM (
    SELECT 'categoria'      AS tabla, count(*) AS observado,     11 AS esperado FROM categoria
    UNION ALL
    SELECT 'usuario',                 count(*),              20000 FROM usuario
    UNION ALL
    SELECT 'producto',                count(*),              50000 FROM producto
    UNION ALL
    SELECT 'pedido',                  count(*),             200000 FROM pedido
    UNION ALL
    SELECT 'detalle_pedido',          count(*),             400000 FROM detalle_pedido
) t;

\echo ''
\echo '--- 2. PRODUCTOS INVALIDOS (precio_lista <= 0 o stock < 0) ---'
SELECT 'productos_invalidos' AS control,
       0 AS esperado,
       count(*) AS observado,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ALERTA' END AS estado
FROM producto
WHERE precio_lista <= 0 OR stock < 0;

\echo ''
\echo '--- 3. DETALLES INVALIDOS (cantidad <= 0 o subtotal < 0) ---'
SELECT 'detalles_invalidos' AS control,
       0 AS esperado,
       count(*) AS observado,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ALERTA' END AS estado
FROM detalle_pedido
WHERE cantidad <= 0 OR subtotal < 0;

\echo ''
\echo '--- 4. CLAVES FORANEAS HUERFANAS ---'
SELECT 'fk_huerfanas' AS control,
       0 AS esperado,
       (
           (SELECT count(*) FROM pedido p
              LEFT JOIN usuario u ON u.id_usuario = p.usuario_id
             WHERE u.id_usuario IS NULL)
         + (SELECT count(*) FROM producto p
              LEFT JOIN categoria c ON c.id_categoria = p.id_categoria
             WHERE c.id_categoria IS NULL)
         + (SELECT count(*) FROM detalle_pedido d
              LEFT JOIN pedido p ON p.id_pedido = d.pedido_id
             WHERE p.id_pedido IS NULL)
         + (SELECT count(*) FROM detalle_pedido d
              LEFT JOIN producto p ON p.id_producto = d.producto_id
             WHERE p.id_producto IS NULL)
       ) AS observado,
       CASE WHEN (
           (SELECT count(*) FROM pedido p
              LEFT JOIN usuario u ON u.id_usuario = p.usuario_id
             WHERE u.id_usuario IS NULL)
         + (SELECT count(*) FROM producto p
              LEFT JOIN categoria c ON c.id_categoria = p.id_categoria
             WHERE c.id_categoria IS NULL)
         + (SELECT count(*) FROM detalle_pedido d
              LEFT JOIN pedido p ON p.id_pedido = d.pedido_id
             WHERE p.id_pedido IS NULL)
         + (SELECT count(*) FROM detalle_pedido d
              LEFT JOIN producto p ON p.id_producto = d.producto_id
             WHERE p.id_producto IS NULL)
       ) = 0 THEN 'OK' ELSE 'ALERTA' END AS estado;

\echo ''
\echo '--- 5. CONSISTENCIA DE TOTALES (pedido.total = SUM(detalle_pedido.subtotal)) ---'
SELECT 'totales_descudrados' AS control,
       0 AS esperado,
       count(*) AS observado,
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ALERTA' END AS estado
FROM (
    SELECT p.id_pedido
      FROM pedido p
      LEFT JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
     GROUP BY p.id_pedido, p.total
    HAVING p.total <> coalesce(sum(d.subtotal), 0)
) x;

\echo ''
\echo '--- 6. SECUENCIAS RESTAURADAS (last_value >= max(id)) ---'
SELECT seq,
       last_value,
       max_id,
       CASE WHEN coalesce(last_value, 0) >= coalesce(max_id, 0)
            THEN 'OK' ELSE 'ALERTA' END AS estado
FROM (
    SELECT 'categoria_id_categoria_seq' AS seq,
           (SELECT last_value FROM categoria_id_categoria_seq) AS last_value,
           (SELECT max(id_categoria) FROM categoria) AS max_id
    UNION ALL
    SELECT 'usuario_id_usuario_seq',
           (SELECT last_value FROM usuario_id_usuario_seq),
           (SELECT max(id_usuario) FROM usuario)
    UNION ALL
    SELECT 'producto_id_producto_seq',
           (SELECT last_value FROM producto_id_producto_seq),
           (SELECT max(id_producto) FROM producto)
    UNION ALL
    SELECT 'pedido_id_pedido_seq',
           (SELECT last_value FROM pedido_id_pedido_seq),
           (SELECT max(id_pedido) FROM pedido)
    UNION ALL
    SELECT 'detalle_pedido_id_detalle_seq',
           (SELECT last_value FROM detalle_pedido_id_detalle_seq),
           (SELECT max(id_detalle) FROM detalle_pedido)
) s;

\echo ''
\echo '--- 7. RESUMEN (PASS / FALLA:motivo) ---'
\ir validaciones_restore_check.sql
\echo ''
