# spec: vistas_reportes_foodstore

## Objetivo
Crear vistas para simplificar el acceso a reportes y aplicar criterios de seguridad sobre datos sensibles.

## Vistas a definir
1. **`v_productos_vigentes`**: Exponer productos activos (`eliminado = FALSE`) con el nombre de su categoría.
2. **`v_pedidos_usuario`**: Exponer pedidos con los datos del usuario asociado.
3. **`v_usuarios_seguros`**: Exponer datos de usuario OCULTANDO la columna `contraseña` (criterio de seguridad).

## Criterios de Aceptación
- Scripts idempotentes (`CREATE OR REPLACE VIEW`).
- Exclusión explícita del campo contraseña en la vista de usuarios.
- Documentar la prueba de equivalencia con `EXCEPT` en ambos sentidos.