BEGIN;

-- Categorías
INSERT INTO categoria (nombre, eliminado)
VALUES ('Pizzas', FALSE), ('Empanadas', FALSE), ('Bebidas', FALSE), ('Postres', FALSE), ('Combos', FALSE)
ON CONFLICT (nombre) DO NOTHING;

-- 20.000 Usuarios
INSERT INTO usuario (nombre, apellido, eliminado)
SELECT 
    'Usuario_' || i,
    'Apellido_' || i,
    (random() < 0.05)
FROM generate_series(1, 20000) AS i;

-- 50.000 Productos
INSERT INTO producto (nombre, precio_lista, stock, id_categoria, eliminado)
SELECT 
    'Producto_' || i,
    (random() * (5000 - 500) + 500)::numeric(10,2),
    (random() * 200)::integer,
    c.id_categoria,
    (random() < 0.08)
FROM generate_series(1, 50000) AS i
CROSS JOIN LATERAL (
    SELECT id_categoria FROM categoria ORDER BY random() LIMIT 1
) c;

-- 200.000 Pedidos
INSERT INTO pedido (usuario_id, fecha, total, eliminado)
SELECT 
    (random() * 19999 + 1)::bigint,
    NOW() - (random() * interval '365 days'),
    0,
    (random() < 0.03)
FROM generate_series(1, 200000) AS i;

-- Detalles de pedidos
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, subtotal, eliminado)
SELECT 
    p.id_pedido,
    (random() * 49999 + 1)::bigint,
    cant,
    (cant * (random() * 2000 + 500))::numeric(10,2),
    FALSE
FROM (SELECT id_pedido FROM pedido) p
CROSS JOIN LATERAL generate_series(1, (random() * 2 + 1)::integer) g
CROSS JOIN LATERAL (SELECT (random() * 4 + 1)::integer AS cant) c;

-- Recalcular totales de pedidos
UPDATE pedido p
SET total = sub.sum_subtotal
FROM (
    SELECT pedido_id, SUM(subtotal) AS sum_subtotal
    FROM detalle_pedido
    GROUP BY pedido_id
) sub
WHERE p.id_pedido = sub.pedido_id;

COMMIT;

ANALYZE categoria;
ANALYZE producto;
ANALYZE usuario;
ANALYZE pedido;
ANALYZE detalle_pedido;