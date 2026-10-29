# TP9 - Unidad 7: Food Store en MongoDB

## Parte 1 - Modelo documental y migración

### 1. Subconjunto relacional de origen

El subconjunto que se migra es **pedidos + detalle de pedidos + datos esenciales del cliente**. Se toma como referencia el esquema canónico usado desde TP3/TP5/TP8 (`foodstore`), no la versión inicial de TP1.

| Tabla | Clave primaria | Claves foráneas / relaciones | Papel en el documento |
|---|---|---|---|
| `pedido` | `id_pedido` | `usuario_id` → `usuario.id_usuario` | Documento raíz |
| `detalle_pedido` | `id_detalle` | `pedido_id` → `pedido.id_pedido`; `producto_id` → `producto.id_producto` | Objetos embebidos en `items[]` |
| `usuario` | `id_usuario` | — | Snapshot embebido en `cliente` |
| `producto` | `id_producto` | `id_categoria` → `categoria.id_categoria` | Referencia + snapshot de nombre/categoría |
| `categoria` | `id_categoria` | — | Snapshot del nombre en `items[]` |

Relaciones principales:

- `pedido` 1:N `detalle_pedido` (un pedido tiene una o más líneas).
- `detalle_pedido` N:1 `producto` (cada línea referencia un producto).
- `pedido` N:1 `usuario` (cada pedido pertenece a un cliente).

#### Correspondencia `cliente` / `usuario`

En TP1 la tabla se llama `cliente`. En el esquema canónico de TP3/TP5/TP8 se llama `usuario`. El documento usa el nombre `cliente` porque la consigna pide datos del cliente, pero conserva el identificador original `id_usuario`. Si el equipo parte del esquema de TP1, debe reemplazar `id_usuario` por `id_cliente` y puede agregar `email` y `telefono`, que en el esquema canónico no existen.

#### Sobre el campo `estado`

El esquema canónico de `pedido` **no tiene columna `estado`**: solo tiene `eliminado` (booleano). Para cumplir la Consigna 2, el modelo documental incorpora `estado` y define esta correspondencia explícita durante la migración:

| Valor en PostgreSQL | Valor en MongoDB |
|---|---|
| `pedido.eliminado = true` | `estado: "CANCELADO"` |
| `pedido.eliminado = false` | `estado: "ENTREGADO"` (estado final asumido para pedidos históricos) |

El modelo admite además `PENDIENTE` y `EN_PREPARACION` para pedidos nuevos, pero la migración no los genera porque la base de origen no registra esa información. El booleano original se conserva en `origen.eliminado` para no perder trazabilidad.

#### Sobre los precios históricos

`detalle_pedido` guarda `cantidad` y `subtotal`, pero **no guarda el precio unitario**. El precio histórico implícito se obtiene como:

```
precio_unitario_historico = subtotal / cantidad
```

Ese valor se embebe en la línea junto con el `subtotal` original. No se copia `producto.precio_lista` como precio del pedido porque ese es el precio **actual** del catálogo y puede haber cambiado: usarlo alteraría el importe histórico. El `precio_lista` solo sirve como referencia de catálogo, no para reconstruir el pedido.

En la carga sintética de desarrollo, `producto.precio_lista` y `detalle_pedido.subtotal` se generaron de forma independiente, por lo que no coinciden entre sí. El dato válido para el pedido es el `subtotal` realmente almacenado en `detalle_pedido`; el precio de lista no se usa para recalcularlo. Esta es una característica de los datos de origen y se conserva sin modificarla.

### 2. Decisión de modelado: qué se embebe y qué queda afuera

La unidad natural de lectura es **el pedido completo**: cabecera, cliente, líneas, cantidades, precios y total. Por eso el pedido se modela como un **agregado documental**:

- **Se embeben las líneas (`items[]`)** porque son una relación de composición 1:N, acotada, que siempre se lee junto con el pedido. Esto evita un `$lookup` en la consulta más frecuente y permite insertar el pedido y sus líneas en una sola operación atómica.
- **Se embebe un snapshot del cliente** (`id_usuario`, `nombre`, `apellido`) porque son pocos campos y se necesitan para mostrar el pedido sin otra consulta. El maestro completo del cliente (altas, bajas, cambios, datos de contacto) sigue en PostgreSQL, o en una colección `clientes` si se migrara.
- **No se embebe el catálogo completo de productos.** La línea conserva `id_producto`, `nombre_producto`, `id_categoria`, `categoria` y el precio histórico. El stock y el precio de lista cambian con el tiempo; el pedido debe conservar el valor del momento de la compra. El catálogo sigue en PostgreSQL, o en una colección `productos` si se migrara.
- **No se crea una colección `detalles_pedido` separada.** Sería el equivalente a la tabla relacional, pero obligaría a hacer `$lookup` para leer un pedido completo y no daría atomicidad entre cabecera y líneas.

Tradeoff aceptado: el nombre del cliente y el nombre/categoría del producto se duplican en cada pedido. Esa duplicación es deliberada: funciona como **snapshot histórico** y evita que un cambio posterior en el maestro modifique pedidos ya cerrados. Si el negocio necesitara mostrar siempre el nombre actual del cliente, se resolvería con una colección `clientes` y `$lookup`, pero no es el acceso principal de este TP.

### 3. Esquema documental propuesto

Colección: `foodstore_nosql.pedidos`

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `_id` | int | Sí | Clave de MongoDB. Conserva el `id_pedido` original |
| `id_pedido` | int | Sí | Identificador de origen conservado explícitamente |
| `fecha` | date | Sí | Fecha del pedido (`timestamp` de PostgreSQL interpretado en `America/Buenos_Aires`) |
| `estado` | string | Sí | `PENDIENTE`, `EN_PREPARACION`, `ENTREGADO` o `CANCELADO` |
| `total` | number | Sí | Total del pedido, copiado de `pedido.total` |
| `cliente` | object | Sí | Snapshot del cliente |
| `cliente.id_usuario` | int | Sí | FK original `usuario.id_usuario` |
| `cliente.nombre` | string | Sí | Nombre al momento de la compra |
| `cliente.apellido` | string | Sí | Apellido al momento de la compra |
| `items` | array | Sí | Líneas del pedido, mínimo 1 |
| `items[].id_detalle` | int | Sí | PK original `detalle_pedido.id_detalle` |
| `items[].id_producto` | int | Sí | FK original `producto.id_producto` |
| `items[].nombre_producto` | string | Sí | Snapshot del nombre del producto |
| `items[].id_categoria` | int | Sí | FK original `categoria.id_categoria` |
| `items[].categoria` | string | Sí | Snapshot del nombre de la categoría |
| `items[].cantidad` | int | Sí | Cantidad, mayor o igual a 1 |
| `items[].precio_unitario_historico` | number | Sí | `subtotal / cantidad` al momento de la compra |
| `items[].subtotal` | number | Sí | Importe original de la línea |
| `items[].eliminado` | bool | Sí | Booleano original de `detalle_pedido.eliminado` |
| `lineas_count` | int | Sí | Cantidad de elementos de `items[]` (control de integridad) |
| `moneda` | string | Sí | `ARS` |
| `origen` | object | Sí | Metadatos de procedencia |
| `origen.sistema` | string | Sí | `PostgreSQL` |
| `origen.base` | string | Sí | `foodstore` |
| `origen.tabla` | string | Sí | `pedido` |
| `origen.eliminado` | bool | Sí | Booleano original de `pedido.eliminado` |
| `migrado_en` | date | Sí | Fecha y hora en que se insertó el documento |
| `schema_version` | int | Sí | Versión del modelo documental (inicial: `1`) |

Identificadores conservados:

- `_id` y `id_pedido` = `pedido.id_pedido`.
- `items[].id_detalle` = `detalle_pedido.id_detalle`.
- `items[].id_producto` = `detalle_pedido.producto_id`.
- `items[].id_categoria` = `producto.id_categoria`.
- `cliente.id_usuario` = `pedido.usuario_id`.
- `detalle_pedido.pedido_id` no se repite en cada ítem: la relación con el pedido queda implícita en el documento padre.

### 4. Ejemplo de documento

En el ejemplo, las fechas se muestran como cadenas ISO para que el JSON sea legible; en MongoDB se almacenan como `Date`. Los importes se muestran como números. El documento corresponde al pedido existente `id_pedido = 1` de `foodstore`:

```json
{
  "_id": 1,
  "id_pedido": 1,
  "fecha": "2026-09-29T13:30:21.757-03:00",
  "estado": "ENTREGADO",
  "total": 4606.71,
  "cliente": {
    "id_usuario": 2578,
    "nombre": "Usuario_2578",
    "apellido": "Apellido_2578"
  },
  "items": [
    {
      "id_detalle": 1,
      "id_producto": 5829,
      "nombre_producto": "Producto_5829",
      "id_categoria": 7,
      "categoria": "Pastas",
      "cantidad": 2,
      "precio_unitario_historico": 1580.345,
      "subtotal": 3160.69,
      "eliminado": false
    },
    {
      "id_detalle": 2,
      "id_producto": 32828,
      "nombre_producto": "Producto_32828",
      "id_categoria": 7,
      "categoria": "Pastas",
      "cantidad": 2,
      "precio_unitario_historico": 723.01,
      "subtotal": 1446.02,
      "eliminado": false
    }
  ],
  "lineas_count": 2,
  "moneda": "ARS",
  "origen": {
    "sistema": "PostgreSQL",
    "base": "foodstore",
    "tabla": "pedido",
    "eliminado": false
  },
  "migrado_en": "2026-10-29T12:00:00.000-03:00",
  "schema_version": 1
}
```

### 5. Validación e índices

La colección se crea con un validador `$jsonSchema` (ver `03_migracion_pedidos.js`) que exige los campos, tipos y mínimos anteriores. Además se crean estos índices:

| Índice | Motivo |
|---|---|
| `{ id_pedido: 1 }` único | Refuerza la clave de origen, además de `_id` |
| `{ estado: 1 }` | Consulta (b): filtrar por estado |
| `{ "cliente.id_usuario": 1 }` | Pedidos de un cliente |
| `{ "items.id_producto": 1 }` | Consulta (c): producto dentro del arreglo (índice multikey) |
| `{ "items.id_detalle": 1 }` único | Evita duplicar una línea de pedido entre documentos |
| `{ total: 1 }` | Consulta (d): total mayor a un umbral |
| `{ fecha: -1 }` | Orden cronológico |

MongoDB no puede validar de forma declarativa una igualdad aritmética entre campos (`total = suma de subtotales`). Esa regla se controla en el script de migración y se documenta en `04_reglas_integridad.md`.

### 6. Procedencia y precisión de los datos

- Se migran **6 pedidos existentes** de la base `foodstore`: `id_pedido` 1, 2, 3, 4, 5 y 6.
- La consulta que permite verificarlos está en `02_extraccion_origen.sql`.
- Las fechas de origen son `timestamp without time zone` y se interpretan en la zona `America/Buenos_Aires` (`-03:00`). BSON `Date` tiene precisión de milisegundos, por lo que los microsegundos de PostgreSQL se truncan; no se altera la identidad del pedido.
- Los importes son `numeric(12,2)` y se almacenan como números. Para estos valores la representación conserva los centavos. En una implementación de producción se recomienda `Decimal128` para evitar errores de punto flotante en cálculos monetarios.
- La base de desarrollo fue generada con una carga sintética que dejó todos los productos en la categoría `Pastas`. Por eso los pedidos migrados muestran esa categoría. Es una característica de los datos de origen, no una decisión del modelo; los valores se conservan sin modificarlos.
