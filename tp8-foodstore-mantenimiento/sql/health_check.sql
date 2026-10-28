-- =====================================================================
-- health_check.sql
-- TP Unidad 6 - Mantenimiento, respaldo y recuperacion (Food Store)
--
-- Objetivo: chequeo de salud diario de la base foodstore. Solo LEE
-- catalogo y vistas de estadisticas (pg_stat_*): no modifica datos ni
-- esquema, por lo que es seguro ejecutarlo contra la base principal.
--
-- Controles (los 4 de SPEC_U6.md seccion 3 + 1 mejora):
--   1. Tamano de la base y de sus tablas.
--   2. Conexiones y transacciones (pg_stat_database).
--   3. Tablas con tuplas muertas y estado de autovacuum/autoanalyze
--      (pg_stat_user_tables).
--   4. Consultas activas (pg_stat_activity).
--   5. MEJORA: cache hit, locks sin conceder y transacciones largas.
--
-- Uso:
--   psql -h localhost -p 5432 -U postgres -d foodstore \
--        -v ON_ERROR_STOP=1 -f sql/health_check.sql
--
-- Salida: cada control imprime una columna ESTADO con OK / ALERTA, de
-- modo que la evidencia muestre el problema y su resolucion sin tener
-- que interpretar numeros a ojo.
-- =====================================================================

\set ON_ERROR_STOP on
\pset pager off
\pset border 2
\pset null '(null)'

-- ---------------------------------------------------------------------
-- Umbrales. Se declaran como variables para que queden visibles en la
-- evidencia y sean el mismo criterio que usa maintenance.sql.
--   muertas_pct    10 %  -> la consigna pide detectar > 10 % de muertas
--   conexiones_pct 80 %  -> margen para no llegar a "too many clients"
--   cache_hit_pct  99 %  -> debajo de eso hay lecturas a disco evitables
--   tx_larga_min    5 min -> una transaccion abierta tanto tiempo bloquea VACUUM
-- ---------------------------------------------------------------------
\set umbral_muertas_pct 10
\set umbral_conexiones_pct 80
\set umbral_cache_hit_pct 99
\set umbral_tx_larga_min 5
\set umbral_muertas_abs 10000

\echo ''
\echo '==============================================================================='
\echo ' HEALTH CHECK - Food Store - TP8 Unidad 6'
\echo '==============================================================================='

SELECT current_database()                    AS base,
       current_user                          AS usuario,
       to_char(now(), 'YYYY-MM-DD HH24:MI:SS') AS ejecutado,
       current_setting('server_version')     AS motor;

-- =====================================================================
-- CONTROL 1/5 - TAMANO DE LA BASE
-- =====================================================================
\echo ''
\echo '--- CONTROL 1/5: tamano de la base --------------------------------------------'

SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_db,
       pg_database_size(current_database())                 AS tamano_bytes,
       (SELECT count(*) FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public' AND c.relkind = 'r')    AS tablas_en_public,
       (SELECT count(*) FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public' AND c.relkind = 'i')    AS indices_en_public;

SELECT relname                                            AS tabla,
       pg_size_pretty(pg_total_relation_size(relid))      AS total,
       pg_size_pretty(pg_relation_size(relid))            AS solo_datos,
       pg_size_pretty(pg_total_relation_size(relid)
                      - pg_relation_size(relid))          AS indices
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- =====================================================================
-- CONTROL 2/5 - CONEXIONES Y TRANSACCIONES
-- =====================================================================
\echo ''
\echo '--- CONTROL 2/5: conexiones y transacciones -----------------------------------'

WITH cfg AS (
    SELECT current_setting('max_connections')::int AS max_conexiones
)
SELECT s.numbackends                                                      AS conexiones,
       cfg.max_conexiones                                                 AS max_conexiones,
       round(100.0 * s.numbackends / cfg.max_conexiones, 2)               AS uso_conexiones_pct,
       s.xact_commit                                                      AS commits,
       s.xact_rollback                                                    AS rollbacks,
       CASE WHEN s.xact_commit + s.xact_rollback = 0 THEN 0
            ELSE round(100.0 * s.xact_rollback
                       / (s.xact_commit + s.xact_rollback), 2)
       END                                                                AS rollback_pct,
       s.deadlocks                                                        AS deadlocks,
       s.tup_returned                                                     AS tuplas_leidas,
       s.tup_fetched                                                      AS tuplas_fetched,
       s.tup_inserted                                                     AS tuplas_insert,
       s.tup_updated                                                      AS tuplas_update,
       s.tup_deleted                                                      AS tuplas_delete,
       s.temp_files                                                       AS archivos_temp,
       pg_size_pretty(s.temp_bytes)                                       AS bytes_temp,
       s.stats_reset                                                      AS reinicio_stats,
       CASE WHEN 100.0 * s.numbackends / cfg.max_conexiones > :umbral_conexiones_pct
            THEN 'ALERTA' ELSE 'OK' END                                   AS estado
FROM pg_stat_database s
CROSS JOIN cfg
WHERE s.datname = current_database();

-- =====================================================================
-- CONTROL 3/5 - TUPLAS MUERTAS Y AUTOVACUUM
-- =====================================================================
\echo ''
\echo '--- CONTROL 3/5: tuplas muertas y autovacuum ----------------------------------'
\echo '    (umbral: mas de 10 % de tuplas muertas o mas de 10000 en una tabla)'

SELECT relname                                                       AS tabla,
       n_live_tup                                                    AS tuplas_vivas,
       n_dead_tup                                                    AS tuplas_muertas,
       round(100.0 * n_dead_tup
             / GREATEST(n_live_tup + n_dead_tup, 1), 2)              AS muertas_pct,
       n_mod_since_analyze                                           AS mods_sin_analyze,
       to_char(last_vacuum,   'YYYY-MM-DD HH24:MI:SS')               AS ultimo_vacuum_manual,
       to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI:SS')             AS ultimo_autovacuum,
       to_char(last_analyze,  'YYYY-MM-DD HH24:MI:SS')               AS ultimo_analyze_manual,
       to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI:SS')            AS ultimo_autoanalyze,
       autovacuum_count                                              AS n_autovacuum,
       autoanalyze_count                                             AS n_autoanalyze,
       CASE WHEN 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
                 OR n_dead_tup > :umbral_muertas_abs
            THEN 'ALERTA' ELSE 'OK' END                              AS estado
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- Tablas que superan el umbral, en formato accionable para maintenance.sql
\echo ''
\echo '    Tablas por encima del umbral (estas son las que maintenance.sql debe tratar):'

SELECT relname                            AS tabla,
       n_dead_tup                         AS tuplas_muertas,
       round(100.0 * n_dead_tup
             / GREATEST(n_live_tup + n_dead_tup, 1), 2) AS muertas_pct,
       'VACUUM (ANALYZE)'                 AS accion_sugerida
FROM pg_stat_user_tables
WHERE 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
   OR n_dead_tup > :umbral_muertas_abs
ORDER BY n_dead_tup DESC;

-- =====================================================================
-- CONTROL 4/5 - CONSULTAS ACTIVAS
-- =====================================================================
\echo ''
\echo '--- CONTROL 4/5: consultas activas --------------------------------------------'

SELECT pid,
       usename                                                        AS usuario,
       datname                                                        AS base,
       state                                                          AS estado,
       client_addr                                                    AS cliente,
       to_char(backend_start, 'YYYY-MM-DD HH24:MI:SS')                AS inicio_sesion,
       to_char(query_start, 'YYYY-MM-DD HH24:MI:SS')                  AS inicio_consulta,
       round(extract(epoch FROM (now() - query_start))::numeric, 2)   AS segundos,
       wait_event_type                                                AS espera_tipo,
       wait_event                                                     AS espera_evento,
       left(regexp_replace(query, '\s+', ' ', 'g'), 70)               AS consulta
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY (state = 'active') DESC, query_start NULLS LAST;

\echo ''
\echo '    Resumen por estado de sesion:'

SELECT coalesce(state, '(sin estado)') AS estado_sesion,
       count(*)                        AS sesiones
FROM pg_stat_activity
GROUP BY coalesce(state, '(sin estado)')
ORDER BY sesiones DESC;

-- =====================================================================
-- CONTROL 5/5 - MEJORA: CACHE HIT, LOCKS Y TRANSACCIONES LARGAS
-- =====================================================================
-- Por que este control: los cuatro controles de la consigna muestran el
-- sintoma (tuplas muertas, sesiones) pero no dos causas muy frecuentes de
-- degradacion en produccion: (a) bajo cache hit, que indica lecturas a
-- disco evitables y suele anticipar falta de memoria o estadisticas
-- viejas; (b) locks sin conceder, que dejan consultas esperando y, si
-- duran, terminan impidiendo que VACUUM recupere espacio. Ademas se mide
-- la transaccion abierta mas antigua porque una transaccion larga o
-- "idle in transaction" bloquea el VACUUM de esas filas: el mantenimiento
-- de maintenance.sql no surte efecto hasta que se cierra. Los tres se
-- evaluan en una sola pasada para que el alerta aparezca en el mismo
-- health check que se archiva como evidencia.
\echo ''
\echo '--- CONTROL 5/5 (mejora): cache hit, locks y transacciones largas -------------'

WITH io AS (
    SELECT blks_hit, blks_read
    FROM pg_stat_database
    WHERE datname = current_database()
),
tx AS (
    SELECT coalesce(max(extract(epoch FROM (now() - xact_start))), 0) AS segundos_tx_mas_larga,
           count(*) FILTER (WHERE state LIKE 'idle in transaction%')   AS idle_in_transaction
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
),
locks AS (
    SELECT count(*) AS esperando_lock
    FROM pg_locks
    WHERE NOT granted
)
SELECT round(100.0 * io.blks_hit / GREATEST(io.blks_hit + io.blks_read, 1), 3) AS cache_hit_pct,
       io.blks_hit                                                              AS blks_hit,
       io.blks_read                                                             AS blks_read,
       locks.esperando_lock                                                     AS locks_sin_conceder,
       tx.idle_in_transaction                                                   AS sesiones_idle_in_tx,
       round(tx.segundos_tx_mas_larga::numeric, 2)                              AS tx_mas_larga_seg,
       CASE WHEN round(100.0 * io.blks_hit / GREATEST(io.blks_hit + io.blks_read, 1), 3) < :umbral_cache_hit_pct
                 OR locks.esperando_lock > 0
                 OR tx.segundos_tx_mas_larga > :umbral_tx_larga_min * 60
            THEN 'ALERTA' ELSE 'OK' END                                         AS estado
FROM io, tx, locks;

-- =====================================================================
-- RESUMEN
-- =====================================================================
\echo ''
\echo '--- RESUMEN -------------------------------------------------------------------'

WITH muertas AS (
    SELECT count(*) FILTER (
               WHERE 100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1) > :umbral_muertas_pct
                  OR n_dead_tup > :umbral_muertas_abs) AS tablas_alerta,
           coalesce(sum(n_dead_tup), 0)                AS muertas_total,
           coalesce(sum(n_live_tup), 0)                AS vivas_total
    FROM pg_stat_user_tables
),
base AS (
    SELECT numbackends::numeric / current_setting('max_connections')::numeric * 100 AS uso_conexiones_pct,
           count(*) FILTER (WHERE state = 'active')                                  AS activas
    FROM pg_stat_database d
    CROSS JOIN pg_stat_activity a
    WHERE d.datname = current_database()
    GROUP BY d.numbackends, d.datname
)
SELECT m.tablas_alerta                                              AS tablas_con_alerta,
       m.muertas_total                                              AS tuplas_muertas_total,
       round(100.0 * m.muertas_total / GREATEST(m.vivas_total + m.muertas_total, 1), 2) AS muertas_pct_global,
       round(b.uso_conexiones_pct, 2)                               AS uso_conexiones_pct,
       b.activas                                                    AS sesiones_activas,
       CASE WHEN m.tablas_alerta > 0 THEN 'ATENCION: ejecutar maintenance.sql'
            ELSE 'OK: sin acciones de mantenimiento requeridas' END AS diagnostico
FROM muertas m, base b;

\echo ''
\echo '==============================================================================='
\echo ' FIN DEL HEALTH CHECK'
\echo '==============================================================================='
