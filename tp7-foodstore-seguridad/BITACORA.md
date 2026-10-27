# Bitácora de uso de IA

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Diseñar roles Food Store con mínimo privilegio y permiso de columna. | Propuso roles de grupo, dos cuentas de login, permisos puntuales y `ALTER DEFAULT PRIVILEGES`. | Se rechazó cualquier `GRANT ALL`; se conservaron sólo operaciones justificadas y se verificará con `\du` e `information_schema`. |
| Generar una secuencia de auditoría nativa con lectura, inserción, actualización y login fallido. | Indicó `log_connections`, `log_disconnections` y `log_statement = 'mod'`. | Se distinguió el login del servidor de una función que devuelve falso y se evitó guardar contraseñas. |
| Reconstruir el simulacro de incidente y proponer contención. | Identificó fallos de autenticación, lectura masiva y un intento de escalamiento. | Se corrigió toda afirmación sobre intención, causa o identidad humana que el log no puede probar; la contención queda a decisión del equipo. |
| Crear `usuario_anon` y una consulta equivalente sobre datos reales. | Propuso reemplazos deterministas y comparación por grupos. | Se verificó que no se copien PII y que los conteos se comparen con un `FULL JOIN`. |

## Error significativo detectado

Una propuesta inicial de permisos amplia habría habilitado `GRANT ALL` sobre las
tablas operativas. El equipo la detectó al contrastarla con la matriz de Kiro:
permitía borrado y actualización general, operaciones que no son necesarias
para la aplicación. Se reemplazó por `INSERT` puntual, lectura de catálogos y
actualización sólo de columnas de soporte.

## Git y validación

La ejecución final debe registrar un commit por parte del TP (A roles, B
auditoría, C incidente y D anonimización). Antes de entregar se deben adjuntar
las salidas de `\du`, `information_schema.role_table_grants`, los logs
anonimizados y los resultados de equivalencia. Ningún log con datos reales ni
contraseña debe ingresar al repositorio.

## Prompt para specs y design de roles y permisos (Kiro)
"Necesito una especificación (requirements + design) de roles y permisos de
MÍNIMO PRIVILEGIO para una base PostgreSQL 17 llamada "Food Store". Todo se
ejecuta solo sobre mi base local de desarrollo. Esta especificación es
planificación previa: todavía no hay que escribir el script SQL.

## Esquema real (schema public, dueño: postgres)
- categoria(id_categoria PK identity, nombre UNIQUE, eliminado)
- producto(id_producto PK identity, nombre, precio_lista, stock,
  id_categoria FK, eliminado)
- usuario(id_usuario PK identity, nombre, apellido, eliminado)
- pedido(id_pedido PK identity, usuario_id FK, fecha, total, eliminado)
- detalle_pedido(id_detalle PK identity, pedido_id FK, producto_id FK,
  cantidad, subtotal, eliminado)
- Vistas: v_productos_vigentes, v_pedidos_usuario, v_usuarios_seguros
  (id_usuario, nombre, apellido de usuarios no eliminados),
  v_detalle_pedido_producto
- Vista materializada: vm_facturacion_categoria_mes (facturación agregada
  por categoría y mes, sin datos personales)
- No existen todavía fn_autenticar ni fn_resetear_password. Hay que
  incluirlas como funciones a reconstruir (usar pgcrypto, que está
  disponible). Para ellas, la tabla usuario necesitaría columnas nuevas:
  email, password_hash, rol, fecha_alta, intentos_fallidos.
- Hoy solo existe el rol "postgres". Todo parte de cero.

## Roles requeridos (mínimo)
Roles de grupo (NOLOGIN): rol_app_lectura, rol_app_escritura, rol_soporte,
rol_reportes.
Roles de login: app_web (la aplicación) y admin_datos (administración).
Podés proponer roles adicionales si los justificás.

## Qué debe incluir cada rol
Para CADA rol: una oración que diga qué operación habilita y POR QUÉ esa
operación y no otra. Después, una matriz rol × objeto × privilegio.

## Requisitos obligatorios
1. Principio de mínimo privilegio: prohibido GRANT ALL; privilegios puntuales.
2. Al menos un permiso A NIVEL DE COLUMNA (por ejemplo UPDATE sobre columnas
   de contacto/estado de usuario para rol_soporte).
3. ALTER DEFAULT PRIVILEGES para que las tablas futuras hereden la política.
   Advertí el riesgo de que un default demasiado amplio contradiga la matriz.
4. Preferir vistas (v_usuarios_seguros, vm_facturacion_categoria_mes) en
   lugar de acceso a tablas con datos personales cuando sea posible.
5. Las funciones tienen EXECUTE para PUBLIC por defecto: especificar
   REVOKE ... FROM PUBLIC y GRANT EXECUTE puntual. fn_autenticar solo para
   app_web; fn_resetear_password solo para admin_datos.
6. app_web NO debe ser superusuario ni tener CREATEROLE/CREATEDB, ni ser
   miembro de admin_datos. Un intento de "GRANT admin_datos TO app_web"
   ejecutado como app_web debe FALLAR; incluir cómo se verifica.
7. Las contraseñas no van en el repositorio.
8. Verificabilidad: cómo comprobar con \du y con
   information_schema.role_table_grants que cada rol tiene exactamente lo
   previsto, ni más ni menos.

## Formato
- requirements.md: historias o requisitos con criterios de aceptación
  verificables (formato EARS si lo usás).
- design.md: matriz de permisos, decisiones de diseño y por qué se
  descartaron alternativas (por ejemplo GRANT ALL, permisos sobre el
  esquema entero), riesgos y plan de verificación.
- Escribí en español rioplatense, sin datos personales reales."

## Correcciones a la creación de design.md y requirements.md
"Revisá la spec con estas correcciones, manteniendo el resto:
1. INSERT ... RETURNING requiere privilegio SELECT sobre las columnas devueltas.
   Corregí RF-03 y design §3/§4.2: otorgá SELECT(id_pedido) en pedido y
   SELECT(id_detalle) en detalle_pedido a rol_app_escritura, a nivel de
   columna, y quitá la afirmación de que RETURNING no necesita SELECT.
2. SELECT(id_usuario) para rol_soporte no es condicional: un UPDATE con WHERE
   sobre esa columna lo requiere. Dejalo como requisito firme.
3. ALTER DEFAULT PRIVILEGES: quitá el GRANT SELECT por defecto a
   rol_app_lectura y rol_reportes, y el INSERT por defecto a rol_app_escritura.
   Dejá solo USAGE,SELECT en secuencias, y agregá
   REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC por defecto.
4. La base se llama copia_trabajo. fn_resetear_password recibe bigint, no int.
5. Quitá la afirmación sobre comparación en tiempo constante de crypt y
   agregá el riesgo de bloqueo de cuentas ajenas por intentos fallidos."