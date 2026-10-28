# STATE.md — Plan de trabajo por integrante (TP8, Unidad 6)

## Estado actual

- **Modalidad:** B. Cada integrante construye su parte desde cero y hace su propio commit. **No hay código de referencia de las Partes 2, 3 y 4 en el repositorio.**
- **Tarea 1:** completada por **Matías** (especificación + reconstrucción de la base).
- **Próximo integrante:** **Santi** (Parte 2, respaldo).
- Después: **Facu Deseff** (Parte 3, monitoreo y mantenimiento) y **Facu Ramirez** (Parte 4, restauración y RTO/RPO).

## Reparto y puntaje de la consigna

| Integrante | Parte | Entregable principal | Puntos | Estado |
|---|---|---|---|---|
| **Matías** | 1 y 5 | `SPEC_U6.md`, `AGENTS.md`, `STATE.md`, reconstrucción de la base e `informe_u6.pdf` | 3,0 | Tarea 1 hecha; informe final pendiente de las Partes 2-4 |
| **Santi** | 2 | `scripts/backup_foodstore.ps1` + evidencia | 2,0 | **Pendiente — siguiente** |
| **Facu Deseff** | 3 | `sql/health_check.sql` y `sql/maintenance.sql` + evidencia | 2,0 | **Pendiente** |
| **Facu Ramirez** | 4 | `scripts/restore_test.ps1` y validaciones + RTO/RPO | 3,0 | **Pendiente** |

## Reglas para los cuatro

1. Cada uno crea sus archivos, los ejecuta en su máquina y genera su evidencia en `docs/` con el prefijo `iN_` (por ejemplo `docs/i2_backup_20261030_1015.txt`).
2. Cada uno agrega **su fila** en `BITACORA.md`: prompt enviado, respuesta resumida y validación humana. No se copia la fila de otro.
3. Cada uno hace **al menos una mejora concreta** a su parte (sugerida en cada tarea).
4. Al terminar: marcar su tarea acá, actualizar la instrucción del siguiente y hacer **un commit propio** con su nombre.
5. Nunca versionar contraseñas ni `.dump` (`backups/` y `logs/` están ignorados).
6. Ningún script se acepta sin ejecutarlo, **incluido su camino de error**.

---

## Tarea 1 — Matías (COMPLETADA)

- **Entregables:** `AGENTS.md`, `SPEC_U6.md`, `STATE.md`, `sql/00_reconstruccion_foodstore.sql`, `docs/i1_reconstruccion_*.txt`, plantilla de `informe_u6.md`.
- **Hecho:** especificación con frecuencia y condición de finalización por tarea; base `foodstore` reconstruida y verificada (11 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos, 400.000 detalles, 0 inválidos).
- **Pendiente de Matías (Parte 5):** armar el `informe_u6.pdf` final con los números que entreguen Santi, Facu Deseff y Facu Ramirez.
- **Traspaso:** habilitado Santi.

---

## Tarea 2 — Santi: respaldo automatizable (PENDIENTE)

**Objetivo:** script de respaldo diario, probado y con evidencia propia.

**Prompt sugerido para OpenCode:**
> «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/backup_foodstore.ps1` para Windows: `pg_dump -Fc` de `foodstore`, nombre `foodstore_YYYYMMDD_HHMM.dump`, escritura en `.parcial` con rename sólo si `pg_dump` sale con código 0, log en `logs/`, salida con error si falla y sin contraseñas (usar `pgpass.conf` y `--no-password`). Después ejecutalo contra `localhost:5433` y mostrame el dump y el log.»

**Pasos:**
1. Crear el script en `scripts/backup_foodstore.ps1`.
2. Probar el camino de error (por ejemplo `-Port 5999`): debe salir con código 1, sin `.dump` y sin `.parcial`.
3. Ejecutar el respaldo real y verificar `RESULTADO=OK`, tamaño y SHA-256.
4. Verificar que el dump sea legible con `pg_restore -l`.
5. **Mejora obligatoria:** agregar política de retención (conservar los últimos N `.dump`) o documentar la programación diaria en el Programador de tareas.
6. Guardar evidencia en `docs/i2_backup_<fecha>.txt`.
7. Completar la sección I2 de `BITACORA.md`, actualizar este archivo y commitear.

**Criterio de aceptación:** dump con nombre `foodstore_YYYYMMDD_HHMM.dump`, log con `RESULTADO=OK`, `.parcial` inexistente, `pg_restore -l` sin error y ninguna credencial en el código.

**Commit:** `feat(tp8): respaldo automatizable (Santi)`

**Traspaso a Facu Deseff:** dejar la ruta del último `.dump` y el resultado de `pg_restore -l`.

---

## Tarea 3 — Facu Deseff: monitoreo y mantenimiento (PENDIENTE)

**Objetivo:** demostrar con datos reales que el chequeo de salud detecta un problema y que el mantenimiento lo resuelve sin `VACUUM FULL`.

**Prompt sugerido para OpenCode:**
> «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `sql/health_check.sql` con los 4 controles de la consigna (tamaño de la base, conexiones y transacciones en `pg_stat_database`, estado de tablas y tuplas muertas en `pg_stat_user_tables`, consultas activas en `pg_stat_activity`) y `sql/maintenance.sql` con revisión de autovacuum y una acción de mantenimiento segura y justificada. No uses `VACUUM FULL`.»

**Pasos:**
1. Crear `sql/health_check.sql` y `sql/maintenance.sql`.
2. Ejecutar el health check y guardar `docs/i3_health_antes_<fecha>.txt`.
3. Generar tuplas muertas reales (por ejemplo con `UPDATE` sobre `pedido` o un script propio `sql/03_churn_controlado.sql`) y volver a correr el health check: `docs/i3_health_con_muertas_<fecha>.txt`.
4. Ejecutar el mantenimiento (`docs/i3_maintenance_<fecha>.txt`) y justificar en el log por qué eligió `VACUUM (ANALYZE)` o `ANALYZE`.
5. Correr el health check final: `docs/i3_health_despues_<fecha>.txt`.
6. **Mejora obligatoria:** agregar un control o umbral justificado (locks no concedidos, transacciones largas, `cache hit`, etc.) y explicarlo en 5 líneas.
7. Completar la sección I3 de `BITACORA.md`, actualizar este archivo y commitear.

**Criterio de aceptación:** se ve el antes (tuplas muertas > 10 % y alerta), la acción justificada y el después (alerta resuelta), sin `VACUUM FULL`.

**Commit:** `feat(tp8): monitoreo y mantenimiento (Facu Deseff)`

**Traspaso a Facu Ramirez:** dejar el health check final y explicar qué tablas quedaron con tuplas muertas.

---

## Tarea 4 — Facu Ramirez: restauración y RTO/RPO (PENDIENTE)

**Objetivo:** restaurar el último respaldo en `foodstore_restore_test`, validar integridad y medir RTO/RPO.

**Prompt sugerido para OpenCode:**
> «Leé `SPEC_U6.md` y `AGENTS.md`. Generá desde cero `scripts/restore_test.ps1` y las validaciones SQL para restaurar el último `.dump` de `backups/` en `foodstore_restore_test` con `pg_restore --no-owner --no-privileges`, validar conteos, productos y detalles inválidos, claves foráneas y totales, y medir RTO y RPO. El script no debe poder tocar `foodstore`.»

**Pasos:**
1. Crear `scripts/restore_test.ps1`, `sql/validaciones_restore.sql` y `sql/validaciones_restore_check.sql` (este último debe devolver `PASS` o `FALLA:motivo`).
2. Ejecutar el simulacro con el último dump y guardar `docs/i4_simulacro_<fecha>.txt`.
3. Verificar `PASS`, conteos y RTO/RPO observados.
4. **Prueba negativa obligatoria:** romper una restricción en `foodstore_restore_test`, insertar un valor inválido, correr el chequeo y confirmar `FALLA:...`; después reconstruir la base.
5. **Mejora obligatoria:** probar un escenario de falla del restore (`-DumpFile` inexistente o dump truncado) y documentar qué deja en disco.
6. Completar la sección I4 de `BITACORA.md`, actualizar este archivo y commitear.
7. Pasar a Matías: RTO, RPO, conteos y resultado de las validaciones.

**Criterio de aceptación:** restauración sólo en `foodstore_restore_test`, `pg_restore --no-owner --no-privileges`, conteos idénticos, 0 inválidos, RTO y RPO registrados.

**Commit:** `feat(tp8): restauración y RTO/RPO (Facu Ramirez)`

**Traspaso a Matías:** entregar los números finales para el informe.

---

## Definición de terminado (todo el equipo)

- [ ] Santi, Facu Deseff y Facu Ramirez ejecutaron su parte y tienen evidencia `docs/iN_*`.
- [ ] Cada uno completó su sección en `BITACORA.md`.
- [ ] Matías actualizó `informe_u6.pdf` con los números finales.
- [ ] `STATE.md` marca las cuatro tareas como completadas.
- [ ] No hay credenciales ni `.dump` versionados.
- [ ] Un commit por integrante, con su nombre en el mensaje.
