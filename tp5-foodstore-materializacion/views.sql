-- ==========================================================
-- TP5: Parte B - Vistas para Reportes y Seguridad
-- ==========================================================

-- 1. Productos vigentes con su categoría
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT 
    p.id_producto,
    p.nombre AS producto,
    p.precio,
    c.nombre AS categoria
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.eliminado = FALSE AND c.eliminado = FALSE;

-- 2. Pedidos con datos de usuario
CREATE OR REPLACE VIEW v_pedidos_usuario AS
SELECT 
    pe.id_pedido,
    pe.fecha,
    pe.total,
    u.id_usuario,
    u.nombre || ' ' || u.apellido AS cliente
FROM pedido pe
JOIN usuario u ON pe.usuario_id = u.id_usuario
WHERE pe.eliminado = FALSE AND u.eliminado = FALSE;

-- 3. Vista de seguridad: Usuarios sin columna contraseña
CREATE OR REPLACE VIEW v_usuarios_seguros AS
SELECT 
    id_usuario,
    nombre,
    apellido,
    email,
    fecha_registro
FROM usuario
WHERE eliminado = FALSE;


-- ==========================================================
-- TP5: Parte C - Vista Materializada
-- ==========================================================

-- Vista materializada para el reporte pesado de facturación por categoría y mes
CREATE MATERIALIZED VIEW IF NOT EXISTS vm_facturacion_categoria_mes AS
SELECT 
    pr.id_categoria,
    DATE_TRUNC('month', pe.fecha) AS mes,
    SUM(dp.subtotal) AS total_facturado,
    COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos
FROM pedido pe
JOIN detalle_pedido dp ON pe.id_pedido = dp.pedido_id
JOIN producto pr ON dp.producto_id = pr.id_producto
WHERE pe.eliminado = FALSE 
  AND dp.eliminado = FALSE 
  AND pr.eliminado = FALSE
GROUP BY pr.id_categoria, DATE_TRUNC('month', pe.fecha)
WITH DATA;

-- Índice único requerido para permitir refrescos concurrentes sin bloquear lecturas
CREATE UNIQUE INDEX IF NOT EXISTS idx_vm_facturacion_cat_mes 
ON vm_facturacion_categoria_mes (id_categoria, mes);