-- ============================================================
-- Consigna 2.a - Tabla donde se importa el CSV del servidor
-- Se ejecuta en SQLite DESPUÉS de crear el esquema (schema_sqlite.sql)
-- y ANTES de importar servidor_snapshot.csv.
-- ============================================================
--
-- En sqlite3 / DB Browser el CSV se importa con:
--   .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
--
-- En PostgreSQL los booleanos del CSV llegan como 't' / 'f'; por eso
-- disponible y eliminado se guardan como TEXT y se traducen a 0/1 al
-- cargar producto_cache (ver cargar_cache.sql).

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS snapshot_servidor;

CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,   -- id_producto del servidor
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      TEXT    NOT NULL CHECK (disponible IN ('t', 'f')),
    eliminado       TEXT    NOT NULL CHECK (eliminado  IN ('t', 'f')),
    fecha_copia     TEXT    NOT NULL       -- fecha de la instantánea
) STRICT;
