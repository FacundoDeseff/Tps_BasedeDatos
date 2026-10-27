-- Pruebas mínimas para log_connections, log_disconnections y log_statement.
-- Ejecutar cada bloque con la identidad indicada y guardar el log del servidor.

\set ON_ERROR_STOP off
\echo 'AUDITORIA: lectura'
SELECT id_categoria, nombre
FROM public.categoria
ORDER BY id_categoria
LIMIT 5;

\echo 'AUDITORIA: insercion'
INSERT INTO public.categoria (nombre)
VALUES ('__AUDITORIA_TEST__')
ON CONFLICT (nombre) DO NOTHING;

\echo 'AUDITORIA: actualizacion'
UPDATE public.categoria
SET nombre = '__AUDITORIA_TEST_ACTUALIZADA__'
WHERE nombre = '__AUDITORIA_TEST__';

\echo 'AUDITORIA: limpieza de datos de prueba'
DELETE FROM public.categoria
WHERE nombre IN ('__AUDITORIA_TEST__', '__AUDITORIA_TEST_ACTUALIZADA__');

\echo 'AUDITORIA: login fallido'
-- PostgreSQL registra este intento en el log si se conecta con psql:
-- psql -h 127.0.0.1 -U usuario_inexistente -d food_store
-- No se incluye una contraseña real ni se automatiza el ingreso de credenciales.

\set ON_ERROR_STOP on