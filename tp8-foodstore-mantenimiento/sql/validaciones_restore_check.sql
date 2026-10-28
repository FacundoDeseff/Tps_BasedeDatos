-- =====================================================================
-- validaciones_restore_check.sql
-- TP Unidad 6 - Simulacro de restauracion (Parte 4)
--
-- Devuelve UNA sola linea: PASS o FALLA:motivo
--
-- Uso:
--   psql -w -h localhost -p 5432 -U postgres -d foodstore_restore_test ^
--        -At -v ON_ERROR_STOP=1 -f sql\validaciones_restore_check.sql
--
-- IMPORTANTE: ejecutar SOLO contra foodstore_restore_test.
-- Las cantidades esperadas son las registradas antes del respaldo del
-- 2026-10-28 20:08 (11 / 20.000 / 50.000 / 200.000 / 400.000).
-- =====================================================================
\set ON_ERROR_STOP on

WITH m AS (
    SELECT
        (SELECT count(*) FROM categoria)      AS cat,
        (SELECT count(*) FROM usuario)        AS usr,
        (SELECT count(*) FROM producto)       AS prod,
        (SELECT count(*) FROM pedido)         AS ped,
        (SELECT count(*) FROM detalle_pedido) AS det,

        (SELECT count(*) FROM producto
          WHERE precio_lista <= 0 OR stock < 0) AS prod_inv,

        (SELECT count(*) FROM detalle_pedido
          WHERE cantidad <= 0 OR subtotal < 0) AS det_inv,

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
          WHERE p.id_producto IS NULL) AS huerfanas,

        (SELECT count(*) FROM (
            SELECT p.id_pedido
              FROM pedido p
              LEFT JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
             GROUP BY p.id_pedido, p.total
            HAVING p.total <> coalesce(sum(d.subtotal), 0)
         ) x) AS totales_mal,

        (SELECT count(*) FROM (
            SELECT (SELECT last_value FROM categoria_id_categoria_seq)      AS lv,
                   (SELECT max(id_categoria) FROM categoria)                 AS mx
            UNION ALL
            SELECT (SELECT last_value FROM usuario_id_usuario_seq),
                   (SELECT max(id_usuario) FROM usuario)
            UNION ALL
            SELECT (SELECT last_value FROM producto_id_producto_seq),
                   (SELECT max(id_producto) FROM producto)
            UNION ALL
            SELECT (SELECT last_value FROM pedido_id_pedido_seq),
                   (SELECT max(id_pedido) FROM pedido)
            UNION ALL
            SELECT (SELECT last_value FROM detalle_pedido_id_detalle_seq),
                   (SELECT max(id_detalle) FROM detalle_pedido)
         ) s
         WHERE coalesce(s.lv, 0) < coalesce(s.mx, 0)) AS seq_atras
)
SELECT CASE
    WHEN cat <> 11 OR usr <> 20000 OR prod <> 50000 OR ped <> 200000 OR det <> 400000
        THEN 'FALLA:conteos(categoria=' || cat || '/11,usuario=' || usr ||
             '/20000,producto=' || prod || '/50000,pedido=' || ped ||
             '/200000,detalle_pedido=' || det || '/400000)'
    WHEN prod_inv > 0 THEN 'FALLA:productos_invalidos=' || prod_inv
    WHEN det_inv > 0  THEN 'FALLA:detalles_invalidos=' || det_inv
    WHEN huerfanas > 0 THEN 'FALLA:fk_huerfanas=' || huerfanas
    WHEN totales_mal > 0 THEN 'FALLA:totales_descudrados=' || totales_mal
    WHEN seq_atras > 0 THEN 'FALLA:secuencias_atrasadas=' || seq_atras
    ELSE 'PASS'
END
FROM m;
