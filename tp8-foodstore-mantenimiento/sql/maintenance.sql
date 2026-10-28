-- =====================================================================
-- maintenance.sql
-- TP Unidad 6 - Mantenimiento, respaldo y recuperacion (Food Store)
--
-- Objetivo: revision semanal de mantenimiento. Observa tuplas muertas y
-- las fechas de autovacuum / autoanalyze, decide que tablas justifican una
-- accion y ejecuta SOLO esa accion.
--
-- Decision de diseno (la justificacion completa va en la evidencia):
--   * VACUUM FULL queda PROHIBIDO como rutina (SPEC_U6.md regla 6): toma
--     un lock ACCESS EXCLUSIVE sobre la tabla y reescribe el archivo
--     completo, dejando la base inutilizable mientras dura.
--   * VACUUM (ANALYZE) es la accion correcta: marca el espacio de las
--     tuplas muertas como reutilizable SIN bloquear escrituras (comparte
--     lock con las operaciones normales) y de paso actualiza estadisticas.
--   * ANALYZE a secas solo se usa cuando el problema es de estadisticas
--     (muchas modificaciones sin analyze) y no de espacio a recuperar.
--
-- Uso:
--   psql -h localhost -p 5432 -U postgres -d foodstore \
--        -v ON_ERROR_STOP=1 -f sql/maintenance.sql
-- =====================================================================

\set ON_ERROR_STOP on
\pset pager off
\pset border 2
\pset null '(null)'

-- Mismo criterio que health_check.sql, para que el antes/despues sea comparable.
\set umbral_muertas_pct 10
\set umbral_muertas_abs 10000
\set umbral_mods_sin_analyze 5000

\echo ''
\echo '==============================================================================='
\echo ' MANTENIMIENTO - Food Store - TP8 Unidad 6'
\echo '==============================================================================='

SELECT current_database()                     AS base,
       to_char(now(), 'YYYY-MM-DD HH24:MI:SS') AS ejecutado,
       current_setting('server_version')      AS motor;

-- =====================================================================
-- 1. OBSERVACION: tuplas muertas y actividad de autovacuum / autoanalyze
-- =====================================================================
\echo ''
\echo '--- 1. OBSERVACION: tuplas muertas y fechas de autovacuum/autoanalyze ----------'
\echo '    (autovacuum_naptime y umbrales efectivos del servidor)'

SELECT current_setting('autovacuum')                          AS autovacuum_habilitado,
       current_setting('autovacuum_naptime')                  AS naptime,
       current_setting('autovacuum_vacuum_threshold')         AS vac_threshold,
       current_setting('autovacuum_vacuum_scale_factor')      AS vac_scale_factor,
       current_setting('autovacuum_analyze_threshold')        AS ana_threshold,
       current_setting('autovacuum_analyze_scale_factor')     AS ana_scale_factor;

SELECT relname                                                        AS tabla,
       n_live_tup                                                     AS tuplas_vivas,
       n_dead_tup                                                     AS tuplas_muertas,
       round(100.0 * n_dead_tup
             / GREATEST(n_live_tup + n_dead_tup, 1), 2)               AS muertas_pct,
       n_mod_since_analyze                                            AS mods_sin_analyze,
       to_char(last_vacuum,      'YYYY-MM-DD HH24:MI:SS')             AS ultimo_vacuum,
       to_char(last_autovacuum,  'YYYY-MM-DD HH24:MI:SS')             AS ultimo_autovacuum,
       to_char(last_analyze,     'YYYY-MM-DD HH24:MI:SS')             AS ultimo_analyze,
       to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI:SS')             AS ultimo_autoanalyze,
       autovacuum_count                                               AS n_autovac,
       autoanalyze_count                                              AS n_autoana,
       pg_size_pretty(pg_total_relation_size(relid))                  AS tamano
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- =====================================================================
-- 2. DIAGNOSTICO: que se decide y por que
-- =====================================================================
\echo ''
\echo '--- 2. DIAGNOSTICO: accion decidida por tabla --------------------------------'
\echo '    VACUUM (ANALYZE) si supera el umbral de tuplas muertas;'
\echo '    ANALYZE si solo hay estadisticas viejas; nada en el resto.'

SELECT tabla,
       tuplas_muertas,
       muertas_pct,
       mods_sin_analyze,
       accion,
       justificacion
FROM (
    SELECT relname AS tabla,
           n_dead_tup AS tuplas_muertas,
           round(100.0 * n_dead_tup
                 / GREATEST(n_live_tup + n_dead_tup, 1), 2) AS muertas_pct,
           n_mod_since_analyze AS mods_sin_analyze,
           CASE
               WHEN 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
                    OR n_dead_tup > :umbral_muertas_abs
                   THEN 'VACUUM (ANALYZE)'
               WHEN n_mod_since_analyze > :umbral_mods_sin_analyze
                   THEN 'ANALYZE'
               ELSE 'sin accion'
           END AS accion,
           CASE
               WHEN 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
                    THEN 'supera el ' || :umbral_muertas_pct::text || ' % de tuplas muertas: hay espacio por recuperar'
               WHEN n_dead_tup > :umbral_muertas_abs
                    THEN 'mas de ' || :umbral_muertas_abs::text || ' tuplas muertas: hay espacio por recuperar'
               WHEN n_mod_since_analyze > :umbral_mods_sin_analyze
                    THEN 'muchas modificaciones sin analyze: las estadisticas estan viejas y el planificador decide mal'
               ELSE 'dentro de parametros'
           END AS justificacion
    FROM pg_stat_user_tables
) s
ORDER BY (accion = 'VACUUM (ANALYZE)') DESC,
         (accion = 'ANALYZE') DESC,
         tuplas_muertas DESC;

-- =====================================================================
-- 3. ACCION 1 - VACUUM (ANALYZE) sobre las tablas que lo justifican
-- =====================================================================
\echo ''
\echo '--- 3. ACCION: VACUUM (ANALYZE) sobre las tablas con exceso de muertas --------'
\echo '    Sin VACUUM FULL: no se toma ACCESS EXCLUSIVE ni se reescribe el archivo.'

SELECT format('VACUUM (ANALYZE, VERBOSE) %I;', relname) AS comando
FROM pg_stat_user_tables
WHERE 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
   OR n_dead_tup > :umbral_muertas_abs
ORDER BY n_dead_tup DESC
\gexec

-- =====================================================================
-- 4. ACCION 2 - ANALYZE solo donde el problema es de estadisticas
-- =====================================================================
\echo ''
\echo '--- 4. ACCION: ANALYZE sobre tablas con estadisticas viejas ------------------'

SELECT format('ANALYZE VERBOSE %I;', relname) AS comando
FROM pg_stat_user_tables
WHERE NOT (100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
           OR n_dead_tup > :umbral_muertas_abs)
  AND n_mod_since_analyze > :umbral_mods_sin_analyze
ORDER BY n_mod_since_analyze DESC
\gexec

-- =====================================================================
-- 5. VERIFICACION POST-MANTENIMIENTO
-- =====================================================================
\echo ''
\echo '--- 5. VERIFICACION: estado despues del mantenimiento -------------------------'

SELECT relname                                                        AS tabla,
       n_live_tup                                                     AS tuplas_vivas,
       n_dead_tup                                                     AS tuplas_muertas,
       round(100.0 * n_dead_tup
             / GREATEST(n_live_tup + n_dead_tup, 1), 2)               AS muertas_pct,
       to_char(last_vacuum,     'YYYY-MM-DD HH24:MI:SS')              AS ultimo_vacuum,
       to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI:SS')              AS ultimo_autovacuum,
       to_char(last_analyze,    'YYYY-MM-DD HH24:MI:SS')              AS ultimo_analyze,
       CASE WHEN 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
                 OR n_dead_tup > :umbral_muertas_abs
            THEN 'PENDIENTE' ELSE 'OK' END                            AS estado
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

\echo ''
\echo '--- Integridad posterior (debe dar todo 0) ------------------------------------'
SELECT (SELECT count(*) FROM producto WHERE stock < 0 OR precio_lista <= 0)       AS productos_invalidos,
       (SELECT count(*) FROM detalle_pedido WHERE cantidad <= 0 OR subtotal < 0)   AS detalles_invalidos,
       (SELECT count(*) FROM pedido p
         JOIN (SELECT pedido_id, sum(subtotal) s
                 FROM detalle_pedido GROUP BY pedido_id) x
           ON x.pedido_id = p.id_pedido
        WHERE p.total <> x.s)                                                      AS totales_descuadrados;

\echo ''
\echo '==============================================================================='
\echo ' FIN DEL MANTENIMIENTO'
\echo '==============================================================================='
