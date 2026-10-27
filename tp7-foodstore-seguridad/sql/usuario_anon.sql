-- ============================================================================
-- Food Store - Parte D, punto 1: tabla usuario_anon
-- PostgreSQL 17 - base copia_trabajo (esquema public)
--
-- Ejecutar conectado como postgres (dueno de usuario y de la politica de
-- privilegios por defecto que fija roles.sql):
--
--   psql -U postgres -d copia_trabajo -f sql/usuario_anon.sql
--
-- Criterio de anonimizacion (determinista, mismo espiritu que la Clase 2):
--
--   SE REEMPLAZA
--     nombre / apellido -> Usuario_NNNNNNNN / Apellido_NNNNNNNN
--     email             -> anon_NNNNNNNN@anon.invalid   (dominio reservado)
--     fecha_alta        -> solo el mes (mes_alta), no el instante exacto
--
--   SE CONSERVA (no identifica y es necesario para agregar)
--     id_usuario (como id_usuario_anon), rol, eliminado
--
--   NO SE COPIA
--     password_hash y intentos_fallidos (credenciales y senales de seguridad)
--
-- Por que se conserva el id: es la unica forma de comprobar que hay una fila
-- por usuario y que la transformacion es determinista. No se publica: los
-- resultados de la Parte D son agregados por rol y mes, donde el id desaparece.
-- ============================================================================

BEGIN;

DROP TABLE IF EXISTS public.usuario_anon;

CREATE TABLE public.usuario_anon (
    id_usuario_anon bigint  PRIMARY KEY,
    nombre_anon     text    NOT NULL,
    apellido_anon   text    NOT NULL,
    email_anon      text    NOT NULL UNIQUE,
    rol             text    NOT NULL,
    mes_alta        date    NOT NULL,
    eliminado       boolean NOT NULL
);

-- Transformacion determinista: cada fila se deriva de su id, nunca del azar.
-- El mes se calcula en UTC para que el resultado no dependa del TimeZone de la
-- sesion que ejecute la consulta (si dependiera, la equivalencia de la Parte D
-- podria romperse al correr las dos consultas en sesiones distintas).
-- fecha_alta es NOT NULL por construccion (sql/00_reconstruccion_clase2.sql);
-- si aparece un NULL, el INSERT falla a proposito en lugar de inventar datos.
INSERT INTO public.usuario_anon (
    id_usuario_anon, nombre_anon, apellido_anon, email_anon,
    rol, mes_alta, eliminado
)
SELECT
    u.id_usuario,
    format('Usuario_%s',  lpad(u.id_usuario::text, 8, '0')),
    format('Apellido_%s', lpad(u.id_usuario::text, 8, '0')),
    format('anon_%s@anon.invalid', lpad(u.id_usuario::text, 8, '0')),
    u.rol,
    (date_trunc('month', u.fecha_alta AT TIME ZONE 'UTC'))::date,
    u.eliminado
FROM public.usuario AS u
ORDER BY u.id_usuario;

-- indice para la agregacion que pide la consigna (rol + mes de alta)
CREATE INDEX idx_usuario_anon_rol_mes
    ON public.usuario_anon (rol, mes_alta);

COMMENT ON TABLE public.usuario_anon IS
    'Copia sintetica determinista de usuario: sin nombre, apellido ni email reales; conserva rol, mes de alta y estado para poder agregar.';

COMMENT ON COLUMN public.usuario_anon.mes_alta IS
    'Mes de fecha_alta calculado en UTC. Se descarta el instante exacto a proposito: es un cuasi-identificador.';

COMMENT ON COLUMN public.usuario_anon.email_anon IS
    'Reemplazo sintetico sobre el dominio reservado .invalid: no es enrutable y no corresponde a ninguna persona.';

COMMIT;

-- ============================================================================
-- Evidencia de equivalencia (Parte D, punto 3)
--
-- Las tres consultas de abajo se ejecutan al correr este mismo script y quedan
-- impresas en la salida. La A y la B son la misma agregacion sobre distinta
-- tabla: deben coincidir grupo por grupo. La C es el chequeo automatico y debe
-- devolver 0 filas. Copiar la salida tal cual a docs/verificacion_equivalencia.md.
-- ============================================================================

\echo '--- A) REAL: cantidad de usuarios por rol y por mes de alta ---'
SELECT u.rol,
       (date_trunc('month', u.fecha_alta AT TIME ZONE 'UTC'))::date AS mes_alta,
       count(*) AS cantidad
FROM public.usuario AS u
GROUP BY 1, 2
ORDER BY 1, 2;

\echo '--- B) ANONIMIZADA: la misma agregacion sobre usuario_anon ---'
SELECT a.rol,
       a.mes_alta,
       count(*) AS cantidad
FROM public.usuario_anon AS a
GROUP BY 1, 2
ORDER BY 1, 2;

\echo '--- C) CHEQUEO AUTOMATICO: debe devolver 0 filas ---'
WITH real AS (
    SELECT u.rol,
           (date_trunc('month', u.fecha_alta AT TIME ZONE 'UTC'))::date AS mes_alta,
           count(*) AS cantidad
    FROM public.usuario AS u
    GROUP BY 1, 2
), anon AS (
    SELECT a.rol, a.mes_alta, count(*) AS cantidad
    FROM public.usuario_anon AS a
    GROUP BY 1, 2
)
SELECT COALESCE(r.rol, a.rol)           AS rol,
       COALESCE(r.mes_alta, a.mes_alta) AS mes_alta,
       r.cantidad                       AS cantidad_real,
       a.cantidad                       AS cantidad_anon
FROM real AS r
FULL JOIN anon AS a USING (rol, mes_alta)
WHERE r.cantidad IS DISTINCT FROM a.cantidad;

\echo '--- D) CARDINALIDAD: las dos columnas deben dar el mismo total ---'
SELECT (SELECT count(*) FROM public.usuario)      AS filas_usuario,
       (SELECT count(*) FROM public.usuario_anon) AS filas_anon;
