# Informe del simulacro de incidente

## Secuencia y resultado esperado

`sql/simulacro_incidente.sql` registra tres intentos fallidos a
`fn_autenticar`, documenta el login exitoso con una cuenta sintética, ejecuta
una lectura masiva de `usuario` y finalmente prueba `GRANT admin_datos TO
app_web`. La última sentencia debe producir `ERROR: permission denied to grant
role "admin_datos"` cuando se conecta como `app_web`.

La parte de autenticación se separa del `GRANT`: una función que devuelve
`false` prueba credenciales inválidas, pero no equivale a un fallo del
protocolo de conexión de PostgreSQL. Por eso el log debe incluir también los
intentos `psql` fallidos, sin registrar contraseñas.

## Reconstrucción crítica

El log anonimizado permite afirmar la secuencia temporal, la identidad de base,
la consulta masiva y el error de autorización. No permite afirmar por sí solo
la intención del actor, la identidad humana detrás de la cuenta, la causa raíz
ni una fecha distinta de la registrada. Cualquier respuesta de IA que complete
esos datos debe marcarse como hipótesis no sustentada.

## Contención decidida por el equipo

En un caso real, el equipo preservaría primero los logs, revocaría o
deshabilitaría la credencial comprometida, forzaría el cambio de credenciales
relacionadas y limitaría el origen de red. Luego revisaría membresías de roles,
consultas sobre `usuario` y accesos posteriores. Estas acciones son una
decisión humana basada en evidencia; no se ejecutan automáticamente por una
recomendación de IA ni se aplican al entorno del TP.

## Evidencia a adjuntar

- fragmento de `log_simulacro_anonimizado.txt`;
- salida de los tres fallos, login exitoso, `SELECT` masivo y `GRANT` fallido;
- respuesta de OpenCode;
- contraste entre lo que el log demuestra y lo que la IA supuso.