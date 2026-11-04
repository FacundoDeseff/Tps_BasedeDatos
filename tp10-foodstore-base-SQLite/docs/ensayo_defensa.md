# Ensayo de defensa — TP10 Food Store (SQLite / Dispositivos Móviles)

**Integrantes:** Ramirez, Deseff, Vargas, Godoy.
**Base de Datos II — Unidad 8: Base de Datos para Dispositivos Móviles e Integración.**

Este ensayo es el texto de defensa oral del TP10. Explica qué se construyó, por qué,
las decisiones clave, los seis casos (C2-C6) y lo que la tablet no hace.

---

## 1. Qué se construyó y por qué

Construimos una aplicación de tablet para una feria que funciona **sin conexión**
constantemente. La tablet guarda una **copia parcial del catálogo** (solo los 8
productos de feria, sin datos personales de clientes) en una base SQLite local,
arma **borradores de pedido sin conexión** (cabecera + ítems) y, cuando vuelve la
señal, simula la sincronización con PostgreSQL a través de un **semáforo** que
clasifica cada solicitud como `RECHAZADO`, `CONFLICTO` o `SIMULADO_APROBADO`.

¿Por qué se hizo así? Porque en una feria la señal falla y la tablet no puede
depender del servidor para cada operación. Pero también porque la tablet **no
tiene que decidir nada de negocio**: el precio, el stock y la venta los decide el
servidor. La regla de oro del trabajo es **el móvil propone, el servidor dispone**.
Todo lo que la tablet arma es una borrador y una propuesta; el servidor la valida
al sincronizar.

La arquitectura es:

```
PostgreSQL (fuente de verdad, copia foodstore_u8)
    vista v_snapshot_movil (8 productos de feria)
        \copy CSV
SQLite: snapshot_servidor (staging) → producto_cache (UPSERT, lápidas)
    pedido_borrador + item_borrador (armados sin conexión)
    cola_sync (solicitud_uuid, estado PENDIENTE)
        semaforo.sql → RECHAZADO / CONFLICTO / SIMULADO_APROBADO + motivo
PostgreSQL NO se modifica por la simulación
```

---

## 2. Decisiones clave

### Precios en centavos (INTEGER)
Usamos `precio_centavos INTEGER` en vez de `NUMERIC` para evitar errores de
redondeo al comparar el precio que vio el vendedor en la tablet con el precio
actual del servidor. El `CONFLICTO` de precios (caso C2) se decide comparando
enteros, lo cual es exacto y determinista. Al mostrarlo se divide por 100.0.

### STRICT en SQLite
Todas las tablas son `STRICT`, de modo que SQLite rechaza tipos incorrectos al
insertar (por ejemplo, texto en un precio). Los CHECKs restringen `precio >= 0`,
`cantidad > 0`, `disponible` y `eliminado` en `0/1`, y `forma_pago` /
`estado` a listas cerradas. Las FKs activas evitan ítems de productos
inexistentes.

### Lápidas de baja lógica
La columna `eliminado` de `producto_cache` es una lápida: nunca se borra físicamente
un producto de la caché. Si el servidor da de baja un producto (`eliminado = true`),
viaja en la instantánea y la tablet lo guarda como `eliminado = 1`. Un producto que
simplemente deja de viajar en la copia parcial no se marca eliminado: se pone
`disponible = 0` y se conserva la fila para no romper los ítems de borradores que
ya lo referencian (UPSERT no borra).

### `SIMULADO_APROBADO` no es venta
Es solo una propuesta local que el servidor todavía tiene que validar. La simulación
no modifica PostgreSQL: pedidos y stock total son iguales antes y después de
correr todos los casos, tanto en la copia `foodstore_u8` como en la original
`foodstore`.

### Idempotencia por UUID en el servidor
En la tablet, `cola_sync.solicitud_uuid` es PK, así que reenviar el mismo UUID
falla con `UNIQUE constraint failed` y no duplica la solicitud (caso C6). Pero la
protección real no puede quedar solo en la tablet: en producción el servidor debe
recibir `solicitud_uuid` como clave de idempotencia, registrarlo en una tabla de
solicitudes procesadas (o usar UNIQUE) dentro de la misma transacción que crea el
pedido, y si el UUID ya existe, responder OK sin volver a vender.

---

## 3. Los seis casos (C2-C6) y qué demuestra cada uno

| Caso | Qué se prueba | Resultado | Qué demuestra |
|---|---|---|---|
| **C2** | Borrador del producto 1 a 125945 centavos; el servidor sube el precio a 135945; se importa la nueva instantánea y se corre el semáforo. | `CONFLICTO | producto 1: 125945 -> 135945`. El cliente acepta, corrige el precio y crea una solicitud nueva: `SIMULADO_APROBADO`. | Detecta cambios de precio y permite corregir antes de aprobar; la solicitud vieja queda en CONFLICTO para revisión. |
| **C3** | Borrador de 192 unidades del producto 3; el servidor tiene stock 142. | `RECHAZADO | producto 3: stock 142 < 192`. | Rechaza por stock insuficiente comparando contra el stock visto de la instantánea. |
| **C4** | Borrador del producto 4; luego se da de baja lógica en el servidor (`eliminado = true`). | `RECHAZADO | producto 4 dado de baja`. El producto 4 queda en `producto_cache` con `eliminado = 1` (lápida) y `disponible = 0`; no aparece como disponible. | Distingue baja lógica (lápida) de producto que falta de la copia parcial; conserva la fila para no romper borradores. |
| **C5** | Borrador del producto 5 sin tocar el servidor; se corre el semáforo dos veces. | `SIMULADO_APROBADO | todo coincide con la instantánea`; al repetir, igual. | El semáforo solo evalúa `estado = 'PENDIENTE'`, así que no reevaluar solicitudes ya resueltas (idempotencia de la simulación). |
| **C6** | Reenvío de la misma `solicitud_uuid`. | `UNIQUE constraint failed: cola_sync.solicitud_uuid`; la cola sigue con 1 solicitud. | Idempotencia local: el mismo UUID no se duplica. En el servidor la protección debe ir en la tabla de solicitudes procesadas. |

Además, en la consigna 1 se probaron COMMIT/ROLLBACK de borradores (transacción
atómica: cabecera + ítems + solicitud), C1 (catálogo disponible sin servidor) y C7
(datos inválidos fallan con CHECK/FK y no dejan filas nuevas).

---

## 4. Qué no hace la tablet

La tablet **no decide el precio**: usa el precio visto al armar el borrador, pero
el servidor lo vuelve a validar contra la instantánea.

La tablet **no decide el stock**: compara contra el `stock_visto` de la copia, que
puede estar viejo; el servidor tiene el stock verdadero al momento de la venta.

La tablet **no confirma ventas**: `SIMULADO_APROBADO` es solo una propuesta. La
venta la confirma el servidor al sincronizar, respetando la idempotencia por UUID.

La tablet **no guarda datos personales**: `pedido_borrador.usuario` es un alias
inventado; no viajan nombres, apellidos, emails ni direcciones.

---

## 5. Lecciones aprendidas y qué se haría distinto

**Lecciones:**
- Una consulta SQL puede ser sintácticamente correcta pero semánticamente
  incompleta: la versión inicial del semáforo aprobaba borradores sin ítems
  (hallazgo F4). Hay que exigir explícitamente el caso vacío.
- Las lápidas y los productos que faltan de la copia parcial son cosas distintas:
  marcar `disponible = 0` sin borrar ni tocar `eliminado` evita romper borradores
  existentes (hallazgo F5).
- Los booleanos del CSV de PostgreSQL llegan como `t`/`f`; hay que convertirlos a
  `0/1` al cargar la caché en SQLite.
- `SIMULADO_APROBADO` no es venta: hay que decirlo explícitamente para que no se
  malinterprete como una confirmación.
- La idempotencia por UUID empieza en la tablet pero debe cerrarse en el servidor
  dentro de la transacción de venta.

**Qué se haría distinto:**
- Crear el índice parcial `ux_cola_una_pendiente` documentado desde el spec y no
  solo como nota posterior.
- Dejar constancia exacta de cada prompt de IA en la bitácora al momento de
  escribirlo, en lugar de reconstruirlo después.
- Probar la restauración de un respaldo viejo de PostgreSQL y verificar qué hacen
  las tablets con datos más nuevos que el servidor (escenario de plan de
  mantenimiento de la consigna 3).
- En un sistema real, mover la tabla de solicitudes procesadas al servidor desde el
  día uno, no dejarla como "pendiente de producción".

---