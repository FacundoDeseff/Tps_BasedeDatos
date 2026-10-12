-- Simulacro controlado: ejecutar únicamente contra la base local de Food Store.
-- Los intentos de autenticación fallida se ejecutan desde psql separado porque
-- una función SQL no puede simular el protocolo de autenticación del servidor.

\set ON_ERROR_STOP off
\echo 'INCIDENTE 1: intentos fallidos contra fn_autenticar'
SELECT public.fn_autenticar('sintetico.atacante.01@example.invalid', 'incorrecta-01');
SELECT public.fn_autenticar('sintetico.atacante.01@example.invalid', 'incorrecta-02');
SELECT public.fn_autenticar('sintetico.atacante.01@example.invalid', 'incorrecta-03');

\echo 'INCIDENTE 2: login exitoso'
-- Reemplazar sólo en el entorno local por credenciales de prueba:
-- SELECT public.fn_autenticar('usuario.prueba@example.invalid', 'password-de-prueba');

\echo 'INCIDENTE 3: lectura masiva de usuario'
SELECT *
FROM public.usuario
ORDER BY id_usuario;

\echo 'INCIDENTE 4: intento de escalamiento'
-- Debe fallar con permiso denegado para app_web/rol de bajo privilegio.
-- Ejecutar esta sentencia conectado como app_web:
GRANT admin_datos TO app_web;

\set ON_ERROR_STOP on