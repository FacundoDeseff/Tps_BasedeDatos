-- ==========================================================
-- TP4: Reportes analíticos asistidos por IA sobre Food Store
-- Integrantes: Facundo Deseff y Facundo Ramirez
-- ==========================================================

-- ==========================================================
-- PARTE 1: Consultas analíticas y optimizaciones
-- ==========================================================

-- Consulta 1 (Inicial): Facturación por categoría y mes
EXPLAIN ANALYZE
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
ORDER BY mes DESC, total_facturado DESC;

-- Consulta 1 (Optimizada con CTE):
EXPLAIN ANALYZE
WITH detalle_agrupado AS (
    SELECT 
        dp.pedido_id,
        pr.id_categoria,
        SUM(dp.subtotal) AS subtotal_cat
    FROM detalle_pedido dp
    JOIN producto pr ON dp.producto_id = pr.id_producto
    WHERE dp.eliminado = FALSE 
      AND pr.eliminado = FALSE
    GROUP BY dp.pedido_id, pr.id_categoria
)
SELECT 
    da.id_categoria,
    DATE_TRUNC('month', pe.fecha) AS mes,
    SUM(da.subtotal_cat) AS total_facturado,
    COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos
FROM pedido pe
JOIN detalle_agrupado da ON pe.id_pedido = da.pedido_id
WHERE pe.eliminado = FALSE
GROUP BY da.id_categoria, DATE_TRUNC('month', pe.fecha)
ORDER BY mes DESC, total_facturado DESC;


-- Consulta 2 (Inicial): Ranking de clientes por gasto total
EXPLAIN ANALYZE
SELECT 
    u.id_usuario,
    u.nombre,
    u.apellido,
    SUM(dp.subtotal) AS total_gastado,
    COUNT(DISTINCT pe.id_pedido) AS pedidos_realizados
FROM usuario u
JOIN pedido pe ON u.id_usuario = pe.usuario_id
JOIN detalle_pedido dp ON pe.id_pedido = dp.pedido_id
WHERE u.eliminado = FALSE 
  AND pe.eliminado = FALSE 
  AND dp.eliminado = FALSE
GROUP BY u.id_usuario, u.nombre, u.apellido
ORDER BY total_gastado DESC
LIMIT 50;

-- Consulta 2 (Optimizada con CTE y Merge Join):
EXPLAIN ANALYZE
WITH totales_usuario AS (
    SELECT 
        pe.usuario_id,
        SUM(dp.subtotal) AS total_gastado,
        COUNT(DISTINCT pe.id_pedido) AS pedidos_realizados
    FROM pedido pe
    JOIN detalle_pedido dp ON pe.id_pedido = dp.pedido_id
    WHERE pe.eliminado = FALSE 
      AND dp.eliminado = FALSE
    GROUP BY pe.usuario_id
)
SELECT 
    u.id_usuario,
    u.nombre,
    u.apellido,
    tu.total_gastado,
    tu.pedidos_realizados
FROM usuario u
JOIN totales_usuario tu ON tu.usuario_id = u.id_usuario
WHERE u.eliminado = FALSE
ORDER BY tu.total_gastado DESC
LIMIT 50;


-- ==========================================================
-- PARTE 3: Rankings, Equivalencia y Subconsultas
-- ==========================================================

-- 1. Versión A: Ranking con JOIN directo
SELECT 
    u.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_completo,
    SUM(pe.total) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(pe.total) DESC) AS puesto
FROM usuario u
JOIN pedido pe ON u.id_usuario = pe.usuario_id
WHERE u.eliminado = FALSE 
  AND pe.eliminado = FALSE
GROUP BY u.id_usuario, u.nombre, u.apellido;

-- 2. Versión B: Ranking con CTE
WITH gasto_usuario AS (
    SELECT 
        usuario_id, 
        SUM(total) AS total_gastado
    FROM pedido
    WHERE eliminado = FALSE
    GROUP BY usuario_id
)
SELECT 
    u.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_completo,
    gu.total_gastado,
    DENSE_RANK() OVER (ORDER BY gu.total_gastado DESC) AS puesto
FROM usuario u
JOIN gasto_usuario gu ON u.id_usuario = gu.usuario_id
WHERE u.eliminado = FALSE;

-- 3. Verificación de equivalencia con EXCEPT (retorna 0 filas)
(
    SELECT 
        u.id_usuario,
        u.nombre || ' ' || u.apellido AS nombre_completo,
        SUM(pe.total) AS total_gastado,
        DENSE_RANK() OVER (ORDER BY SUM(pe.total) DESC) AS puesto
    FROM usuario u
    JOIN pedido pe ON u.id_usuario = pe.usuario_id
    WHERE u.eliminado = FALSE AND pe.eliminado = FALSE
    GROUP BY u.id_usuario, u.nombre, u.apellido
)
EXCEPT
(
    WITH gasto_usuario AS (
        SELECT 
            usuario_id, 
            SUM(total) AS total_gastado
        FROM pedido
        WHERE eliminado = FALSE
        GROUP BY usuario_id
    )
    SELECT 
        u.id_usuario,
        u.nombre || ' ' || u.apellido AS nombre_completo,
        gu.total_gastado,
        DENSE_RANK() OVER (ORDER BY gu.total_gastado DESC) AS puesto
    FROM usuario u
    JOIN gasto_usuario gu ON u.id_usuario = gu.usuario_id
    WHERE u.eliminado = FALSE
);

-- 4. Subconsulta correlacionada (Último pedido por cliente)
SELECT 
    u.id_usuario,
    u.nombre || ' ' || u.apellido AS cliente,
    (
        SELECT MAX(pe.fecha)
        FROM pedido pe
        WHERE pe.usuario_id = u.id_usuario
          AND pe.eliminado = FALSE
    ) AS fecha_ultimo_pedido
FROM usuario u
WHERE u.eliminado = FALSE;