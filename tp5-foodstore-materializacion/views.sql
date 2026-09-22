-- TP5 - Parte B: Vistas de reportes y seguridad

-- 1. Productos vigentes (con su categoría)
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT 
    p.id_producto,
    p.nombre AS producto_nombre,
    p.precio_lista,
    p.stock,
    c.id_categoria,
    c.nombre AS categoria_nombre
FROM producto p
JOIN categoria c ON p.categoria_id = c.id_categoria
WHERE p.eliminado = FALSE;

-- 2. Pedidos de usuarios (pedidos vinculados con datos del cliente)
CREATE OR REPLACE VIEW v_pedidos_usuario AS
SELECT 
    p.id_pedido,
    p.fecha,
    p.total,
    u.id_usuario,
    u.nombre AS usuario_nombre,
    u.email
FROM pedido p
JOIN usuario u ON p.usuario_id = u.id_usuario
WHERE p.eliminado = FALSE;

-- 3. Usuarios seguros (oculta la contraseña u otros campos sensibles por seguridad)
CREATE OR REPLACE VIEW v_usuarios_seguros AS
SELECT 
    id_usuario,
    nombre,
    email,
    fecha_registro
FROM usuario
WHERE eliminado = FALSE;


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
JOIN categoria c ON pr.categoria_id = c.id_categoria
WHERE p.eliminado = FALSE AND dp.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
WITH DATA;

-- Índice único para habilitar el REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_vm_facturacion_cat_mes 
ON vm_facturacion_categoria_mes (id_categoria, mes);