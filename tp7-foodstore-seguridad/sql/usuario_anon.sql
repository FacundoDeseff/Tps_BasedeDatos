-- Tabla anonimizada determinista para compartir agregados sin exponer PII.
-- Compatible con la tabla usuario del esquema base de Food Store.

BEGIN;

DROP TABLE IF EXISTS public.usuario_anon;

CREATE TABLE public.usuario_anon (
    id_usuario_anon BIGINT PRIMARY KEY,
    nombre_anon TEXT NOT NULL,
    apellido_anon TEXT NOT NULL,
    eliminado BOOLEAN NOT NULL
);

INSERT INTO public.usuario_anon (
    id_usuario_anon, nombre_anon, apellido_anon, eliminado
)
SELECT
    id_usuario,
    format('Usuario_%s', lpad(id_usuario::text, 8, '0')),
    format('Apellido_%s', lpad(id_usuario::text, 8, '0')),
    eliminado
FROM public.usuario
ORDER BY id_usuario;

COMMENT ON TABLE public.usuario_anon IS
    'Copia sintética determinista: no contiene nombre ni apellido reales.';

COMMIT;

-- Equivalencia de agregados (mismos grupos y conteos):
-- SELECT eliminado, count(*) FROM public.usuario GROUP BY eliminado ORDER BY eliminado;
-- SELECT eliminado, count(*) FROM public.usuario_anon GROUP BY eliminado ORDER BY eliminado;