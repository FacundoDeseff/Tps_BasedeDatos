# Declaracion de Uso de IA (DUIA) - TP5

Completar una fila por cada herramienta o asistencia de IA utilizada.

| Herramienta | Proposito | Prompt / Spec entregado | Propuesta de la IA | Decision y justificacion |
| Kiro | Redactar las especificaciones de optimizacion (Parte A) | Consultas con Seq Scan de `queries.sql` + frecuencia de ejecucion + columnas de filtro/JOIN/ORDER BY | Specs de los indices 1, 2 y 3 en `specs/01-indices.md` | Se adoptaron tal cual: cada spec definio consulta objetivo, frecuencia, columnas y el indice a evaluar |
| OpenCode | Proponer y justificar los indices optimos por consulta | Para la consulta 1 (LIKE por nombre): proponer indices con pros/contras; idem consultas 2 y 3 | C1: index trigram `idx_producto_nombre_trgm` (GIN); C2 y C3: covering index parcial con `INCLUDE` | C1: se descarto el B-tree por el comodin `_` y se eligio GIN trigram; C2/C3: se adoptaron los covering, midiendo mejora de plan (Seq Scan a Bitmap/Index Only Scan) |
| OpenCode | Medir y documentar impacto en escritura | Script de carga de 500 INSERT en `detalle_pedido` y metodologia con/sin indices (`\timing`) | BEGIN;
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, subtotal, eliminado)
SELECT (g % 200000) + 1, (g % 46000) + 1, 3,
       ROUND((RANDOM() * 500 + 10)::numeric, 2), FALSE
FROM generate_series(1, 500) g;
COMMIT; | Se ejecuto en `copia_trabajo`: +~1.3 ms (~+10%) de overhead; costo aceptable frente a mejoras de lectura de hasta ~230x |
| OpenCode | Descartar propuesta por sobreindexacion | Revisar si alguna propuesta era redundante o sobre columna de baja cardinalidad | Descartar `idx_pedido_fecha_activo` (redundante con el covering) y un hipotetico indice plano sobre `eliminado` | Se documentaron los descartes en `informe_mediciones.md` (seccion "Descarte por sobreindexacion") |
| OpenCode | Generar vistas para reportes y aplicar criterios de seguridad (Parte B) | Vistas en `specs/02-vistas.md` | Generar `v_productos_vigentes`, `v_pedidos_usuario`, `v_usuarios_seguros` y `v_detalle_pedido_producto` | Se aceptaron las cuatro vistas y se verificó la equivalencia de resultados con consultas directas usando `EXCEPT`; `v_usuarios_seguros` aplica el principio de menor privilegio |
| OpenCode | Crear vista materializada e índice para refresco (Parte C) | Especificación en `specs/03-materializada.md` | Generar `vm_facturacion_categoria_mes` con `WITH DATA` e índice único en `(id_categoria, mes)` | Se aceptó la propuesta para habilitar `REFRESH MATERIALIZED VIEW CONCURRENTLY` |