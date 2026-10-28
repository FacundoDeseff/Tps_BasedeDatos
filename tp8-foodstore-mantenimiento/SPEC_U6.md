# SPEC_U6.md — Especificación del plan de mantenimiento y respaldo

**Proyecto:** Food Store · **Motor:** PostgreSQL 17.11 (requisito: 16+) · **Alcance:** laboratorio, ejecución manual supervisada.

## 1. Entorno y credenciales

| Elemento | Valor |
|---|---|
| Base principal | `foodstore` |
| Base descartable de ensayo | `foodstore_restore_test` |
| Servidor local | `localhost:5433` (parámetro `-Port`, default 5433) |
| Usuario | `postgres` (parámetro `-User`) |
| Autenticación | `%APPDATA%\postgresql\pgpass.conf`; nunca contraseña en scripts ni en el repo |

## 2. Reglas de seguridad (obligatorias)

1. Prohibido `DROP DATABASE foodstore` o cualquier operación destructiva sobre la base principal.
2. Todo ensayo destructivo y toda restauración se ejecutan **solo** sobre `foodstore_restore_test`.
3. Los respaldos se generan en formato personalizado (`pg_dump -Fc`) para permitir `pg_restore` selectivo.
4. El respaldo se escribe primero en `*.dump.parcial` y se renombra únicamente si `pg_dump` termina con código 0.
5. Ante cualquier error el script corta (`$ErrorActionPreference = 'Stop'`), deja el `.parcial` eliminado y registra `ERROR` en `logs/`.
6. `VACUUM FULL` queda prohibido como rutina periódica: bloquea la tabla de forma exclusiva. El mantenimiento rutinario usa `VACUUM (ANALYZE)` / `ANALYZE`.

## 3. Tareas, frecuencia y condición de finalización

| Tarea | Entregable | Frecuencia | Condición que confirma que terminó bien | Evidencia |
|---|---|---|---|---|
| Respaldo de `foodstore` | `scripts/backup_foodstore.ps1` | Diaria (03:00) | Existe `backups/foodstore_YYYYMMDD_HHMM.dump` (no `.parcial`), `pg_dump` salió con código 0 y `pg_restore -l` lista los objetos del archivo | `docs/i2_backup_YYYYMMDD_HHMM.txt` + `logs/backup_YYYYMMDD.log` |
| Chequeo de salud | `sql/health_check.sql` | Diaria (08:00) | Se ejecuta sin error y devuelve los 4 controles: tamaño, conexiones/transacciones, tablas con tuplas muertas y autovacuum, consultas activas | `docs/i3_health_*_YYYYMMDD_HHMM.txt` |
| Revisión de mantenimiento | `sql/maintenance.sql` | Semanal (lunes 03:30) | Se observan tuplas muertas y fechas de autovacuum/autoanalyze; se ejecuta `ANALYZE` solo sobre las tablas que lo justifican | `docs/i3_maintenance_YYYYMMDD_HHMM.txt` |
| Restauración de prueba | `scripts/restore_test.ps1` + `sql/validaciones_restore.sql` | Semanal (sábado 10:00) | `foodstore_restore_test` se crea desde el último `.dump`; los conteos coinciden con el respaldo; productos y detalles inválidos = 0; se registra RTO y antigüedad del respaldo (RPO) | `docs/i4_simulacro_YYYYMMDD_HHMM.txt` |

## 4. Criterios de aceptación

- **Respaldo restaurable:** `pg_restore -l <dump>` lista tablas y secuencias sin error.
- **Restauración íntegra:** `categoria`, `usuario`, `producto`, `pedido` y `detalle_pedido` con el mismo conteo que la base de origen al momento del respaldo.
- **Restricciones lógicas:** `producto.precio_lista >= 0`, `producto.stock >= 0`, `detalle_pedido.cantidad > 0`, `detalle_pedido.subtotal >= 0`; además `pedido.total = SUM(detalle_pedido.subtotal)` y sin huérfanos en las claves foráneas.
- **Métricas:** RTO = tiempo entre `createdb` de la base de prueba y fin de validaciones; RPO = antigüedad del `.dump` usado.
- **Sin secretos:** una búsqueda de `PASSWORD` y de la clave local en los archivos versionados no devuelve credenciales; la autenticación vive solo en `pgpass.conf`.

## 5. Adaptaciones al esquema real

La consigna propone `cliente`, `producto.precio` y `detalle_pedido.precio_unitario`; el esquema integrador del proyecto (TP1 → TP5) usa `usuario`, `producto.precio_lista` y `detalle_pedido.subtotal`. Las validaciones se adaptan a los nombres reales y se deja constancia en `informe_u6`.
