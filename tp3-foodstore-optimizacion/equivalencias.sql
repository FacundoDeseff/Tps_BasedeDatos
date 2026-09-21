-- COMPROBACIÓN A: Cantidad de productos por categoría vigente
-- Si son idénticas, ambas operaciones EXCEPT deben retornar 0 filas
(
    -- Versión 1 (LEFT JOIN + GROUP BY)
    SELECT c.nombre, COUNT(p.id_producto) AS total_productos
    FROM categoria c
    LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.eliminado = FALSE
    WHERE c.eliminado = FALSE
    GROUP BY c.id_categoria, c.nombre
)
EXCEPT
(
    -- Versión 2 (Subconsulta correlacionada en SELECT)
    SELECT 
        c.nombre,
        (SELECT COUNT(*) 
         FROM producto p 
         WHERE p.id_categoria = c.id_categoria AND p.eliminado = FALSE) AS total_productos
    FROM categoria c
    WHERE c.eliminado = FALSE
);


-- COMPROBACIÓN B: Pedidos con total superior al promedio general vigente
(
    -- Versión 1 (Subconsulta escalar en WHERE)
    SELECT id_pedido, fecha, total
    FROM pedido
    WHERE eliminado = FALSE
      AND total > (SELECT AVG(total) FROM pedido WHERE eliminado = FALSE)
)
EXCEPT
(
    -- Versión 2 (CTE agregada + Cross Join)
    WITH promedio AS (
        SELECT AVG(total) AS prom FROM pedido WHERE eliminado = FALSE
    )
    SELECT p.id_pedido, p.fecha, p.total
    FROM pedido p, promedio
    WHERE p.eliminado = FALSE AND p.total > promedio.prom
);