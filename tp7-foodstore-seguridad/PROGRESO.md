# TP7 - Registro de avance y guía para terminar

Archivo de trabajo, no es parte de la entrega (se puede borrar antes de entregar).
Última actualización: 2026-10-27, al terminar el simulacro de la Parte C (hasta C.3).
Base: `copia_trabajo`, PostgreSQL 17.11, Windows.

## 1. Dónde estamos

| Parte | Estado | Qué falta |
|---|---|---|
| **A** Roles y permisos | Hecha, con evidencia | Decidir sobre los hallazgos H1 a H7; registrar en la bitácora |
| **B** Auditoría | Hecha, con evidencia | Confirmar una afirmación del informe (punto 4); apagar la auditoría al final |
| **C** Simulacro | C.1, C.2 y C.3 hechos | C.4 (IA), C.5 (contraste), C.6 (contención); reescribir informe y script |
| **D** Anonimización | No empezada | Todo; `usuario_anon.sql` y `verificacion_equivalencia.md` están desactualizados |
| **E** Bitácora y Git | No empezada | Reescribir `BITACORA.md`; commits por parte |

### Archivos de la entrega

| Archivo | Estado |
|---|---|
| `sql/roles.sql` | Listo, ejecutado y verificado |
| `sql/auditoria_test.sql` | **Desactualizado**: no refleja lo que se ejecutó (sesiones por rol) |
| `sql/simulacro_incidente.sql` | **Desactualizado**: falta la secuencia real |
| `sql/usuario_anon.sql` | **Desactualizado**: sólo agrupa por `eliminado` |
| `docs/kiro_roles_spec/` | Listo (con las correcciones) |
| `docs/informe_auditoria.md` | Listo |
| `docs/log_auditoria_prueba.txt` | Listo |
| `docs/log_simulacro_anonimizado.txt` | Listo |
| `docs/informe_incidente.md` | **Desactualizado**: es una plantilla |
| `docs/verificacion_equivalencia.md` | **Desactualizado** |
| `BITACORA.md` | **Genérica**: las filas actuales no son registros reales |

### Archivos extra creados (apoyan la entrega)

`sql/00_reconstruccion_clase2.sql`, `sql/verificacion_roles.sql`,
`docs/verificacion_roles.txt`, `docs/pruebas_funcionales_roles.txt`,
`docs/auditoria_roles_sql.md`.

## 2. Qué se hizo, en orden

1. **Revisión inicial** de la carpeta contra la consigna: faltaban logs, evidencia
   ejecutada y bitácora real; los informes estaban en futuro ("se debe...").
2. **Estado de la base**: faltaban `email`, `password_hash`, `rol`, `fecha_alta`
   e `intentos_fallidos` en `usuario`, y no existían `fn_autenticar` ni
   `fn_resetear_password`. Faltaba la vista `v_usuarios_seguros` (TP5).
   Las tablas de `control_lote` y `mv_top_categorias_diarias` (TP6) siguen sin
   crearse; no son necesarias para el TP7.
3. **Spec en Kiro** (requirements + design), corregida tras detectar tres errores
   de la IA (ver sección 4).
4. **Reconstrucción** (`00_reconstruccion_clase2.sql`): columnas nuevas, datos
   sintéticos deterministas (20.000 usuarios, 400 admins, altas repartidas en 24
   meses) y las dos funciones `SECURITY DEFINER`.
5. **`roles.sql`** reescrito según la spec; verificado con `\du`,
   `role_table_grants`, `column_privileges` y `pg_default_acl`.
6. **Pruebas funcionales** de los seis roles.
7. **Auditoría de `roles.sql`** (hecha por Claude Code, no por OpenCode).
8. **Parte B**: `log_connections`, `log_disconnections`, `log_statement='all'` y
   `log_line_prefix` activados; secuencia de prueba en cinco sesiones; log
   guardado e informe reescrito.
9. **Parte C**: un primer intento falló (se ejecutó como `postgres`); se repitió
   como `app_web`; el escalamiento falló como debía; el log se anonimizó.

## 3. Decisiones y desvíos respecto de la consigna y la spec

| Tema | Decisión |
|---|---|
| Auditoría de `roles.sql` | La hizo Claude Code, no OpenCode. Debe constar así en la bitácora |
| `log_statement` | `'all'` y no `'mod'`, para que queden registrados los `SELECT` del simulacro |
| `admin_datos` sobre `usuario` | `SELECT` e `INSERT` por columna, sin `password_hash` (la spec decía a nivel de tabla) |
| `REFRESH` de la vista materializada | `GRANT MAINTAIN` (PostgreSQL 17) |
| `REVOKE EXECUTE ... FROM PUBLIC` por defecto | Global, porque PostgreSQL no permite hacerlo `IN SCHEMA` |
| `fn_autenticar` | Devuelve `'cuenta_bloqueada'` con 5 o más intentos; el umbral y el aviso son decisión de diseño |
| Anonimización del log | Se reemplazaron emails y claves; se conservaron nombres de rol, base de datos, `::1` y horas (ver `PROGRESO` sección 5, C.3) |
| Contraseñas | `app_web` y `admin_datos` se definieron con `\password`; no figuran en ningún archivo. El usuario 2 tiene una clave de prueba sintética |

## 4. Errores reales detectados (material para la bitácora)

| # | Error | Quién | Cómo se detectó |
|---|---|---|---|
| 1 | Primera versión de `roles.sql`: `SELECT` completo sobre `usuario` para soporte, secuencias `ALL`, `SELECT` por defecto | IA | Lectura contra la matriz de mínimo privilegio |
| 2 | Defaults de `ALTER DEFAULT PRIVILEGES` más amplios que la matriz | Kiro | Cotejo de la spec con su propia matriz |
| 3 | "`RETURNING` no necesita `SELECT`": falso | Kiro | Contraste con el funcionamiento de PostgreSQL; confirmado con `INSERT ... RETURNING id_pedido` (devolvió 200001) |
| 4 | `SELECT(id_usuario)` "condicional" y `crypt` "de tiempo constante" | Kiro | Revisión de la spec |
| 5 | Prueba de soporte `SET email = email` (lee la columna) | Claude Code | La ejecución dio `permiso denegado` |
| 6 | Se esperaba `t` en `fn_resetear_password(1, ...)`; el usuario 1 está eliminado | Claude Code | Resultado `f` y razonamiento |
| 7 | `admin_datos` con `INSERT` general permitía saltear el hasheo | Spec / Claude Code | Contraste con el objetivo de la propia spec |
| 8 | Simulacro ejecutado como `postgres`, no como `app_web` | Equipo | El campo `user=postgres` del log; se descartó el intento y se repitió |

**Candidato a caso más significativo (Parte E.2): el 3.** La IA afirmó con seguridad
algo falso y la consecuencia habría sido una aplicación que no puede registrar pedidos.
El 8 es un buen caso complementario de error humano detectado gracias a la auditoría.

## 5. Guía para completar lo que falta

### 5.0 Sobre OpenCode (límite diario agotado)

Hay tres usos pendientes: auditar `roles.sql` (A.4), analizar el log (C.4) y
generar la consulta equivalente (D.2). Opciones:

1. **Esperar a que se reinicie el límite** (recomendado): es lo que pide la
   consigna. Se puede avanzar con el resto mientras tanto.
2. **Usar otro asistente** en una conversación nueva, sin contexto previo. Si se
   elige esta vía, la bitácora debe decir cuál se usó y por qué (OpenCode no
   estaba disponible). No ocultar el cambio.

En ambos casos: nunca pasarle datos reales ni contexto extra, y guardar prompt y
respuesta completos y sin editar.

### 5.1 Parte C: terminar

1. **C.4**: en una conversación nueva con la IA elegida, enviar este prompt seguido
   del contenido completo de `docs/log_simulacro_anonimizado.txt`:
   ```text
   Este es un fragmento de log de un servidor PostgreSQL. Reconstruí qué ocurrió
   y proponé una hipótesis de contención.
   ```
   No agregar nada más. Guardar la respuesta completa en
   `docs/respuesta_ia_simulacro.md`. No ejecutar lo que sugiera.
2. **C.5**: pegar la respuesta a Claude Code para armar el contraste. Qué se
   busca: qué acertó, qué omitió y qué afirma que el log no sustenta. Hechos que
   el log sí prueba: usuario `app_web`; cinco llamadas a `fn_autenticar` con el
   mismo email y claves distintas; `SELECT *` y `SELECT count(*)` sobre `usuario`
   denegados; dos `GRANT admin_datos` denegados (a `app_web` y a `rol_soporte`);
   sesión de 40 segundos, origen local. Hechos que el log **no** prueba: cuál
   `fn_autenticar` tuvo éxito (no registra resultados), si hubo filtración de
   datos (las lecturas fallaron), la intención o identidad del actor, el método
   de acceso a la credencial.
3. **C.6**: redactar la decisión de contención como decisión **del equipo**, a
   partir de la evidencia. Debe decir qué se haría en un caso real (por ejemplo
   revisar y rotar la credencial de `app_web`, revisar el origen, verificar que
   ningún rol tenga membresía en `admin_datos`, revisar `intentos_fallidos`) y
   dejar claro que no se ejecutó nada automáticamente por lo que dijo la IA.
4. Reescribir `docs/informe_incidente.md` (ver contenido en la sección 6) y
   `sql/simulacro_incidente.sql` con la secuencia real, indicando que se ejecuta
   conectado como `app_web`.

### 5.2 Parte D: anonimización y equivalencia

1. Pedir a Claude Code que reescriba `sql/usuario_anon.sql`. Debe conservar lo que
   no identifica y se necesita para agregar (`rol`, mes de alta, `eliminado`) y
   reemplazar nombre, apellido y email por valores sintéticos deterministas
   (patrón `Usuario_00000002`). La tabla actual en la base se recrea con
   `DROP TABLE IF EXISTS`.
2. Ejecutarlo como `postgres`.
3. **D.2** con la IA (sin datos reales): pedir una consulta de agregación sobre
   `usuario_anon` (cantidad de usuarios por rol y por mes de alta) y la consulta
   equivalente sobre `usuario`. Guardar prompt y respuesta.
4. **D.3**: ejecutar ambas y comparar. Guardar los dos resultados lado a lado en
   `docs/verificacion_equivalencia.md`. Conviene comprobarlo también con un
   `FULL JOIN` que debe devolver cero diferencias.
5. **D.4**: redactar 2 o 3 oraciones sobre qué datos no deben salir hacia una IA
   sin anonimizar (nombres, apellidos, emails, claves o hashes, logs sin anonimizar,
   direcciones de origen).

### 5.3 Parte E: cierre

1. **`BITACORA.md`**: reescribirla con la tabla de tres columnas (prompt, respuesta
   resumida, validación humana) usando los registros reales de la sección 4 y los
   de las Partes C y D. Incluir: la nota de que se reconstruyeron los artefactos de
   la Clase 2 (consigna), que la auditoría de `roles.sql` la hizo Claude Code, el
   párrafo del caso más significativo (E.2) y una nota sobre el historial de Git
   (E.3).
2. **Git**: hoy hay un único commit y la carpeta nueva está sin versionar. Hacer
   commits por parte, por ejemplo:
   ```bash
   git add -A tp-foodstore-seguridad tp7-foodstore-seguridad   # registra el cambio de nombre
   git commit -m "docs(tp7): spec de Kiro y roles de minimo privilegio (parte A)"
   ```
   y luego uno por cada parte B, C, D y bitácora. Antes de cada commit revisar
   `git status`: no deben entrar logs reales ni contraseñas.
3. Si el historial no queda prolijo, anotar en la bitácora qué se haría distinto.

### 5.4 Pendientes menores

- Comprobar que el log del servidor se lee sin permisos de administrador (abrirlo
  en el Bloc de notas). El informe de la Parte B lo afirma en el punto 4.
- Decidir sobre los hallazgos H1 a H7 de `docs/auditoria_roles_sql.md`
  (aplicar, o documentar por qué no).
- Actualizar `sql/auditoria_test.sql` con las sesiones que se ejecutaron.
- Al terminar, volver la auditoría a su estado normal:
  ```sql
  ALTER SYSTEM RESET log_statement;
  ALTER SYSTEM RESET log_connections;
  ALTER SYSTEM RESET log_disconnections;
  ALTER SYSTEM RESET log_line_prefix;
  SELECT pg_reload_conf();
  ```
  (o dejar `log_statement = 'mod'`).
- Opcional: borrar este archivo antes de entregar.

## 6. Contenido previsto de `docs/informe_incidente.md`

1. Secuencia ejecutada (con horas) y resultado real de cada paso.
2. Verificación del escalamiento (C.2): falló, mensaje exacto, dos sentencias.
3. Nota sobre el primer intento fallido (ejecutado como `postgres`).
4. Criterio de anonimización: tabla de reemplazos y datos conservados con motivo.
5. Respuesta de la IA (referencia al archivo) y contraste (C.5).
6. Decisión de contención del equipo (C.6).

## 7. Lista de verificación final

- [ ] Los siete archivos de `sql/` y `docs/` de la consigna existen y están al día
- [ ] `BITACORA.md` tiene registros reales, el caso más significativo y la nota de Git
- [ ] No hay contraseñas ni logs sin anonimizar en el repositorio
- [ ] Al menos un commit por parte, con mensajes legibles
- [ ] Todo se ejecutó sólo contra la base propia (`copia_trabajo`)
