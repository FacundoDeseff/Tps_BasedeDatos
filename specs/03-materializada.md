# spec: vista_materializada_facturacion

## Objetivo
Materializar la consulta analítica de facturación por categoría y mes para reducir el tiempo de respuesta en reportes pesados.

## Requerimientos
1. Crear la vista materializada `vm_facturacion_categoria_mes` con `WITH DATA`.
2. Incluir un índice único compuesto sobre `(id_categoria, mes)` para habilitar `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

## Criterios de Aceptación
- Script SQL válido para PostgreSQL 16+.
- Documentar en el informe la justificación del índice y la frecuencia sugerida de refresco.