-- PARTE 2: DESNORMALIZACIÓN CONTROLADA

-- 1. Consulta original pesada (Medición ANTES)
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.pedido_id
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- 2. Estructura desnormalizada (Vista Materializada)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_top_categorias_diarias AS
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido,
       ped.fecha
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.pedido_id
WHERE dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre, ped.fecha;

CREATE INDEX IF NOT EXISTS idx_mv_top_cat_fecha ON mv_top_categorias_diarias(fecha);

-- 3. Consulta optimizada (Medición DESPUÉS)
EXPLAIN ANALYZE
SELECT categoria, total_vendido
FROM mv_top_categorias_diarias
WHERE fecha = CURRENT_DATE
ORDER BY total_vendido DESC
LIMIT 5;

-- 4. Script de auditoría (Debe dar 0 filas)
SELECT 
    c.nombre AS categoria,
    SUM(dp.subtotal) AS total_calculado,
    mv.total_vendido AS total_registrado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.pedido_id
LEFT JOIN mv_top_categorias_diarias mv ON mv.categoria = c.nombre AND mv.fecha = ped.fecha
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre, ped.fecha, mv.total_vendido
HAVING SUM(dp.subtotal) IS DISTINCT FROM mv.total_vendido;