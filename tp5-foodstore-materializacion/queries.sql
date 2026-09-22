-- TP5 - Consultas de trabajo
-- Deseff Facundo y Ramirez Facundo

-- ===== Queries parte A =====

-- Query para buscar productos por nombre
EXPLAIN ANALYZE
SELECT id_producto, nombre, precio_lista, stock
FROM producto
WHERE nombre LIKE 'Producto_45345%' AND eliminado = FALSE;

-- Query para reportar ventas en rangos de fechas
EXPLAIN ANALYZE
SELECT id_pedido, usuario_id, fecha, total
FROM pedido
WHERE fecha >= NOW() - INTERVAL '7 days' AND eliminado = FALSE;

-- Query para revisar el contenido de un pedido
EXPLAIN ANALYZE
SELECT dp.id_detalle, dp.producto_id, dp.cantidad, dp.subtotal, pr.nombre
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
WHERE dp.pedido_id = 150000 AND dp.eliminado = FALSE;