# Spec Kiro — TP10 Food Store (SQLite / Dispositivos Móviles)

**Proyecto:** Food Store en la feria.
**Base local:** `movil/foodstore_movil.db` (SQLite) + copia de pruebas `foodstore_u8` (PostgreSQL).
**Regla de oro:** el móvil propone, el servidor dispone.

Este documento es la especificación previa (requirements + design) de la consigna 4.
Sigue el formato del Anexo A de `tp7-foodstore-seguridad/BITACORA.md`: requisitos con
criterios de aceptación verificables (EARS donde corresponde) y un bloque de diseño con
arquitectura, esquema, reglas de negocio, decisiones, riesgos y plan de verificación.

Escrito en español rioplatense, sin datos personales reales.

---

## 1. Requisitos (RF)

Cada requisito tiene un criterio de aceptación verificable en la base o en la evidencia
del simulador (`docs/evidencia_consigna2.txt`).

### RF-01 — La tablet almacena una copia parcial del catálogo (solo productos de feria, sin datos personales)

**Historia:** Como vendedor en la feria, quiero ver el catálogo de productos de feria en la
tablet aunque no tenga señal, para ofrecerlos a los clientes.

**EARS:**
- Si la tablet tiene una instantánea del servidor, entonces el catálogo visible son
  los productos de feria (`id_producto IN (1,3,4,5,6,7,8,10)`) y no hay columnas de
  datos personales (`id_usuario`, nombre/apellido, email, dirección).

**Criterios de aceptación:**
- `producto_cache` tiene exactamente los 8 productos de feria.
- Ninguna columna de `producto_cache`, `pedido_borrador`, `item_borrador` ni `cola_sync`
  guarda nombre, apellido ni ningún dato personal de cliente; `pedido_borrador.usuario`
  es un alias inventado.
- El catálogo se lee solo de `producto_cache` (consigna 1, prueba C1), sin red ni
  PostgreSQL.

### RF-02 — La tablet arma borradores de pedido sin conexión (cabecera + ítems)

**Historia:** Como vendedor, quiero armar un borrador de pedido con cabecera y varios
ítems en la tablet sin conexión, para enviarlo después cuando vuelva la señal.

**EARS:**
- Si el vendedor agrega ítems a un borrador, entonces `pedido_borrador` guarda la
  cabecera (alias, forma de pago, fecha) y `item_borrador` guarda cada ítem con
  producto, cantidad y precio visto, todo vinculado por `id_local`.
- La transacción COMMIT deja borrador, ítems y solicitud persistidos; ROLLBACK los
  deshace todos (consigna 1, pruebas 1.c.1).

**Criterios de aceptación:**
- `pedido_borrador.id_local` es PK; `item_borrador.id_local` referencia a
  `pedido_borrador` (FK).
- `item_borrador.cantidad > 0` y `precio_centavos_visto >= 0` (CHECK).
- Pruebas COMMIT/ROLLBACK dan los conteos esperados (1 | 2 | 1 tras COMMIT; sin
  cambios tras ROLLBACK).

### RF-03 — El semáforo evalúa solicitudes PENDIENTE contra la instantánea y las clasifica

**Historia:** Como sistema, quiero evaluar cada solicitud de la cola contra la copia del
servidor para saber si se puede aprobar, rechazar o deja un conflicto.

**EARS:**
- Si una solicitud está `PENDIENTE`, entonces el semáforo la clasifica en uno de los
  tres estados: `RECHAZADO`, `CONFLICTO` o `SIMULADO_APROBADO`.
- Solo se evalúan las filas con `estado = 'PENDIENTE'` (idempotencia de la simulación).

**Criterios de aceptación:**
- `cola_sync.estado` tiene CHECK restringido a los cuatro valores.
- `WHERE estado = 'PENDIENTE'` en la actualización del semáforo (`semaforo.sql`).
- Ejecutar `semaforo.sql` dos veces no cambia una solicitud ya resuelta (C5, C6).

### RF-04 — Rechazo si borrador sin ítems, producto inexistente, dado de baja, no disponible o stock insuficiente

**Historia:** Como sistema, quiero rechazar una solicitud cuando el borrador no sea
vendible, con un motivo que diga qué producto falló y por qué.

**EARS:**
- Si un borrador no tiene ítems, entonces la solicitud se rechaza con motivo
  "borrador sin ítems".
- Si algún ítem referencia un producto que no está en la instantánea, o está dado de
  baja (`eliminado`), o no disponible (`disponible = 0`), o pide más unidades del
  stock visto, entonces la solicitud se rechaza con el detalle de cada ítem problemático.

**Criterios de aceptación:**
- C3: 192 unidades del producto 3 con stock 142 → `RECHAZADO | producto 3: stock 142 < 192`.
- C4: producto 4 dado de baja → `RECHAZADO | producto 4 dado de baja`.
- Hallazgo F4 (consigna 3): borrador sin ítems → `RECHAZADO` (antes daba
  `SIMULADO_APROBADO`; se agregó la rama `NOT EXISTS`).
- El `motivo` lista cada producto con su problema, separado por `; `.

### RF-05 — Conflicto si cambió al menos un precio respecto a lo visto

**Historia:** Como sistema, quiero marcar en CONFLICTO una solicitud cuyo precio visto
ya no coincide con el del servidor, para que el vendedor lo revise con el cliente.

**EARS:**
- Si no hay rechazo y al menos un ítem tiene `precio_centavos_visto` distinto del
  `precio_centavos` de la instantánea, entonces la solicitud pasa a `CONFLICTO`.

**Criterios de aceptación:**
- C2: borrador del producto 1 a 125945 centavos, servidor sube a 135945 →
  `CONFLICTO | producto 1: 125945 -> 135945`.
- El motivo concatena cada precio que cambió: `producto N: visto -> actual`.

### RF-06 — SIMULADO_APROBADO solo si todo coincide con la instantánea

**Historia:** Como sistema, quiero aprobar en simulación solo cuando cada ítem exista,
esté disponible, tenga stock suficiente y el precio visto sea el actual.

**EARS:**
- Si no hay rechazo ni conflicto, entonces la solicitud pasa a `SIMULADO_APROBADO`
  con motivo "todo coincide con la instantánea".

**Criterios de aceptación:**
- C5: borrador sin cambios → `SIMULADO_APROBADO | todo coincide con la instantánea`.
- C2 segunda solicitud (precio corregido) → `SIMULADO_APROBADO`.
- `SIMULADO_APROBADO` no es una venta: es una propuesta para que el servidor valide.

### RF-07 — Idempotencia de solicitud (mismo UUID no se duplica)

**Historia:** Como sistema, quiero que reenviar la misma `solicitud_uuid` no cree una
solicitud nueva ni la reevalue.

**EARS:**
- Si se intenta insertar una `solicitud_uuid` que ya existe en `cola_sync`, entonces
  falla por restricción de clave primaria y la cola queda con una sola solicitud.

**Criterios de aceptación:**
- C6: mismo UUID dos veces → `UNIQUE constraint failed: cola_sync.solicitud_uuid`;
  conteo de la cola igual antes y después (1 = 1).
- La clave primaria de `cola_sync` es `solicitud_uuid`.

### RF-08 — La simulación NO modifica PostgreSQL; es una propuesta que el servidor valida

**Historia:** Como administrador, quiero estar seguro de que la tablet y la simulación
nunca tocan precios, stock ni pedidos del servidor.

**EARS:**
- Si se corre el semáforo o el simulador, entonces PostgreSQL no cambia: pedidos y
  stock total son iguales antes y después.

**Criterios de aceptación:**
- Invariantes del simulador: `pedidos = 200000` y `stock_total = 4998378` iguales
  antes y después de cada caso, en la copia `foodstore_u8` y en la original
  `foodstore`.
- `semaforo.sql` solo escribe en `cola_sync` de SQLite; no hay `UPDATE`/`DELETE`/`INSERT`
  sobre PostgreSQL.

### RF-09 — UPSERT del caché no borra ítems de borradores existentes

**Historia:** Como vendedor, quiero que al recargar el catálogo no se borren los
productos de mis borradores aunque ya no viajen en la instantánea nueva.

**EARS:**
- Si la instantánea nueva ya no trae un producto, entonces su fila en
  `producto_cache` se marca `disponible = 0` pero no se borra; `eliminado` no se toca
  (faltar en la copia parcial no es baja lógica).

**Criterios de aceptación:**
- `cargar_cache.sql` usa `INSERT ... ON CONFLICT (id) DO UPDATE` (UPSERT).
- Después de `cargar_cache.sql`, `UPDATE producto_cache SET disponible = 0` para los
  ids que ya no vienen en `snapshot_servidor` (hallazgo F5, consigna 3).
- C4: producto 4 dado de baja sigue en `producto_cache` con `eliminado = 1` (lápida)
  pero `disponible = 0`.

### RF-10 — Lápida de baja lógica viaja en la instantánea; producto faltante se marca no disponible, no eliminado

**Historia:** Como sistema, quiero distinguir un producto dado de baja del servidor de
uno que simplemente dejó de viajar en la copia parcial de la feria.

**EARS:**
- Si el servidor tiene `eliminado = true`, entonces la instantánea viaja con
  `eliminado = 't'` y la tablet lo guarda como lápida (`eliminado = 1`).
- Si un producto deja de venir en la instantánea, entonces en la tablet se pone
  `disponible = 0` y se conserva `eliminado = 0`.

**Criterios de aceptación:**
- `snapshot_servidor.eliminado` y `snapshot_servidor.disponible` llegan como texto
  `'t'`/`'f'` del CSV de PostgreSQL; `cargar_cache.sql` los convierte a 0/1 con
  `CASE ... WHEN 't' THEN 1 ELSE 0 END`.
- C4: producto 4 → `eliminado = 1`, `disponible = 0`; no aparece en
  `WHERE disponible = 1 AND eliminado = 0`.

---

## 2. Design

### 2.1 Arquitectura

```
PostgreSQL (fuente de verdad, copia foodstore_u8)
        │
        ▼  servidor_snapshot.sql
 vista v_snapshot_movil (8 productos de feria: id, nombre, precio_centavos,
                          stock, disponible, eliminado, fecha_copia)
        │
        ▼  \copy ... CSV HEADER  (exporta servidor_snapshot.csv)
        │
        ▼  importar_snapshot.sql + .import CSV
 tabla snapshot_servidor en SQLite (staging, booleanos como TEXT 't'/'f')
        │
        ▼  cargar_cache.sql  (UPSERT, traduce 't'/'f' a 0/1, lápidas)
 tabla producto_cache (STRICT, CHECKs, FKs)
        │
        ▼  pedidos_borrador + item_borrador (armados sin conexión en la tablet)
        │
        ▼  cola_sync (solicitud_uuid PK, estado PENDIENTE por defecto)
        │
        ▼  semaforo.sql  (solo estado = 'PENDIENTE')
        │        RECHAZADO / CONFLICTO / SIMULADO_APROBADO + motivo
        │
   PostgreSQL NO se toca: SIMULADO_APROBADO es solo una propuesta
```

### 2.2 Flujo de sincronización paso a paso

1. En PostgreSQL (copia `foodstore_u8`): ejecutar
   `movil/servidor_snapshot.sql` para crear/actualizar la vista `v_snapshot_movil`.
2. Exportar la vista a CSV: `\copy (SELECT * FROM v_snapshot_movil ORDER BY id)
   TO 'movil/servidor_snapshot.csv' CSV HEADER`.
3. En SQLite: crear la base con `schema_sqlite.sql` (4 tablas STRICT).
4. Crear la tabla de staging con `importar_snapshot.sql`.
5. Importar el CSV en `snapshot_servidor` (`.import --csv --skip 1`).
6. Ejecutar `cargar_cache.sql`: UPSERT a `producto_cache`; convierte booleanos de
   texto a 0/1; marca `disponible = 0` los productos que ya no viajan; conserva
   lápidas de baja.
7. El vendedor arma borradores (`pedido_borrador` + `item_borrador`) sin conexión.
8. Insertar en `cola_sync` con `solicitud_uuid` y `id_local` (estado `PENDIENTE`).
9. Ejecutar `semaforo.sql`: evalúa solo `estado = 'PENDIENTE'` y escribe
   `RECHAZADO` / `CONFLICTO` / `SIMULADO_APROBADO` con `motivo`.
10. PostgreSQL no cambió; el servidor validará la propuesta cuando se sincronice.

### 2.3 Esquema SQLite (justificación)

Todas las tablas son `STRICT` para que SQLite rechace tipos de dato incorrectos en
tiempo de inserción (por ejemplo, no dejar meter texto en `precio_centavos`).

- `producto_cache(id PK, nombre TEXT NOT NULL, precio_centavos INTEGER CHECK >= 0,
  stock_visto INTEGER CHECK >= 0, disponible INTEGER CHECK IN (0,1),
  eliminado INTEGER CHECK IN (0,1), fecha_copia TEXT DEFAULT datetime('now')) STRICT`
  - `precio_centavos` en centavos enteros: evita errores de redondeo de decimales al
    comparar precios del servidor con los vistos en la tablet (RF-05).
  - `disponible` y `eliminado` son enteros 0/1 porque SQLite no tiene booleanos
    nativos; el CHECK los restringe.
  - `eliminado` es la lápida de baja lógica: nunca se borra físicamente de la caché.

- `pedido_borrador(id_local PK, usuario TEXT NOT NULL, forma_pago TEXT CHECK IN
  ('EFECTIVO','TARJETA','TRANSFERENCIA'), fecha TEXT DEFAULT datetime('now')) STRICT`
  - `usuario` es un alias inventado (`cliente_c2`, `cliente_demo`, etc.); nunca viaja
    el nombre real ni apellido del cliente (RF-01, privacidad).

- `item_borrador(id_local REFERENCES pedido_borrador, producto_id REFERENCES
  producto_cache, cantidad CHECK > 0, precio_centavos_visto CHECK >= 0, PK
  (id_local, producto_id)) STRICT`
  - FK a `producto_cache` evita ítems de productos inexistentes (prueba C7).
  - `precio_centavos_visto` guarda el precio que vio el vendedor al armar el
    borrador, para compararlo después con el del servidor.

- `cola_sync(solicitud_uuid PK, id_local REFERENCES pedido_borrador, estado TEXT
  DEFAULT 'PENDIENTE' CHECK IN (...), motivo TEXT) STRICT`
  - PK sobre `solicitud_uuid` da idempotencia local (RF-07).
  - Índice parcial único `ux_cola_una_pendiente ON cola_sync(id_local) WHERE
    estado = 'PENDIENTE'`: un borrador no puede tener dos envíos pendientes a la vez.

**Nota (consigna 1.a, nota del índice parcial):** al reenviar, SQLite prioriza la
validación del índice parcial frente a un envío que sigue `PENDIENTE` (error sobre
`id_local`). Una vez procesada y ya no pendiente, actúa la PK de
`solicitud_uuid`, garantizando la idempotencia del sistema.

### 2.4 Semáforo: reglas de negocio

El script `semaforo.sql` hace un `UPDATE cola_sync SET estado = CASE ..., motivo =
CASE ... WHERE estado = 'PENDIENTE'`:

1. **ROJO → `RECHAZADO`:** borrador sin ítems (`NOT EXISTS` sobre `item_borrador`),
   o algún ítem con producto inexistente en `snapshot_servidor` (`s.id IS NULL`),
   dado de baja (`eliminado = 't'`), no disponible (`disponible = 'f'`) o cantidad
   mayor al stock visto (`i.cantidad > s.stock`). El `motivo` concatena cada ítem
   problemático con `group_concat`.
2. **AMARILLO → `CONFLICTO`:** no hay rojo, pero al menos un precio cambió
   (`precio_centavos_visto <> precio_centavos`). El `motivo` concatena cada precio
   `visto -> actual`.
3. **VERDE → `SIMULADO_APROBADO`:** todo coincide con la instantánea.

El `WHERE estado = 'PENDIENTE'` es la clave de la idempotencia de la simulación:
volver a correr `semaforo.sql` no reevalúa solicitudes ya resueltas (C5, C6).

### 2.5 Idempotencia

- **En la tablet:** `cola_sync.solicitud_uuid` es PK; reinsertar el mismo UUID falla
  con `UNIQUE constraint failed` (C6). El índice parcial `ux_cola_una_pendiente`
  evita dos pendientes por borrador.
- **En el servidor (producción real):** la protección de la tablet no alcanza. El
  servidor recibe `solicitud_uuid` como clave de idempotencia, la registra en una
  tabla de solicitudes procesadas (o usa UNIQUE) dentro de la misma transacción que
  crea el pedido, y si el UUID ya existe responde OK sin volver a vender.

### 2.6 Decisiones de diseño

- **Precios en centavos (`INTEGER`):** evita errores de redondeo y comparación
  inexacta de decimales al decidir `CONFLICTO` (RF-05). Se muestra al usuario como
  `precio_centavos / 100.0`.
- **Alias en vez de datos personales:** `pedido_borrador.usuario` guarda un alias
  inventado; la tablet no guarda nombres, apellidos ni direcciones (RF-01).
- **`SIMULADO_APROBADO` no es venta:** es solo una propuesta local; el servidor
  dispone del precio, el stock y la venta final (RF-08).
- **Lápida de baja lógica:** `eliminado = 1` se conserva en `producto_cache` aunque
  el producto no viaje más; se diferencia de un producto que simplemente falta de la
  copia parcial (RF-10).
- **UPSERT no borra ítems:** `cargar_cache.sql` actualiza en lugar de borrar, para
  no romper FKs de borradores existentes (RF-09).

### 2.7 Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| La copia de la tablet está vieja (precio o stock cambiaron en el servidor). | El semáforo clasifica `CONFLICTO` o `RECHAZADO`; el servidor valida al sincronizar. `SIMULADO_APROBADO` no confirma nada. |
| Reenvío de la misma solicitud por caída de red. | PK de `solicitud_uuid` en la tablet; en el servidor, tabla de solicitudes procesadas con UNIQUE dentro de la transacción de venta. |
| Borrador sin ítems aprobado por error. | Rama `NOT EXISTS` en el semáforo → `RECHAZADO` (corrección F4, consigna 3). |
| Producto deja de viajar en la instantánea y se sigue ofreciendo. | `cargar_cache.sql` pone `disponible = 0` a los ids ausentes sin borrar (corrección F5). |
| Booleanos del CSV de PostgreSQL (`t`/`f`) vs enteros de SQLite (0/1). | `snapshot_servidor` los guarda como TEXT y `cargar_cache.sql` los traduce con `CASE`. |
| La tablet queda con datos más nuevos que un respaldo viejo restaurado en el servidor. | Al reconectar, el servidor descarta la instantánea local, exige una copia completa y reevaluar pendientes; si el UUID ya está procesado, responde OK sin volver a vender. |

### 2.8 Plan de verificación

Cada requisito se verifica con los casos del simulador y las pruebas de SQLite:

- **RF-01 (catálogo parcial):** `docs/evidencia_consigna2.txt` muestra 8 filas en
  `servidor_snapshot.csv` y `producto_cache` con solo productos de feria; prueba C1
  de `pruebas_sqlite.sql` lee el catálogo sin servidor.
- **RF-02 (borradores sin conexión):** pruebas COMMIT/ROLLBACK de
  `pruebas_sqlite.sql` (conteos 1 | 2 | 1 tras COMMIT; sin cambios tras ROLLBACK).
- **RF-03 (semáforo evalúa PENDIENTE):** `semaforo.sql` tiene `WHERE estado =
  'PENDIENTE'`; C5 y C6 muestran que repetir la simulación no cambia el resultado.
- **RF-04 (rechazos):** C3 (stock insuficiente), C4 (dado de baja), y la corrección
  F4 (borrador sin ítems → `RECHAZADO`).
- **RF-05 (conflicto de precio):** C2 → `CONFLICTO | producto 1: 125945 -> 135945`.
- **RF-06 (SIMULADO_APROBADO):** C5 y la segunda solicitud de C2.
- **RF-07 (idempotencia UUID):** C6 → `UNIQUE constraint failed`, conteo 1 = 1.
- **RF-08 (no modifica PostgreSQL):** invariantes del simulador (pedidos y stock
  iguales antes y después, en copia y original).
- **RF-09 (UPSERT no borra ítems):** `cargar_cache.sql` usa `ON CONFLICT`; corrección
  F5 (F5, consigna 3).
- **RF-10 (lápidas y no disponibles):** C4 (`eliminado = 1`, `disponible = 0`,
  producto 4 no aparece como disponible).

Los casos C2-C6 y sus resultados están documentados en `docs/evidencia_consigna2.txt`.
Las pruebas de esquema están en `movil/pruebas_sqlite.sql`.

---