# Evidencias del TP8

## Convención de nombres

Cada integrante genera y firma su propia evidencia con el prefijo de su número:

| Integrante | Archivos esperados |
|---|---|
| Matías (I1) | `i1_reconstruccion_<fecha>.txt`, `i1_informe_<fecha>.txt` |
| Santi (I2) | `i2_backup_<fecha>.txt` (salida del script + `pg_restore -l` + listado de `backups/`) |
| Facu Deseff (I3) | `i3_health_antes_<fecha>.txt`, `i3_health_con_muertas_<fecha>.txt`, `i3_maintenance_<fecha>.txt`, `i3_health_despues_<fecha>.txt` |
| Facu Ramirez (I4) | `i4_simulacro_<fecha>.txt`, `i4_prueba_negativa_<fecha>.txt` |

`<fecha>` en formato `yyyyMMdd_HHmm`.

## Modo de trabajo

El equipo eligió el **modo B**: cada integrante construye su parte desde cero. Por eso no
hay código ni evidencias de referencia de las Partes 2, 3 y 4 en el repositorio; cada dueño
ejecuta su parte en su máquina y genera sus archivos con su prefijo.

## Reglas

- La evidencia es **salida cruda** del comando ejecutado; no se edita a mano.
- No incluir contraseñas ni cadenas de conexión con credenciales.
- Los `.dump` y los logs van a `backups/` y `logs/`, que no se versionan.
