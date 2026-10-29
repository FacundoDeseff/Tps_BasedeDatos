# Bitácora de uso de IA — TP Unidad 6 (Mantenimiento, respaldo y recuperación)

Registro de las interacciones con asistentes de IA durante el trabajo, en el formato de
tres columnas que pide la consigna: **prompt enviado**, **respuesta relevante (resumida)**
y **validación o corrección humana aplicada**.

Herramienta usada por el equipo: **OpenCode** sobre Windows, con PostgreSQL 17.11. El puerto
por defecto del equipo es 5433 (máquina de Matías); en las máquinas de Santi y de Facu
Ramirez el servidor escucha en 5432, así que cada corrida pasa `-Port` explícito y lo deja
registrado en su evidencia. La consigna y `AGENTS.md` se usaron como especificación de
entrada.
Ninguna credencial se pasó por prompt ni quedó en archivos versionados: la autenticación
se resuelve con `%APPDATA%\postgresql\pgpass.conf`.

> **Cómo se completa esta bitácora.** Cada integrante registra **su propio** prompt, la
> respuesta que recibió y la verificación que hizo en su máquina. No se copia la fila de
> otro ni se registra trabajo que no se ejecutó. Un script que no se probó, incluido su
> camino de error, no se anota como validado.

## Registros por integrante

### Matías — Especificación, reconstrucción de la base e informe (Partes 1 y 5)

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| «La base `foodstore` la creé hace poco, no sé si está bien; creala de nuevo bien. Credencial local `localhost:5433`, usuario `postgres`.» | Relevó el esquema canónico del proyecto, detectó que la base tenía el doble de pedidos de los esperados y propuso reconstruirla desde cero con un dump de seguridad previo. Generó `sql/00_reconstruccion_foodstore.sql` con esquema, índices y carga reproducible (`setseed(0.42)`). | Se **aceptó** la reconstrucción. Antes de borrar se ejecutó `pg_dump -Fc` a un archivo fuera del repositorio. Después se verificaron conteos (11 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos, 400.000 detalles), 0 productos o detalles inválidos, 0 pedidos sin detalle y 0 totales descuadrados. Evidencia: `docs/i1_reconstruccion_*.txt`. |
| «Actualizá `SPEC_U6.md` con la frecuencia y la condición de finalización de cada tarea.» | Agregó a la especificación la tabla de tareas con frecuencia (diaria, semanal, mensual, trimestral) y el criterio que permite cerrar cada una. | Se **revisó** contra la consigna y se corrigieron los nombres de columnas al esquema real (`usuario`, `precio_lista`, `subtotal`); la adaptación quedó documentada en la sección 5 del `SPEC_U6.md`. |
| «Armá el informe final del TP con los números de las cuatro partes y exportalo a PDF.» | Comenzó con la plantilla de 8 bloques de `informe_u6.md` y la completó con los datos crudos de `docs/i1_*` a `docs/i4_*`: respaldo usado (nombre, tamaño, SHA-256 y 33 objetos), simulacro (comando, T0/T1 y base destino), RTO/RPO, tabla de validaciones, un problema real por integrante, la mejora propuesta y el resumen de la intervención de la IA. Generó `informe_u6.pdf` con `python scripts/generar_informe_pdf.py`. | Se **contrastó número por número** contra la evidencia: RTO 16,7 s y RPO 29 min 54 s contra `docs/i4_simulacro_*`; conteos e integridad contra el mismo archivo; dump y hash contra `docs/i2_backup_20261028_2008.txt`; muertes y `VACUUM` contra `docs/i3_*`. Se corrigieron tres cosas: el puerto del entorno (5432 en la máquina de ejecución, no 5433), el tamaño de la base (102 MB, no 105 MB) y dos símbolos (`≤`, `→`) que la fuente del PDF no renderiza. El PDF final tiene 2 páginas y no quedan bloques «completar». |

### Santi — Respaldo automatizable (Parte 2)

Prompt enviado: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/backup_foodstore.ps1`
para Windows con `pg_dump -Fc`, nombre `foodstore_YYYYMMDD_HHMM.dump`, escritura en `.parcial`
con rename sólo si termina bien, log en `logs/`, salida con error si falla y sin contraseñas.
Después ejecutalo contra `foodstore` y mostrame el dump y el log.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/backup_foodstore.ps1`… (prompt completo arriba)» | Escribió el script con parámetros `-Server -Port -User -Database -PgBin -BackupDir -LogDir -Retention`: `pg_dump -Fc --no-password` a `*.dump.parcial`, rename sólo con código 0, log por día en `logs/backup_YYYYMMDD.log` con `RESULTADO=OK/ERROR`, verificación con `pg_restore -l`, SHA-256 y retención de los últimos N `.dump`. Detectó que en PowerShell 5.1 un exit code distinto de 0 de un `.exe` **no** dispara `try/catch`, así que el script chequea `$LASTEXITCODE` y baja `$ErrorActionPreference` alrededor de las llamadas nativas para que el `stderr` de `pg_dump` no se convierta en excepción. | Se **revisó** línea por línea antes de ejecutar: ningún `VACUUM`, ningún `DROP`, ninguna contraseña, `$ErrorActionPreference = 'Stop'`, `--no-password` y `.parcial` limpiado en `catch` y en `finally`. Se verificó que `backups/`, `logs/` y `*.parcial` sigan en `.gitignore` (`git check-ignore -v`). |
| «Ejecutalo y probá también el camino de error.» | Propuso `-Port 5999` para el fallo y `-Port 5432` para la corrida real. | **Camino de error** (`-Port 5999`, `-BackupDir` aislado): `EXITCODE=1`, `RESULTADO=ERROR parcial=eliminado`, **0** archivos `.dump` y **0** `.parcial` en la carpeta; sólo quedó el log. **Corrida real** (`-Port 5432`): `EXITCODE=0`, `RESULTADO=OK`, `foodstore_20261028_2008.dump` de 8,94 MB (9.378.143 bytes), `pg_restore -l OK` con 33 objetos y las 5 tablas, SHA-256 `DA38B10B7C0F87D3EF3D018809543E80406B08A20EA702E3933B96C110BE096D` recalculado aparte con `Get-FileHash` y coincidente con el del log. **Retención** (`-Retention 7`): con 8 `.dump` simulados más el nuevo conservó 7 y borró los 2 más viejos. Evidencia vigente: `docs/i2_backup_20261028_2008.txt`; la de `1656` quedó **obsoleta** y se conserva sin editar como registro histórico. |
| «La base no existía en mi máquina; verificala antes de respaldar.» | Indicó que en esta máquina PostgreSQL 17.11 escucha en **5432**, no en 5433, y que `foodstore` no estaba creada. | Se creó `foodstore` y se ejecutó `sql/00_reconstruccion_foodstore.sql` con `ON_ERROR_STOP=1`: 11 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos, 400.000 detalles, 102 MB (idéntico a `docs/i1_*`), y recién después se corrió el respaldo. |

**Errores reales detectados y corregidos.** (1) La primera versión de la evidencia volcaba la
salida completa de `pg_restore -l` en una sola línea y mezclaba los restos del camino de error
con la carpeta real de respaldos, con lo que no se podía asegurar si el fallo había dejado un
archivo: se aisló la prueba de error en un directorio temporal y se unió la salida línea por
línea. (2) El `-Port` por defecto del SPEC (5433) no corresponde a esta máquina (5432): se
mantiene el default del equipo y se pasa el puerto explícito, documentado en la evidencia.
(3) La `foodstore` de la máquina donde se regeneró la evidencia estaba vacía y con el esquema
viejo (sin tabla `usuario`): un respaldo en ese estado habría sido inútil. Se detectó con los
conteos previos, se reconstruyó con `sql/00_reconstruccion_foodstore.sql` y recién entonces se
respaldó; el detalle crudo quedó en el anexo de la evidencia de 2008.

### Facu Deseff — Monitoreo y mantenimiento (Parte 3)

Prompt sugerido: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `sql/health_check.sql` con
los 4 controles de la consigna y `sql/maintenance.sql` con revisión de autovacuum y una acción
justificada, sin `VACUUM FULL`. Después ejecutá el ciclo completo: health check, generación de
tuplas muertas, health check, mantenimiento y health check final.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| «Auditá las Partes 1 y 2 antes de que empiece la mía.» | Encontró un error **crítico** en `sql/00_reconstruccion_foodstore.sql`: hacía `DROP TABLE ... CASCADE` sobre `foodstore`, en contra de `AGENTS.md` y de la regla 1 del SPEC; el `CASCADE` habría arrastrado objetos de TP5/TP7 que el script no recrea. En el script de respaldo encontró que el `LogPath` se asignaba tarde (los fallos tempranos quedaban sin log), que el `.dump` se renombraba **antes** de verificarlo con `pg_restore -l`, y que la retención con el filtro `foodstore_*.dump` podía borrar dumps de otra base. | Se **aceptó** el diagnóstico y se corrigió antes de seguir. La reconstrucción ahora tiene guardia: si el esquema ya existe **aborta sin borrar nada** y solo limpia con `-v reset=1` explícito, y aun así sin `CASCADE`. Se re-ejecutó contra `foodstore` en mi máquina: 11/20.000/50.000/200.000/400.000, 0 inválidos, 102 MB. La segunda corrida sin `reset` devolvió `ERROR: ABORTADO...` con exit 3 y los datos intactos. |
| «Aplicá los fixes del respaldo y re-probalo, incluidos los caminos de error.» | Reordenó el script (log primero, validación después), movió la verificación con `pg_restore -l` **antes** del rename, ancló la retención con regex `^<base>_\d{8}_\d{4}\.dump$` excluyendo el dump recién creado, hizo el log tolerante a fallos con respaldo en `%TEMP%`, pasó los nombres a cultura invariante, resolvió `PgBin` desde el PATH y agregó `PGCONNECT_TIMEOUT` y `--lock-wait-timeout`. | Se **verificaron con cinco corridas** en directorios aislados: (A) puerto 5999 → exit 1, `RESULTADO=ERROR`, 0 `.dump` y 0 `.parcial`; (B) `-Retention 0` → exit 1 **y ahora sí deja log** (antes no dejaba); (C) `-PgBin` inválido → exit 1 con log; (D) retención con 5 respaldos viejos + 2 señuelos `foodstore_restore_test_*` → borró los 3 más viejos de `foodstore` y **conservó los 2 señuelos**; (E) `PgBin` sin `pg_restore` → el dump **no** queda como `.dump`, se descarta el `.parcial`. Corrida real: `foodstore_20261028_1814.dump`, 8,94 MB, 33 objetos, tablas verificadas. |
| «Generá `sql/health_check.sql` con los 4 controles de la consigna y `sql/maintenance.sql` con revisión de autovacuum y una acción justificada, sin `VACUUM FULL`; después ejecutá el ciclo completo.» | Escribió el health check con los 4 controles pedidos más un quinto control propio (cache hit, locks sin conceder y transacción abierta más antigua), cada uno con columna `ESTADO` (`OK`/`ALERTA`), y el mantenimiento con observación de `last_autovacuum`/`last_autoanalyze`, decisión por tabla y ejecución selectiva vía `\gexec`. | Se **revisó y se corrigió**: la primera versión del health check incluía una columna `indice_menos_heap` calculada como `pg_indexes_size - pg_relation_size`, una métrica inventada que daba valores negativos sin significado (detectado al ver la primera salida); se eliminó. Se agregó el umbral absoluto de 10.000 tuplas muertas para no depender solo del porcentaje en tablas chicas. |
| «Ejecutá el ciclo: health check, tuplas muertas, health check, mantenimiento y health check final.» | Generó `sql/03_churn_controlado.sql` con `UPDATE` controlado (no `DELETE`) para dejar versiones muertas sin romper restricciones, y propuso la secuencia de cuatro evidencias. | **Antes:** 0 tuplas muertas, todo `OK`. **Con muertas:** `pedido` 160.000/200.000 y `producto` 40.000/50.000 → 44,44 % en ambas, `estado=ALERTA`, resumen `ATENCION: ejecutar maintenance.sql`. **Mantenimiento:** eligió `VACUUM (ANALYZE)` solo en esas dos tablas (el resto quedó `sin accion`), sin `VACUUM FULL`. **Después:** 0 tuplas muertas, `last_vacuum` y `last_analyze` de 18:17:08, `estado=OK` y resumen `OK: sin acciones de mantenimiento requeridas`. Integridad posterior: 0 productos inválidos, 0 detalles inválidos, 0 totales descuadrados. Evidencia: `docs/i3_*_20261028_1816.txt`. |

**Errores reales detectados en esta parte.** (1) El `DROP TABLE ... CASCADE` de la reconstrucción, que habría borrado objetos fuera del alcance del TP8: se reemplazó por una guardia que aborta sin tocar nada. (2) El respaldo daba por bueno un dump que todavía no había sido verificado: la verificación se movió antes del rename. (3) En mi propio health check inventé una columna de tamaño de índices mal calculada (`pg_indexes_size - pg_relation_size`), que devolvía negativos: la saqué al ver la primera corrida. (4) El `UPDATE` masivo del churn podía haber roto el invariante `pedido.total = SUM(subtotal)` si se tocaba `detalle_pedido`; se decidió explícitamente no tocar esa tabla y el script valida la integridad al final.

**Justificación de la mejora (control 5/5, cinco líneas).** Los cuatro controles de la consigna muestran el síntoma (tuplas muertas, sesiones), pero no dos causas frecuentes de degradación: un cache hit bajo indica lecturas a disco evitables y suele anticipar falta de memoria o estadísticas viejas; los locks sin conceder dejan consultas esperando y, si se acumulan, terminan frenando al propio `VACUUM`; y una transacción abierta demasiado tiempo (o `idle in transaction`) impide que `VACUUM` recupere las filas que esa transacción todavía puede ver, así que el mantenimiento no surte efecto hasta que se cierra. Medir los tres en el mismo chequeo diario permite detectar la causa antes de que se convierta en el síntoma. Los umbrales son explícitos y están declarados al inicio del script: cache hit > 99 %, 0 locks sin conceder y ninguna transacción de más de 5 minutos.

### Facu Ramirez — Restauración y RTO/RPO (Parte 4)

Prompt sugerido: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/restore_test.ps1`
y las validaciones SQL para restaurar el último `.dump` en `foodstore_restore_test` con
`pg_restore --no-owner --no-privileges`, validar conteos e integridad y medir RTO y RPO. El
script no debe poder tocar `foodstore`.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/restore_test.ps1`… (prompt completo arriba)» | Escribió el script con la base destino como **constante** `foodstore_restore_test` (sin parámetro `-Database`, para que no pueda apuntar a `foodstore`), pre-flight del dump (`Test-Path`, tamaño > 0, `pg_restore -l` y verificación de las 5 tablas), `dropdb --if-exists` + `createdb` sólo sobre esa constante y `pg_restore --no-owner --no-privileges --exit-on-error`. Agregó `sql\validaciones_restore.sql` (reporte de 7 bloques) y `sql\validaciones_restore_check.sql` (una línea `PASS` o `FALLA:motivo`) y calculó RTO (T0 justo antes del `createdb` → T1 al terminar la validación) y RPO (antigüedad del dump en T0). | Se **revisó y se ejecutó**. **Simulacro** (`.\scripts\restore_test.ps1 -Port 5432`): `EXITCODE=0`, `validacion=PASS`, conteos 11 / 20.000 / 50.000 / 200.000 / 400.000, 0 inválidos, 0 huérfanas, 0 totales descuadrados y secuencias al día. **RTO 16,7 s** y **RPO 29 min 54 s**. Después se verificó aparte que `foodstore` seguía con los mismos conteos y `PASS`. Evidencia: `docs/i4_simulacro_20261028_2038.txt`. |
| «Hacé la prueba negativa: rompé una restricción en `foodstore_restore_test`, dejá un valor inválido y confirmá que el chequeo devuelva `FALLA:...`.» | Propuso `ALTER TABLE producto DROP CONSTRAINT producto_precio_lista_check` y después un `INSERT` con `precio_lista = -1`. | **Corrección humana:** el `INSERT` hacía fallar primero el control de conteos (`FALLA:conteos(producto=50001/50000)`) y **enmascaraba** el control que se quería probar. Se cambió a `UPDATE` sobre una fila existente: los conteos no cambian y el resultado es `FALLA:productos_invalidos=1`, que es el esperado. Se volvió a correr el script y la base quedó en `PASS`. Evidencia: `docs/i4_prueba_negativa_20261028_2038.txt`, secciones A–C. |
| «Probá escenarios de falla del restore y documentá qué deja en disco.» | Propuso tres casos: `-DumpFile` inexistente, dump ilegible de 100 bytes y dump truncado a 1 MB. Advirtió que el truncado no lo detecta el pre-flight. | **Inexistente:** `EXITCODE=1` y 0 bases creadas. **Ilegible (100 bytes):** `pg_restore -l` falla, el pre-flight aborta y 0 bases creadas. **Truncado (1 MB):** el pre-flight lo acepta porque el TOC está al inicio; `pg_restore` falla al leer los datos (`could not read from input file: end of file`), deja las 5 tablas creadas pero sólo `categoria` con sus 11 filas (14 MB) y el chequeo devuelve `FALLA:conteos(...usuario=0/20000...)`: una restauración parcial nunca pasa la validación. Se reconstruyó a `PASS`. Detalle crudo: secciones D–G de la misma evidencia. |

**Errores reales detectados en esta parte.** (1) El `INSERT` de la prueba negativa cambiaba los
conteos y disparaba el control de conteos antes que el que se quería demostrar: se reemplazó
por un `UPDATE` para aislar `FALLA:productos_invalidos=1`. (2) Se daba por hecho que un dump
truncado se detectaba en el pre-flight con `pg_restore -l`; no es así porque el TOC del formato
custom está al inicio del archivo y el corte se descubre recién al leer los datos. Se dejó
documentado y se comprobó que el chequeo de conteos sí lo frena: la restauración parcial queda
en `FALLA:conteos`. (3) El script deja la base parcial para inspección en vez de borrarla: se
decidió así para poder mostrar qué queda en disco, y el `EXITCODE=1` impide que el fallo pase
inadvertido.

**Traspaso a Matías (Parte 5).** Números para el informe: RTO observado **16,7 s** (previsto
≤ 300 s) y RPO observado **29 min 54 s** (previsto ≤ 24 h, con respaldo diario a las 03:00);
`PASS` en las 8 validaciones, conteos 11 / 20.000 / 50.000 / 200.000 / 400.000 y 33 objetos en
el dump `foodstore_20261028_2008.dump` (8,94 MB, SHA-256 `DA38B10…BE096D`).

---

## Reglas de verificación del equipo

- **Ningún script se acepta sin ejecutarlo**, incluido su camino de error. Un script que
  sólo se leyó no cuenta como validado.
- La validación humana se registra con el comando ejecutado y el resultado observado, no
  con una afirmación genérica del tipo «funciona».
- Toda prueba destructiva va **exclusivamente** sobre `foodstore_restore_test`.
- Cada integrante documenta al menos un error real de su parte y cómo lo detectó.
