# Informe de Mediciones y Justificaciones - TP5

## Parte A: Mediciones de Indices

### Consultas evaluadas

Las tres consultas de queries.sql se ejecutaron con EXPLAIN ANALYZE antes (sin índices) y después de crear los índices definidos en indices.sql.

Consulta 1 — Búsqueda de productos por nombre
SELECT id_producto, nombre, precio_lista, stock
FROM producto
WHERE nombre LIKE 'Producto_45345%' AND eliminado = FALSE;
Índice: idx_producto_nombre_trgm — GIN con pg_trgm, parcial WHERE eliminado = FALSE.

Consulta 2 — Reporte de ventas semanal
SELECT id_pedido, usuario_id, fecha, total
FROM pedido
WHERE fecha >= NOW() - INTERVAL '7 days' AND eliminado = FALSE;
Índice: idx_pedido_fecha_activo_cover — B-tree parcial cobertor sobre fecha con INCLUDE (usuario_id, total).

Consulta 3 — Detalle de un pedido
SELECT dp.id_detalle, dp.producto_id, dp.cantidad, dp.subtotal, pr.nombre
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
WHERE dp.pedido_id = 150000 AND dp.eliminado = FALSE;
Índice: idx_detalle_pedido_pedidoid_cover — B-tree parcial cobertor sobre pedido_id con INCLUDE (id_detalle, producto_id, cantidad, subtotal).

| Consulta | Antes | Despues | Mejora / observaciones |
| 1: producto por nombre | Seq Scan — 6.781 ms | Bitmap Heap Scan — 2.387 ms | ~2.8×. El B-tree no servía porque _ es comodín de LIKE y corta el prefijo en Producto (matchea toda la tabla); el trigram poda por trigramas internos. |
| 2: ventas semanales | Parallel Seq Scan — 175.084 ms | Bitmap Heap Scan — 0.759 ms | ~230×. Rango de fechas resuelto por el B-tree cobertor; solo lee bloques de los últimos 7 días. Nota: la ventana devolvió 0 filas (datos sin pedidos recientes), se midió la poda sobre rango vacío. |
| 3: detalle de pedido | Nested Loop + Seq Scan — 18.901 ms | Nested Loop + Index Only Scan — 0.212 ms | ~90×. Covering index: Heap Fetches: 0, desaparece el barrido de 200.000 filas; JOIN a producto resuelto por la PK. |

Los planes completos se encuentran antes/después en indice.sql (comentados junto a cada CREATE INDEX).


### Impacto en escritura

Para medir el costo de mantenimiento de los indices se cargaron 500 filas en `detalle_pedido` (INSERT ... SELECT con `generate_series`), ejecutadas **con los indices creados** y luego **con los indices eliminados** (DROP temporal), usando `\timing` en psql y tomando como metrica la duracion del `INSERT`. La primera corrida de cada escenario se descarta por cache frio.

Carga utilizada (recomendada por OpenCode):
```sql
BEGIN;
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, subtotal, eliminado)
SELECT (g % 200000) + 1, (g % 46000) + 1, 3,
       ROUND((RANDOM() * 500 + 10)::numeric, 2), FALSE
FROM generate_series(1, 500) g;
COMMIT;
```

| Escenario | Corrida 1 | Corrida 2 | Corrida 3 | Valor estable (promedio) |
| Con los 3 indices | 13.861 ms | 13.982 ms | 16.170 ms | ~14.7 ms |
| Sin los 3 indices | 44.458 ms* | 13.558 ms | 13.339 ms | ~13.4 ms |

\* Descartada por cache frio tras el DROP (outlier).

**Conclusion:** 
mantener los 3 indices (1 GIN trigram + 2 B-tree parciales cobertores) degrada la carga de 500 INSERT en **~1.3 ms (~+10%)**. 
El costo es aceptable frente a las mejoras de lectura obtenidas (hasta ~230x en la consulta 2), dado que la escritura no es la operacion dominante del sistema.


### Descarte por sobreindexación

Descartado: idx_pedido_fecha_activo (B-tree simple parcial sobre pedido(fecha), propuesto en specs/01-indices.md). 
Es redundante con el cobertor idx_pedido_fecha_activo_cover ya creado, que comparte la misma clave fecha y el mismo predicado parcial, 
y además cubre las columnas del SELECT. Mantenerlo duplicaría el costo de escritura sin aportar ningún plan alternativo mejor; por eso se descarta para no sobreindexar.
También se descartó un hipotético índice plano sobre eliminado: columna booleana de baja cardinalidad sin condición parcial, que el planificador no usaría para podar.

---

## Parte B: Verificación de Equivalencia de Vistas

Se compararon cada vista con su consulta equivalente mediante `EXCEPT` en ambos sentidos. Criterio: equivalencia exacta si ambos `EXCEPT` devuelven 0 filas.

| Vista | Prueba | Resultado | Observación |
|---|---|---|---|
| `v_productos_vigentes` | `vista EXCEPT manual` / `manual EXCEPT vista` | 0 filas / 0 filas | Equivalentes |
| `v_pedidos_usuario` | `vista EXCEPT manual` / `manual EXCEPT vista` | 0 filas / 0 filas | Equivalentes |
| `v_usuarios_seguros` | `vista EXCEPT manual` / `manual EXCEPT vista` | 0 filas / 0 filas | Equivalentes; vista de menor privilegio |
| `v_detalle_pedido_producto` | `vista EXCEPT manual` / `manual EXCEPT vista` | 0 filas / 0 filas | Equivalentes |

Se cumplen las equivalencias exactas, esto valida que la vista replica a la consulta definida.

### Consultas de equivalencia ejecutadas

#### 1. `v_productos_vigentes`

```sql
-- Vista EXCEPT consulta manual
(SELECT * FROM v_productos_vigentes)
EXCEPT
(SELECT p.id_producto, p.nombre AS producto_nombre, p.precio_lista, p.stock,
                c.id_categoria, c.nombre AS categoria_nombre
 FROM producto p
 JOIN categoria c ON p.id_categoria = c.id_categoria
 WHERE p.eliminado = FALSE
     AND c.eliminado = FALSE);

-- Consulta manual EXCEPT vista
(SELECT p.id_producto, p.nombre AS producto_nombre, p.precio_lista, p.stock,
                c.id_categoria, c.nombre AS categoria_nombre
 FROM producto p
 JOIN categoria c ON p.id_categoria = c.id_categoria
 WHERE p.eliminado = FALSE
     AND c.eliminado = FALSE)
EXCEPT
(SELECT * FROM v_productos_vigentes);
```

#### 2. `v_pedidos_usuario`

```sql
-- Vista EXCEPT consulta manual
(SELECT * FROM v_pedidos_usuario)
EXCEPT
(SELECT p.id_pedido, p.fecha, p.total, u.id_usuario,
                u.nombre AS usuario_nombre, u.apellido AS usuario_apellido
 FROM pedido p
 JOIN usuario u ON p.usuario_id = u.id_usuario
 WHERE p.eliminado = FALSE);

-- Consulta manual EXCEPT vista
(SELECT p.id_pedido, p.fecha, p.total, u.id_usuario,
                u.nombre AS usuario_nombre, u.apellido AS usuario_apellido
 FROM pedido p
 JOIN usuario u ON p.usuario_id = u.id_usuario
 WHERE p.eliminado = FALSE)
EXCEPT
(SELECT * FROM v_pedidos_usuario);
```

#### 3. `v_usuarios_seguros`

```sql
-- Vista EXCEPT consulta manual
(SELECT * FROM v_usuarios_seguros)
EXCEPT
(SELECT u.id_usuario, u.nombre, u.apellido
 FROM usuario u
 WHERE u.eliminado = FALSE);

-- Consulta manual EXCEPT vista
(SELECT u.id_usuario, u.nombre, u.apellido
 FROM usuario u
 WHERE u.eliminado = FALSE)
EXCEPT
(SELECT * FROM v_usuarios_seguros);
```

#### 4. `v_detalle_pedido_producto`

```sql
-- Vista EXCEPT consulta manual
(SELECT * FROM v_detalle_pedido_producto)
EXCEPT
(SELECT dp.pedido_id AS id_pedido, dp.id_detalle, dp.producto_id,
                pr.nombre AS producto_nombre, dp.cantidad, dp.subtotal
 FROM detalle_pedido dp
 JOIN pedido p ON dp.pedido_id = p.id_pedido
 JOIN producto pr ON dp.producto_id = pr.id_producto
 WHERE dp.eliminado = FALSE
     AND p.eliminado = FALSE
     AND pr.eliminado = FALSE);

-- Consulta manual EXCEPT vista
(SELECT dp.pedido_id AS id_pedido, dp.id_detalle, dp.producto_id,
                pr.nombre AS producto_nombre, dp.cantidad, dp.subtotal
 FROM detalle_pedido dp
 JOIN pedido p ON dp.pedido_id = p.id_pedido
 JOIN producto pr ON dp.producto_id = pr.id_producto
 WHERE dp.eliminado = FALSE
     AND p.eliminado = FALSE
     AND pr.eliminado = FALSE)
EXCEPT
(SELECT * FROM v_detalle_pedido_producto);
```


---

## Parte C: Vista Materializada

### Reporte elegido y creación

Reporte agregado costoso: **facturación por categoría y mes** (identificado en las consultas analíticas de la Semana 4). Requiere 3 JOINs sobre ~198.000 filas de `detalle_pedido`, sort a disco y agregaciones `COUNT(DISTINCT)` + `SUM`, pero devuelve solo 13 filas.

Creada en `views.sql` con `WITH DATA` e índice único compuesto.
El índice único sobre (id_categoria, mes) es obligatorio: PostgreSQL exige un índice único que cubra la cláusula GROUP BY para habilitar REFRESH MATERIALIZED VIEW CONCURRENTLY.

### Medición de Consulta vs Vista Materializada

Se midió la consulta original ejecutada directamente sobre las tablas contra la consulta sobre la vista materializada, con el mismo dataset.

Caso |	Corrida 1 (ms) |	Corrida 2 (ms) |	Corrida 3 (ms) |	Promedio (ms) |
Consulta original (sin materializar) |	910.482 |	932.041 |	938.331 | 926.95 |
Vista materializada (vm_facturacion_categoria_mes) |	0.040 |	0.040 |	0.040 |	0.040 |

Resultado: la vista materializada responde ~23.000× más rápido (0,040 ms vs 927 ms).

### Frecuencia de REFRESH MATERIALIZED VIEW

Frecuencia sugerida: 1 vez al día, en ventana nocturna (fuera de pico):
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;

Justificación:
- El reporte es agregado histórico (facturación por categoría y mes); los pedidos ya facturados no se modifican retroactivamente con frecuencia.
- El REFRESH recalcula el agregado completo sobre ~198.000 filas, por lo que ejecutarlo ante cada nuevo pedido sería costoso e innecesario.
- El uso esperado es de reporte gerencial/analítico, consultado por lotes (diario/semanal), no en tiempo real.
- El índice único (id_categoria, mes) habilita CONCURRENTLY, de modo que las lecturas no se bloquean durante el refresco.
- Si el volumen creciera, podría aumentarse a cada 6–12 horas; con el volumen actual, el refresco diario es suficiente.

### Qué implica para los usuarios:
El dato no se actualiza en cada operación: existe latencia de frescura. Los pedidos ingresados después del último refresco no aparecerán en el reporte hasta la próxima ejecución del REFRESH; el reporte siempre refleja el estado "al corte del último refresco". Este compromiso es aceptable para un reporte analítico (menor tiempo de respuesta a cambio de frescura acotada), pero no lo sería para una consulta transaccional que exija ver los últimos pedidos al instante.