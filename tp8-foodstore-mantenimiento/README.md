# TP 8 — Food Store: mantenimiento, respaldo y recuperación

Trabajo Práctico de la Unidad 6 (Semana 10). Procedimiento completo sobre PostgreSQL 16+:
respaldo en formato custom, monitoreo, mantenimiento seguro y simulacro de restauración
con medición de RTO/RPO.

## Equipo y reparto

| Integrante | Parte | Entregable | Estado |
|---|---|---|---|
| **Matías** | 1 y 5 | especificación, reconstrucción de la base e informe final | Parte 1 hecha; informe final en `informe_u6.pdf` |
| **Santi** | 2 | respaldo automatizable | hecho (`docs/i2_backup_20261028_2008.txt`; la evidencia de `1656` quedó obsoleta) |
| **Facu Deseff** | 3 | monitoreo y mantenimiento | hecho (`docs/i3_*_20261028_1816.txt`) |
| **Facu Ramirez** | 4 | restauración, validaciones y RTO/RPO | hecho (`docs/i4_*_20261028_2038.txt`; RTO 16,7 s / RPO 29 min 54 s) |

El detalle de pasos, criterios de aceptación y commits está en `STATE.md`. Cada integrante
construye su parte desde cero y firma su evidencia en `docs/`.

## Requisitos

- PostgreSQL 16 o superior (probado en 17.11) con `psql`, `pg_dump`, `pg_restore`,
  `pg_isready` y `createdb`/`dropdb` en el `PATH`.
- Windows PowerShell 5.1 o superior (los scripts son `.ps1`).
- Credenciales resueltas por `%APPDATA%\postgresql\pgpass.conf` (o `~/.pgpass`).
  **Ningún script contiene contraseñas.**
- Base `foodstore` creada. Si hace falta reconstruirla:
  ```powershell
  createdb -h localhost -p 5433 -U postgres foodstore
  psql -h localhost -p 5433 -U postgres -d foodstore -v ON_ERROR_STOP=1 -f sql\00_reconstruccion_foodstore.sql
  ```

## Estructura

```
tp8-foodstore-mantenimiento/
├── AGENTS.md                          reglas de operación y seguridad
├── SPEC_U6.md                         especificación: frecuencia y condición de éxito
├── STATE.md                           estado y reparto del trabajo
├── BITACORA.md                        uso de IA: prompt, respuesta y validación humana
├── informe_u6.md                      informe post-incidente (Parte 5), fuente del PDF
├── informe_u6.pdf                     informe final exportado
├── sql/
│   ├── 00_reconstruccion_foodstore.sql   esquema + datos reproducibles (Matías)
│   ├── health_check.sql                  monitoreo (Facu Deseff)
│   ├── maintenance.sql                   mantenimiento seguro, sin VACUUM FULL (Facu Deseff)
│   ├── 03_churn_controlado.sql           generación controlada de tuplas muertas (Facu Deseff)
│   ├── validaciones_restore.sql          reporte de validaciones de la restauración (Facu Ramirez)
│   └── validaciones_restore_check.sql    PASS / FALLA:motivo en una línea (Facu Ramirez)
├── scripts/
│   ├── backup_foodstore.ps1             respaldo diario con pg_dump -Fc y retención (Santi)
│   ├── restore_test.ps1                 simulacro en foodstore_restore_test + RTO/RPO (Facu Ramirez)
│   └── generar_informe_pdf.py            exporta el informe a PDF (Matías)
├── docs/                                 evidencias (salidas reales)
├── backups/                              .dump generados (no versionados)
└── logs/                                 logs de respaldo y simulacro (no versionados)
```

Archivos que crea cada integrante:

| Integrante | Archivos |
|---|---|
| Santi | `scripts/backup_foodstore.ps1` |
| Facu Deseff | `sql/health_check.sql`, `sql/maintenance.sql` y su escenario de tuplas muertas |
| Facu Ramirez | `scripts/restore_test.ps1`, `sql/validaciones_restore.sql`, `sql/validaciones_restore_check.sql` |
| Matías | `informe_u6.pdf` al final, con los números de los tres |

## Flujo de trabajo

1. Leer `STATE.md` y `SPEC_U6.md`.
2. Construir la parte propia y ejecutarla contra el servidor local (5433 por defecto; en las
   máquinas de Santi y Facu Ramirez escucha en 5432, se pasa `-Port 5432`).
3. Probar también el camino de error.
4. Guardar la evidencia en `docs/iN_*.txt` y completar la sección propia de `BITACORA.md`.
5. Actualizar `STATE.md` y commitear sólo los archivos propios.

Los scripts de respaldo aceptan `-Server`, `-Port`, `-User`, `-Database`, `-PgBin`. El puerto
por defecto es **5433** porque es el de la instalación local usada en el TP; en un servidor
estándar se pasa `-Port 5432`. `restore_test.ps1` **no** acepta `-Database` a propósito: la
base destino es la constante `foodstore_restore_test`, así no puede apuntar a `foodstore`.

## Decisiones de la especificación

- **Formato custom (`-Fc`)** para poder inspeccionar (`pg_restore -l`) y restaurar de forma
  selectiva.
- **Sin `VACUUM FULL`**: bloquea la tabla con `ACCESS EXCLUSIVE`. El mantenimiento rutinario
  usa `VACUUM (ANALYZE)` cuando corresponde y `ANALYZE` cuando no, con la decisión
  justificada en el log.
- **Nombres adaptados al esquema integrador**: la consigna usa `cliente`,
  `producto.precio` y `detalle_pedido.precio_unitario`; el esquema real del proyecto usa
  `usuario`, `precio_lista` y `subtotal`. Las validaciones se adaptan y quedan documentadas
  en `SPEC_U6.md` §5 y en el informe.
- **Seguridad de la restauración**: las pruebas destructivas van sólo sobre
  `foodstore_restore_test`; nunca sobre `foodstore`.

## Resultados

Corrida de referencia del 2026-10-28, sobre el respaldo `foodstore_20261028_2008.dump`
(8,94 MB / 9.378.143 bytes, SHA-256 `DA38B10…BE096D`, 33 objetos):

- **Restauración** en `foodstore_restore_test` con `pg_restore --no-owner --no-privileges
  --exit-on-error`: `PASS`.
- **Conteos** idénticos al pre-respaldo: 11 categorías, 20.000 usuarios, 50.000 productos,
  200.000 pedidos y 400.000 detalles.
- **Integridad:** 0 productos inválidos, 0 detalles inválidos, 0 claves foráneas huérfanas,
  0 totales descuadrados y las 5 secuencias al día.
- **RTO observado:** 16,7 s (previsto 300 s como máximo).
- **RPO observado:** 29 min 54 s (previsto 24 h como máximo, con respaldo diario a las 03:00).
- **Prueba negativa:** `FALLA:productos_invalidos=1` al romper el `CHECK` de `precio_lista`.
- **Escenarios de falla:** dump inexistente e ilegible abortan antes de crear la base; un dump
  truncado falla durante la carga y deja una base parcial que el chequeo rechaza con
  `FALLA:conteos`.

Cada número se rastrea hasta `docs/i4_simulacro_20261028_2038.txt` y
`docs/i4_prueba_negativa_20261028_2038.txt`; el informe completo está en `informe_u6.pdf`.
