# Auditoría de `roles.sql` (Parte A, punto 4)

## Quién auditó y con qué

La consigna pide que la auditoría la haga OpenCode. Esta auditoría la realizó
**Claude Code**, que fue el asistente usado en la sesión de implementación;
OpenCode no intervino. Se deja constancia para que la bitácora refleje lo que
ocurrió. Si el equipo repite la auditoría con OpenCode, su prompt y su respuesta
deben agregarse a `BITACORA.md` como un registro aparte.

Insumos de la auditoría: `sql/roles.sql`, `sql/00_reconstruccion_clase2.sql`,
`docs/kiro_roles_spec/`, la salida de `sql/verificacion_roles.sql` y las pruebas
funcionales (`docs/verificacion_roles.txt`, `docs/pruebas_funcionales_roles.txt`).

## 1. Casos reales en que la IA propuso algo incorrecto o más amplio

Son hechos ocurridos durante el trabajo, no hipótesis. En todos el equipo no
aplicó la propuesta tal cual.

| # | Quién lo propuso | Propuesta | Por qué era incorrecta o excesiva | Cómo se detectó | Corrección |
|---|---|---|---|---|---|
| 1 | Primera versión de `roles.sql` (previa a la spec) | `rol_soporte` con `SELECT` sobre toda la tabla `usuario`; `GRANT USAGE, SELECT ON ALL SEQUENCES` a `rol_app_escritura`; `GRANT SELECT ON TABLES` por defecto a `rol_app_lectura` | Más amplio que la necesidad: expone todas las columnas de `usuario` y toda secuencia y tabla futura | Lectura del script contra la matriz de mínimo privilegio, en la revisión inicial de la carpeta | Soporte lee sólo por `v_usuarios_seguros` y actualiza por columna; secuencias sólo de `pedido` y `detalle_pedido`; sin defaults de `SELECT` |
| 2 | Kiro (`design.md` y `requirements.md`, primera versión) | `ALTER DEFAULT PRIVILEGES` con `SELECT` por defecto para `rol_app_lectura` y `rol_reportes`, e `INSERT` por defecto para `rol_app_escritura` | Contradecía la propia matriz: cualquier tabla futura con datos personales heredaría `SELECT` | Cotejo de la sección de defaults con la matriz de permisos | Se pidió a Kiro quitar esos defaults; las tablas nuevas nacen sin acceso |
| 3 | Kiro (primera versión) | Afirmaba que `rol_app_escritura` no necesita `SELECT` porque los datos se obtienen con `INSERT ... RETURNING` | **Falso:** `RETURNING` exige `SELECT` sobre las columnas devueltas. Con ese diseño `app_web` no podía recuperar el `id_pedido` | Contraste con el funcionamiento de PostgreSQL al revisar la spec | `SELECT(id_pedido)` y `SELECT(id_detalle)` por columna; confirmado en vivo: `INSERT ... RETURNING id_pedido` devolvió `200001` |
| 4 | Kiro (primera versión) | `SELECT(id_usuario)` para `rol_soporte` "condicional"; afirmación de que `crypt` compara en tiempo constante | Un `UPDATE ... WHERE id_usuario` exige `SELECT` sobre esa columna; lo del tiempo constante no estaba respaldado | Revisión de la spec | Requisito firme; se quitó la afirmación y se agregó el riesgo de bloqueo de cuentas ajenas |
| 5 | Claude Code (implementación) | Prueba de `rol_soporte`: `UPDATE usuario SET email = email WHERE id_usuario = 1` "debe dar `UPDATE 1`" | `SET email = email` lee `email`, que soporte no puede leer; el rechazo era correcto y la prueba errónea | La ejecución devolvió `permiso denegado` y se razonó por qué | Se repitió con un valor constante y dio `UPDATE 1` |
| 6 | Claude Code (implementación) | Admin con `SELECT` e `INSERT` sobre `usuario` completa, tal como decía la spec | Un `INSERT` general permitiría a `admin_datos` escribir un `password_hash` propio y saltearse `fn_resetear_password`, contradiciendo la justificación de la spec | Revisión del criterio de la spec contra su propio objetivo | `SELECT` e `INSERT` por columna, sin `password_hash` (desvío documentado respecto de la spec) |

El caso 3 es el candidato a "más significativo" para la Parte E: la IA afirmó con
seguridad algo técnicamente falso y la consecuencia habría sido una aplicación
que no puede registrar pedidos.

## 2. Hallazgos de la auditoría del `roles.sql` vigente

La implementación coincide con la matriz de la spec (ver
`docs/verificacion_roles.txt`). Estos son los puntos que quedan, ordenados por
relevancia. El estado "pendiente" significa que **la decisión es del equipo**.

| # | Severidad | Hallazgo | Recomendación | Estado |
|---|---|---|---|---|
| H1 | Media | `admin_datos` tiene `CREATE` sobre el esquema `public` y las funciones `SECURITY DEFINER` resuelven `crypt` y `gen_salt` (de `pgcrypto`, instalada en `public`) a través de `search_path = public, pg_temp`. Es el patrón clásico de secuestro de funciones. Hoy las llamadas coinciden exactamente con la firma de `pgcrypto`, por lo que la explotación es poco probable, pero la defensa depende de un detalle | Calificar `public.crypt` y `public.gen_salt` dentro de las funciones, o instalar `pgcrypto` en un esquema propio | Pendiente de decisión |
| H2 | Media | `admin_datos` tiene `TRUNCATE`, `TRIGGER` y `REFERENCES` sobre cuatro tablas. La spec los enumera, pero ninguna tarea descrita los necesita; `TRIGGER` permite además ejecutar código ajeno cuando otros roles escriben en esas tablas | Quitar `TRUNCATE`, `TRIGGER` y `REFERENCES` y otorgarlos sólo cuando una tarea de mantenimiento lo requiera | Pendiente de decisión |
| H3 | Baja | `PUBLIC` conserva `CONNECT` y `TEMP` sobre la base. Cualquier rol, incluido `app_web`, puede crear tablas temporales. La spec no lo trata | `REVOKE TEMP ON DATABASE copia_trabajo FROM PUBLIC` y `GRANT CONNECT` explícito a `app_web` y `admin_datos` | Pendiente de decisión |
| H4 | Baja | El `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` es global (la sintaxis no admite `IN SCHEMA` para quitarle un default a `PUBLIC`). Las funciones que `postgres` cree en el futuro, incluidas las de extensiones, no serán ejecutables por todos | Documentarlo (hecho en el comentario del script) y otorgar `EXECUTE` explícito cuando corresponda | Aceptado y documentado |
| H5 | Baja | `admin_datos` tiene `UPDATE` sobre todas las secuencias, lo que permite `setval` y podría provocar choques de claves primarias | Limitar a `USAGE, SELECT` salvo mantenimiento | Pendiente de decisión |
| H6 | Baja | `SELECT(id_pedido)` permite a `app_web` enumerar los ids de todos los pedidos | Riesgo residual aceptado: es el mínimo para que `RETURNING` funcione | Aceptado |
| H7 | Baja | No hay `VALID UNTIL` ni `CONNECTION LIMIT` en los roles de login | Fijar un límite de conexiones para `app_web` | Pendiente de decisión |
| H8 | Informativa | Soporte puede corregir un email pero no verlo (la vista segura no lo incluye) | Es coherente con el mínimo privilegio; si el trabajo real lo exige, crear una vista de soporte con `email` | Documentado |
| H9 | Informativa | `roles.sql` no controla desde dónde se conectan los roles: eso lo define `pg_hba.conf` | Revisar `pg_hba.conf` (fuera del alcance del script) | Fuera de alcance |

## 3. Pruebas ejecutadas como `admin_datos`

Conectado con `psql -U admin_datos -h localhost -d copia_trabajo`:

```text
copia_trabajo=> ALTER ROLE app_web PASSWORD 'x';
ERROR:  se ha denegado el permiso para alterar el rol
DETALLE:  Para cambiar la password de otro rol, el usuario actual debe tener el atributo CREATEROLE y la opción ADMIN en el rol.
copia_trabajo=> SELECT password_hash FROM usuario LIMIT 1;
ERROR:  permiso denegado a la tabla usuario
copia_trabajo=> SELECT fn_resetear_password(1, 'clave-de-prueba');
 fn_resetear_password
----------------------
 f
(1 fila)

copia_trabajo=> SELECT fn_autenticar('usuario1@example.invalid', 'clave-de-prueba');
ERROR:  permiso denegado a la función fn_autenticar
```

Lectura:

1. **`CREATEROLE` no permite tocar roles ajenos.** `admin_datos` tiene el
   atributo pero no la opción `ADMIN` sobre `app_web`, y PostgreSQL 17 exige las
   dos cosas. Esto acota el riesgo de tener `CREATEROLE` en `admin_datos`.
2. **El hash no es legible**, ni siquiera para el administrador de datos.
3. **`fn_resetear_password(1, ...)` devolvió `f` (falso).** La expectativa
   escrita de antemano era `t`, y estaba equivocada: el usuario 1 está dado de
   baja (`eliminado = true`; `v_usuarios_seguros` empieza en el id 2) y la
   función, por diseño, no actúa sobre usuarios eliminados (RF-09). Es un
   error de la prueba propuesta por el asistente, no de la función. Repetida
   con un usuario activo (id 2) devolvió `t`:

   ```text
   copia_trabajo=> SELECT fn_resetear_password(2, 'clave-de-prueba');
    fn_resetear_password
   ----------------------
    t
   (1 fila)
   ```
4. **`fn_autenticar` no es ejecutable por `admin_datos`**, como indica la
   separación de funciones de RF-07.
