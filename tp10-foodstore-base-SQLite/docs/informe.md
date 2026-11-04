# INFORME Trabajo Práctico
- Base de Datos II
- Unidad 8: Base de Datos para Dispositivos Móviles e Integración
- Integrantes: Ramirez, Deseff, Vargas, Godoy

## Estado del trabajo

- **Consigna 1:** hecha. Están el esquema, las pruebas y la tabla de qué datos viajan.
- **Consigna 2:** **hecha y probada**. Armamos la instantánea, el semáforo y los cinco casos (C2 a C6). Todos dieron lo que pedía la consigna y PostgreSQL no cambió. La salida completa está en `docs/evidencia_consigna2.txt`.
- **Consignas 3 y 4:** pendientes.

## 1.a Qué datos viajan a la tablet

Durante la feria, la tablet necesita almacenar una copia parcial del sistema. Sin señal, la información que viaja desde la base principal en PostgreSQL hacia la tabla local producto_cache en SQLite y los datos que se dejaron afuera son los siguientes:

| Columna en PostgreSQL | ¿Viaja? | En la tablet | Por qué |
|---|---|---|---|
| `id_producto` | Sí | `id` | Identifica el producto en los borradores y en la sincronización. |
| `nombre` | Sí | `nombre` | Para mostrar el catálogo en pantalla. |
| `precio_lista` (NUMERIC 10,2) | Sí | `precio_centavos` (INTEGER) | Se convierte a centavos enteros para evitar errores de redondeo con decimales. |
| `stock` | Sí | `stock_visto` | Solo orientativo: es el stock que se vio al hacer la copia. |
| `eliminado` | Sí | `eliminado` | Lápida de baja lógica: la tablet debe enterarse de que un producto se dio de baja. |
| *(derivada)* `stock > 0 AND NOT eliminado` | Sí | `disponible` | Permite filtrar el catálogo sin recalcular. |
| *(generada en la tablet)* | — | `fecha_copia` | Indica qué tan vieja es la copia. |
| `id_categoria` | No | — | No hace falta para vender en la feria; se puede sumar si se muestra por categoría. |
| Tabla `usuario` (nombre, apellido) | No | — | Datos personales: no tienen por qué estar en un dispositivo que se puede perder. La tablet solo guarda un alias en `pedido_borrador.usuario`. |
| Tablas `pedido` y `detalle_pedido` | No | — | Son las ventas confirmadas; las decide el servidor. La tablet solo tiene borradores. |



**¿Por qué se decidió esto y quién manda?** 

A la tablet viaja solo lo mínimo para mostrar el catálogo y armar borradores sin conexión; cuanto menos datos sensibles hayan en la tablet, menos riesgo se corre si se extravía. Acá, la fuente de verdad es PostgreSQL ya que el precio, el stock y las ventas los decide el servidor (la copia de la tablet puede estar vieja) por eso lo que la tablet arma es solo una propuesta  para que el servidor la valide al sincronizarla con la Base original.


**Nota sobre el índice único parcial 'ux_cola_una_pendiente'**

Al realizar las pruebas del reenvío, se observó que SQLite prioriza la validación del índica frente a un envío que sigue 'PENDIENTE' (se arroja un error sobre id_local). Una vez que la solicitud se procesa y deja de estar pendiente, actúa la clave primaria de solicitud_uuid, garantizando la idempotencia del sistema.

## 2. Sincronizar y resolver

### 2.a La instantánea

Para no tocar la base original, hicimos una copia en PostgreSQL: `foodstore_u8` (sale de `CREATE DATABASE foodstore_u8 TEMPLATE foodstore;`). Ahí armamos la vista `v_snapshot_movil`, que junta lo justo para la feria: id, nombre, precio en centavos, stock, si está disponible, la lápida `eliminado` y la fecha de la copia.

```sql
CREATE VIEW v_snapshot_movil AS
SELECT p.id_producto                         AS id,
       p.nombre                              AS nombre,
       round(p.precio_lista * 100)::bigint   AS precio_centavos,
       p.stock                               AS stock,
       (p.stock > 0 AND NOT p.eliminado)     AS disponible,
       p.eliminado                           AS eliminado,
       now()                                 AS fecha_copia
FROM producto p
WHERE p.id_producto IN (1, 3, 4, 5, 6, 7, 8, 10);
```

La feria de este TP trabaja con esos 8 productos, así que la vista se limita a ese catálogo. La copia de la tablet es parcial, como pide la consigna.

Para pasarla a SQLite exportamos el CSV con `\copy ... CSV HEADER` y lo importamos con `.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor`. Ojo: PostgreSQL escribe los booleanos como `t`/`f`, así que `snapshot_servidor` los guarda como texto y `cargar_cache.sql` los pasa a 0/1 al llenar `producto_cache`. Ese llenado lo hacemos con UPSERT para no borrar filas que todavía tienen ítems de borradores apuntándolas.

La copia base nos quedó con 8 productos y fecha **2026-11-04**; el detalle exacto está en la columna `fecha_copia` de `movil/servidor_snapshot.csv`. Las instantáneas de cada caso quedaron en `movil/casos/`.

### 2.b El semáforo

`semaforo.sql` mira solo las solicitudes que están `PENDIENTE` y las compara con `snapshot_servidor`:

- **RECHAZADO (rojo):** algún producto no existe, está dado de baja (`eliminado = 't'`), no está disponible (`disponible = 'f'`) o no alcanza el stock.
- **CONFLICTO (amarillo):** no hay rojo, pero cambió algún precio.
- **SIMULADO_APROBADO (verde):** todo coincide con la instantánea.

La consulta hace un `LEFT JOIN` de `item_borrador` con `snapshot_servidor` y usa un `CASE` con conteos por solicitud. El `WHERE estado = 'PENDIENTE'` es la clave: si volvés a correr la simulación, no cambia nada. El script no toca PostgreSQL, solo escribe en `cola_sync` de SQLite. Y `SIMULADO_APROBADO` no es una venta: es solo una propuesta que después tiene que validar el servidor.

### 2.c Los casos

Probamos todo con `python movil/simulador.py`. El simulador arma la base SQLite, importa la instantánea de cada caso y corre `semaforo.sql`. La salida completa está en `docs/evidencia_consigna2.txt`.

En todos los casos el alta del borrador y la solicitud sigue el mismo patrón (cambian los valores):

```sql
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('<uuid-borrador>', 'cliente_demo', 'EFECTIVO');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('<uuid-borrador>', <producto>, <cantidad>, <precio>);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('<uuid-solicitud>', '<uuid-borrador>');
```

**C2 · Precio cambiado.** Armamos un borrador del producto 1 (2 unidades a 125945 centavos). Después subimos el precio en el servidor:

```sql
UPDATE producto SET precio_lista = precio_lista + 100.00 WHERE id_producto = 1;
```

Exportamos la instantánea nueva y corrimos el semáforo. Nos dio `CONFLICTO | producto 1: 125945 -> 135945`. El cliente aceptó el precio: actualizamos `item_borrador.precio_centavos_visto` y creamos una solicitud nueva. Ahí nos dio `SIMULADO_APROBADO`. La solicitud vieja queda en `CONFLICTO` para revisión.

**C3 · Más unidades que el stock.** Armamos un borrador de 192 unidades del producto 3, pero el servidor tiene 142:

```sql
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c3c3c3c3-0000-4000-8000-000000000003', 3, 192, 391303);
```

Nos dio `RECHAZADO | producto 3: stock 142 < 192`.

**C4 · Producto dado de baja.** Armamos un borrador del producto 4 y después lo dimos de baja lógica:

```sql
UPDATE producto SET eliminado = true WHERE id_producto = 4;
```

Nos dio `RECHAZADO | producto 4 dado de baja`. Cuando recargamos el catálogo, el producto 4 ya no aparece entre los disponibles, pero la fila sigue en `producto_cache` con `eliminado = 1` (la lápida).

**C5 · Sin cambios.** Armamos un borrador del producto 5 sin tocar el servidor:

```sql
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c5c5c5c5-0000-4000-8000-000000000005', 5, 1, 58450);
```

Nos dio `SIMULADO_APROBADO | todo coincide con la instantánea`. Lo corrimos dos veces y quedó igual, porque el semáforo solo mira las solicitudes `PENDIENTE`.

**C6 · Reenvío del mismo UUID.** Mandamos la misma solicitud con el mismo `solicitud_uuid`:

```sql
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a6a6a6a6-0000-4000-8000-000000000006',
        'c6c6c6c6-0000-4000-8000-000000000006');  -- repetido
```

Nos dio el error `UNIQUE constraint failed: cola_sync.solicitud_uuid`; la cola siguió con una sola solicitud y repetir la simulación no reevaluó nada. En un sistema de verdad, la protección no puede quedar en la tablet: el servidor tiene que recibir `solicitud_uuid` como clave de idempotencia y guardarlo en una tabla de solicitudes procesadas (o tener una restricción UNIQUE) dentro de la misma transacción que crea el pedido. Si el UUID ya existe, responde OK sin volver a vender.

### Verificación en PostgreSQL

Antes y después de toda la simulación miramos los pedidos y el stock:

```sql
SELECT (SELECT count(*) FROM pedido)                          AS pedidos,
       (SELECT coalesce(sum(stock), 0) FROM producto)         AS stock_total;
```

Nos dio lo mismo en los dos momentos:

| Momento | Pedidos | Stock total |
|---|---:|---:|
| Antes de la simulación | 200000 | 4998378 |
| Después de la simulación | 200000 | 4998378 |

El resultado fue igual en la copia `foodstore_u8` y en la base original `foodstore`. La tablet nunca cambió el stock ni confirmó ventas. El cambio de precio de C2 y la baja de C4 los hicimos nosotros en la copia del servidor para preparar los casos, no los hizo el semáforo.

La salida completa, con los comandos y los resultados de cada caso, está en `docs/evidencia_consigna2.txt`.
