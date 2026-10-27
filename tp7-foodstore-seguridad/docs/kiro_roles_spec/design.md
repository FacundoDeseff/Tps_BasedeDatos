# Diseño de roles y permisos — Food Store

> Diseño que acompaña a `requirements.md`. Cubre la matriz de permisos
> rol×objeto×privilegio, las decisiones de diseño, las alternativas descartadas,
> los riesgos y el plan de verificación. **No es el script SQL** (fase de
> implementación posterior). Base `copia_trabajo` (**PostgreSQL 17**), esquema
> `public`, dueño `postgres`.

---

## 1. Decisiones de alto nivel

1. **Roles de grupo `NOLOGIN` + roles de login `INHERIT`.** La app (`app_web`)
   hereda los privilegios de sus grupos (`rol_app_lectura`,
   `rol_app_escritura`) directamente, sin `SET ROLE`. Los grupos nunca inician
   sesión.
2. **`app_web` no es admin.** No tiene `CREATEROLE`/`CREATEDB`/`SUPERUSER` y no
   es miembro de `admin_datos`. Por eso no puede otorgar roles (RF-12).
3. **`admin_datos` es admin limitado, no superuser.** Tiene `CREATEDB` y
   `CREATEROLE` pero `NOSUPERUSER`: puede gestionar roles y bases sin ser
   omnipotente.
4. **Las contraseñas viven solo en `password_hash`.** Ningún rol de aplicación
   tiene `SELECT` ni `UPDATE` sobre esa columna; solo las funciones
   `SECURITY DEFINER` (dueño `postgres`) la leen/escriben.
5. **PII por vistas.** Los datos personales (`usuario`) se leen por
   `v_usuarios_seguros` (soporte/admin) y nunca por la app ni por reportes. La
   facturación agregada se consume por `vm_facturacion_categoria_mes` (sin PII).
6. **Permisos a nivel de columna.** `rol_soporte` recibe `UPDATE(email,
   intentos_fallidos)` y `SELECT(id_usuario)` sobre `usuario`;
   `rol_app_escritura` recibe `SELECT(id_pedido)` y `SELECT(id_detalle)` para
   que `RETURNING` devuelva los IDs. Ninguno recibe `UPDATE`/`SELECT` sobre la
   tabla entera.
7. **Sin `GRANT ALL`.** Todos los privilegios se enumeran, incluso para
   `admin_datos`.
8. **Defaults mínimos, sin grants de tablas por defecto.** `ALTER DEFAULT
   PRIVILEGES` parte de `REVOKE ALL` y **no** otorga `SELECT`/`INSERT` sobre
   tablas a ningún rol; solo `USAGE, SELECT` en secuencias a
   `rol_app_escritura` y `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`. Las tablas
   nuevas nacen sin acceso a los roles de aplicación y se otorgan a mano
   conforme a la matriz (ver §8.1).

---

## 2. Roles

| Rol | Tipo | Atributos | Miembro de |
|---|---|---|---|
| `rol_app_lectura` | grupo | `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE` | — |
| `rol_app_escritura` | grupo | `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE` | — |
| `rol_soporte` | grupo | `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE` | — |
| `rol_reportes` | grupo | `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE` | — |
| `app_web` | login | `LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE` | `rol_app_lectura`, `rol_app_escritura` |
| `admin_datos` | login | `LOGIN INHERIT NOSUPERUSER CREATEDB CREATEROLE` | — |

Notas:
- `app_web` recibe `REVOKE admin_datos FROM app_web;` para que no haya herencia
  accidental.
- Los grupos se declaran `NOINHERIT` (irrelevante para `NOLOGIN`, pero explícito
  y seguro); `app_web` y `admin_datos` son `INHERIT`.

---

## 3. Justificación por rol (una oración)

> Para cada rol: qué habilita y por qué esa operación y no otra.

- **`rol_app_lectura`** habilita a navegar el catálogo público (categorías,
  productos y `v_productos_vigentes`), y no escritura ni PII porque un navegador
  solo necesita mostrar el catálogo y exponer más ampliaría la superficie.
- **`rol_app_escritura`** habilita a registrar una compra (`INSERT` en `pedido`
  y `detalle_pedido`, uso de sus secuencias y `SELECT` a nivel de columna sobre
  `id_pedido`/`id_detalle` para que `RETURNING` devuelva el ID generado), y no
  `UPDATE`/`DELETE` ni `SELECT` sobre el resto de las columnas porque el pedido
  es inmutable desde la app y no debe poder leer pedidos ajenos.
- **`rol_soporte`** habilita a atender incidencias de cuentas (corregir
  `email` y reiniciar `intentos_fallidos`, a nivel de columna, y localizar el
  usuario con `SELECT(id_usuario)`) y a ver qué usuario hizo qué pedido, y no
  `SELECT`/`UPDATE` sobre el resto de las columnas de `usuario` porque no debe
  tocar identidad, `password_hash`, `rol`, `fecha_alta` ni `eliminado`.
- **`rol_reportes`** habilita a construir reportes de catálogo y facturación
  sin PII (`categoria`, `producto`, `v_productos_vigentes`,
  `v_detalle_pedido_producto`, `vm_facturacion_categoria_mes`), y no acceso a
  `usuario`/`pedido`/`detalle_pedido` base ni a las vistas con PII porque los
  agregados no requieren datos personales.
- **`app_web`** habilita a la app a navegar, registrar pedidos y autenticar
  (hereda `rol_app_lectura` + `rol_app_escritura` y ejecuta `fn_autenticar`),
  y no `CREATEROLE`/`CREATEDB`/`SUPERUSER` ni miembro de `admin_datos` porque no
  debe poder crear roles ni escalar a admin.
- **`admin_datos`** habilita la administración de datos y usuarios (DDL sobre
  `public`, DML enumerado sobre las tablas, `EXECUTE` de
  `fn_resetear_password` y `REFRESH` de la materializada), y no
  `SUPERUSER` ni `UPDATE` directo sobre `password_hash` porque el cambio de
  contraseña debe forzar el hasheo vía función.

---

## 4. Matriz de permisos (rol × objeto × privilegio)

> T: tabla · V: vista · VM: vista materializada · S: secuencia · F: función ·
> SC: esquema. Los privilegios se enumeran; no hay `GRANT ALL` en ningún rol.

### 4.1 `rol_app_lectura`

| Objeto | Tipo | Privilegio |
|---|---|---|
| `public` | SC | `USAGE` |
| `categoria` | T | `SELECT` |
| `producto` | T | `SELECT` |
| `v_productos_vigentes` | V | `SELECT` |

### 4.2 `rol_app_escritura`

| Objeto | Tipo | Privilegio | Notas |
|---|---|---|---|
| `public` | SC | `USAGE` | |
| `pedido` | T | `INSERT` | |
| `detalle_pedido` | T | `INSERT` | |
| `pedido` | T | `SELECT(id_pedido)` | **a nivel de columna**; `INSERT ... RETURNING` exige `SELECT` sobre las columnas devueltas |
| `detalle_pedido` | T | `SELECT(id_detalle)` | **a nivel de columna**; ídem |
| secuencias de `pedido`, `detalle_pedido` | S | `USAGE, SELECT` | |

> Nota: `INSERT ... RETURNING` requiere `SELECT` sobre las columnas que
> devuelve, por eso se otorga `SELECT(id_pedido)` y `SELECT(id_detalle)` a
> nivel de columna, no sobre la tabla entera. Así la app recupera el ID
> generado sin poder leer columnas de negocio ni pedidos ajenos.

### 4.3 `rol_soporte`

| Objeto | Tipo | Privilegio | Notas |
|---|---|---|---|
| `public` | SC | `USAGE` | |
| `v_usuarios_seguros` | V | `SELECT` | localizar usuario sin PII sensible |
| `v_pedidos_usuario` | V | `SELECT` | ver pedido + nombre del usuario |
| `v_detalle_pedido_producto` | V | `SELECT` | ver contenido de un pedido |
| `usuario` | T | `UPDATE(email, intentos_fallidos)` | **a nivel de columna** |
| `usuario` | T | `SELECT(id_usuario)` | **a nivel de columna**; el `UPDATE ... WHERE id_usuario = ...` exige `SELECT` sobre la columna del `WHERE` |

### 4.4 `rol_reportes`

| Objeto | Tipo | Privilegio |
|---|---|---|
| `public` | SC | `USAGE` |
| `categoria` | T | `SELECT` |
| `producto` | T | `SELECT` |
| `v_productos_vigentes` | V | `SELECT` |
| `v_detalle_pedido_producto` | V | `SELECT` |
| `vm_facturacion_categoria_mes` | VM | `SELECT` (sin `REFRESH`) |

### 4.5 `app_web` (login)

| Objeto | Tipo | Privilegio |
|---|---|---|
| (hereda) | — | privilegios de `rol_app_lectura` + `rol_app_escritura` (vía `INHERIT`) |
| `fn_autenticar(text, text)` | F | `EXECUTE` |

### 4.6 `admin_datos` (login)

| Objeto | Tipo | Privilegio |
|---|---|---|
| `public` | SC | `CREATE, USAGE` |
| `categoria`, `producto`, `pedido`, `detalle_pedido` | T | `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER` (enumerados) |
| `usuario` | T | `SELECT, INSERT, DELETE` |
| `usuario` | T | `UPDATE(nombre, apellido, email, rol, fecha_alta, intentos_fallidos, eliminado)` (todas menos `password_hash` y la PK `id_usuario`) |
| secuencias (todas) | S | `USAGE, SELECT, UPDATE` |
| `v_productos_vigentes`, `v_pedidos_usuario`, `v_usuarios_seguros`, `v_detalle_pedido_producto` | V | `SELECT` |
| `vm_facturacion_categoria_mes` | VM | `SELECT` + `REFRESH` |
| `fn_resetear_password(bigint, text)` | F | `EXECUTE` |

Atributos: `CREATEDB`, `CREATEROLE`, `NOSUPERUSER`, `INHERIT`.

---

## 5. Semántica asumida de vistas y materializada

> El enunciado solo describió `v_usuarios_seguros` y
> `vm_facturacion_categoria_mes`. Las demás se asumen como sigue; confirmar
> sus definiciones reales en la implementación.

| Objeto | Definición asumida | PII | Acceso |
|---|---|---|---|
| `v_productos_vigentes` | `producto` JOIN `categoria` WHERE `producto.eliminado = false` | No | lectura, reportes |
| `v_detalle_pedido_producto` | `detalle_pedido` JOIN `producto` (líneas + datos de producto) | No (sin `usuario`) | soporte, reportes |
| `v_pedidos_usuario` | `pedido` JOIN `usuario` (pedido + nombre/apellido del usuario) | **Sí** | soporte, admin |
| `v_usuarios_seguros` | `id_usuario, nombre, apellido` WHERE `eliminado = false` | **Sí** (nombre/apellido) | soporte, admin |
| `vm_facturacion_categoria_mes` | facturación agregada por categoría y mes | No | reportes (y `REFRESH` por admin) |

Decisión: a la app (`rol_app_*`) y a `rol_reportes` se les niega toda vista con
PII. A `rol_soporte` se le da `SELECT` sobre las vistas con PII porque su
función es atender incidencias de cuentas y pedidos, pero **no** sobre la tabla
`usuario` completa (solo `SELECT(id_usuario)` y `UPDATE` por columnas).

---

## 6. Funciones de autenticación

### 6.1 `fn_autenticar(p_email text, p_password text)`

- `SECURITY DEFINER`, dueño `postgres`, `search_path = public` (fijado).
- Lee `usuario` (filtrando `eliminado = false`) por `email`; compara
  `crypt(p_password, password_hash) = password_hash`.
- Éxito: `intentos_fallidos := 0`; devuelve el `rol` de aplicación (y datos
  mínimos no sensibles) para que la app autorice la UI.
- Fallo: `intentos_fallidos := intentos_fallidos + 1`; al llegar al umbral
  (p. ej. 5) devuelve "cuenta bloqueada".
- No distingue "email inexistente" de "password incorrecta".
- SQL: siempre parametrizado (`$1`, `$2` con `USING` si usa dinámico).
- Permisos:
  - `REVOKE EXECUTE ON FUNCTION fn_autenticar(text, text) FROM PUBLIC;`
  - `GRANT EXECUTE ON FUNCTION fn_autenticar(text, text) TO app_web;`
- Por qué `SECURITY DEFINER`: `app_web` no tiene `SELECT` sobre
  `password_hash`; la función es la **única** puerta controlada a esa
  columna. Las funciones de `pgcrypto` (`crypt`, `gen_salt`) las ejecuta el
  definer (`postgres`), no el caller, así que no se conceden a `app_web`.

### 6.2 `fn_resetear_password(p_id_usuario bigint, p_nueva_password text)`

- `SECURITY DEFINER`, dueño `postgres`, `search_path = public` (fijado).
- Calcula `password_hash := crypt(p_nueva_password, gen_salt('bf', 8))`,
  actualiza `password_hash` y `intentos_fallidos := 0` donde
  `id_usuario = p_id_usuario AND eliminado = false`.
- No registra la contraseña en claro.
- Permisos:
  - `REVOKE EXECUTE ON FUNCTION fn_resetear_password(bigint, text) FROM PUBLIC;`
  - `GRANT EXECUTE ON FUNCTION fn_resetear_password(bigint, text) TO admin_datos;`
- Por qué solo la función escribe `password_hash`: `admin_datos` **no** recibe
  `UPDATE(password_hash)` directo, así que el hasheo siempre pasa por la
  función y no se puede bypassar con un hash débil o en claro.

### 6.3 Sobre `REVOKE ... FROM PUBLIC`

PostgreSQL concede `EXECUTE` a `PUBLIC` por defecto en las funciones. Por eso
**ambas** funciones arrancan con `REVOKE ... FROM PUBLIC` y luego `GRANT
EXECUTE` puntual al rol correspondiente. Esto vale para cualquier función nueva
que se agregue, y se refuerza con el default `REVOKE EXECUTE ON FUNCTIONS FROM
PUBLIC` (ver §8).

---

## 7. Nuevas columnas en `usuario`

| Columna | Tipo | Notas |
|---|---|---|
| `email` | text | `UNIQUE`; not null para usuarios activos; sirve de login |
| `password_hash` | text | solo leído/escrito por las funciones `SECURITY DEFINER` |
| `rol` | text | rol **de aplicación** (`cliente`/`admin`), default `cliente`; no es un rol de BD |
| `fecha_alta` | timestamptz | auditoría; no editable por `rol_soporte` |
| `intentos_fallidos` | int | default 0; lo reinicia `fn_autenticar` (éxito) y `fn_resetear_password` |

La creación de columnas es implementación. Lo relevante para este diseño:
ningún rol de aplicación recibe `SELECT` ni `UPDATE` sobre `password_hash`;
`rol` y `fecha_alta` tampoco son editables por `rol_soporte`.

---

## 8. ALTER DEFAULT PRIVILEGES

Para que los objetos futuros hereden la política mínima, se configuran defaults
para el propietario que crea objetos, en `public`. Diseño:

- `REVOKE ALL ON TABLES FROM PUBLIC, rol_app_lectura, rol_app_escritura,
  rol_soporte, rol_reportes;` (punto de partida limpio; **no** se otorgan
  `SELECT`/`INSERT` sobre tablas por defecto).
- `REVOKE ALL ON SEQUENCES FROM PUBLIC, rol_app_lectura, rol_app_escritura,
  rol_soporte, rol_reportes;`
- `GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;` (único otorgamiento
  por defecto sobre objetos).
- `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;` (las funciones futuras no son
  ejecutables por `PUBLIC` hasta un `GRANT EXECUTE` explícito).
- **No** se otorga `SELECT` por defecto a `rol_app_lectura` ni a `rol_reportes`,
  ni `INSERT` por defecto a `rol_app_escritura`, sobre tablas: las tablas nuevas
  nacen sin acceso a los roles de aplicación y se otorgan a mano conforme a la
  matriz.
- **No** se incluyen `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES` ni `TRIGGER`
  en ningún default.
- **No** se incluye `rol_soporte` ni `admin_datos` en defaults: el acceso de
  soporte es por columna y manual; el admin recibe privilegios explícitos.

### 8.1 Advertencia: defaults y tablas nuevas

> Al no otorgarse `SELECT`/`INSERT` por defecto sobre tablas, cada tabla nueva
> **nace sin acceso** para los roles de aplicación (postura segura). Eso evita
> que una tabla futura con PII herede `SELECT` y exponga datos personales, pero
> obliga a otorgar a mano conforme a la matriz.

Riesgos residuales del default:

1. **Secuencias:** el `GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura`
   aplica a toda secuencia futura creada por el grantor. Si se crea una
   secuencia sensible, heredaría `USAGE, SELECT`; mitigarlo con `REVOKE` puntual
   sobre esa secuencia.
2. **Funciones:** el `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` hace que las
   funciones nuevas no sean ejecutables por nadie salvo grant explícito.
   Acordarse de otorgar `EXECUTE` a quien corresponda (p. ej. una futura `fn_*`
   para la app → `app_web`).
3. **Múltiples propietarios:** `ALTER DEFAULT PRIVILEGES` solo aplica a los
   objetos creados por el `grantor` especificado (`FOR <owner>`). Si otro rol
   crea tablas/funciones, esas tablas **no** heredan estos defaults y quedan en
   el estado por defecto de PostgreSQL. Documentar quién crea objetos en la
   implementación.
4. **PG17:** desde PG15 el esquema `public` ya no concede `CREATE` a `PUBLIC`
   por defecto; igual conviene `REVOKE CREATE ON SCHEMA public FROM PUBLIC;`
   para dejarlo explícito.

---

## 9. Prevención de escalamiento `app_web` → `admin_datos`

- `app_web` no tiene `CREATEROLE` ni es miembro de `admin_datos`.
- Para que un `GRANT <rol> TO <otro>` funcione, el grantor debe ser miembro del
  rol objetivo **con `ADMIN OPTION`** (o tener `CREATEROLE`/superuser). Como
  `app_web` no cumple ninguna de esas condiciones:
  - `GRANT admin_datos TO app_web;` ejecutado como `app_web` → **error**
    (`permission denied to grant role admin_datos` / `must be member of role
    admin_datos`).
- Adicionalmente el script ejecuta `REVOKE admin_datos FROM app_web;` para
  garantizar que no exista membresía residual.

### 9.1 Cómo se verifica (ver también §11)

```sql
-- 1) Ejecutar como app_web: debe fallar.
--    GRANT admin_datos TO app_web;
--    ERROR: permission denied to grant role admin_datos

-- 2) Confirmar que no quedó como miembro.
SELECT m.memberid::regrole AS miembro, r.rolname AS es_miembro_de
FROM pg_auth_members m
JOIN pg_roles r ON r.oid = m.roleid
WHERE m.memberid = (SELECT oid FROM pg_roles WHERE rolname = 'app_web')
  AND r.rolname = 'admin_datos';
-- Debe devolver 0 filas.

-- 3) Atributos de app_web: rolsuper/rolcreatedb/rolcreaterole deben ser false.
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolinherit
FROM pg_roles WHERE rolname = 'app_web';
```

---

## 10. Alternativas descartadas

| Alternativa | Por qué se descarta |
|---|---|
| `GRANT ALL` sobre tablas a algún rol | Viola mínimo privilegio (R1). Se enumeran privilegios. |
| `GRANT ... ON ALL TABLES IN SCHEMA public` como política permanente | Da acceso a todas las tablas, incluidas futuras con PII. Se otorga por objeto. |
| Defaults de `SELECT`/`INSERT` sobre tablas | Una tabla futura con PII heredaría `SELECT` y expondría datos personales. Se eliminan los defaults de tablas (§8). |
| Dar `SELECT` sobre `usuario` a la app o a reportes | Expone `password_hash`, `rol`, PII. Se usa `v_usuarios_seguros`. |
| Dar `UPDATE` sobre `usuario` entera a `rol_soporte` | Permite tocar identidad, `rol`, `password_hash`. Se hace a nivel de columna. |
| Dejar `SELECT(id_usuario)` como "condicional" | El `UPDATE ... WHERE id_usuario` lo exige; es requisito firme, no opcional. |
| Hacer `app_web` miembro de `admin_datos` | Escalamiento. Se prohíbe (RF-12). |
| Dar `CREATEROLE`/`CREATEDB` a `app_web` | Permite crear roles/bases. Se prohíbe. |
| `admin_datos` `SUPERUSER` | Demasiado amplio. Se limita a `CREATEDB`/`CREATEROLE` + `NOSUPERUSER`. |
| `admin_datos` con `UPDATE` directo sobre `password_hash` | Permite hasheos débiles/en claro. Se fuerza por `fn_resetear_password`. |
| Funciones `SECURITY INVOKER` | `app_web` no tiene `SELECT` sobre `password_hash`; el invoker no podría autenticar. Se usa `SECURITY DEFINER` con `search_path` fijado. |
| Dejar `EXECUTE` a `PUBLIC` en las funciones | Expone autenticación y reset a cualquiera. Se hace `REVOKE FROM PUBLIC` + grant puntual, y se refuerza con el default `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`. |
| Asumir `crypt` de tiempo constante | No se garantiza; no se afirma. Se iguala el flujo para reducir timing (ver §11). |
| Roles extras: `rol_backups`, `rol_migraciones` | Inflan la matriz sin necesidad en dev local; `admin_datos` cubre backups y migraciones. Descartados (no agregados). |
| RLS para "mis pedidos" | Fuera de alcance de este TP. Recomendada solo si se implanta el historial de pedidos del cliente (ver §11). |

---

## 11. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Nuevas tablas nacen sin default de acceso → grants manuales olvidados o excesivos | Medio | Sin default de tablas (§8); cada tabla nueva se otorga a mano conforme a la matriz y se revisa al alta. |
| Default de secuencias y `REVOKE EXECUTE` afectan a objetos futuros del grantor | Medio | `REVOKE` puntual sobre secuencias/funciones sensibles; otorgar `EXECUTE` explícito a quien corresponda (§8.1). |
| Múltiples propietarios crean tablas y no heredan defaults | Medio | Documentar el `grantor` de `ALTER DEFAULT PRIVILEGES`; cada creador debe aplicar su propia política. |
| Inyección SQL en funciones `SECURITY DEFINER` | Alto | SQL parametrizado (`USING`), `search_path` fijado a `public`, sin concatenación de texto del usuario. |
| `app_web` hereda un privilegio peligroso si se modifica un grupo | Medio | Auditar grants de `rol_app_lectura`/`rol_app_escritura` ante cada cambio; la matriz es la referencia. |
| `v_detalle_pedido_producto` expone líneas de **todos** los pedidos (sin PII) | Bajo/Medio | Aceptado para dev; si se requiere estricto, RLS o función parametrizada por `pedido_id`. |
| `vm_facturacion_categoria_mes` desactualizada → reportes con datos stale | Bajo | `admin_datos` define la frecuencia de `REFRESH`; documentar la antigüedad máxima tolerada. |
| Diferencias de timing en `fn_autenticar` | Medio | No asumir que la comparación es de tiempo constante; igualar el flujo para email inexistente vs. password incorrecta para reducir (no eliminar) la fuga de timing. |
| **Bloqueo de cuentas ajenas por intentos fallidos (DoS)** | Medio | Un atacante que conoce un `email` puede disparar intentos fallidos y llevar `intentos_fallidos` al umbral, bloqueando la cuenta de la víctima. Mitigación a nivel app: rate-limit por IP, CAPTCHA tras N intentos, notificar al dueño, backoff decreciente; no exponer el estado de bloqueo como oráculo. |
| Confundir `usuario.rol` (app) con un rol de BD | Bajo | Glosario en `requirements.md` §3 y nota en §7. |
| `rol_soporte` modifica `eliminado` y borra usuarios lógicamente | Medio | No se le otorga `UPDATE(eliminado)`; la baja lógica es administrativa (`admin_datos`). |
| Quemar contraseñas en el repo | Alto | RF-13: contraseñas fuera de banda, nunca en el script. |

---

## 12. Brecha con la implementación existente (`sql/roles.sql`)

El script actual **no** se ajusta a este spec (es previo a esta planificación).
Diferencias a resolver en la fase de implementación:

- Apunta a **PostgreSQL 16+**, no a 17.
- Maneja nombres genéricos (`cliente`, `linea_pedido`) que **no existen** en el
  esquema real.
- **No cubre** las vistas ni `vm_facturacion_categoria_mes`.
- **No crea** `fn_resetear_password` ni las columnas nuevas de `usuario`.
- Le da a `rol_soporte` `SELECT` sobre la tabla `usuario` completa (debería ser
  `v_usuarios_seguros` + `SELECT(id_usuario)`/`UPDATE` por columna).
- No documenta ni verifica el fallo de `GRANT admin_datos TO app_web`.
- Otorga `SELECT`/`INSERT` por defecto sobre tablas (este spec los elimina y
  deja solo secuencias + `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`).
- No contempla el `SELECT` a nivel de columna que `INSERT ... RETURNING`
  exige sobre `id_pedido`/`id_detalle`.

> No se modifica `roles.sql` en esta fase. Se regenerará conforme a este spec.

---

## 13. Plan de verificación

### 13.1 Roles y atributos

```sql
\du
\du app_web
\du admin_datos

SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolinherit, rolcanlogin
FROM pg_roles
WHERE rolname IN ('rol_app_lectura','rol_app_escritura','rol_soporte',
                  'rol_reportes','app_web','admin_datos')
ORDER BY rolname;
```

Esperado: los cuatro grupos con `rolcanlogin = false`; `app_web` con
`rolsuper/rolcreatedb/rolcreaterole = false`; `admin_datos` con
`rolcreatedb/rolcreaterole = true` y `rolsuper = false`.

### 13.2 Membresías y no-escalamiento

```sql
SELECT member::regrole AS miembro, roleid::regrole AS miembro_de
FROM pg_auth_members
ORDER BY 1,2;
```

Esperado: `app_web` miembro de `rol_app_lectura` y `rol_app_escritura`;
**ninguna** fila `app_web → admin_datos`.

### 13.3 Privilegios por tabla (matriz)

```sql
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte',
                  'rol_reportes','app_web','admin_datos')
  AND table_schema = 'public'
ORDER BY grantee, table_name, privilege_type;
```

La salida debe coincidir con la matriz de §4, **ni más ni menos**. Para
`rol_app_escritura` aparece `INSERT` sobre `pedido` y `detalle_pedido` (el
`SELECT` a nivel de columna sobre las PK se verifica en §13.4); no debe
aparecer `DELETE`, `TRUNCATE`, `REFERENCES` ni `TRIGGER` para los roles web ni
para `rol_soporte`; `rol_reportes` solo `SELECT` (sobre tablas y vistas);
`admin_datos` con el set enumerado (no `GRANT ALL`).

### 13.4 Privilegios a nivel de columna

```sql
SELECT grantee, table_name, column_name, privilege_type
FROM information_schema.column_privileges
WHERE grantee IN ('rol_soporte','rol_app_escritura')
  AND table_schema = 'public'
ORDER BY grantee, table_name, column_name, privilege_type;
```

Esperado:

- `rol_soporte` sobre `usuario`: `SELECT(id_usuario)` y `UPDATE(email)`,
  `UPDATE(intentos_fallidos)`. **No** `password_hash`, `rol`, `fecha_alta`,
  `nombre`, `apellido` ni `eliminado`.
- `rol_app_escritura` sobre `pedido`: `SELECT(id_pedido)`; sobre
  `detalle_pedido`: `SELECT(id_detalle)`. **No** otras columnas de negocio.

### 13.5 `EXECUTE` en funciones

```sql
SELECT grantee, routine_name, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN ('fn_autenticar','fn_resetear_password')
ORDER BY grantee, routine_name;
```

Esperado: `fn_autenticar` → `app_web` únicamente; `fn_resetear_password` →
`admin_datos` únicamente. **No** `PUBLIC` ni el otro rol.

### 13.6 Defaults

```sql
SELECT pg_get_userbyid(d.defaclrole) AS propietario,
       n.nspname AS esquema,
       d.deftype
FROM pg_default_acl d
JOIN pg_namespace n ON n.oid = d.defaclnamespace
WHERE n.nspname = 'public';
```

Esperado: defaults para el propietario que crea objetos, con `REVOKE ALL`
previo; **sin grants de tablas** por defecto, solo `USAGE, SELECT` en secuencias
a `rol_app_escritura` y `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`.

### 13.7 Pruebas funcionales

- **Sin `GRANT ALL`:** `grep -n "GRANT ALL" <script>` debe devolver 0 líneas.
- **Escalamiento:** conectado como `app_web`, ejecutar
  `GRANT admin_datos TO app_web;` → debe dar error.
- **`EXECUTE` cruzado:** conectado como `app_web`, llamar a
  `fn_resetear_password(...)` → `permission denied`. Conectado como
  `admin_datos`, llamar a `fn_autenticar(...)` → `permission denied` (si se
  restringe a `app_web`; ver RF-07).
- **`RETURNING` funciona:** conectado como `app_web`,
  `INSERT INTO pedido (...) VALUES (...) RETURNING id_pedido;` debe devolver el
  ID generado. En cambio `SELECT * FROM pedido LIMIT 1;` → `permission denied`
  (solo hay `SELECT` a nivel de columna sobre `id_pedido`).
- **Sin `SELECT` sobre `password_hash`:** conectado como `app_web`,
  `SELECT password_hash FROM usuario LIMIT 1;` → `permission denied`.
