# Auditoría de `roles.sql` (Parte A, punto 4)

## Quién auditó y con qué

La consigna pide que la auditoría la haga OpenCode. La **primera** auditoría la
realizó **Claude Code**, que fue el asistente usado en la sesión de
implementación: se deja constancia para que la bitácora refleje lo que ocurrió.
Después la auditoría se **repitió con OpenCode** en una sesión nueva y sin
contexto previo; su prompt, su respuesta y la validación del equipo están en la
sección 4 y en `BITACORA.md`. Las dos auditorías se conservan.

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
relevancia. La decisión del equipo sobre cada uno está en la §5.

| # | Severidad | Hallazgo | Recomendación | Estado |
|---|---|---|---|---|
| H1 | Media | `admin_datos` tiene `CREATE` sobre el esquema `public` y las funciones `SECURITY DEFINER` resuelven `crypt` y `gen_salt` (de `pgcrypto`, instalada en `public`) a través de `search_path = public, pg_temp`. Es el patrón clásico de secuestro de funciones. Hoy las llamadas coinciden exactamente con la firma de `pgcrypto`, por lo que la explotación es poco probable, pero la defensa depende de un detalle | Calificar `public.crypt` y `public.gen_salt` dentro de las funciones, o instalar `pgcrypto` en un esquema propio | Aceptado, con la mitigación indicada (§5) |
| H2 | Media | `admin_datos` tiene `TRUNCATE`, `TRIGGER` y `REFERENCES` sobre cuatro tablas. La spec los enumera, pero ninguna tarea descrita los necesita; `TRIGGER` permite además ejecutar código ajeno cuando otros roles escriben en esas tablas | Quitar `TRUNCATE`, `TRIGGER` y `REFERENCES` y otorgarlos sólo cuando una tarea de mantenimiento lo requiera | Aceptado (§5) |
| H3 | Baja | `PUBLIC` conserva `CONNECT` y `TEMP` sobre la base. Cualquier rol, incluido `app_web`, puede crear tablas temporales. La spec no lo trata | `REVOKE TEMP ON DATABASE copia_trabajo FROM PUBLIC` y `GRANT CONNECT` explícito a `app_web` y `admin_datos` | Aceptado (§5) |
| H4 | Baja | El `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` es global (la sintaxis no admite `IN SCHEMA` para quitarle un default a `PUBLIC`). Las funciones que `postgres` cree en el futuro, incluidas las de extensiones, no serán ejecutables por todos | Documentarlo (hecho en el comentario del script) y otorgar `EXECUTE` explícito cuando corresponda | Aceptado y documentado |
| H5 | Baja | `admin_datos` tiene `UPDATE` sobre todas las secuencias, lo que permite `setval` y podría provocar choques de claves primarias | Limitar a `USAGE, SELECT` salvo mantenimiento | Aceptado (§5) |
| H6 | Baja | `SELECT(id_pedido)` permite a `app_web` enumerar los ids de todos los pedidos | Riesgo residual aceptado: es el mínimo para que `RETURNING` funcione | Aceptado |
| H7 | Baja | No hay `VALID UNTIL` ni `CONNECTION LIMIT` en los roles de login | Fijar un límite de conexiones para `app_web` | Aceptado (§5) |
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

## 4. Re-auditoría con OpenCode (Parte A, punto 4)

Sesión nueva, sin contexto previo: se le pasó únicamente el contenido de
`sql/roles.sql`.

**Prompt enviado (textual):**

```text
Auditá este script de roles y permisos de PostgreSQL bajo el principio de
mínimo privilegio. Marcá los permisos que son más amplios de lo necesario,
los riesgos de seguridad que veas y qué cambiarías concretamente.
```

**Qué acertó.** Coincidió con hallazgos ya registrados: `TRUNCATE` + `TRIGGER`
equivalen a `ALL` (H2), `admin_datos` con `UPDATE` sobre todas las secuencias (H5)
y la ausencia de `CONNECTION LIMIT` / `VALID UNTIL` (H7). Además encontró un punto
que las auditorías anteriores no habían registrado:

| # | Severidad | Hallazgo | Recomendación | Estado |
|---|---|---|---|---|
| H10 | Baja | `roles.sql` revoca `CREATE` a `PUBLIC` sobre el esquema, pero `PUBLIC` conserva `USAGE`, que es el valor por defecto del motor. Cualquier rol no previsto en la matriz puede navegar el esquema y resolver nombres de objetos | `REVOKE USAGE ON SCHEMA public FROM PUBLIC`, después de otorgar `USAGE` a los seis roles | Aceptado (§5) |

**Qué afirmó sin sustento.** Tres puntos, y son justamente los que sostienen su
veredicto:

1. «`EXECUTE` de funciones sigue concedido a `PUBLIC`», marcado como **crítico**.
   Es falso: `sql/00_reconstruccion_clase2.sql:134` y `:163` ejecutan
   `REVOKE ALL ON FUNCTION ... FROM PUBLIC` al crear las funciones, y
   `docs/verificacion_roles.txt:125-131` muestra el estado real, sin `PUBLIC`. La
   IA leyó sólo `roles.sql` y generalizó sobre lo que no veía.
2. «`rol_soporte` puede reescribir el email y después resetear la clave». La
   primera mitad es cierta —es el permiso por columna que exige la consigna—; la
   segunda no: `rol_soporte` no tiene `EXECUTE` sobre `fn_resetear_password`.
3. «`v_usuarios_seguros` podría exponer datos personales a `rol_reportes`». Esa
   vista no está otorgada a `rol_reportes` (ver `sql/roles.sql:135-137`).

**Qué se descartó por diseño.** `CREATEDB`, `CREATEROLE` y `CREATE` sobre el
esquema para `admin_datos`, y el `UPDATE (email)` de `rol_soporte`: son decisiones
de la matriz de la spec, justificadas en `design.md`, y la sección 3 de este
documento prueba que `CREATEROLE` no alcanza para modificar roles ajenos en
PostgreSQL 17.

**Veredicto del equipo.** La implementación **sí** coincide con la matriz de la
spec (ver `docs/verificacion_roles.txt`); el veredicto «no cumple» de la IA se
descarta. Las decisiones sobre los diez hallazgos están en la §5.

## 5. Decisión del equipo sobre los hallazgos

Se revisaron los diez hallazgos y se decidió **no modificar `roles.sql`**: el
script y su verificación (`docs/verificacion_roles.txt`,
`docs/pruebas_funcionales_roles.txt`) están cerrados, y cualquier cambio obliga a
regenerar toda la evidencia ejecutada. El objetivo de este TP es demostrar mínimo
privilegio con evidencia, no endurecer un servidor en producción; por eso las
correcciones quedan documentadas y priorizadas para un despliegue real.

| # | Decisión | Motivo |
|---|---|---|
| H1 | Aceptar, con la mitigación indicada | La explotación exige `CREATE` en `public` (sólo lo tiene `admin_datos`) y una coincidencia exacta de firma con `pgcrypto`; en un entorno real se califican `public.crypt` y `public.gen_salt`. |
| H2 | Aceptar | `admin_datos` es el rol de mantenimiento y la matriz de la spec enumera esos privilegios; ninguna tarea del TP los usa, pero quitarlos no cambia lo que se evalúa. |
| H3 | Aceptar | Revocar `TEMP` y `CONNECT` a `PUBLIC` afecta a todo el clúster y su efecto depende de `pg_hba.conf`; es una decisión de despliegue. |
| H4 | Aceptado y documentado | El `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` es global por una limitación de sintaxis, y así está comentado en el script. |
| H5 | Aceptar | `admin_datos` usa las secuencias para mantenimiento; el riesgo de `setval` existe pero no hay tareas automáticas que lo disparen. |
| H6 | Aceptado | Es el mínimo privilegio que hace funcionar `INSERT ... RETURNING`. |
| H7 | Aceptar | El límite de conexiones y `VALID UNTIL` son parámetros operativos que se fijan al desplegar, no en el script de permisos. |
| H8 | Documentado | Es coherente con mínimo privilegio; si soporte necesita ver el email, corresponde una vista específica. |
| H9 | Fuera de alcance | El origen de las conexiones se define en `pg_hba.conf`, no en `roles.sql`. |
| H10 | Aceptar | El `USAGE` de `PUBLIC` sobre el esquema es el default del motor; revocarlo obliga a re-otorgar a los seis roles y a regenerar la evidencia. |

Orden de aplicación si se llevara a un entorno real: H1 y H10 primero (menor
esfuerzo y mayor reducción de superficie), después H2 y H5 (privilegios que
ninguna tarea usa) y por último H3 y H7 (requieren coordinación con la operación).
