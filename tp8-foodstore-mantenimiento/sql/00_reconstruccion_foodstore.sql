-- =====================================================================
-- 00_reconstruccion_foodstore.sql
-- TP Unidad 6 - Mantenimiento, respaldo y recuperacion (Food Store)
--
-- Objetivo: dejar una base foodstore reproducible y consistente para
-- ejecutar el plan de mantenimiento del TP8 (respaldo, monitoreo,
-- mantenimiento y simulacro de restauracion).
--
-- Requisitos:
--   * PostgreSQL 16+ (probado en PostgreSQL 17).
--   * Base vacia llamada foodstore ya creada:
--       createdb -h localhost -p 5433 -U postgres foodstore
--   * Ejecutar con ON_ERROR_STOP:
--       psql -h localhost -p 5433 -U postgres -d foodstore -v ON_ERROR_STOP=1 -f 00_reconstruccion_foodstore.sql
--
-- Nota: este script NO crea ni elimina la base. Solo reconstruye el
-- esquema y los datos dentro de foodstore. La base real no se toca
-- desde ningun script de restauracion (ver AGENTS.md).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Limpieza del esquema (idempotente)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;

-- ---------------------------------------------------------------------
-- 2. Esquema canonico (mismo que TP3 / TP5 del proyecto integrador)
-- ---------------------------------------------------------------------
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    eliminado BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    precio_lista NUMERIC(10,2) NOT NULL CHECK (precio_lista > 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    id_categoria BIGINT NOT NULL REFERENCES categoria(id_categoria) ON DELETE RESTRICT,
    eliminado BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE usuario (
    id_usuario BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    eliminado BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    fecha TIMESTAMP NOT NULL DEFAULT NOW(),
    total NUMERIC(12,2) NOT NULL DEFAULT 0,
    eliminado BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE detalle_pedido (
    id_detalle BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id BIGINT NOT NULL REFERENCES pedido(id_pedido) ON DELETE CASCADE,
    producto_id BIGINT NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    eliminado BOOLEAN NOT NULL DEFAULT FALSE
);

-- Indices del TP3 (se mantienen para que el monitoreo sea realista)
CREATE INDEX idx_producto_categoria_vig ON producto (id_categoria) WHERE eliminado = FALSE;
CREATE INDEX idx_pedido_usuario ON pedido (usuario_id);
CREATE INDEX idx_detalle_producto ON detalle_pedido (producto_id, subtotal) WHERE eliminado = FALSE;

-- ---------------------------------------------------------------------
-- 3. Carga de datos (volumen canonico del TP3)
--    20.000 usuarios / 50.000 productos / 200.000 pedidos
--    ~800.000 detalles de pedido.
--    setseed hace la carga reproducible entre ejecuciones.
-- ---------------------------------------------------------------------
BEGIN;

SELECT setseed(0.42);

INSERT INTO categoria (nombre, eliminado)
VALUES
    ('Pizzas', FALSE),
    ('Empanadas', FALSE),
    ('Bebidas', FALSE),
    ('Postres', FALSE),
    ('Combos', FALSE),
    ('Ensaladas', FALSE),
    ('Pastas', FALSE),
    ('Parrilla', FALSE),
    ('Panaderia', FALSE),
    ('Sushi', FALSE),
    ('Veganos', FALSE)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO usuario (nombre, apellido, eliminado)
SELECT
    'Usuario_' || i,
    'Apellido_' || i,
    (random() < 0.05)
FROM generate_series(1, 20000) AS i;

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

INSERT INTO pedido (usuario_id, fecha, total, eliminado)
SELECT
    (random() * 19999 + 1)::bigint,
    NOW() - (random() * interval '365 days'),
    0,
    (random() < 0.03)
FROM generate_series(1, 200000) AS i;

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

UPDATE pedido p
SET total = sub.sum_subtotal
FROM (
    SELECT pedido_id, SUM(subtotal) AS sum_subtotal
    FROM detalle_pedido
    GROUP BY pedido_id
) sub
WHERE p.id_pedido = sub.pedido_id;

COMMIT;

-- ---------------------------------------------------------------------
-- 4. Estadisticas iniciales
-- ---------------------------------------------------------------------
ANALYZE categoria;
ANALYZE producto;
ANALYZE usuario;
ANALYZE pedido;
ANALYZE detalle_pedido;
