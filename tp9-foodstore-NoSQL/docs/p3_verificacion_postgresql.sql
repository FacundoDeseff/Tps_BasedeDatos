-- =====================================================================
-- p3_verificacion_postgresql.sql
-- TP9 - Unidad 7 - Parte 3: verificacion de las afirmaciones de IA
--
-- Uso:
--   psql -h localhost -U postgres -d foodstore -f docs/p3_verificacion_postgresql.sql
--
-- La prueba de total incoherente corre dentro de BEGIN/ROLLBACK: no deja datos.
-- Las pruebas C, D y E fallan a proposito y no insertan filas.
-- =====================================================================

\echo '=============================================================='
\echo 'A) RESTRICCIONES DECLARATIVAS DE pedido Y detalle_pedido'
\echo '=============================================================='
SELECT c.conrelid::regclass AS tabla, c.conname AS restriccion, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
WHERE c.conrelid IN ('pedido'::regclass, 'detalle_pedido'::regclass)
ORDER BY tabla, c.contype, c.conname;

\echo ''
\echo '=============================================================='
\echo 'B) PRUEBA: PostgreSQL ACEPTA un total incoherente con el detalle'
\echo '   pedido total=1.00 con una linea subtotal=100.00 (ROLLBACK)'
\echo '=============================================================='
BEGIN;
INSERT INTO pedido (id_pedido, usuario_id, total)
OVERRIDING SYSTEM VALUE
VALUES (999999, (SELECT id_usuario FROM usuario LIMIT 1), 1.00);

INSERT INTO detalle_pedido (id_detalle, pedido_id, producto_id, cantidad, subtotal)
OVERRIDING SYSTEM VALUE
VALUES (999999, 999999, (SELECT id_producto FROM producto LIMIT 1), 1, 100.00);

SELECT p.id_pedido, p.total, SUM(d.subtotal) AS suma_subtotales
FROM pedido p JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
WHERE p.id_pedido = 999999
GROUP BY p.id_pedido, p.total;

\echo 'RESULTADO: la fila se inserto sin error; PostgreSQL no compara total con la suma de subtotales.'
ROLLBACK;

\echo ''
\echo '=============================================================='
\echo 'C) PRUEBA: clave foranea RECHAZA un detalle huerfano'
\echo '=============================================================='
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, subtotal)
VALUES (999999998, (SELECT id_producto FROM producto LIMIT 1), 1, 10.00);
\echo 'RESULTADO: RECHAZADO por la clave foranea.'

\echo ''
\echo '=============================================================='
\echo 'D) PRUEBA: CHECK RECHAZA cantidad = 0'
\echo '=============================================================='
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, subtotal)
VALUES (1, (SELECT id_producto FROM producto LIMIT 1), 0, 10.00);
\echo 'RESULTADO: RECHAZADO por el CHECK de cantidad.'

\echo ''
\echo '=============================================================='
\echo 'E) PRUEBA: CHECK RECHAZA subtotal negativo'
\echo '=============================================================='
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, subtotal)
VALUES (1, (SELECT id_producto FROM producto LIMIT 1), 1, -10.00);
\echo 'RESULTADO: RECHAZADO por el CHECK de subtotal.'

\echo ''
\echo '=============================================================='
\echo 'F) ESTADO FINAL: no quedaron filas de prueba'
\echo '=============================================================='
SELECT COUNT(*) AS pedidos_999999 FROM pedido WHERE id_pedido = 999999;
SELECT COUNT(*) AS detalles_999999 FROM detalle_pedido WHERE id_detalle IN (999999, 999999998);
