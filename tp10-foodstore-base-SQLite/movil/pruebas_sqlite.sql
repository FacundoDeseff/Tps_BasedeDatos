PRAGMA foreign_keys = ON;
.headers on
.mode column

-- Catalogo de prueba
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado) VALUES
  (1, 'Pizza muzzarella',  850000, 20, 1, 0),
  (2, 'Empanada de carne', 120000, 50, 1, 0),
  (3, 'Gaseosa 500ml',     100000,  0, 0, 0),   -- sin stock: no disponible
  (4, 'Milanesa napolitana', 1500000, 8, 0, 1); -- dada de baja (lapida)

SELECT '--- 1.c.1 TRANSACCION: COMMIT ---' AS prueba;
-- Borrador completo (cabecera + items + solicitud) en UNA transaccion.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('11111111-1111-4111-8111-111111111111', 'cliente_demo_1', 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES
  ('11111111-1111-4111-8111-111111111111', 1, 2, 850000),
  ('11111111-1111-4111-8111-111111111111', 2, 6, 120000);
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-0001-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111');
COMMIT;

SELECT 'tras COMMIT' AS momento,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;   -- esperado: 1 | 2 | 1

SELECT '--- 1.c.1 TRANSACCION: ROLLBACK ---' AS prueba;
-- El cliente se arrepiente a mitad de camino: se deshace todo.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('22222222-2222-4222-8222-222222222222', 'cliente_demo_2', 'TARJETA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('22222222-2222-4222-8222-222222222222', 1, 1, 850000);
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-0002-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222');
SELECT 'dentro de la tx' AS momento, COUNT(*) AS borradores FROM pedido_borrador;  -- 2
ROLLBACK;

SELECT 'tras ROLLBACK' AS momento,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;   -- sigue 1 | 2 | 1

SELECT '--- C1: catalogo disponible SIN servidor ---' AS prueba;
-- Solo lee producto_cache (archivo local): no hace falta red ni PostgreSQL.
SELECT id, nombre, precio_centavos / 100.0 AS precio_pesos, stock_visto
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY nombre;   -- esperado: ids 1 y 2

SELECT '--- C7: datos invalidos -> error y sin filas nuevas ---' AS prueba;
SELECT 'antes' AS momento,
       (SELECT COUNT(*) FROM item_borrador) AS items,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores;

-- (a) cantidad = 0  -> "CHECK constraint failed: cantidad > 0"
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 1, 0, 850000);

-- (b) producto inexistente -> "FOREIGN KEY constraint failed"
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 999, 1, 100000);

SELECT 'despues' AS momento,
       (SELECT COUNT(*) FROM item_borrador) AS items,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores;   -- iguales a 'antes'

-- Extra: otras reglas del esquema (cada una debe dar error)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('33333333-3333-4333-8333-333333333333', 'x', 'BITCOIN');           -- forma_pago invalida
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado)
VALUES (9, 'Precio negativo', -1, 1, 1, 0);                                 -- precio < 0
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado)
VALUES (10, 'Flag invalido', 100, 1, 2, 0);                                 -- disponible solo 0/1
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('aaaaaaaa-0003-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'VENDIDO');  -- estado invalido
