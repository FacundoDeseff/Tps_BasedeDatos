# Requisitos de roles y permisos — Food Store

> **Planificación previa.** Este documento no incluye el script SQL: define
> requisitos verificables para la fase de implementación posterior.
> Apunta a una base **PostgreSQL 17** local de desarrollo llamada
> `copia_trabajo`, esquema `public`, dueño `postgres`.

---

## 1. Alcance y contexto

- **Motor:** PostgreSQL 17.
- **Base:** `copia_trabajo`, esquema `public`, dueño `postgres`.
- **Entorno:** solo base local de desarrollo. Nada se ejecuta contra
  producción ni contra servidores compartidos.
- **Estado inicial:** existe únicamente el rol `postgres`. No hay roles de
  aplicación ni funciones de autenticación. Todo parte de cero.
- **Extensión disponible:** `pgcrypto` (`crypt`, `gen_salt`).

### 1.1 Objetos del esquema (tal como están hoy)

**Tablas** (PK `identity`, todas con columna `eliminado` para baja lógica):

- `categoria(id_categoria, nombre UNIQUE, eliminado)`
- `producto(id_producto, nombre, precio_lista, stock, id_categoria FK, eliminado)`
- `usuario(id_usuario, nombre, apellido, eliminado)`
- `pedido(id_pedido, usuario_id FK, fecha, total, eliminado)`
- `detalle_pedido(id_detalle, pedido_id FK, producto_id FK, cantidad, subtotal, eliminado)`

**Vistas:** `v_productos_vigentes`, `v_pedidos_usuario`, `v_usuarios_seguros`
(id_usuario, nombre, apellido de usuarios no eliminados),
`v_detalle_pedido_producto`.

**Vista materializada:** `vm_facturacion_categoria_mes` (facturación agregada
por categoría y mes, sin datos personales).

**Funciones a (re)construir:** `fn_autenticar(text, text)` y
`fn_resetear_password(bigint, text)`. Hoy no existen. Para ellas, la tabla
`usuario` necesita columnas nuevas (ver RF-10).

## 2. Objetivos y no objetivos

**Objetivos**

- Definir un conjunto mínimo de roles y privilegios de mínimo privilegio.
- Proteger los datos personales de `usuario` mediante vistas y permisos a
  nivel de columna.
- Proveer una superficie de ataque controlada para autenticación y cambio de
  contraseña vía funciones.
- Garantizar que la identidad de la aplicación no pueda escalar a
  administradora.

**No objetivos**

- Escribir el script SQL (fase de implementación posterior).
- Implementar Row Level Security (RLS): se la menciona como alternativa, no es
  requerida por esta especificación.
- Cargar o tratar datos personales reales.
- Desplegar o tocar producción.

## 3. Glosario

- **Rol de BD (PostgreSQL):** rol del gestor, p. ej. `app_web`. Es lo que
  controla este documento.
- **Rol de aplicación:** valor de la columna `usuario.rol` (p. ej.
  `cliente`/`admin` de la app Food Store). Es autorización de la aplicación,
  **no** un rol de BD. No hay que confundirlos.
- **Mínimo privilegio:** cada rol recibe exactamente los privilegios necesarios
  para su función, ni uno más.
- **PII:** información personal identificable (nombre, apellido, email).

## 4. Requisitos funcionales

Las historias usan criterios de aceptación en estilo EARS
(`CUANDO… EL SISTEMA DEBERÁ…`, `SI… ENTONCES…`, etc.).

---

### RF-01 — Conjunto mínimo de roles

**Como** administrador de la base,
**quiero** un conjunto mínimo de roles de grupo y de login,
**para** aplicar mínimo privilegio sin inflar la matriz de permisos.

Criterios de aceptación:

- EL SISTEMA DEBERÁ definir los roles de grupo `NOLOGIN`:
  `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`.
- EL SISTEMA DEBERÁ definir los roles de login: `app_web`, `admin_datos`.
- SI se proponen roles adicionales, ENTONCES deberán justificarse; el conjunto
  base se mantiene en seis roles.
- NINGÚN rol de grupo deberá tener `LOGIN`, `SUPERUSER`, `CREATEDB` ni
  `CREATEROLE`.
- `app_web` deberá tener `LOGIN` e `INHERIT`, y `NOSUPERUSER`, `NOCREATEDB`,
  `NOCREATEROLE`.
- `admin_datos` deberá tener `LOGIN`, `INHERIT`, `CREATEDB`, `CREATEROLE` y
  `NOSUPERUSER` (es admin limitado, no superuser).

---

### RF-02 — rol_app_lectura (navegación del catálogo)

**Como** aplicación web,
**quiero** un rol de solo lectura sobre el catálogo,
**para** mostrar categorías y productos sin exponer datos personales ni
operaciones de escritura.

Criterios de aceptación:

- EL SISTEMA DEBERÁ otorgar `USAGE` sobre el esquema `public` a
  `rol_app_lectura`.
- EL SISTEMA DEBERÁ otorgar `SELECT` sobre `categoria` y `producto` a
  `rol_app_lectura`.
- EL SISTEMA DEBERÁ otorgar `SELECT` sobre la vista `v_productos_vigentes` a
  `rol_app_lectura`.
- EL SISTEMA NO DEBERÁ otorgar `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`,
  `REFERENCES` ni `TRIGGER` sobre ningún objeto a `rol_app_lectura`.
- EL SISTEMA NO DEBERÁ otorgar `SELECT` sobre `usuario`, `pedido`,
  `detalle_pedido`, `v_pedidos_usuario`, `v_usuarios_seguros` ni
  `v_detalle_pedido_producto` a `rol_app_lectura`.

---

### RF-03 — rol_app_escritura (registro de compras)

**Como** aplicación web,
**quiero** un rol que permita registrar pedidos y sus detalles,
**para** completar una compra sin poder editar, borrar ni leer pedidos ajenos.

Criterios de aceptación:

- EL SISTEMA DEBERÁ otorgar `USAGE` sobre `public` a `rol_app_escritura`.
- EL SISTEMA DEBERÁ otorgar `INSERT` sobre `pedido` y `detalle_pedido` a
  `rol_app_escritura`.
- EL SISTEMA DEBERÁ otorgar **a nivel de columna** `SELECT(id_pedido)` sobre
  `pedido` y `SELECT(id_detalle)` sobre `detalle_pedido` a
  `rol_app_escritura`, porque `INSERT ... RETURNING` exige `SELECT` sobre las
  columnas devueltas (ver design.md §4.2).
- EL SISTEMA DEBERÁ otorgar `USAGE, SELECT` sobre las secuencias asociadas a
  `pedido` y `detalle_pedido` a `rol_app_escritura`.
- EL SISTEMA NO DEBERÁ otorgar `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` ni
  `TRIGGER` sobre `pedido` ni `detalle_pedido` a `rol_app_escritura`.
- EL SISTEMA NO DEBERÁ otorgar `SELECT` sobre las tablas base `pedido` ni
  `detalle_pedido` **como tablas** a `rol_app_escritura`: solo `SELECT` a nivel
  de columna sobre las PK (`id_pedido`, `id_detalle`) para que `RETURNING`
  devuelva el ID generado, sin poder leer columnas de negocio ni pedidos ajenos.
- EL SISTEMA NO DEBERÁ otorgar acceso a `usuario`, `categoria` ni `producto`
  desde `rol_app_escritura` (el catálogo ya lo cubre `rol_app_lectura`, que
  `app_web` hereda).

---

### RF-04 — rol_soporte (atención de incidencias, permiso a nivel de columna)

**Como** agente de soporte,
**quiero** localizar usuarios y corregir su email o desbloquear su cuenta,
**para** resolver incidencias sin poder cambiar identidad, contraseña ni rol.

Criterios de aceptación:

- EL SISTEMA DEBERÁ otorgar `USAGE` sobre `public` a `rol_soporte`.
- EL SISTEMA DEBERÁ otorgar `SELECT` sobre `v_usuarios_seguros` a `rol_soporte`
  (localizar usuarios por nombre/apellido sin exponer `password_hash` ni
  `rol`).
- EL SISTEMA DEBERÁ otorgar `SELECT` sobre `v_pedidos_usuario` y
  `v_detalle_pedido_producto` a `rol_soporte` (ver qué usuario hizo qué pedido
  y el contenido de ese pedido).
- EL SISTEMA DEBERÁ otorgar **a nivel de columna** `UPDATE(email,
  intentos_fallidos)` sobre la tabla `usuario` a `rol_soporte`.
- EL SISTEMA DEBERÁ otorgar **a nivel de columna** `SELECT(id_usuario)` sobre
  `usuario` a `rol_soporte`, porque el `UPDATE ... WHERE id_usuario = ...`
  exige `SELECT` sobre la columna del `WHERE`.
- EL SISTEMA NO DEBERÁ otorgar `SELECT` sobre la tabla `usuario` completa a
  `rol_soporte` (debe leer por `v_usuarios_seguros`).
- EL SISTEMA NO DEBERÁ permitir `UPDATE` de `password_hash`, `rol`,
  `fecha_alta`, `nombre`, `apellido` ni `eliminado` a `rol_soporte`.

---

### RF-05 — rol_reportes (reportes sin datos personales)

**Como** analista,
**quiero** un rol de lectura para construir reportes de catálogo y facturación,
**para** generar agregados sin acceso a datos personales.

Criterios de aceptación:

- EL SISTEMA DEBERÁ otorgar `USAGE` sobre `public` a `rol_reportes`.
- EL SISTEMA DEBERÁ otorgar `SELECT` sobre `categoria`, `producto`,
  `v_productos_vigentes`, `v_detalle_pedido_producto` y
  `vm_facturacion_categoria_mes` a `rol_reportes`.
- EL SISTEMA NO DEBERÁ otorgar `SELECT` sobre `usuario`, `pedido`,
  `detalle_pedido`, `v_pedidos_usuario` ni `v_usuarios_seguros` a
  `rol_reportes`.
- EL SISTEMA NO DEBERÁ otorgar `INSERT`, `UPDATE`, `DELETE` ni `TRUNCATE` sobre
  ningún objeto a `rol_reportes`.
- EL SISTEMA NO DEBERÁ permitir que `rol_reportes` ejecute
  `REFRESH MATERIALIZED VIEW` sobre `vm_facturacion_categoria_mes` (el refresh
  es tarea de `admin_datos`).

---

### RF-06 — app_web (identidad de la aplicación)

**Como** aplicación web,
**quiero** una identidad de conexión que combine lectura y escritura,
**para** navegar el catálogo, registrar pedidos y autenticar usuarios.

Criterios de aceptación:

- EL SISTEMA DEBERÁ hacer `app_web` miembro de `rol_app_lectura` y
  `rol_app_escritura` (con `INHERIT`, sin necesidad de `SET ROLE`).
- EL SISTEMA DEBERÁ otorgar `EXECUTE` sobre `fn_autenticar(text, text)` a
  `app_web`.
- EL SISTEMA NO DEBERÁ otorgar `CREATEROLE`, `CREATEDB` ni `SUPERUSER` a
  `app_web`.
- EL SISTEMA NO DEBERÁ hacer `app_web` miembro de `admin_datos` (ver RF-12).
- EL SISTEMA NO DEBERÁ otorgar `EXECUTE` sobre `fn_resetear_password` a
  `app_web`.

---

### RF-07 — admin_datos (administración)

**Como** administrador de datos,
**quiero** una identidad separada para mantenimiento y gestión de usuarios,
**para** administrar la base sin exponer esa capacidad a la aplicación.

Criterios de aceptación:

- EL SISTEMA DEBERÁ dar a `admin_datos` los atributos `CREATEDB` y
  `CREATEROLE`, con `NOSUPERUSER`.
- EL SISTEMA DEBERÁ otorgar `CREATE, USAGE` sobre el esquema `public` a
  `admin_datos`.
- EL SISTEMA DEBERÁ otorgar sobre `categoria`, `producto`, `pedido` y
  `detalle_pedido` los privilegios `SELECT, INSERT, UPDATE, DELETE, TRUNCATE,
  REFERENCES, TRIGGER` **enumerados** (no `GRANT ALL`).
- EL SISTEMA DEBERÁ otorgar sobre `usuario` los privilegios `SELECT, INSERT,
  DELETE` y `UPDATE` sobre todas sus columnas **excepto `password_hash` y la
  PK `id_usuario`** (la PK no se actualiza).
- EL SISTEMA DEBERÁ otorgar `EXECUTE` sobre `fn_resetear_password(bigint, text)`
  a `admin_datos`.
- EL SISTEMA DEBERÁ permitir que `admin_datos` ejecute
  `REFRESH MATERIALIZED VIEW vm_facturacion_categoria_mes`.
- EL SISTEMA NO DEBERÁ permitir que `admin_datos` actualice `password_hash`
  directamente: el cambio de contraseña debe ir por `fn_resetear_password`
  (ver design.md §6.2).
- EL SISTEMA NO DEBERÁ otorgar `EXECUTE` sobre `fn_autenticar` a
  `admin_datos` (separación de funciones; ver design.md §6).

---

### RF-08 — fn_autenticar (autenticación de la app)

**Como** aplicación web,
**quiero** una función que valide email/contraseña y devuelva el rol de app,
**para** autenticar sin exponer la columna `password_hash`.

Criterios de aceptación:

- EL SISTEMA DEBERÁ (re)construir `fn_autenticar(p_email text, p_password text)`
  con `SECURITY DEFINER`, dueño `postgres`, y `search_path` fijado a
  `public, pg_temp` (evitar inyección por `search_path`).
- LA FUNCIÓN deberá comparar `crypt(p_password, password_hash) = password_hash`
  para el usuario no eliminado con ese `email`.
- LA FUNCIÓN deberá incrementar `intentos_fallidos` ante un intento fallido y,
  al alcanzar el umbral (p. ej. 5), devolver un estado de cuenta bloqueada.
- LA FUNCIÓN deberá reiniciar `intentos_fallidos` a 0 ante un login exitoso.
- LA FUNCIÓN no deberá revelar si el email existe (mismo resultado para
  "email inexistente" y "password incorrecta").
- EL DOCUMENTO DEBERÁ registrar el riesgo de bloqueo de cuentas ajenas por
  intentos fallidos, porque el mecanismo de `intentos_fallidos` permite a un
  atacante que conoce un `email` bloquear la cuenta de la víctima (ver
  design.md §11).
- EL SISTEMA DEBERÁ ejecutar `REVOKE EXECUTE ON FUNCTION fn_autenticar(text,
  text) FROM PUBLIC;` y luego `GRANT EXECUTE ON FUNCTION fn_autenticar(text,
  text) TO app_web;`.
- SI la función usa SQL dinámico, ENTONCES usará parámetros (`USING`) y no
  concatenación de texto.

---

### RF-09 — fn_resetear_password (cambio de contraseña por admin)

**Como** administrador de datos,
**quiero** una función que cambie la contraseña con hasheo correcto,
**para** forzar `bcrypt` y evitar hashes débiles o en claro.

Criterios de aceptación:

- EL SISTEMA DEBERÁ (re)construir
  `fn_resetear_password(p_id_usuario bigint, p_nueva_password text)` con
  `SECURITY DEFINER`, dueño `postgres`, `search_path` fijado.
- LA FUNCIÓN deberá calcular
  `password_hash := crypt(p_nueva_password, gen_salt('bf', 8))` y actualizar
  `password_hash`, además de `intentos_fallidos := 0`.
- LA FUNCIÓN no deberá aplicar el cambio si el usuario está `eliminado`.
- LA FUNCIÓN no deberá registrar la contraseña en claro en ningún log.
- EL SISTEMA DEBERÁ ejecutar `REVOKE EXECUTE ON FUNCTION
  fn_resetear_password(bigint, text) FROM PUBLIC;` y luego `GRANT EXECUTE ON
  FUNCTION fn_resetear_password(bigint, text) TO admin_datos;`.

---

### RF-10 — Nuevas columnas en `usuario`

**Como** administrador,
**quiero** que `usuario` tenga email, hash de password, rol de app, fecha de
alta e intentos fallidos,
**para** soportar autenticación y bloqueo de cuentas.

Criterios de aceptación:

- EL SISTEMA DEBERÁ agregar a `usuario` las columnas: `email` (UNIQUE, not null
  para usuarios activos), `password_hash` text, `rol` text (rol de aplicación,
  p. ej. `cliente`, default `cliente`), `fecha_alta` timestamptz, y
  `intentos_fallidos` int default 0.
- EL SISTEMA DEBERÁ asegurar que ningún rol de aplicación tenga `SELECT` ni
  `UPDATE` directo sobre `password_hash` (solo las funciones `SECURITY
  DEFINER`).
- La agregación de columnas es parte de la fase de implementación, no de este
  documento de requisitos.

---

### RF-11 — ALTER DEFAULT PRIVILEGES (política para tablas futuras)

**Como** administrador,
**quiero** que las tablas futuras hereden la política mínima,
**para** no tener que acordarme de aplicar permisos en cada objeto nuevo.

Criterios de aceptación:

- EL SISTEMA DEBERÁ configurar `ALTER DEFAULT PRIVILEGES` para el propietario
  que cree objetos futuros, en el esquema `public`.
- LOS DEFAULTS deberán partir de `REVOKE ALL` sobre tablas, secuencias y
  funciones para los roles de aplicación y para `PUBLIC`.
- LOS DEFAULTS **no** deberán otorgar `SELECT` por defecto a `rol_app_lectura`
  ni a `rol_reportes`, ni `INSERT` por defecto a `rol_app_escritura`, sobre
  tablas.
- EL ÚNICO otorgamiento por defecto sobre objetos será `USAGE, SELECT` en
  secuencias a `rol_app_escritura`.
- EL SISTEMA DEBERÁ agregar, como default, `REVOKE EXECUTE ON FUNCTIONS FROM
  PUBLIC`, de modo que las funciones futuras no sean ejecutables por `PUBLIC`
  hasta un `GRANT EXECUTE` explícito.
- LOS DEFAULTS NO deberán incluir `UPDATE`, `DELETE`, `TRUNCATE`,
  `REFERENCES` ni `TRIGGER` para ningún rol de aplicación.
- `rol_soporte` y `admin_datos` NO deberán aparecer en los defaults de tablas
  ni de funciones.
- EL DOCUMENTO DEBERÁ advertir que, al no haber defaults de tablas, cada tabla
  nueva nace sin acceso para los roles de aplicación y requiere grant manual
  conforme a la matriz; y que el default de secuencias y el `REVOKE EXECUTE`
  residual se documentan en design.md §8.1.

---

### RF-12 — No escalamiento app_web → admin_datos

**Como** administrador de seguridad,
**quiero** que la app no pueda escalar a administradora,
**para** contener un eventual compromiso de la credencial `app_web`.

Criterios de aceptación:

- EL SISTEMA DEBERÁ ejecutar `REVOKE admin_datos FROM app_web;`.
- CUANDO un usuario conectado como `app_web` ejecute
  `GRANT admin_datos TO app_web;`, EL SISTEMA DEBERÁ rechazar la sentencia con
  error de permisos (porque `app_web` no es miembro de `admin_datos` con
  `ADMIN OPTION` ni tiene `CREATEROLE`).
- EL SISTEMA NO DEBERÁ dar `CREATEROLE` ni `CREATEDB` a `app_web`.
- EL SISTEMA DEBERÁ proveer forma de verificar lo anterior (ver RF-14 y
  design.md §9).

---

### RF-13 — Contraseñas fuera del repositorio

**Como** administrador de seguridad,
**quiero** que ninguna contraseña quede en el repositorio,
**para** evitar exposición de credenciales.

Criterios de aceptación:

- EL SCRIPT (cuando exista) NO deberá contener contraseñas literales de los
  roles `app_web` ni `admin_datos`.
- LAS CONTRASEÑAS deberán definirse fuera de banda (p. ej. `\password` en
  psql, o `ALTER ROLE ... PASSWORD` leyendo de una variable de entorno/secret
  manager).
- ESTE DOCUMENTO no contiene contraseñas ni datos personales reales.

---

### RF-14 — Verificabilidad

**Como** administrador,
**quiero** comprobar que cada rol tiene exactamente lo previsto,
**para** auditar la matriz de permisos.

Criterios de aceptación:

- EL SISTEMA DEBERÁ poder verificarse con `\du` (roles, atributos y
  membresías) y con `information_schema.role_table_grants` (privilegios por
  tabla y rol).
- LA VERIFICACIÓN de permisos a nivel de columna deberá usar
  `information_schema.column_privileges`: para `rol_soporte` el
  `UPDATE(email, intentos_fallidos)` y `SELECT(id_usuario)` sobre `usuario`;
  para `rol_app_escritura` el `SELECT(id_pedido)` sobre `pedido` y
  `SELECT(id_detalle)` sobre `detalle_pedido`.
- LA VERIFICACIÓN de `EXECUTE` en funciones deberá usar
  `information_schema.role_routine_grants`.
- LA VERIFICACIÓN de membresía/escalamiento deberá usar `pg_auth_members` y
  `pg_roles` (atributos `rolsuper`, `rolcreatedb`, `rolcreaterole`,
  `rolinherit`).
- LA VERIFICACIÓN de defaults deberá usar `pg_default_acl`.
- LA SALIDA de cada consulta de verificación deberá coincidir exactamente con
  la matriz de `design.md`, ni más ni menos.

---

## 5. Restricciones (no funcionales)

- **R1 — Mínimo privilegio:** prohibido `GRANT ALL`; todo privilegio se
  enumera puntualmente.
- **R2 — Permiso a nivel de columna:** al menos uno (cumplido por RF-03 y
  RF-04: `SELECT(id_pedido)`/`SELECT(id_detalle)` en `rol_app_escritura` y
  `UPDATE(email, intentos_fallidos)` + `SELECT(id_usuario)` en `rol_soporte`).
- **R3 — Preferir vistas para PII:** acceso a datos personales va por
  `v_usuarios_seguros` y `vm_facturacion_categoria_mes`, no por tablas base.
- **R4 — Funciones y PUBLIC:** toda función nueva se le hace `REVOKE EXECUTE
  FROM PUBLIC` y `GRANT EXECUTE` puntual. `fn_autenticar` → `app_web`;
  `fn_resetear_password` → `admin_datos`.
- **R5 — No escalamiento:** `app_web` sin `CREATEROLE`/`CREATEDB`/`SUPERUSER` y
  no miembro de `admin_datos`.
- **R6 — Sin datos personales reales:** solo placeholders ficticios.
- **R7 — Solo entorno local de desarrollo.**
- **R8 — Sin contraseñas en el repositorio** (RF-13).

## 6. Criterios de aceptación globales

La especificación se considera satisfecha cuando:

1. Existen exactamente los seis roles definidos (o más, con justificación) y
   ninguno de grupo tiene `LOGIN`/`SUPERUSER`/`CREATEDB`/`CREATEROLE`.
2. La matriz de `design.md` cubre, para cada rol, sus objetos y privilegios, y
   cada privilegio está enumerado (sin `GRANT ALL`).
3. Existe al menos un permiso a nivel de columna.
4. Los defaults están definidos con la advertencia de amplitud documentada.
5. Las dos funciones tienen `REVOKE ... FROM PUBLIC` y `GRANT EXECUTE` puntual.
6. Se documenta cómo verificar que `GRANT admin_datos TO app_web` falla.
7. Se documentan las consultas de verificación (`\du`,
   `role_table_grants`, `column_privileges`, `role_routine_grants`,
   `pg_auth_members`, `pg_default_acl`).
