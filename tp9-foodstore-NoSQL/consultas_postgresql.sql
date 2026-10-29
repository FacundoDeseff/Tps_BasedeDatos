-- =====================================================================
-- consultas_postgresql.sql
-- TP9 - Unidad 7: Food Store en MongoDB
-- Parte 2 - Consigna 5: consultas equivalentes a b) y c)
--
-- Uso:
--   psql -h localhost -U postgres -d foodstore -f consultas_postgresql.sql
--
-- Universo comparable: id_pedido 1 a 6 (los pedidos migrados a MongoDB).
-- La base completa tiene 200000 pedidos; sin acotar, las cantidades no
-- serian comparables con la coleccion de MongoDB.
-- =====================================================================

\pset pager off

-- ---------------------------------------------------------------------
-- b) Estado ENTREGADO
--    pedido no tiene columna estado: el modelo documental define
--    ENTREGADO como pedido.eliminado = false (CANCELADO = true).
-- ---------------------------------------------------------------------
SELECT p.id_pedido, p.eliminado, p.total
FROM pedido p
WHERE p.eliminado = false
  AND p.id_pedido IN (1, 2, 3, 4, 5, 6)
ORDER BY p.id_pedido;

SELECT COUNT(*) AS cantidad, ARRAY_AGG(id_pedido ORDER BY id_pedido) AS ids
FROM pedido
WHERE eliminado = false
  AND id_pedido IN (1, 2, 3, 4, 5, 6);

-- ---------------------------------------------------------------------
-- c) Pedidos que contienen el producto 5829
--    EXISTS evita duplicar un pedido si el producto aparece en 2 lineas.
--    En el origen no hay lineas con detalle_pedido.eliminado = true, por lo
--    que no se filtra por ese campo (en MongoDB tampoco).
-- ---------------------------------------------------------------------
SELECT p.id_pedido, p.eliminado, p.total
FROM pedido p
WHERE EXISTS (
        SELECT 1 FROM detalle_pedido d
        WHERE d.pedido_id = p.id_pedido AND d.producto_id = 5829)
  AND p.id_pedido IN (1, 2, 3, 4, 5, 6)
ORDER BY p.id_pedido;

SELECT COUNT(*) AS cantidad, ARRAY_AGG(id_pedido ORDER BY id_pedido) AS ids
FROM pedido p
WHERE EXISTS (
        SELECT 1 FROM detalle_pedido d
        WHERE d.pedido_id = p.id_pedido AND d.producto_id = 5829)
  AND p.id_pedido IN (1, 2, 3, 4, 5, 6);

-- ---------------------------------------------------------------------
-- Contraste: la misma consulta SIN acotar el universo.
--   Muestra por que hay que restringir a los pedidos migrados.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS cantidad_sin_acotar, ARRAY_AGG(id_pedido ORDER BY id_pedido) AS ids
FROM pedido p
WHERE EXISTS (
        SELECT 1 FROM detalle_pedido d
        WHERE d.pedido_id = p.id_pedido AND d.producto_id = 5829);

SELECT COUNT(*) AS entregados_sin_acotar
FROM pedido
WHERE eliminado = false;
