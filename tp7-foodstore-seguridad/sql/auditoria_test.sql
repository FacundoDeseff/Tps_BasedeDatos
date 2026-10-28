-- Auditoría nativa (Parte B): reproducción de la secuencia ejecutada.
--
-- Base: copia_trabajo (PostgreSQL 17). Requiere los parámetros de auditoría
-- activos (docs/informe_auditoria.md §1):
--   log_connections = on, log_disconnections = on,
--   log_statement = 'all',
--   log_line_prefix = '%m [%p] user=%u,db=%d,app=%a,client=%h '
--
-- La secuencia son CINCO sesiones separadas. Este archivo se ejecuta una vez por
-- sesión, con el rol y la conexión que indica cada bloque: los bloques 1, 2 y 5
-- son sentencias SQL; los bloques 3 y 4 son intentos de conexión y se ejecutan
-- desde la consola, no dentro de psql.
--
-- Los marcadores INICIO_B y FIN_B delimitan el tramo del log que se copia a
-- docs/log_auditoria_prueba.txt.
--
-- Este archivo describe la secuencia que ya se ejecutó y cuya salida está en
-- docs/log_auditoria_prueba.txt. No se volvió a ejecutar para esta entrega.

\set ON_ERROR_STOP off

-- ===========================================================================
-- SESIÓN 1 — app_web: una lectura permitida y una lectura denegada
--   psql -U app_web -h localhost -d copia_trabajo
-- ===========================================================================
\echo 'INICIO_B'

\echo 'S1 app_web: lectura permitida sobre categoria'
SELECT id_categoria, nombre
FROM public.categoria
ORDER BY id_categoria
LIMIT 5;

\echo 'S1 app_web: lectura denegada sobre pedido (se espera ERROR)'
SELECT * FROM public.pedido LIMIT 1;

-- ===========================================================================
-- SESIÓN 2 — admin_datos: inserción, actualización y borrado
--   psql -U admin_datos -h localhost -d copia_trabajo
-- ===========================================================================
\echo 'S2 admin_datos: insercion'
INSERT INTO public.categoria (nombre)
VALUES ('__AUDITORIA_TEST__')
ON CONFLICT (nombre) DO NOTHING;

\echo 'S2 admin_datos: actualizacion'
UPDATE public.categoria
SET nombre = '__AUDITORIA_TEST_ACTUALIZADA__'
WHERE nombre = '__AUDITORIA_TEST__';

\echo 'S2 admin_datos: borrado de los datos de prueba'
DELETE FROM public.categoria
WHERE nombre IN ('__AUDITORIA_TEST__', '__AUDITORIA_TEST_ACTUALIZADA__');

-- ===========================================================================
-- SESIÓN 3 — inicio de sesión fallido con un rol que no existe
--   psql -h localhost -U usuario_inexistente -d copia_trabajo
-- (cualquier clave o ninguna; el motor responde FATAL: no existe el rol)
-- ===========================================================================

-- ===========================================================================
-- SESIÓN 4 — inicio de sesión fallido con un rol real y clave incorrecta
--   psql -h localhost -U app_web -d copia_trabajo
-- (escribir una clave incorrecta en el prompt; no se guarda ninguna clave acá)
-- ===========================================================================

-- ===========================================================================
-- SESIÓN 5 — app_web: cierre del tramo
--   psql -U app_web -h localhost -d copia_trabajo
-- ===========================================================================
\echo 'FIN_B'
SELECT 'FIN_B' AS marcador;

\set ON_ERROR_STOP on
