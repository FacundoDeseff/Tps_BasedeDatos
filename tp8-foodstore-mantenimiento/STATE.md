# STATE.md — Plan de trabajo por integrante (TP8, Unidad 6)

## Estado actual

- **Modalidad:** B. Cada integrante construyó su parte desde cero y hace su propio commit. Las Partes 2, 3 y 4 ya están versionadas por sus dueños.
- **Tarea 1:** completada por **Matías** (especificación + reconstrucción de la base).
- **Tarea 2:** completada por **Santi** (respaldo automatizable, 2026-10-28).
- **Tarea 3:** completada por **Facu Deseff** (monitoreo y mantenimiento, 2026-10-28).
- **Tarea 4:** completada por **Facu Ramirez** (restauración y RTO/RPO, 2026-10-28).
- **Siguiente paso:** **Matías** cierra la Parte 5 con el informe final (`informe_u6.pdf`).

## Reparto y puntaje de la consigna

| Integrante | Parte | Entregable principal | Puntos | Estado |
|---|---|---|---|---|
| **Matías** | 1 y 5 | `SPEC_U6.md`, `AGENTS.md`, `STATE.md`, reconstrucción de la base e `informe_u6.pdf` | 3,0 | Tarea 1 hecha; informe final cerrado con los números de las Partes 2-4 |
| **Santi** | 2 | `scripts/backup_foodstore.ps1` + evidencia | 2,0 | **Completada** — `docs/i2_backup_20261028_2008.txt` (la de 1656 quedó obsoleta) |
| **Facu Deseff** | 3 | `sql/health_check.sql` y `sql/maintenance.sql` + evidencia | 2,0 | **Completada** — `docs/i3_*_20261028_1816.txt` |
| **Facu Ramirez** | 4 | `scripts/restore_test.ps1` y validaciones + RTO/RPO | 3,0 | **Completada** — `docs/i4_*_20261028_2038.txt` (RTO 16,7 s / RPO 29 min 54 s) |

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

**Entregables:** `scripts/backup_foodstore.ps1` y `docs/i2_backup_20261028_2008.txt`.

**Hecho:**
1. Script con `-Server -Port -User -Database -PgBin -BackupDir -LogDir -Retention`; `pg_dump -Fc --no-password` a `*.dump.parcial` y rename sólo con código 0; log diario en `logs/backup_YYYYMMDD.log` con `RESULTADO=OK/ERROR`; sin credenciales (usa `pgpass.conf`).
2. **Camino de error** (`-Port 5999`): exit 1, `RESULTADO=ERROR`, 0 `.dump` y 0 `.parcial`, sólo el log.
3. **Corrida real** contra `foodstore`: `RESULTADO=OK`, `foodstore_20261028_2008.dump` (8,94 MB / 9.378.143 bytes), 33 objetos en `pg_restore -l`, SHA-256 `DA38B10B7C0F87D3EF3D018809543E80406B08A20EA702E3933B96C110BE096D` (verificado con `Get-FileHash`).
4. **Mejora obligatoria:** retención `-Retention N` (default 7) ordenada por `LastWriteTime`, probada con 8 `.dump` simulados → conservó 7 y borró los 2 más viejos informándolo en el log. Complemento documentado: alta diaria 03:00 en el Programador de tareas de Windows (ver abajo).
5. Base reconstruida en la máquina de Santi con `sql/00_reconstruccion_foodstore.sql` (11/20.000/50.000/200.000/400.000, 102 MB), porque `foodstore` no existía en su instalación.

> **Vigencia de la evidencia (2026-10-28 20:08):** `docs/i2_backup_20261028_1656.txt` quedó **OBSOLETA** y se conserva sin editar como registro histórico. Se generó con una versión anterior del script: mostraba `Dump generado` antes de `pg_restore -l OK` y, en el camino de error, imprimía `parcial=<ruta>` en lugar de `parcial=eliminado`. La evidencia vigente es `docs/i2_backup_20261028_2008.txt`, producida con el script commiteado (HEAD `866c2ea`), que verifica `pg_restore -l` **antes** del rename e informa `parcial=eliminado`. En la máquina FACU hubo que reconstruir `foodstore` con `sql/00_reconstruccion_foodstore.sql` porque estaba vacía (0 filas) y sin la tabla `usuario`; el detalle crudo de la reconstrucción está en el anexo de la evidencia nueva.

**Nota de entorno:** PostgreSQL 17.11 escucha en **5432** tanto en la máquina de Santi como en FACU, donde se regeneró la evidencia vigente (el 5433 es el de la máquina de Matías y no responde acá). El default del script sigue siendo 5433, según el SPEC; en estas máquinas se ejecuta con `-Port 5432`.

**Traspaso a Facu Deseff:** último `.dump` en `backups/foodstore_20261028_2008.dump` (SHA-256 `DA38B10B7C0F87D3EF3D018809543E80406B08A20EA702E3933B96C110BE096D`); el `foodstore_20261028_1656.dump` citado en la evidencia obsoleta no es el vigente. `pg_restore -l` lo lista sin error: 5 tablas, 5 secuencias, 5 `TABLE DATA`, 5 `SEQUENCE SET`, 6 PK/UNIQUE, 3 índices y 4 FK (33 objetos). Recordá que `backups/` y `logs/` no se versionan: generá tu propio dump con `.\scripts\backup_foodstore.ps1 -Port <puerto>` si necesitás uno.

**Programación diaria (mejora documentada):**
```powershell
$accion  = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\ruta\al\tp8\scripts\backup_foodstore.ps1" -Port 5432'
$trigger = New-ScheduledTaskTrigger -Daily -At 03:00
Register-ScheduledTask -TaskName 'FoodStore-Backup' -Action $accion -Trigger $trigger -Description 'Respaldo diario de foodstore'
```

**Commit:** `feat(tp8): respaldo automatizable (Santi)`

---

## Tarea 3 — Facu Deseff: monitoreo y mantenimiento (COMPLETADA)

**Entregables:** `sql/health_check.sql`, `sql/maintenance.sql`, `sql/03_churn_controlado.sql` y la evidencia `docs/i3_*_20261028_1816.txt`.

**Hecho:**
1. **Health check** con los 4 controles de la consigna (tamaño, conexiones y transacciones en `pg_stat_database`, tuplas muertas y autovacuum en `pg_stat_user_tables`, consultas activas en `pg_stat_activity`), más un **control 5 propio** de la mejora (cache hit, locks sin conceder y transacción abierta más antigua). Cada control imprime `estado = OK|ALERTA` y el script cierra con un resumen accionable. Es de solo lectura: no modifica nada, se puede correr contra la base principal.
2. **Mantenimiento** con observación de `last_autovacuum`/`last_autoanalyze` y de los parámetros efectivos del servidor, decisión por tabla (`VACUUM (ANALYZE)` / `ANALYZE` / `sin accion`) con la justificación escrita, y ejecución selectiva vía `\gexec`. **Sin `VACUUM FULL`**: `VACUUM (ANALYZE)` no toma `ACCESS EXCLUSIVE` ni reescribe el archivo.
3. **Ciclo completo (2026-10-28 18:16 hs):**

| Paso | Evidencia | Resultado |
|---|---|---|
| Antes | `docs/i3_health_antes_20261028_1816.txt` | 0 tuplas muertas, todo `OK` |
| Churn | `docs/i3_churn_20261028_1816.txt` | `UPDATE` ×2 sobre 40 % de las filas: **160.000** muertas en `pedido` y **40.000** en `producto` |
| Con muertas | `docs/i3_health_con_muertas_20261028_1816.txt` | **44,44 %** en ambas tablas, `estado=ALERTA`, resumen `ATENCION: ejecutar maintenance.sql` |
| Mantenimiento | `docs/i3_maintenance_20261028_1816.txt` | `VACUUM (ANALYZE)` solo en `pedido` y `producto`; el resto `sin accion` |
| Después | `docs/i3_health_despues_20261028_1816.txt` | 0 tuplas muertas, `last_vacuum`/`last_analyze` 18:17:08, `OK: sin acciones requeridas` |

4. Integridad verificada antes y después del churn y del mantenimiento: 0 productos inválidos, 0 detalles inválidos, 0 totales descuadrados.

**Correcciones aplicadas al trabajo previo (auditoría pedida por Facu Deseff):**
- 🔴 `sql/00_reconstruccion_foodstore.sql`: el `DROP TABLE ... CASCADE` sobre `foodstore` violaba la regla 1 del SPEC y de `AGENTS.md`. Ahora **aborta sin borrar nada** si el esquema ya existe; solo limpia con `-v reset=1` explícito y **sin `CASCADE`**. Probado: segunda corrida sin `reset` → exit 3, datos intactos.
- 🟠 `scripts/backup_foodstore.ps1`: (a) el log ahora se abre antes de cualquier validación, así los fallos tempranos quedan registrados; (b) la verificación con `pg_restore -l` pasó **antes** del rename, así un dump ilegible nunca queda como respaldo; (c) la retención usa regex anclado y ya no puede borrar dumps de otra base (probado con señuelos `foodstore_restore_test_*`); (d) log tolerante a fallos con respaldo en `%TEMP%`; (e) nombres con cultura invariante; (f) `PgBin` se resuelve del PATH; (g) `PGCONNECT_TIMEOUT` y `--lock-wait-timeout`.

**Commit:** `feat(tp8): monitoreo y mantenimiento (Facu Deseff)`

**Traspaso a Facu Ramirez (Parte 4):**
- `foodstore` está levantada y **sin tuplas muertas**: es el estado limpio desde el cual hay que respaldar y restaurar.
- El último respaldo bueno de esta máquina es `backups/foodstore_20261028_2008.dump` (8,94 MB / 9.378.143 bytes, 33 objetos, `pg_restore -l` OK, SHA-256 `DA38B10B7C0F87D3EF3D018809543E80406B08A20EA702E3933B96C110BE096D`). El `..._1814.dump` mencionado en la corrida de I3 no existe en esta máquina. `backups/` y `logs/` no se versionan: generá el tuyo con `.\scripts\backup_foodstore.ps1 -Port 5432`.
- **Ojo con el nombre de la base de prueba:** la retención del respaldo ya está protegida contra `foodstore_restore_test_*`, pero esa base **no existe todavía** en esta máquina.
- El health check se puede correr antes y después de tu simulacro para dejar constancia de que la restauración no alteró la base principal.

---

## Tarea 4 — Facu Ramirez: restauración y RTO/RPO (COMPLETADA)

**Entregables:** `scripts/restore_test.ps1`, `sql/validaciones_restore.sql`, `sql/validaciones_restore_check.sql` y las evidencias `docs/i4_simulacro_20261028_2038.txt` y `docs/i4_prueba_negativa_20261028_2038.txt`.

**Hecho:**
1. **Simulacro** (`.\scripts\restore_test.ps1 -Port 5432`): restauró `foodstore_20261028_2008.dump` en `foodstore_restore_test` con `pg_restore --no-owner --no-privileges --exit-on-error`. `EXITCODE=0` y `validacion=PASS`.
2. **Métricas:** T0 = 20:38:31,651 (inmediatamente antes del `createdb`), T1 = 20:38:48,395 → **RTO 16,7 s**; **RPO 29 min 54 s** (1.794,5 s), medido como la antigüedad del dump en T0.
3. **Validaciones:** conteos 11 / 20.000 / 50.000 / 200.000 / 400.000; 0 productos inválidos; 0 detalles inválidos; 0 claves foráneas huérfanas; 0 totales descuadrados; las 5 secuencias al día.
4. **Prueba negativa:** `ALTER TABLE producto DROP CONSTRAINT producto_precio_lista_check` y `UPDATE` de una fila a `precio_lista = -1` → `FALLA:productos_invalidos=1`. La reconstrucción posterior vuelve a `PASS`.
5. **Mejora obligatoria (escenarios de falla):** (a) `-DumpFile` inexistente → exit 1 y 0 bases creadas; (b) dump de 100 bytes → el pre-flight aborta y no crea base; (c) dump truncado a 1 MB → el pre-flight **lo acepta** porque el TOC está al inicio del archivo, `pg_restore` falla al leer los datos y deja 5 tablas con sólo `categoria` cargada (11 filas, 14 MB); el chequeo devuelve `FALLA:conteos`.
6. **Guardia de seguridad:** la base destino es la constante `foodstore_restore_test` y el script **no** acepta `-Database`, así que no puede apuntar a `foodstore`. Después del simulacro se verificó que `foodstore` seguía con los mismos conteos y `PASS`.

**Commit:** `feat(tp8): restauración y RTO/RPO (Facu Ramirez)`

**Traspaso a Matías (Parte 5):** RTO 16,7 s, RPO 29 min 54 s, `PASS` en las 8 validaciones y 33 objetos en el dump `foodstore_20261028_2008.dump`. Con eso quedan completos los bloques de `informe_u6.md`; el PDF se regenera con `python scripts/generar_informe_pdf.py`.

---

## Definición de terminado (todo el equipo)

- [x] Santi, Facu Deseff y Facu Ramirez ejecutaron su parte y tienen evidencia `docs/iN_*`.
- [x] Cada uno completó su sección en `BITACORA.md`.
- [x] Matías actualizó `informe_u6.pdf` con los números finales.
- [x] `STATE.md` marca las cuatro tareas como completadas.
- [x] No hay credenciales ni `.dump` versionados (`git check-ignore` confirma `backups/` y `logs/`).
- [x] Un commit por integrante, con su nombre en el mensaje.
