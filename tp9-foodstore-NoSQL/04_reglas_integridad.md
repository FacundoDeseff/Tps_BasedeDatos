# Consigna 3 - Reglas de integridad y justificación del embebido

## Regla 1: integridad referencial y trazabilidad de identificadores

**Enunciado:** todo pedido migrado debe conservar un `id_pedido` válido y todas sus líneas embebidas deben conservar el `id_detalle` y el `id_producto` de origen. No se permite un pedido sin líneas, una línea sin producto referenciado ni identificadores duplicados.

**Cómo se conserva durante la migración:**

- `_id` e `id_pedido` toman el valor de `pedido.id_pedido`.
- Cada elemento de `items[]` conserva `detalle_pedido.id_detalle` y `detalle_pedido.producto_id`.
- `cliente.id_usuario` conserva `pedido.usuario_id`; `items[].id_categoria` conserva `producto.id_categoria`.
- El validador `$jsonSchema` exige que `items` sea un arreglo con al menos un elemento y que todos los identificadores sean enteros.
- Se crean índices únicos sobre `_id` (implícito), `id_pedido` y `items.id_detalle`; el script de migración verifica que `lineas_count` coincida con `items.length` y que no haya `id_detalle` repetidos dentro de un pedido.
- La consulta `02_extraccion_origen.sql` permite comprobar en PostgreSQL que los pedidos y detalles migrados existen y que sus claves coinciden.

**Por qué importa:** sin esta regla se pierde la correspondencia con Food Store y no se pueden comparar los resultados de MongoDB con PostgreSQL (Parte 2). Además, un `id_producto` huérfano haría imposible rastrear qué producto se vendió.

## Regla 2: consistencia aritmética y precios históricos

**Enunciado:** el `total` del pedido debe ser igual a la suma de los `subtotal` de sus líneas, y cada `subtotal` debe cumplir `subtotal = cantidad × precio_unitario_historico` (redondeado a dos decimales). Los importes y cantidades de un pedido ya confirmado no se modifican; solo se permite un cambio de estado siguiendo transiciones válidas.

**Cómo se conserva durante la migración:**

- `total` se copia exactamente de `pedido.total`.
- `subtotal` se copia exactamente de `detalle_pedido.subtotal`.
- `precio_unitario_historico` se calcula una sola vez como `subtotal / cantidad` y se congela en la línea. No se toma `producto.precio_lista`, porque ese es el precio actual del catálogo y puede haber cambiado.
- El script `03_migracion_pedidos.js` verifica, para cada pedido, que `total = Σ subtotal` y que `subtotal = round(cantidad × precio_unitario_historico, 2)`. Si alguna verificación falla, aborta la migración.
- El validador `$jsonSchema` exige `cantidad >= 1`, `subtotal >= 0`, `precio_unitario_historico >= 0` y `total >= 0`, pero **no puede** validar la igualdad aritmética entre campos. Por eso la verificación se hace en el script de migración y, en un sistema en producción, se reforzaría en la capa de aplicación o en una transacción con una comprobación previa a la escritura.
- Para cambios de estado se propone: `PENDIENTE → EN_PREPARACION → ENTREGADO`; `CANCELADO` solo desde `PENDIENTE` o `EN_PREPARACION`. Un pedido `ENTREGADO` o `CANCELADO` no vuelve a un estado anterior.
- El alcance de esta Parte 1 es la migración. La inmutabilidad posterior de importes y cantidades, y las transiciones de estado, se reforzarían en la capa de aplicación o con roles de MongoDB; `$jsonSchema` no puede expresar esas reglas por sí solo.

**Por qué importa:** la consigna exige respetar importes, cantidades y estados. Si el total no coincide con el detalle, las consultas de la Parte 2 devuelven resultados distintos a PostgreSQL. Si se usa el precio actual del producto en lugar del histórico, se altera el importe original del pedido.

## Qué se incluyó dentro del documento y qué quedó afuera

| Dato | Decisión | Justificación |
|---|---|---|
| Líneas del pedido (`detalle_pedido`) | Embebidas en `items[]` | Relación de composición 1:N, acotada y siempre leída con el pedido. Evita `$lookup` y permite insertar cabecera y líneas en una sola operación atómica. |
| Cliente (`usuario`) | Snapshot embebido: `id_usuario`, `nombre`, `apellido` | Son pocos campos y se necesitan para mostrar el pedido. El maestro completo del cliente sigue separado. |
| Nombre y categoría del producto | Snapshot en cada línea | El pedido debe mostrar qué se vendió aunque el producto cambie de nombre o de categoría. |
| Precio histórico | `precio_unitario_historico` y `subtotal` embebidos | El precio de lista actual no sirve para reconstruir una venta pasada. El valor histórico debe quedar congelado en la línea. |
| Catálogo completo de productos | **No** se embebe | `stock` y `precio_lista` cambian con el tiempo; duplicar todo el catálogo generaría documentos grandes y datos obsoletos. La línea conserva la referencia (`id_producto`) y el snapshot mínimo. |
| Maestro completo del cliente | **No** se embebe | Puede tener datos de contacto y cambios frecuentes. Se embebe solo lo esencial para el pedido. |
| Colección separada `detalles_pedido` | **No** se crea | Sería una traducción literal del modelo relacional y obligaría a `$lookup` para el acceso principal. El pedido completo es el agregado natural. |

La duplicación de `nombre_producto`, `categoria` y datos del cliente es deliberada: funciona como **snapshot histórico**. Si se modificara el maestro, los pedidos ya cerrados no deberían cambiar. El costo es espacio; el beneficio es integridad histórica y lectura de un pedido completo con una sola consulta.

## Nota sobre el estado

El esquema PostgreSQL canónico no tiene columna `estado`; solo `eliminado`. Para cumplir la consigna se agregó `estado` al documento con esta correspondencia:

- `eliminado = true` → `CANCELADO`.
- `eliminado = false` → `ENTREGADO` (estado final asumido para pedidos históricos).

El booleano original se conserva en `origen.eliminado`. Los estados `PENDIENTE` y `EN_PREPARACION` quedan disponibles en el modelo para pedidos nuevos, pero no se inventaron para los pedidos migrados.
