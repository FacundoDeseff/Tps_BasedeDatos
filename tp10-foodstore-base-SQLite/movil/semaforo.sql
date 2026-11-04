-- ============================================================
-- Consigna 2.b - El semáforo de sincronización
-- Se ejecuta en SQLite, después de importar la instantánea del servidor.
-- ============================================================
--
-- Reglas (solo se evalúan las solicitudes PENDIENTE):
--   ROJO    -> RECHAZADO:
--              el borrador no tiene ítems, o algún producto no existe en la
--              instantánea, está dado de baja (eliminado = 't'), no está
--              disponible o no alcanza el stock visto.
--   AMARILLO -> CONFLICTO:
--              no hay rojo, pero cambió al menos un precio.
--   VERDE   -> SIMULADO_APROBADO:
--              todos los ítems coinciden con la instantánea.
--
-- IMPORTANTE: esto NO modifica PostgreSQL. SIMULADO_APROBADO no es una
-- venta: es solo una simulación local de lo que el servidor debería
-- aprobar cuando la tablet sincronice.
--
-- El WHERE estado = 'PENDIENTE' hace que repetir la simulación no
-- reevalúe las solicitudes ya resueltas (idempotencia de la simulación).

PRAGMA foreign_keys = ON;

UPDATE cola_sync
SET estado = CASE
        -- Un borrador sin ítems no es una venta válida: sin esta rama, los
        -- dos conteos siguientes dan 0 y el CASE caía en SIMULADO_APROBADO.
        WHEN NOT EXISTS (
            SELECT 1 FROM item_borrador i WHERE i.id_local = cola_sync.id_local
        ) THEN 'RECHAZADO'

        WHEN (
            SELECT COUNT(*)
            FROM item_borrador i
            LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
            WHERE i.id_local = cola_sync.id_local
              AND (
                    s.id IS NULL                 -- producto inexistente
                 OR s.eliminado = 't'            -- baja lógica
                 OR s.disponible = 'f'           -- sin stock / no disponible
                 OR i.cantidad > s.stock         -- no alcanza el stock
              )
        ) > 0 THEN 'RECHAZADO'

        WHEN (
            SELECT COUNT(*)
            FROM item_borrador i
            JOIN snapshot_servidor s ON s.id = i.producto_id
            WHERE i.id_local = cola_sync.id_local
              AND i.precio_centavos_visto <> s.precio_centavos
        ) > 0 THEN 'CONFLICTO'

        ELSE 'SIMULADO_APROBADO'
    END,

    motivo = CASE
        -- Motivo del rechazo: borrador vacío
        WHEN NOT EXISTS (
            SELECT 1 FROM item_borrador i WHERE i.id_local = cola_sync.id_local
        ) THEN 'borrador sin ítems: no hay nada para sincronizar'

        -- Motivo del rechazo: detalle de cada ítem con problema
        WHEN (
            SELECT COUNT(*)
            FROM item_borrador i
            LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
            WHERE i.id_local = cola_sync.id_local
              AND (
                    s.id IS NULL
                 OR s.eliminado = 't'
                 OR s.disponible = 'f'
                 OR i.cantidad > s.stock
              )
        ) > 0 THEN (
            SELECT group_concat(detalle, '; ')
            FROM (
                SELECT CASE
                    WHEN s.id IS NULL
                        THEN 'producto ' || i.producto_id || ' inexistente'
                    WHEN s.eliminado = 't'
                        THEN 'producto ' || i.producto_id || ' dado de baja'
                    WHEN s.disponible = 'f'
                        THEN 'producto ' || i.producto_id || ' no disponible'
                    ELSE 'producto ' || i.producto_id || ': stock ' || s.stock
                         || ' < ' || i.cantidad
                END AS detalle
                FROM item_borrador i
                LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
                WHERE i.id_local = cola_sync.id_local
                  AND (
                        s.id IS NULL
                     OR s.eliminado = 't'
                     OR s.disponible = 'f'
                     OR i.cantidad > s.stock
                  )
            )
        )

        -- Motivo del conflicto: precios vistos vs. precios actuales
        WHEN (
            SELECT COUNT(*)
            FROM item_borrador i
            JOIN snapshot_servidor s ON s.id = i.producto_id
            WHERE i.id_local = cola_sync.id_local
              AND i.precio_centavos_visto <> s.precio_centavos
        ) > 0 THEN (
            SELECT group_concat(
                       'producto ' || i.producto_id || ': '
                       || i.precio_centavos_visto || ' -> '
                       || s.precio_centavos,
                       '; '
                   )
            FROM item_borrador i
            JOIN snapshot_servidor s ON s.id = i.producto_id
            WHERE i.id_local = cola_sync.id_local
              AND i.precio_centavos_visto <> s.precio_centavos
        )

        ELSE 'todo coincide con la instantánea'
    END
WHERE estado = 'PENDIENTE';
