# Informe post-incidente — TP Unidad 6
## Food Store · Mantenimiento, respaldo y recuperación

**Respaldo utilizado.** `foodstore_20261028_2008.dump`, generado por `.\scripts\backup_foodstore.ps1 -Port 5432` el **2026-10-28 entre las 20:08:27 y las 20:08:38**. Tamaño 9.378.143 bytes (8,94 MB); SHA-256 `DA38B10B7C0F87D3EF3D018809543E80406B08A20EA702E3933B96C110BE096D`; `pg_restore -l` lista 33 objetos (5 tablas, 5 secuencias, 5 `TABLE DATA`, 5 `SEQUENCE SET`, 6 PK/UNIQUE, 3 índices y 4 FK). PostgreSQL 17.11 en `localhost:5432` (el default del equipo es 5433; se pasa `-Port` explícito). Autenticación por `pgpass.conf`: ninguna contraseña en el repositorio.

**Simulacro.** `.\scripts\restore_test.ps1 -Port 5432` restaura en `foodstore_restore_test` con `pg_restore --no-owner --no-privileges --exit-on-error`; `foodstore` no se toca. T0 = 20:38:31,651, inmediatamente antes del `createdb`; T1 = 20:38:48,395, al terminar las validaciones. **Tiempo total de restauración y validación: 16,7 s.**

**RTO y RPO.**
- **RTO previsto:** 300 s como máximo. **Observado: 16,7 s.**
- **RPO previsto:** 24 h como máximo (respaldo diario a las 03:00). **Observado: 29 min 54 s** (1.794,5 s): antigüedad del dump al iniciar el cronómetro.
- El RPO observado depende del momento del simulacro: corrido 29 minutos después del respaldo, **no representa el peor caso**, que con el plan diario sigue siendo de hasta 24 h.

**Validaciones** (sobre `foodstore_restore_test`; `sql/validaciones_restore_check.sql` devuelve `PASS`).
- Conteos idénticos al pre-respaldo: 11 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos y 400.000 detalles.
- Productos inválidos 0, detalles inválidos 0 y claves foráneas huérfanas 0.
- Restricciones lógicas: 0 pedidos con `total <> SUM(subtotal)`, 0 productos con `precio_lista <= 0` o `stock < 0` y 0 detalles con `cantidad <= 0` o `subtotal < 0`.
- Las 5 secuencias quedaron con `last_value >= max(id)`.
- Prueba negativa: al romper el `CHECK` de `precio_lista` y dejar una fila en `-1`, el chequeo devuelve `FALLA:productos_invalidos=1`; reconstruida la base, vuelve a `PASS`.

**Problema real encontrado.** La prueba negativa se planteó con un `INSERT` de un producto con `precio_lista = -1`; eso cambiaba los conteos y el chequeo devolvía `FALLA:conteos(producto=50001/50000)` en lugar del control que se quería demostrar. Se reemplazó por un `UPDATE` sobre una fila existente y el resultado pasó a `FALLA:productos_invalidos=1`. También se comprobó que un dump truncado **no** lo detecta `pg_restore -l`, porque el TOC está al inicio del archivo: falla al leer los datos, deja una base parcial (5 tablas, sólo `categoria` con 11 filas, 14 MB) y el chequeo la rechaza con `FALLA:conteos`. En I2, la `foodstore` estaba vacía y sin tabla `usuario`: se detectó antes de respaldar; en I3, la reconstrucción hacía `DROP TABLE ... CASCADE` y el health check tenía una métrica de índices mal calculada. Ambas se corrigieron.

**Mejora concreta.** Programar el ensayo de restauración semanal (sábado 10:00) con el mismo `restore_test.ps1` en el Programador de tareas, con alerta si no devuelve `PASS`, y evaluar archivado WAL + PITR para bajar el RPO de 24 h a minutos. Sin eso, el plan actual puede perder un día entero de pedidos.

**Intervención de OpenCode.** OpenCode generó scripts y consultas a partir de `SPEC_U6.md` y `AGENTS.md`; cada pieza se ejecutó antes de aceptarla. I1: especificación y reconstrucción (se corrigieron las columnas al esquema real). I2: respaldo (se verificó que no hubiera `VACUUM`, `DROP` ni contraseñas y se probaron camino de error y retención). I3: monitoreo (se eliminó una métrica inventada). I4: restauración (se corrigió `INSERT` por `UPDATE` y se agregaron tres escenarios de falla). Detalle en `BITACORA.md`.

**Evidencias.** `docs/i1_reconstruccion_20261028_1630.txt`; `docs/i2_backup_20261028_2008.txt` (vigente) y `..._1656.txt` (obsoleta); `docs/i3_*_20261028_1816.txt`; `docs/i4_simulacro_20261028_2038.txt` y `docs/i4_prueba_negativa_20261028_2038.txt`.
