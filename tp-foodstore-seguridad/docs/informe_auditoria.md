# Informe de auditoría nativa

## Configuración

En el servidor de desarrollo se deben establecer los siguientes parámetros en
`postgresql.conf` (o con `ALTER SYSTEM`, si el equipo administra la instancia):

```conf
log_connections = on
log_disconnections = on
log_statement = 'mod'
log_line_prefix = '%m [%p] user=%u,db=%d,app=%a,client=%h '
```

Después de modificar la configuración se debe ejecutar `SELECT pg_reload_conf();`
o reiniciar el servidor cuando corresponda. La evidencia final debe incluir la
salida de `SHOW` de esos parámetros y el fragmento producido por
`sql/auditoria_test.sql`.

## Prueba ejecutada

El script realiza una lectura, una inserción, una actualización y una limpieza
de datos sintéticos. El intento de login fallido se ejecuta con `psql` usando
un usuario inexistente o una contraseña incorrecta; no se guardan contraseñas
en Git.

## Lectura del log

Con `log_line_prefix` se identifican **cuándo** ocurrió el evento (`%m`),
**quién** (`%u`), **sobre qué base** (`%d`), **desde dónde** (`%h`) y el proceso
servidor (`%p`). `log_statement = 'mod'` deja evidencia de sentencias de
inserción, actualización y borrado, pero no es auditoría fila por fila:
puede no registrar el valor anterior/nuevo de cada fila ni el contexto de
negocio. Para esa granularidad se evaluaría `pgaudit` o auditoría mediante
triggers, según el riesgo y el volumen.

## Sensibilidad del log

El log es un activo sensible: puede contener nombres de usuario, consultas,
direcciones de origen y errores útiles para un atacante. Debe ser legible sólo
por el usuario del servicio PostgreSQL y personal autorizado de auditoría,
mediante permisos restrictivos del sistema operativo; no debe concederse
`SELECT` general del directorio de logs a usuarios de la aplicación.