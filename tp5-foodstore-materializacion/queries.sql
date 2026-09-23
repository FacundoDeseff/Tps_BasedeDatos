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


-- ===== Queries Parte B =====

-- Consulta equivalente a v_productos_vigentes
SELECT 
    p.id_producto,
    p.nombre AS producto_nombre,
    p.precio_lista,
    p.stock,
    c.id_categoria,
    c.nombre AS categoria_nombre
FROM producto p
INNER JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.eliminado = FALSE
  AND c.eliminado = FALSE;


-- Consulta equivalente a v_pedidos_usuario
SELECT 
    p.id_pedido,
    p.fecha,
    p.total,
    u.id_usuario,
    u.nombre AS usuario_nombre,
    u.apellido AS usuario_apellido
FROM pedido p
INNER JOIN usuario u ON p.usuario_id = u.id_usuario
WHERE p.eliminado = FALSE;


-- Consulta equivalente a v_detalle_pedido_producto
SELECT 
    dp.pedido_id AS id_pedido,
    dp.id_detalle,
    dp.producto_id,
    pr.nombre AS producto_nombre,
    dp.cantidad,
    dp.subtotal
FROM detalle_pedido dp
INNER JOIN pedido p ON dp.pedido_id = p.id_pedido
INNER JOIN producto pr ON dp.producto_id = pr.id_producto
WHERE dp.eliminado = FALSE
  AND p.eliminado = FALSE
  AND pr.eliminado = FALSE;



-- ===== Query Parte C =====

-- Consulta equivalente a vista materializada vm_facturacion_categoria_mes
SELECT 
    c.id_categoria,
    c.nombre AS categoria_nombre,
    DATE_TRUNC('month', p.fecha) AS mes,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    SUM(dp.subtotal) AS total_facturado
FROM pedido p
JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
JOIN producto pr ON dp.producto_id = pr.id_producto
JOIN categoria c ON pr.id_categoria = c.id_categoria
WHERE p.eliminado = FALSE 
  AND dp.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
ORDER BY mes, categoria_nombre;