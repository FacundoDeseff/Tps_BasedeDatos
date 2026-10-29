-- =====================================================================
-- 02_extraccion_origen.sql
-- TP9 - Unidad 7: Food Store en MongoDB
-- Parte 1: verificacion del subconjunto relacional que se migra
--
-- Base de origen: foodstore (esquema canonico TP3 / TP5 / TP8)
-- Pedidos seleccionados: id_pedido 1, 2, 3, 4, 5 y 6
--
-- Uso:
--   psql -h localhost -U postgres -d foodstore -f 02_extraccion_origen.sql
-- =====================================================================

\pset pager off

-- ---------------------------------------------------------------------
-- 1. Filas de origen: cabecera, cliente, lineas, producto y categoria
-- ---------------------------------------------------------------------
SELECT
    p.id_pedido,
    p.usuario_id,
    u.nombre AS cliente_nombre,
    u.apellido AS cliente_apellido,
    p.fecha,
    p.total,
    p.eliminado AS pedido_eliminado,
    d.id_detalle,
    d.producto_id,
    pr.nombre AS nombre_producto,
    pr.precio_lista,
    c.id_categoria,
    c.nombre AS categoria,
    d.cantidad,
    d.subtotal,
    d.eliminado AS detalle_eliminado
FROM pedido p
JOIN usuario u ON u.id_usuario = p.usuario_id
JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
JOIN producto pr ON pr.id_producto = d.producto_id
JOIN categoria c ON c.id_categoria = pr.id_categoria
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 6)
ORDER BY p.id_pedido, d.id_detalle;

-- ---------------------------------------------------------------------
-- 2. Control de integridad en el origen:
--    el total del pedido debe coincidir con la suma de sus subtotales.
-- ---------------------------------------------------------------------
SELECT
    p.id_pedido,
    p.total,
    SUM(d.subtotal) AS suma_subtotales,
    (p.total = SUM(d.subtotal)) AS total_coincide
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 6)
GROUP BY p.id_pedido, p.total
ORDER BY p.id_pedido;

-- ---------------------------------------------------------------------
-- 3. Vista previa del documento JSON que se inserta en MongoDB.
--    No incluye migrado_en: ese campo lo agrega el script de migracion.
--    El precio unitario historico se deriva de subtotal / cantidad.
-- ---------------------------------------------------------------------
WITH seleccion AS (
    SELECT
        p.id_pedido,
        p.usuario_id,
        u.nombre,
        u.apellido,
        p.fecha,
        p.total,
        p.eliminado
    FROM pedido p
    JOIN usuario u ON u.id_usuario = p.usuario_id
    WHERE p.id_pedido IN (1, 2, 3, 4, 5, 6)
),
items AS (
    SELECT
        d.pedido_id,
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id_detalle', d.id_detalle,
                'id_producto', d.producto_id,
                'nombre_producto', pr.nombre,
                'id_categoria', c.id_categoria,
                'categoria', c.nombre,
                'cantidad', d.cantidad,
                'precio_unitario_historico', ROUND(d.subtotal / d.cantidad, 4),
                'subtotal', d.subtotal,
                'eliminado', d.eliminado
            )
            ORDER BY d.id_detalle
        ) AS items,
        COUNT(*) AS lineas_count
    FROM detalle_pedido d
    JOIN producto pr ON pr.id_producto = d.producto_id
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    WHERE d.pedido_id IN (1, 2, 3, 4, 5, 6)
    GROUP BY d.pedido_id
)
SELECT JSONB_PRETTY(
    JSONB_AGG(
        JSONB_BUILD_OBJECT(
            '_id', s.id_pedido,
            'id_pedido', s.id_pedido,
            'fecha', TO_CHAR(s.fecha, 'YYYY-MM-DD"T"HH24:MI:SS.MS"-03:00"'),
            'estado', CASE WHEN s.eliminado THEN 'CANCELADO' ELSE 'ENTREGADO' END,
            'total', s.total,
            'cliente', JSONB_BUILD_OBJECT(
                'id_usuario', s.usuario_id,
                'nombre', s.nombre,
                'apellido', s.apellido
            ),
            'items', i.items,
            'lineas_count', i.lineas_count,
            'moneda', 'ARS',
            'origen', JSONB_BUILD_OBJECT(
                'sistema', 'PostgreSQL',
                'base', 'foodstore',
                'tabla', 'pedido',
                'eliminado', s.eliminado
            ),
            'schema_version', 1
        )
        ORDER BY s.id_pedido
    )
)
FROM seleccion s
JOIN items i ON i.pedido_id = s.id_pedido;
