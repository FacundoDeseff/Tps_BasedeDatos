# STATE.md — Plan de trabajo por integrante (TP8, Unidad 6)

## Estado actual

- **Modalidad:** B. Cada integrante construye su parte desde cero y hace su propio commit. **No hay código de referencia de las Partes 2, 3 y 4 en el repositorio.**
- **Tarea 1:** completada por **Matías** (especificación + reconstrucción de la base).
- **Tarea 2:** completada por **Santi** (respaldo automatizable, 2026-10-28).
- **Próximo integrante:** **Facu Deseff** (Parte 3, monitoreo y mantenimiento).
- Después: **Facu Ramirez** (Parte 4, restauración y RTO/RPO).

## Reparto y puntaje de la consigna

| Integrante | Parte | Entregable principal | Puntos | Estado |
|---|---|---|---|---|
| **Matías** | 1 y 5 | `SPEC_U6.md`, `AGENTS.md`, `STATE.md`, reconstrucción de la base e `informe_u6.pdf` | 3,0 | Tarea 1 hecha; informe final pendiente de las Partes 2-4 |
| **Santi** | 2 | `scripts/backup_foodstore.ps1` + evidencia | 2,0 | **Completada** — `docs/i2_backup_20261028_1656.txt` |
| **Facu Deseff** | 3 | `sql/health_check.sql` y `sql/maintenance.sql` + evidencia | 2,0 | **Pendiente — siguiente** |
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

## Tarea 2 — Santi: respaldo automatizable (COMPLETADA)

**Entregables:** `scripts/backup_foodstore.ps1` y `docs/i2_backup_20261028_1656.txt`.

**Hecho:**
1. Script con `-Server -Port -User -Database -PgBin -BackupDir -LogDir -Retention`; `pg_dump -Fc --no-password` a `*.dump.parcial` y rename sólo con código 0; log diario en `logs/backup_YYYYMMDD.log` con `RESULTADO=OK/ERROR`; sin credenciales (usa `pgpass.conf`).
2. **Camino de error** (`-Port 5999`): exit 1, `RESULTADO=ERROR`, 0 `.dump` y 0 `.parcial`, sólo el log.
3. **Corrida real** contra `foodstore`: `RESULTADO=OK`, `foodstore_20261028_1656.dump` (8,94 MB / 9.378.194 bytes), 33 objetos en `pg_restore -l`, SHA-256 `0FCF7C4282C3442F6B53A3BA51EE5909A60E8C2FDA26D6E41FCC5299432FA136` (verificado con `Get-FileHash`).
4. **Mejora obligatoria:** retención `-Retention N` (default 7) ordenada por `LastWriteTime`, probada con 8 `.dump` simulados → conservó 7 y borró los 2 más viejos informándolo en el log. Complemento documentado: alta diaria 03:00 en el Programador de tareas de Windows (ver abajo).
5. Base reconstruida en la máquina de Santi con `sql/00_reconstruccion_foodstore.sql` (11/20.000/50.000/200.000/400.000, 102 MB), porque `foodstore` no existía en su instalación.

**Nota de entorno:** en la máquina de Santi PostgreSQL 17.11 escucha en **5432** (el 5433 es el de la máquina de Matías). El default del script sigue siendo 5433, según el SPEC; en esa máquina se ejecuta con `-Port 5432`.

**Traspaso a Facu Deseff:** último `.dump` en `backups/foodstore_20261028_1656.dump` (SHA-256 arriba). `pg_restore -l` lo lista sin error: 5 tablas, 5 secuencias, 5 `TABLE DATA`, 5 `SEQUENCE SET`, 6 PK/UNIQUE, 3 índices y 4 FK (33 objetos). Recordá que `backups/` y `logs/` no se versionan: generá tu propio dump con `.\scripts\backup_foodstore.ps1 -Port <puerto>` si necesitás uno.

**Programación diaria (mejora documentada):**
```powershell
$accion  = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\ruta\al\tp8\scripts\backup_foodstore.ps1" -Port 5432'
$trigger = New-ScheduledTaskTrigger -Daily -At 03:00
Register-ScheduledTask -TaskName 'FoodStore-Backup' -Action $accion -Trigger $trigger -Description 'Respaldo diario de foodstore'
```

**Commit:** `feat(tp8): respaldo automatizable (Santi)`

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
