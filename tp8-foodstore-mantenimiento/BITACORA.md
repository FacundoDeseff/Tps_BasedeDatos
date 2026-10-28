# Bitácora de uso de IA — TP Unidad 6 (Mantenimiento, respaldo y recuperación)

Registro de las interacciones con asistentes de IA durante el trabajo, en el formato de
tres columnas que pide la consigna: **prompt enviado**, **respuesta relevante (resumida)**
y **validación o corrección humana aplicada**.

Herramienta usada por el equipo: **OpenCode** sobre Windows, con PostgreSQL 17.11 local en
el puerto 5433. La consigna y `AGENTS.md` se usaron como especificación de entrada.
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
| _(pendiente)_ Redacción del informe final con los números de Santi, Facu Deseff y Facu Ramirez. | _(pendiente)_ | _(pendiente: contrastar RTO/RPO y conteos contra `docs/i4_*`)_ |

### Santi — Respaldo automatizable (Parte 2)

Prompt enviado: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/backup_foodstore.ps1`
para Windows con `pg_dump -Fc`, nombre `foodstore_YYYYMMDD_HHMM.dump`, escritura en `.parcial`
con rename sólo si termina bien, log en `logs/`, salida con error si falla y sin contraseñas.
Después ejecutalo contra `foodstore` y mostrame el dump y el log.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/backup_foodstore.ps1`… (prompt completo arriba)» | Escribió el script con parámetros `-Server -Port -User -Database -PgBin -BackupDir -LogDir -Retention`: `pg_dump -Fc --no-password` a `*.dump.parcial`, rename sólo con código 0, log por día en `logs/backup_YYYYMMDD.log` con `RESULTADO=OK/ERROR`, verificación con `pg_restore -l`, SHA-256 y retención de los últimos N `.dump`. Detectó que en PowerShell 5.1 un exit code distinto de 0 de un `.exe` **no** dispara `try/catch`, así que el script chequea `$LASTEXITCODE` y baja `$ErrorActionPreference` alrededor de las llamadas nativas para que el `stderr` de `pg_dump` no se convierta en excepción. | Se **revisó** línea por línea antes de ejecutar: ningún `VACUUM`, ningún `DROP`, ninguna contraseña, `$ErrorActionPreference = 'Stop'`, `--no-password` y `.parcial` limpiado en `catch` y en `finally`. Se verificó que `backups/`, `logs/` y `*.parcial` sigan en `.gitignore` (`git check-ignore -v`). |
| «Ejecutalo y probá también el camino de error.» | Propuso `-Port 5999` para el fallo y `-Port 5432` para la corrida real. | **Camino de error** (`-Port 5999`, `-BackupDir` aislado): `EXITCODE=1`, `RESULTADO=ERROR`, **0** archivos `.dump` y **0** `.parcial` en la carpeta; sólo quedó el log. **Corrida real** (`-Port 5432`): `EXITCODE=0`, `RESULTADO=OK`, `foodstore_20261028_1656.dump` de 8,94 MB (9.378.194 bytes), 33 objetos listados por `pg_restore -l`, SHA-256 `0FCF7C42…9432FA136` recalculado aparte con `Get-FileHash` y coincidente. **Retención** (`-Retention 7`): con 8 `.dump` simulados más el nuevo conservó 7 y borró los 2 más viejos. Evidencia cruda: `docs/i2_backup_20261028_1656.txt`. |
| «La base no existía en mi máquina; verificala antes de respaldar.» | Indicó que en esta máquina PostgreSQL 17.11 escucha en **5432**, no en 5433, y que `foodstore` no estaba creada. | Se creó `foodstore` y se ejecutó `sql/00_reconstruccion_foodstore.sql` con `ON_ERROR_STOP=1`: 11 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos, 400.000 detalles, 102 MB (idéntico a `docs/i1_*`), y recién después se corrió el respaldo. |

**Errores reales detectados y corregidos.** (1) La primera versión de la evidencia volcaba la
salida completa de `pg_restore -l` en una sola línea y mezclaba los restos del camino de error
con la carpeta real de respaldos, con lo que no se podía asegurar si el fallo había dejado un
archivo: se aisló la prueba de error en un directorio temporal y se unió la salida línea por
línea. (2) El `-Port` por defecto del SPEC (5433) no corresponde a esta máquina (5432): se
mantiene el default del equipo y se pasa el puerto explícito, documentado en la evidencia.

### Facu Deseff — Monitoreo y mantenimiento (Parte 3)

Prompt sugerido: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `sql/health_check.sql` con
los 4 controles de la consigna y `sql/maintenance.sql` con revisión de autovacuum y una acción
justificada, sin `VACUUM FULL`. Después ejecutá el ciclo completo: health check, generación de
tuplas muertas, health check, mantenimiento y health check final.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| _(pendiente)_ | _(pendiente)_ | _(pendiente: comparar el antes y el después y justificar la acción ejecutada)_ |

### Facu Ramirez — Restauración y RTO/RPO (Parte 4)

Prompt sugerido: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/restore_test.ps1`
y las validaciones SQL para restaurar el último `.dump` en `foodstore_restore_test` con
`pg_restore --no-owner --no-privileges`, validar conteos e integridad y medir RTO y RPO. El
script no debe poder tocar `foodstore`.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| _(pendiente)_ | _(pendiente)_ | _(pendiente: simulacro real, prueba negativa que devuelva `FALLA:...` y comparación de conteos)_ |

---

## Reglas de verificación del equipo

- **Ningún script se acepta sin ejecutarlo**, incluido su camino de error. Un script que
  sólo se leyó no cuenta como validado.
- La validación humana se registra con el comando ejecutado y el resultado observado, no
  con una afirmación genérica del tipo «funciona».
- Toda prueba destructiva va **exclusivamente** sobre `foodstore_restore_test`.
- Cada integrante documenta al menos un error real de su parte y cómo lo detectó.
