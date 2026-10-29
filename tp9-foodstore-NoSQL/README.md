# TP9 - Unidad 7: NoSQL y nuevas formas de almacenamiento

## Food Store en MongoDB - Parte 1

Esta carpeta contiene el modelo documental, la extracción desde PostgreSQL y la migración de un subconjunto de pedidos de Food Store a MongoDB.

### Requisitos

- PostgreSQL 16 o superior (probado en 17) con la base `foodstore` reconstruida (esquema TP3/TP5/TP8).
- MongoDB 6.0 o superior y `mongosh`.
- `psql` disponible en el PATH (o usar la ruta completa de PostgreSQL).

### Archivos

| Archivo | Contenido |
|---|---|
| `01_modelo_documental.md` | Análisis del subconjunto relacional, esquema documental, campos, objetos embebidos, arreglos e identificadores conservados. |
| `02_extraccion_origen.sql` | Consultas para verificar en PostgreSQL los pedidos migrados y el control `total = suma de subtotales`. Incluye una vista previa del JSON. |
| `03_migracion_pedidos.js` | Script de `mongosh` que crea la base/colección, define el validador `$jsonSchema`, crea índices e inserta 6 pedidos existentes con `insertMany()`. |
| `04_reglas_integridad.md` | Las dos reglas de integridad de la Consigna 3 y la justificación de los datos embebidos. |

### Datos migrados

Se toman 6 pedidos existentes en la base `foodstore`:

| `id_pedido` | Cliente | Estado documental | Total |
|---|---|---|---|
| 1 | Usuario_2578 | ENTREGADO | 4606.71 |
| 2 | Usuario_7439 | ENTREGADO | 7208.54 |
| 3 | Usuario_3430 | CANCELADO | 3885.17 |
| 4 | Usuario_352 | ENTREGADO | 5515.37 |
| 5 | Usuario_7773 | ENTREGADO | 5198.69 |
| 6 | Usuario_6009 | ENTREGADO | 3283.34 |

El pedido 3 tiene `pedido.eliminado = true` en PostgreSQL; por eso se mapea a `CANCELADO`. Los demás se mapean a `ENTREGADO`. El booleano original queda en `origen.eliminado`.

### Cómo ejecutar

1. Verificar el origen en PostgreSQL (opcional, pero recomendado para el informe):

```powershell
psql -h localhost -U postgres -d foodstore -f 02_extraccion_origen.sql
```

Si `psql` no está en el PATH, usar la ruta completa de la instalación, por ejemplo:

```powershell
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h localhost -U postgres -d foodstore -f 02_extraccion_origen.sql
```

2. Ejecutar la migración en MongoDB:

```powershell
mongosh "mongodb://localhost:27017/foodstore_nosql" --file 03_migracion_pedidos.js
```

El script imprime la cantidad de documentos insertados, el resultado de las verificaciones de integridad, un resumen de los pedidos y la cantidad por estado.

Salida esperada (resumen):

```text
Documentos insertados: 6
Integridad OK
ENTREGADO: 5
CANCELADO: 1
```

3. Verificar manualmente en `mongosh`:

```javascript
use foodstore_nosql
db.pedidos.find({}, { _id: 1, estado: 1, total: 1 }).sort({ _id: 1 })
db.pedidos.countDocuments({ estado: "ENTREGADO" })
db.pedidos.countDocuments({ "items.id_producto": 5829 })
```

### Decisiones principales

- El pedido es el agregado documental: cabecera + cliente + líneas en un solo documento.
- `_id` conserva el `id_pedido` original y se mantiene además el campo `id_pedido` para trazabilidad explícita.
- Las líneas se embeben en `items[]`; no se crea una colección separada de detalles.
- Se conservan `id_detalle`, `id_producto`, `id_categoria` y `id_usuario`.
- Se congela el precio histórico en cada línea (`precio_unitario_historico`) y se conserva el `subtotal` original.
- El catálogo completo de productos y el maestro completo de clientes no se embeben: cambian con el tiempo y no forman parte del agregado del pedido.

### Notas sobre los datos de origen

- La base de desarrollo se generó con una carga sintética que asignó todos los productos a la categoría `Pastas`. Por eso todos los pedidos migrados muestran esa categoría. No se modificaron los datos: se migraron tal como están.
- Las fechas de PostgreSQL son `timestamp without time zone` en `America/Buenos_Aires`. En MongoDB se guardan como `Date` con offset `-03:00`; los microsegundos se truncan a milisegundos.
- Los importes son `numeric(12,2)` y se guardan como números. Para producción se recomienda `Decimal128`.

### Próximos pasos (Partes 2 y 3)

- Crear `consultas_mongodb.js` con las consultas a, b, c y d de la Consigna 4.
- Crear `consultas_postgresql.sql` con las consultas equivalentes a b y c.
- Completar la tabla comparativa de cantidades e identificadores.
- Redactar el contraste de afirmaciones de IA y la conclusión de la Parte 3.
