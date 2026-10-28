# Bitácora de uso de IA — TP Unidad 5

Registro de las interacciones relevantes con asistentes de IA durante el trabajo,
en el formato de tres columnas que pide la consigna: **prompt enviado**,
**respuesta relevante (resumida)** y **validación o corrección humana aplicada**.

Herramientas usadas: **Kiro** para la especificación de la Parte A, **Claude Code**
en la sesión de implementación y **OpenCode** como asistente de terminal para las
auditorías y las reconstrucciones.

> **Constancia de herramienta (Parte A, punto 4).** La primera auditoría de
> `roles.sql` la hizo Claude Code, que era el asistente de la sesión de
> implementación. Como la consigna pide que la auditoría la haga OpenCode, la
> auditoría se **repitió con OpenCode** en una sesión nueva y las dos quedaron en
> `docs/auditoria_roles_sql.md`. Los resultados no se ocultan: se comparan.

## Registros

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| **A.1 — Kiro.** «Necesito una especificación (requirements + design) de roles y permisos de MÍNIMO PRIVILEGIO para una base PostgreSQL 17 llamada "Food Store"…» Se le dio el esquema real, los roles requeridos, ocho requisitos obligatorios y el formato esperado. Prompt completo en el **Anexo A**. | Generó `requirements.md` (RF-01 a RF-12, criterios en formato EARS) y `design.md` con los cuatro roles de grupo y los dos de login, una justificación por rol, la matriz rol × objeto × privilegio, el permiso a nivel de columna para `rol_soporte`, `ALTER DEFAULT PRIVILEGES` y el plan de verificación con `\du` e `information_schema`. | Se aceptó la estructura y se rechazaron tres puntos, que se le pidieron corregir en el prompt siguiente: (1) afirmaba que `INSERT ... RETURNING` no necesita `SELECT`; (2) decía que `SELECT(id_usuario)` era «condicional»; (3) los `ALTER DEFAULT PRIVILEGES` otorgaban `SELECT` e `INSERT` por defecto, **más amplio que la propia matriz** que la IA había escrito. Ninguno de los tres se aplicó. |
| **A.1 (corrección) — Kiro.** «Revisá la spec con estas correcciones, manteniendo el resto: 1. `INSERT ... RETURNING` requiere privilegio `SELECT`… 2. `SELECT(id_usuario)` para `rol_soporte` no es condicional… 3. `ALTER DEFAULT PRIVILEGES`: quitá el `GRANT SELECT` por defecto… 4. La base se llama `copia_trabajo`… 5. Quitá la afirmación sobre comparación en tiempo constante de `crypt`…». Prompt completo en el **Anexo B**. | Corrigió RF-03 y la matriz: agregó `SELECT(id_pedido)` y `SELECT(id_detalle)` **a nivel de columna**; quitó los `SELECT` e `INSERT` por defecto; agregó `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` como default; eliminó la afirmación sobre `crypt` y agregó el riesgo de bloquear cuentas ajenas; cambió `int` por `bigint`. | Se verificó contra el comportamiento real del motor: con sólo `SELECT(id_pedido)` de columna, `INSERT ... RETURNING id_pedido` devolvió `200001`. La spec corregida es la que está en `docs/kiro_roles_spec/`. |
| **A.4 — OpenCode.** «Auditá este script de roles y permisos de PostgreSQL bajo el principio de mínimo privilegio. Marcá los permisos que son más amplios de lo necesario, los riesgos de seguridad que veas y qué cambiarías concretamente. [contenido de `sql/roles.sql`]» | Quince hallazgos ordenados por severidad. Los dos que marcó como más graves: «`EXECUTE` de funciones sigue concedido a `PUBLIC`» (crítico) y «`admin_datos` es casi un superusuario» (`CREATEDB` + `CREATEROLE` + `CREATE` en `public` + `ALL` sobre las tablas). Veredicto: «**no cumple** el principio de mínimo privilegio». | Se **descartó el veredicto** y se descartó el hallazgo crítico, que es falso: el `REVOKE ... FROM PUBLIC` de las dos funciones está en `sql/00_reconstruccion_clase2.sql:134` y `:163`, y `docs/verificacion_roles.txt:125-131` muestra que `PUBLIC` no tiene `EXECUTE` sobre ninguna. También es falsa la cadena de ataque «soporte cambia el email y después resetea la clave»: `rol_soporte` no tiene `EXECUTE` sobre `fn_resetear_password`. Sí se retuvieron los hallazgos que coinciden con la auditoría previa (`TRUNCATE`/`TRIGGER`, `UPDATE` sobre secuencias, falta de `CONNECTION LIMIT`) y se incorporó uno nuevo (H10: `PUBLIC` conserva `USAGE` sobre el esquema). Detalle y decisión en `docs/auditoria_roles_sql.md`. |
| **B.1 y B.2 — auditoría nativa.** «Generar una secuencia de auditoría nativa con lectura, inserción, actualización y login fallido.» | Indicó `log_connections`, `log_disconnections` y `log_statement = 'mod'`, y distinguió el login fallido del servidor de una función que devuelve falso. | Se subió `log_statement` a **`'all'`** y no `'mod'`, porque el simulacro de la Parte C necesita que queden registrados los `SELECT`; el costo y el motivo están en `docs/informe_auditoria.md`. La secuencia se ejecutó en cinco sesiones y su log quedó en `docs/log_auditoria_prueba.txt`. |
| **C.4 — OpenCode.** «Este es un fragmento de log de un servidor PostgreSQL. Reconstruí qué ocurrió y proponé una hipótesis de contención.» Seguido de las 26 líneas de `docs/log_simulacro_anonimizado.txt`, en una sesión nueva y sin contexto adicional. | Reconstruyó la secuencia (cinco llamadas a `fn_autenticar`, lectura masiva denegada, dos `GRANT admin_datos` denegados), la interpretó como un test controlado de seguridad y propuso diez medidas de contención. | Contraste completo en `docs/informe_incidente.md` §6; respuesta sin editar en `docs/respuesta_ia_simulacro.md`. Acertó la secuencia, las denegaciones y el motivo. Afirmó sin sustento que el quinto intento fue un login exitoso (el log no registra resultados) y que la sesión duró «83 ms» (fueron 92). Dijo que «no hay throttling» cuando `fn_autenticar` bloquea al quinto fallo. **No se ejecutó nada** de lo que sugirió. |
| **D.2 — OpenCode.** «Necesito dos consultas SQL para PostgreSQL 17 sobre estas dos tablas… [esquema de `usuario` y de `usuario_anon`] La primera tiene que ser una consulta de agregación sobre `usuario_anon`: cantidad de usuarios por rol y por mes de alta. La segunda tiene que ser la consulta equivalente sobre la tabla real `usuario`.» | Devolvió las dos consultas con `date_trunc('month', …)::date`, con `AT TIME ZONE 'UTC'` en la tabla real, y explicó por qué son equivalentes. | Coincidió con la implementación de `sql/usuario_anon.sql` (consultas A y B), incluido el `AT TIME ZONE 'UTC'`, que evita que el corte de mes dependa del `TimeZone` de la sesión. Se descartó su sugerencia de filtrar `eliminado = false`: la consigna pide la misma agregación sobre el universo completo y el filtro no aporta a la comparación. La equivalencia se comprobó ejecutando las dos consultas y un `FULL JOIN` que devolvió 0 filas (`docs/verificacion_equivalencia.md`). |

## Caso más significativo de error de la IA (Parte E, punto 2)

El caso más significativo es el de **`INSERT ... RETURNING`**, en la primera
versión de la spec de Kiro. La IA afirmó, con seguridad y dentro de una matriz de
permisos prolija, que `rol_app_escritura` **no necesitaba `SELECT`** sobre
`pedido`, porque los datos se recuperaban con `INSERT ... RETURNING`. Es falso:
`RETURNING` exige `SELECT` sobre las columnas que devuelve. Con ese diseño, la
aplicación habría podido insertar un pedido pero no recuperar su `id_pedido`, es
decir, no habría podido registrar el detalle de la compra.

Se detectó leyendo la spec contra el funcionamiento documentado de PostgreSQL y no
contra lo que la IA decía de sí misma; después se confirmó en la base, con el
permiso ya corregido: `INSERT ... RETURNING id_pedido` devolvió `200001`. El error
es significativo por tres razones: estaba escrito con confianza, aparecía en un
documento de planificación que parecía completo, y su consecuencia no era un
mensaje de error visible sino una función del sistema que se rompe en producción.

Un segundo caso, complementario, es el de la auditoría de la Parte A.4 hecha con
OpenCode: la IA calificó de **crítico** un problema inexistente (decía que
`PUBLIC` conservaba `EXECUTE` sobre las funciones) y dictaminó que el script «no
cumple» mínimo privilegio. El `REVOKE` estaba dos archivos más allá y la
verificación ejecutada lo desmentía. La lección es la misma: la IA lee lo que se
le muestra y generaliza sobre lo que no ve.

## Nota sobre la reconstrucción de la Clase 2

Los artefactos de la Clase 2 no se conservaron completos: faltaban las columnas
`email`, `password_hash`, `rol`, `fecha_alta` e `intentos_fallidos` en `usuario`,
y no existían `fn_autenticar` ni `fn_resetear_password`. Se reconstruyeron en
`sql/00_reconstruccion_clase2.sql` (columnas, datos sintéticos deterministas para
20.000 usuarios y las dos funciones `SECURITY DEFINER` con `search_path` fijo) y
la reconstrucción se verificó ejecutando las pruebas de
`docs/pruebas_funcionales_roles.txt`. No se conservó el prompt exacto de esa
reconstrucción; queda constancia del artefacto, de su ejecución y de sus
resultados.

## Revisión del historial de Git (Parte E, punto 3)

El historial del TP tiene tres commits:

| Commit | Qué contiene |
|---|---|
| `f3541da` | Primera subida de la carpeta, todavía con la versión plantilla de los informes. |
| `d037bef` | Spec de Kiro, `roles.sql`, auditoría, guion de trabajo y primera versión de C y D. |
| `6260773` | Regeneración de la evidencia de las Partes C y D. |

**El historial no refleja el avance por partes**, como pide la consigna: la Parte
A y la Parte B quedaron mezcladas en `d037bef`, y la Parte E no tiene commit
propio. Además, el primer commit subió una versión plantilla que después hubo que
reemplazar, con lo cual el repositorio conserva dos carpetas del mismo trabajo.

Qué se haría distinto la próxima vez: crear la carpeta definitiva antes del primer
commit, y commitear cada parte **al terminarla** —A con su spec y su verificación,
B con su log, C con su simulacro y su contraste, D con su equivalencia— en lugar
de agrupar varias partes en un commit de corrección. Los mensajes de los commits
existentes sí describen qué se hizo, pero llegan tarde respecto del trabajo.

## Anexo A — Prompt completo de la especificación (Kiro)

```text
Necesito una especificación (requirements + design) de roles y permisos de
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
Podés proponer roles adicionales si lo justificás.

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
- Escribí en español rioplatense, sin datos personales reales.
```

## Anexo B — Prompt completo de corrección de la spec (Kiro)

```text
Revisá la spec con estas correcciones, manteniendo el resto:
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
   agregá el riesgo de bloqueo de cuentas ajenas por intentos fallidos.
```
