# spec: opt_indices_foodstore

## Objetivo
Optimizar las consultas analíticas principales del sistema Food Store eliminando escaneos secuenciales (`Seq Scan`) mediante índices estratégicos en PostgreSQL.

## Consultas de Carga de Trabajo
1. **Filtro y Agregación por Pedidos Activos**:
   - Campos involucrados: `pedido.eliminado`, `pedido.fecha`, `pedido.usuario_id`.
2. **Relación Detalle-Producto**:
   - Campos involucrados: `detalle_pedido.pedido_id`, `detalle_pedido.producto_id`, `detalle_pedido.eliminado`.
3. **Subconsulta de Último Pedido por Usuario**:
   - Campos involucrados: `pedido.usuario_id`, `pedido.fecha` donde `eliminado = FALSE`.

## Criterios de Aceptación
1. Proponer scripts `CREATE INDEX IF NOT EXISTS` para mejorar `JOIN`s, filtros soft-delete (`eliminado = FALSE`) y ordenamientos.
2. Identificar y descartar explícitamente al menos 1 propuesta por sobreindexación.
3. Asegurar sintaxis SQL pura para PostgreSQL 16+.