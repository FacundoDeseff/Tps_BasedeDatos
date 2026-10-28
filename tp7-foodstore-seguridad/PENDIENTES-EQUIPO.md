# Pendientes del TP7 — guía para continuar

Archivo de trabajo, **no es parte de la entrega** (igual que `PROGRESO.md`: se
puede borrar antes de entregar). Sirve para que otra persona del equipo retome el
trabajo sin reconstruir el contexto.

Última actualización: 2026-10-28.

## Estado al día de hoy

| Parte | Estado |
|---|---|
| A — Roles y permisos | Completa. `roles.sql` implementado y verificado; auditoría hecha por Claude Code y **repetida con OpenCode**. |
| B — Auditoría | Completa, con una deuda: `sql/auditoria_test.sql` no refleja las sesiones ejecutadas. |
| C — Simulacro | Completa. C.4, C.5 y C.6 cerrados con la respuesta real de la IA. |
| D — Anonimización | Completa. Equivalencia verificada con `FULL JOIN`. |
| E — Bitácora y Git | Bitácora consolidada; revisión de Git escrita. Faltan commits de las limpiezas. |

Últimos commits:

```text
0a24bac  docs(tp7): reescribir la bitacora y registrar la re-auditoria A.4
39785c2  feat(tp7): completar C.4, C.5 y C.6 con la reconstruccion del log
6260773  feat(tp7): regenerar la evidencia de las Partes C y D
```

## Reglas duras para quien siga

1. **No inventar evidencia.** Si algo no se ejecutó, no se escribe como ejecutado:
   se deja marcado como pendiente y se avisa.
2. **No borrar ni renombrar archivos sin consultar.** Hay dos cosas que el equipo
   decidió no tocar todavía: la carpeta vieja `tp-foodstore-seguridad/` y
   `PROGRESO.md`.
3. **No commitear sin pedir permiso.** Primero se muestra el resumen y el mensaje
   propuesto.
4. Nada de contraseñas, logs sin anonimizar, datos personales ni rutas con el
   nombre de usuario de Windows en el repositorio.
5. Todo se ejecuta **solo contra la base local propia** (`copia_trabajo`).
   Ninguna prueba va contra sistemas de terceros.
6. Español rioplatense, con tildes.
7. Antes de cambiar algo, leer el archivo y el documento que lo justifica.

## Contexto técnico

- PostgreSQL 17.11 sobre Windows. Base `copia_trabajo`, esquema `public`, dueño
  `postgres`.
- Roles: `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`
  (NOLOGIN) + `app_web` y `admin_datos` (LOGIN).
- Funciones `SECURITY DEFINER`: `fn_autenticar(text,text)` y
  `fn_resetear_password(bigint,text)`.
- La consigna está en `docs/Trabajo Practico Unidad 5.pdf`.

Archivos clave:

- `sql/roles.sql`, `sql/00_reconstruccion_clase2.sql`, `sql/verificacion_roles.sql`
- `sql/auditoria_test.sql`, `sql/simulacro_incidente.sql`, `sql/usuario_anon.sql`
- `docs/kiro_roles_spec/requirements.md`, `docs/kiro_roles_spec/design.md`
- `docs/informe_auditoria.md`, `docs/informe_incidente.md`,
  `docs/verificacion_equivalencia.md`, `docs/auditoria_roles_sql.md`
- `docs/log_auditoria_prueba.txt`, `docs/log_simulacro_anonimizado.txt`
- `BITACORA.md`

---

## Prompt 0 — Contexto (pegar al inicio de cada sesión)

```text
Contexto: trabajo práctico de Base de Datos II (Unidad 5) sobre una base
PostgreSQL 17 llamada copia_trabajo, dueño postgres. El repo es
Tps_BasedeDatos y la entrega está en la carpeta tp7-foodstore-seguridad/.
La consigna está en tp7-foodstore-seguridad/docs/Trabajo Practico Unidad 5.pdf.

Estado: las Partes A, B, C y D están completas y con evidencia ejecutada.
La Parte E (bitácora + Git) está consolidada en BITACORA.md. Quedan deudas
menores de prolijidad, que están listadas abajo.

Archivos clave:
- sql/roles.sql, sql/00_reconstruccion_clase2.sql, sql/verificacion_roles.sql
- sql/auditoria_test.sql, sql/simulacro_incidente.sql, sql/usuario_anon.sql
- docs/kiro_roles_spec/{requirements,design}.md
- docs/informe_auditoria.md, docs/informe_incidente.md,
  docs/verificacion_equivalencia.md, docs/auditoria_roles_sql.md
- docs/log_auditoria_prueba.txt, docs/log_simulacro_anonimizado.txt
- BITACORA.md

Reglas duras:
1. No inventes evidencia. Si algo no se ejecutó, no escribas que se ejecutó:
   dejalo marcado como pendiente y avisá.
2. No borres ni renombres archivos sin preguntarme. Hay una carpeta vieja
   (tp-foodstore-seguridad/) y un PROGRESO.md que decidimos NO tocar todavía.
3. No hagas commits sin pedirme permiso.
4. Nada de contraseñas, logs sin anonimizar ni datos personales reales en el
   repo. Tampoco rutas con nombres de usuario de Windows.
5. Todo se ejecuta solo contra la base local propia. Nada de sistemas de
   terceros.
6. Escribí en español rioplatense, con tildes.
7. Antes de cambiar algo, leé el archivo y el documento que lo justifica.
```

## Prompt 1 — Alinear `sql/auditoria_test.sql` con lo ejecutado

```text
Leé docs/informe_auditoria.md, docs/log_auditoria_prueba.txt y
sql/auditoria_test.sql.

Problema: el script de auditoría no refleja lo que realmente se ejecutó. El
informe describe cinco sesiones (incluidos dos inicios de sesión fallidos),
pero el script solo deja un comentario sobre el login fallido y no reproduce
esa secuencia.

Tarea: reescribí sql/auditoria_test.sql para que, ejecutado paso a paso,
reproduzca exactamente la secuencia documentada en el informe: lectura,
inserción, actualización y login fallido, indicando en comentarios qué
sentencia va en qué sesión y con qué rol. No cambies el informe ni el log:
son evidencia de lo ya ejecutado.

Si tenés la base levantada, ejecutalo y pasame la salida; si no, dejá el
script listo y decime claramente que quedó sin ejecutar. No inventes salidas.
```

## Prompt 2 — Limpiar `docs/kiro_roles_spec/design.md`

```text
Leé docs/kiro_roles_spec/design.md, requirements.md, sql/roles.sql y
docs/verificacion_roles.txt.

Problema: el design quedó escrito antes de implementar y hay tres cosas que
hoy son falsas o ambiguas:
1. La sección final (alrededor de las líneas 383-399) dice que roles.sql "no
   se ajusta a este spec" y que "no se modifica en esta fase". roles.sql ya
   está implementado y verificado.
2. Alrededor de las líneas 176-177 quedó un "confirmar definiciones reales".
3. El design dice search_path = public, pero la implementación usa
   search_path = public, pg_temp.

Tarea: actualizá esas tres partes para que el design describa lo que
efectivamente se implementó. No cambies la matriz de permisos (es el criterio
de aceptación) y no cambies roles.sql. Si encontrás otra afirmación del design
que contradiga la implementación, listala y preguntame antes de tocarla.
```

## Prompt 3 — Sacar datos del entorno de la evidencia + README

```text
Dos tareas de prolijidad, ninguna toca la evidencia técnica.

1. En docs/pruebas_simulacro.txt aparece una ruta absoluta con el nombre de
   usuario de Windows (C:/Users/Facundo/...). Reemplazala por <repo>/... y no
   toques nada más de ese archivo: es la salida real de psql. Después revisá
   el resto de los .md y .txt de tp7-foodstore-seguridad/ y decime si hay
   otras rutas absolutas, nombres de usuario o correos que no sean sintéticos.

2. En el README.md de la raíz del repo falta el TP 7. Agregalo siguiendo el
   estilo de los seis anteriores (una línea, qué se trabajó).
```

## Prompt 4 — Decidir los hallazgos de la auditoría (esto es del equipo)

```text
Leé docs/auditoria_roles_sql.md, secciones 2 y 4. Hay diez hallazgos (H1 a
H10), casi todos con estado "pendiente de decisión".

Tarea: armame una tabla con una recomendación por hallazgo —aplicar, aceptar
el riesgo o descartar— y el motivo en una línea cada uno. Tené en cuenta que
este es un TP y que el objetivo es demostrar mínimo privilegio con evidencia,
no endurecer un servidor en producción.

No apliques nada. No modifiques roles.sql. Primero quiero ver la propuesta y
decidir con el grupo; después te pido que la ejecutes y que quede registrada
en BITACORA.md.
```

## Prompt 5 — Cierre: estado del repo y commits que falten

```text
Revisá el estado del repo (git status, git log --oneline -6) y decime:
1. si quedó algo modificado sin commitear,
2. si hay archivos nuevos que no deberían subirse (el PDF de la consigna
   tiene que quedar fuera),
3. si algún commit tiene contraseñas, logs sin anonimizar o rutas personales.

No commitees todavía: primero pasame el resumen y qué mensaje propondrías para
cada commit que falte. Cuando te lo confirme, los hacés.
```

---

## Decisiones que quedan para el grupo

| Tema | Opciones | Nota |
|---|---|---|
| Carpeta vieja `tp-foodstore-seguridad/` | Borrarla del repo / sacarla a otra carpeta | Está versionada desde `f3541da` y contradice a la nueva (dice 3 intentos, `'mod'`, etc.). Un corrector puede abrirla por error. |
| `PROGRESO.md` | Borrarlo antes de entregar / reescribirlo / dejarlo | Él mismo dice que se puede borrar. Hoy está desactualizado (dice que D no empezó). |
| Hallazgos H1 a H10 | Aplicar / aceptar / descartar | Ver `docs/auditoria_roles_sql.md` §2 y §4. `H10` (`PUBLIC` conserva `USAGE` sobre el esquema) es el único nuevo. |
| Historial de Git | Dejarlo y sostener la nota de E.3 / reescribirlo | La nota de qué se haría distinto ya está en `BITACORA.md`. Reescribir el historial cambiaría los hashes. |

## Checklist antes de entregar

- [ ] Los siete archivos de `sql/` y `docs/` de la consigna existen y están al día
- [ ] `sql/auditoria_test.sql` refleja la secuencia ejecutada (Prompt 1)
- [ ] `design.md` no contradice la implementación (Prompt 2)
- [ ] No hay rutas personales ni correos reales en la evidencia (Prompt 3)
- [ ] `BITACORA.md` tiene los registros de las Partes A a D y el caso significativo
- [ ] No hay contraseñas ni logs sin anonimizar en el repositorio
- [ ] El PDF de la consigna quedó fuera del repo
- [ ] Al menos un commit por parte, con mensajes legibles
- [ ] Auditoría del servidor devuelta a su estado normal (`ALTER SYSTEM RESET ...`)
- [ ] Todo se ejecutó sólo contra la base propia (`copia_trabajo`)
