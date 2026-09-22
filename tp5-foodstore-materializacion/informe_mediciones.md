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


## Parte B: Mediciones y equivalencia de vistas

Documentar la comparacion entre cada vista y su consulta equivalente, incluyendo las pruebas con `EXCEPT` en ambos sentidos.

## Parte C: Mediciones de la vista materializada

Registrar la comparacion entre la consulta en vivo y la consulta sobre la vista materializada.

### Indice y frecuencia de refresco

Justificar el indice unico y documentar la frecuencia y estrategia de `REFRESH MATERIALIZED VIEW`.
