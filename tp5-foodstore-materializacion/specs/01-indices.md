# Specs de Índices — TP5 FoodStore

---

## Índice 1 — Búsqueda de productos por nombre

### Consulta objetivo

```sql
SELECT id_producto, nombre, precio_lista, stock
FROM producto
WHERE nombre LIKE 'Producto_45345%' AND eliminado = FALSE;
```

### Contexto y justificación

| Atributo | Detalle |
|---|---|
| **Frecuencia** | Alta — se ejecuta en cada búsqueda del cliente (decenas por hora) |
| **Tabla** | `producto` (~46.000 filas efectivas) |
| **Filtros activos** | `nombre LIKE 'Producto_45345%'` (patrón con prefijo) y `eliminado = FALSE` |
| **JOINs / ORDER BY** | Ninguno relevante |
| **Plan actual** | Seq Scan sobre `producto` — recorre toda la tabla en cada ejecución |

### Problema

Sin índice, PostgreSQL realiza un **Sequential Scan** sobre las ~46.000 filas de `producto` para cada búsqueda. Dado que la consulta filtra por prefijo (`LIKE 'texto%'`) y por un flag booleano (`eliminado = FALSE`), existe una oportunidad clara de acelerar la búsqueda con un índice.

### Solución propuesta

Crear un **índice B-tree parcial** sobre la columna `nombre`, restringido solo a las filas donde `eliminado = FALSE`:

```sql
CREATE INDEX idx_producto_nombre_activo
    ON producto (nombre)
    WHERE eliminado = FALSE;
```

**Por qué B-tree parcial:**
- Los patrones de prefijo (`LIKE 'abc%'`) son compatibles con recorrido B-tree, siempre que la collation lo permita (o se use `text_pattern_ops`).
- La condición `WHERE eliminado = FALSE` reduce el tamaño del índice a solo los productos activos, que son la mayoría de las búsquedas reales.
- El resultado esperado es pasar de **Seq Scan** a **Index Scan** (o Bitmap Index Scan), reduciendo drásticamente los bloques leídos.

### Resultado esperado

| Métrica | Antes (Seq Scan) | Después (Index Scan) |
|---|---|---|
| Filas evaluadas | ~46.000 | Solo las que coinciden con el prefijo |
| Tipo de plan | Sequential Scan | Index Scan / Bitmap Index Scan |
| Costo estimado | Alto (proporcional a toda la tabla) | Bajo (proporcional al resultado) |

### Consideraciones adicionales

- Si la base usa collation por defecto (`C` o `POSIX`), el índice funciona directamente con `LIKE`.
- Para collations del tipo `en_US.UTF-8` o `es_AR.UTF-8` puede ser necesario usar la clase de operador `text_pattern_ops`:
  ```sql
  CREATE INDEX idx_producto_nombre_activo
      ON producto (nombre text_pattern_ops)
      WHERE eliminado = FALSE;
  ```
- Verificar el plan resultante con `EXPLAIN ANALYZE` tras crear el índice.

---

## Índice 2 — Reporte de ventas semanal

### Consulta objetivo

```sql
SELECT id_pedido, usuario_id, fecha, total
FROM pedido
WHERE fecha >= NOW() - INTERVAL '7 days' AND eliminado = FALSE;
```

### Contexto y justificación

| Atributo | Detalle |
|---|---|
| **Frecuencia** | Media-alta — corre en cada cierre semanal diario |
| **Tabla** | `pedido` (~200.000 filas efectivas) |
| **Filtros activos** | `fecha >= NOW() - INTERVAL '7 days'` (rango temporal) y `eliminado = FALSE` |
| **JOINs / ORDER BY** | Sin JOIN; ORDER BY implícito por fecha descendente en la salida |
| **Plan actual** | Seq Scan sobre `pedido` — recorre las 200.000 filas en cada ejecución |

### Problema

Sin índice, PostgreSQL evalúa **todas las filas de `pedido`** para encontrar los pedidos de los últimos 7 días. Con 200.000 filas y una frecuencia de ejecución diaria, el costo acumulado es significativo. Los filtros de rango sobre columnas de tipo fecha/timestamp son el caso de uso clásico para un índice B-tree.

### Solución propuesta

Crear un **índice B-tree parcial** sobre la columna `fecha`, restringido a las filas donde `eliminado = FALSE`:

```sql
CREATE INDEX idx_pedido_fecha_activo
    ON pedido (fecha)
    WHERE eliminado = FALSE;
```

**Por qué B-tree parcial:**
- B-tree soporta de forma nativa los operadores de rango (`>=`, `<=`, `BETWEEN`), por lo que es el tipo correcto para filtros sobre `fecha`.
- La condición `WHERE eliminado = FALSE` excluye los pedidos borrados lógicamente del índice, reduciendo su tamaño y manteniéndolo alineado con el predicado de la consulta.
- Al coincidir exactamente el predicado del índice con el filtro de la consulta, el planificador puede usar **Bitmap Index Scan** o **Index Scan**, evitando el Seq Scan.
- Si la consulta final necesita ORDER BY fecha DESC, el índice también puede servir el orden sin un paso adicional de Sort.

### Resultado esperado

| Métrica | Antes (Seq Scan) | Después (Bitmap/Index Scan) |
|---|---|---|
| Filas evaluadas | ~200.000 | Solo los pedidos de los últimos 7 días |
| Tipo de plan | Sequential Scan | Bitmap Index Scan / Index Scan |
| Costo estimado | Alto (proporcional a toda la tabla) | Bajo (proporcional al rango temporal) |

### Consideraciones adicionales

- La ventana de 7 días es dinámica (`NOW() - INTERVAL '7 days'`), por lo que el índice siempre se consulta sobre un rango móvil — esto es eficiente con B-tree.
- Si el volumen de pedidos activos de los últimos 7 días representa más del 20–30 % de la tabla, el planificador puede preferir Seq Scan igualmente. En ese caso se puede forzar la evaluación con `SET enable_seqscan = OFF` durante las pruebas.
- Verificar el plan resultante con `EXPLAIN ANALYZE` tras crear el índice.
