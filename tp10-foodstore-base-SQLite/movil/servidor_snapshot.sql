-- ============================================================
-- Consigna 2.a - La instantánea que viaja del servidor a la tablet
-- Se ejecuta en PostgreSQL, sobre la COPIA de pruebas: foodstore_u8
-- ============================================================
--
-- La vista arma el catálogo mínimo que necesita la feria:
--   * id/nombre para mostrar el producto,
--   * precio en centavos (entero) para no arrastrar decimales,
--   * stock visto y disponible para orientar al cliente,
--   * eliminado como lápida (baja lógica),
--   * fecha_copia para saber qué tan vieja es la instantánea.
--
-- Se limita a los productos de la feria de este TP (ids 1,3,4,5,6,7,8,10)
-- para que la copia de la tablet sea parcial, como pide la consigna.
-- Las bajas lógicas NO se filtran: tienen que viajar para que la tablet
-- se entere de que un producto ya no se vende.

DROP VIEW IF EXISTS v_snapshot_movil;

CREATE VIEW v_snapshot_movil AS
SELECT
    p.id_producto                         AS id,
    p.nombre                              AS nombre,
    round(p.precio_lista * 100)::bigint   AS precio_centavos,
    p.stock                               AS stock,
    (p.stock > 0 AND NOT p.eliminado)     AS disponible,
    p.eliminado                           AS eliminado,
    now()                                 AS fecha_copia
FROM producto p
WHERE p.id_producto IN (1, 3, 4, 5, 6, 7, 8, 10);

-- Verificación rápida (8 filas esperadas)
SELECT * FROM v_snapshot_movil ORDER BY id;
