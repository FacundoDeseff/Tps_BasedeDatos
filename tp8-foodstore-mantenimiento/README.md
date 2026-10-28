# TP 8 — Food Store: mantenimiento, respaldo y recuperación

Trabajo Práctico de la Unidad 6 (Semana 10). Procedimiento completo sobre PostgreSQL 16+:
respaldo en formato custom, monitoreo, mantenimiento seguro y simulacro de restauración
con medición de RTO/RPO.

## Equipo y reparto

| Integrante | Parte | Entregable | Estado |
|---|---|---|---|
| **Matías** | 1 y 5 | especificación, reconstrucción de la base e informe final | Parte 1 hecha; informe pendiente |
| **Santi** | 2 | respaldo automatizable | pendiente |
| **Facu Deseff** | 3 | monitoreo y mantenimiento | pendiente |
| **Facu Ramirez** | 4 | restauración, validaciones y RTO/RPO | pendiente |

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
├── informe_u6.md                      informe post-incidente (Parte 5)
├── sql/
│   └── 00_reconstruccion_foodstore.sql   esquema + datos reproducibles (Matías)
├── scripts/
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
2. Construir la parte propia y ejecutarla contra `localhost:5433`.
3. Probar también el camino de error.
4. Guardar la evidencia en `docs/iN_*.txt` y completar la sección propia de `BITACORA.md`.
5. Actualizar `STATE.md` y commitear sólo los archivos propios.

Los scripts aceptan `-Server`, `-Port`, `-User`, `-Database`, `-PgBin`. El puerto por
defecto es **5433** porque es el de la instalación local usada en el TP; en un servidor
estándar se pasa `-Port 5432`.

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

Pendiente. Los completa Facu Ramirez (RTO/RPO y validaciones) y los cierra Matías en el
informe. Cada número debe poder rastrearse hasta un archivo `docs/i4_*`.
