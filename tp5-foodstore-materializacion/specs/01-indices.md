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
