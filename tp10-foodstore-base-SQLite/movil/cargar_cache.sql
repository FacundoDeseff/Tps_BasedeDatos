-- ============================================================
-- Consigna 2.a - Cargar/actualizar producto_cache desde la instantánea
-- Se ejecuta en SQLite después de importar el CSV en snapshot_servidor.
-- ============================================================
--
-- Se usa UPSERT (ON CONFLICT) para no borrar filas que todavía tengan
-- ítems de borradores apuntándolas por clave foránea. Las bajas lógicas
-- llegan como eliminado = 't' y quedan como lápida en la tablet.

PRAGMA foreign_keys = ON;

INSERT INTO producto_cache (
    id,
    nombre,
    precio_centavos,
    stock_visto,
    disponible,
    eliminado,
    fecha_copia
)
SELECT
    id,
    nombre,
    precio_centavos,
    stock,
    CASE disponible WHEN 't' THEN 1 ELSE 0 END,
    CASE eliminado  WHEN 't' THEN 1 ELSE 0 END,
    fecha_copia
FROM snapshot_servidor
-- El WHERE 1 evita que SQLite confunda "ON CONFLICT" con un JOIN.
WHERE 1
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;
