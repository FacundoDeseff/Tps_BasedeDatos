-- TP5 - Parte B: Vistas para reportes del sistema

-- 1. Productos vigentes con su categoría
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT 
    p.id_producto,
    p.nombre AS producto_nombre,
    p.precio_lista,
    p.stock,
    c.id_categoria,
    c.nombre AS categoria_nombre
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.eliminado = FALSE;

-- 2. Pedidos con datos del usuario (Aplica criterio de seguridad: expone solo nombre/apellido)
CREATE OR REPLACE VIEW v_pedidos_usuario AS
SELECT 
    p.id_pedido,
    p.fecha,
    p.total,
    u.id_usuario,
    u.nombre AS usuario_nombre,
    u.apellido AS usuario_apellido
FROM pedido p
JOIN usuario u ON p.usuario_id = u.id_usuario
WHERE p.eliminado = FALSE;

-- 3. Detalle de pedido con el nombre del producto
CREATE OR REPLACE VIEW v_detalle_pedido_producto AS
SELECT 
    dp.id_detalle,
    dp.pedido_id,
    dp.producto_id,
    pr.nombre AS producto_nombre,
    dp.cantidad,
    dp.subtotal
FROM detalle_pedido dp
JOIN producto pr ON dp.producto_id = pr.id_producto
WHERE dp.eliminado = FALSE;


-- TP5 - Parte C: Vista materializada

-- Vista materializada de facturación agregada por categoría y mes
CREATE MATERIALIZED VIEW IF NOT EXISTS vm_facturacion_categoria_mes AS
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
WHERE p.eliminado = FALSE AND dp.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
WITH DATA;

-- Índice único obligatorio para REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_vm_facturacion_cat_mes 
ON vm_facturacion_categoria_mes (id_categoria, mes);