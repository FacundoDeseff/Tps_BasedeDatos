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

Prompt sugerido: «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/backup_foodstore.ps1`
para Windows con `pg_dump -Fc`, nombre `foodstore_YYYYMMDD_HHMM.dump`, escritura en `.parcial`
con rename sólo si termina bien, log en `logs/`, salida con error si falla y sin contraseñas.
Después ejecutalo contra `foodstore` en `localhost:5433` y mostrame el dump y el log.»

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| _(pendiente)_ | _(pendiente)_ | _(pendiente: prueba de error con un puerto inexistente, ejecución real, `pg_restore -l` y retención)_ |

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
