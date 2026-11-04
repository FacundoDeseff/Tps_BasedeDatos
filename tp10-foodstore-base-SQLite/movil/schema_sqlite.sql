PRAGMA foreign_keys = ON; 

DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;

-- Copia local del catalogo
CREATE TABLE producto_cache (
    id               INTEGER PRIMARY KEY,                 -- = id_producto del servidor
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),  -- stock cuando se hizo la copia
    disponible       INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado        INTEGER NOT NULL CHECK (eliminado  IN (0, 1)),  -- lapida: baja logica
    fecha_copia      TEXT    NOT NULL DEFAULT (datetime('now'))      -- cuando se trajo del servidor
) STRICT;

-- Cabecera del borrador
CREATE TABLE pedido_borrador (
    id_local    TEXT PRIMARY KEY,
    usuario     TEXT NOT NULL,                            -- dato inventado / alias, nada personal real
    forma_pago  TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha       TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

-- Items del borrador
CREATE TABLE item_borrador (
    id_local               TEXT    NOT NULL REFERENCES pedido_borrador (id_local),
    producto_id            INTEGER NOT NULL REFERENCES producto_cache (id),
    cantidad               INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto  INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- Cola de sincronizacion
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY,
    id_local        TEXT NOT NULL REFERENCES pedido_borrador (id_local),
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
                    CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo          TEXT
) STRICT;

-- Un borrador no puede tener dos envios PENDIENTES a la vez (indice unico parcial)
CREATE UNIQUE INDEX ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';
