# spec: vistas_reportes_foodstore

## Objetivo
Crear vistas para simplificar el acceso a reportes y aplicar criterios de seguridad sobre datos sensibles.

## Vistas a definir
1. **`v_productos_vigentes`**: Exponer productos activos (`eliminado = FALSE`) con el nombre de su categoría.
2. **`v_pedidos_usuario`**: Exponer pedidos con los datos del usuario asociado.
3. **`v_detalle_pedido_producto`**: Exponer el detalle de un pedido con el nombre del producto (ítems de pedido vigentes).

## Especificación detallada

### 1. v_productos_vigentes
- Columnas a exponer: `id_producto`, `producto_nombre` (alias de `producto.nombre`), `precio_lista`, `stock`, `id_categoria`, `categoria_nombre` (alias de `categoria.nombre`)
- Filtros de vigencia: `p.eliminado = FALSE` (productos vigentes). Se recomienda también considerar vigencia de categoría (`c.eliminado = FALSE`) si se quiere evitar mostrar productos de categorías eliminadas (opcional pero coherente).
- Seguridad: No expone datos sensibles.

### 2. v_pedidos_usuario
- Columnas a exponer: `id_pedido`, `fecha`, `total`, `id_usuario`, `usuario_nombre` (alias de `usuario.nombre`), `usuario_apellido` (alias de `usuario.apellido`)
- Filtro de vigencia: `p.eliminado = FALSE`
- Seguridad: Exponer únicamente datos necesarios del usuario. **No** debe exponerse ningún campo sensible (no existe `contraseña` en el esquema; tampoco se incluyen otros campos innecesarios).

### 3. v_detalle_pedido_producto
- Columnas a exponer: `id_pedido` (pedido al que pertenece el ítem), `id_detalle`, `producto_id`, `producto_nombre` (alias de `producto.nombre`), `cantidad`, `subtotal`
- Filtros de vigencia: `dp.eliminado = FALSE AND p.eliminado = FALSE AND pr.eliminado = FALSE`. Esto asegura que solo se muestren ítems vigentes de pedidos vigentes y productos vigentes.
- Seguridad: Vista orientada a reporte (solo datos operativos). No expone información sensible del usuario. Se cumple el principio de **mínima exposición** (solo lo necesario para el reporte).
- Justificación: Permite consultar el detalle completo de un pedido sin acceder directamente a las tablas base.

## Criterios de Aceptación
- Scripts idempotentes (`CREATE OR REPLACE VIEW`).
- Aplicar filtro de vigencia explícito en cada vista.
- Documentar la prueba de equivalencia con `EXCEPT` en ambos sentidos para cada vista.