-- Consulta 1: Listado por categoría (filtro simple con borrado lógico)
EXPLAIN ANALYZE 
SELECT * FROM producto 
WHERE id_categoria = 3 AND eliminado = FALSE;

-- Consulta 2: Historial de pedidos por usuario
EXPLAIN ANALYZE 
SELECT * FROM pedido 
WHERE usuario_id = 4520;

-- Consulta 3: Facturación agregada por categoría
EXPLAIN ANALYZE 
SELECT pr.id_categoria, SUM(dp.subtotal) AS facturado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
WHERE dp.eliminado = FALSE
GROUP BY pr.id_categoria;