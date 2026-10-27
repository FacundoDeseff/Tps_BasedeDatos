-- ============================================================================
-- Food Store - Parte C, punto 1: simulacro de incidente de acceso indebido
-- PostgreSQL 17 - base copia_trabajo (esquema public)
--
-- ADVERTENCIA: este script se ejecuta UNICAMENTE contra la base local de
-- desarrollo del equipo (copia_trabajo). Ninguna de sus sentencias debe
-- correrse contra bases de otros equipos ni contra sistemas de terceros.
--
-- Se ejecuta conectado como app_web. Ese es el punto del simulacro: el
-- escalamiento falla porque la identidad es de bajo privilegio. Si se corre
-- como postgres, el GRANT final tendria exito y ademas dejaria a app_web con
-- membresia en admin_datos, arruinando el escenario y el esquema de la Parte A.
--
-- Uso (una sola linea; en PowerShell se puede cortar con acento grave):
--
--   psql -U app_web -h localhost -d copia_trabajo -v clave_prueba=CLAVE_SINTETICA -f sql/simulacro_incidente.sql
--
--   -v email_objetivo=... es opcional; por defecto usa la cuenta con la que se
--   capturo el log del 2026-10-27 (cuenta_a@sintetico.example).
--
-- La clave de prueba NUNCA se escribe en este archivo ni se commitea: se pasa
-- como variable de psql en el momento de ejecutar.
--
-- Si la cuenta no existe o quedo bloqueada por corridas anteriores, ejecutar
-- primero sql/simulacro_preparacion.sql conectado como postgres.
-- ============================================================================

\set ON_ERROR_STOP off

\if :{?clave_prueba}
\else
    \warn 'Falta la variable clave_prueba. Ver el encabezado del script.'
    \quit
\endif

\if :{?email_objetivo}
\else
    \set email_objetivo 'cuenta_a@sintetico.example'
\endif

\echo '=== Identidad de la sesion: debe ser app_web ==='
SELECT current_user AS identidad, session_user AS usuario_de_sesion;

\echo '=== INICIO_C ==='
SELECT 'INICIO_C' AS marcador;

-- ----------------------------------------------------------------------------
-- C.1 paso 1: intentos fallidos de inicio de sesion contra fn_autenticar
-- Devuelve NULL cuando la clave es incorrecta y suma 1 en intentos_fallidos.
-- El umbral de bloqueo de la cuenta es 5 (RF-08), por eso se hacen 4: con 5
-- la quinta llamada devolveria 'cuenta_bloqueada' y no habria login exitoso.
-- ----------------------------------------------------------------------------
\echo '--- C.1 paso 1: cuatro intentos fallidos contra fn_autenticar ---'
SELECT public.fn_autenticar(:'email_objetivo', 'clave_incorrecta_01') AS intento_1;
SELECT public.fn_autenticar(:'email_objetivo', 'clave_incorrecta_02') AS intento_2;
SELECT public.fn_autenticar(:'email_objetivo', 'clave_incorrecta_03') AS intento_3;
SELECT public.fn_autenticar(:'email_objetivo', 'clave_incorrecta_04') AS intento_4;

-- ----------------------------------------------------------------------------
-- C.1 paso 2: inicio de sesion exitoso
-- Quinta llamada: el contador esta en 4 (debajo del umbral) y la clave es
-- correcta, asi que devuelve el rol de aplicacion y reinicia el contador a 0.
--
-- OJO, esto es clave para C.5: el log del servidor registra la SENTENCIA, no su
-- resultado. La prueba de que el login tuvo exito es esta salida de psql. El log
-- por si solo no puede demostrarlo, y una IA que lo afirme esta completando un
-- dato que la evidencia no sustenta.
-- ----------------------------------------------------------------------------
\echo '--- C.1 paso 2: inicio de sesion exitoso (devuelve el rol) ---'
SELECT public.fn_autenticar(:'email_objetivo', :'clave_prueba') AS resultado_login;

-- ----------------------------------------------------------------------------
-- C.1 paso 3: lectura masiva de la tabla usuario
-- app_web no tiene privilegios sobre la tabla: se esperan dos ERROR.
-- ----------------------------------------------------------------------------
\echo '--- C.1 paso 3: lectura masiva de usuario (debe fallar) ---'
SELECT * FROM public.usuario;
SELECT count(*) FROM public.usuario;

-- ----------------------------------------------------------------------------
-- C.1 paso 4 / C.2: intento de escalamiento de privilegios
-- app_web no tiene CREATEROLE ni la opcion ADMIN sobre admin_datos, asi que
-- ambos GRANT deben fallar. Si alguno tuviera exito, es un hallazgo: el esquema
-- de la Parte A tiene un defecto y hay que corregirlo antes de seguir.
-- ----------------------------------------------------------------------------
\echo '--- C.1 paso 4: intento de escalamiento (debe fallar) ---'
GRANT admin_datos TO app_web;
GRANT admin_datos TO rol_soporte;

\echo '=== FIN_C ==='
SELECT 'FIN_C' AS marcador;

-- ============================================================================
-- Resultado esperado (contrastado con la corrida del 2026-10-27 16:45 -03)
-- ============================================================================
--   intento_1 .. intento_4     -> NULL
--   resultado_login            -> el rol de la cuenta (en la corrida: 'cliente')
--   SELECT * FROM usuario      -> ERROR:  permiso denegado a la tabla usuario
--   SELECT count(*)            -> ERROR:  permiso denegado a la tabla usuario
--   GRANT admin_datos TO app_web
--                              -> ERROR:  se ha denegado el permiso para otorgar el rol "admin_datos"
--                                 DETALLE: Solo los roles con la opcion ADMIN en el rol
--                                 "admin_datos" pueden otorgar este rol.
--   GRANT admin_datos TO rol_soporte
--                              -> mismo error
--
-- C.2 - Verificacion de que el escalamiento no dejo rastro. Ejecutar como
-- postgres; debe devolver 0 filas:
--
--   SELECT m.rolname AS miembro_de, r.rolname AS miembro
--   FROM pg_auth_members AS am
--   JOIN pg_roles AS r ON r.oid = am.member
--   JOIN pg_roles AS m ON m.oid = am.roleid
--   WHERE m.rolname = 'admin_datos';
--
-- C.3 - Despues de correr esto: extraer del log del servidor el fragmento
-- entre INICIO_C y FIN_C (mas las lineas de conexion y desconexion de esa
-- sesion) y ANONIMIZARLO antes de darselo a cualquier asistente de IA:
-- reemplazar emails y claves por valores sinteticos; conservar rol, base,
-- origen y horas, que son lo unico necesario para reconstruir la secuencia.
-- ============================================================================
