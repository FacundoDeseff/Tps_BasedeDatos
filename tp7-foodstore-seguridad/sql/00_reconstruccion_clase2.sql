-- Food Store - Reconstrucción de los artefactos de la Clase 2
-- PostgreSQL 17 - base copia_trabajo (esquema public)
--
-- Los artefactos de la Clase 2 (columnas de autenticación en usuario,
-- fn_autenticar y fn_resetear_password) no existían en esta base, por lo que
-- se reconstruyen según docs/kiro_roles_spec (RF-08, RF-09, RF-10).
--
-- Ejecutar ANTES de roles.sql, conectado como postgres (dueño de los objetos).
-- Es idempotente: puede correrse más de una vez.
-- Este script no asigna contraseñas: password_hash queda en NULL hasta que
-- admin_datos (o postgres) llame a fn_resetear_password con una clave que NO
-- se guarda en el repositorio. Los GRANT EXECUTE a roles se hacen en roles.sql.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Columnas nuevas en usuario (RF-10)
-- ---------------------------------------------------------------------------
ALTER TABLE public.usuario
    ADD COLUMN IF NOT EXISTS email             text,
    ADD COLUMN IF NOT EXISTS password_hash     text,
    ADD COLUMN IF NOT EXISTS rol               text        NOT NULL DEFAULT 'cliente',
    ADD COLUMN IF NOT EXISTS fecha_alta        timestamptz,
    ADD COLUMN IF NOT EXISTS intentos_fallidos integer     NOT NULL DEFAULT 0;

-- Datos sintéticos deterministas (sólo donde todavía no hay valor).
-- El email usa el dominio reservado .invalid: no corresponde a ninguna persona.
UPDATE public.usuario
SET email = format('usuario%s@example.invalid', id_usuario)
WHERE email IS NULL;

-- Fecha de alta repartida en 24 meses (ene-2024 a dic-2025) según el id,
-- para que la agregación por mes de la Parte D tenga varios grupos.
UPDATE public.usuario
SET fecha_alta = timestamptz '2024-01-01'
                 + make_interval(months => (id_usuario % 24)::int,
                                 days   => (id_usuario % 28)::int)
WHERE fecha_alta IS NULL;

-- Rol de aplicación (no es un rol de la base): 1 de cada 50 es 'admin'.
UPDATE public.usuario
SET rol = 'admin'
WHERE id_usuario % 50 = 0
  AND rol = 'cliente';

ALTER TABLE public.usuario
    ALTER COLUMN fecha_alta SET DEFAULT now(),
    ALTER COLUMN fecha_alta SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_usuario_email
    ON public.usuario (email);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_usuario_rol'
                     AND conrelid = 'public.usuario'::regclass) THEN
        ALTER TABLE public.usuario
            ADD CONSTRAINT ck_usuario_rol CHECK (rol IN ('cliente', 'admin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_usuario_email_activo'
                     AND conrelid = 'public.usuario'::regclass) THEN
        ALTER TABLE public.usuario
            ADD CONSTRAINT ck_usuario_email_activo
            CHECK (eliminado OR email IS NOT NULL);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'ck_usuario_intentos'
                     AND conrelid = 'public.usuario'::regclass) THEN
        ALTER TABLE public.usuario
            ADD CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos >= 0);
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 2. fn_autenticar (RF-08)
-- Devuelve el rol de aplicación si las credenciales son válidas, NULL si no, y
-- 'cuenta_bloqueada' si la cuenta ya alcanzó el umbral de intentos fallidos.
-- Mismo resultado (NULL) para email inexistente y para clave incorrecta.
-- SECURITY DEFINER: app_web no tiene SELECT sobre password_hash; esta función
-- es la única puerta a esa columna. search_path fijo con pg_temp al final.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_autenticar(p_email text, p_password text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    c_umbral CONSTANT integer := 5;
    v_id        bigint;
    v_hash      text;
    v_rol       text;
    v_intentos  integer;
    v_ok        boolean;
BEGIN
    SELECT u.id_usuario, u.password_hash, u.rol, u.intentos_fallidos
    INTO v_id, v_hash, v_rol, v_intentos
    FROM public.usuario AS u
    WHERE u.email = p_email
      AND u.eliminado = FALSE;

    -- Se hace el mismo trabajo criptográfico exista o no el email, para no
    -- agregar una diferencia de tiempo evidente (no se garantiza tiempo constante).
    v_ok := crypt(coalesce(p_password, ''), coalesce(v_hash, gen_salt('bf', 8)))
            = coalesce(v_hash, '');

    IF v_id IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_intentos >= c_umbral THEN
        RETURN 'cuenta_bloqueada';
    END IF;

    IF v_ok THEN
        IF v_intentos > 0 THEN
            UPDATE public.usuario SET intentos_fallidos = 0 WHERE id_usuario = v_id;
        END IF;
        RETURN v_rol;
    END IF;

    UPDATE public.usuario
    SET intentos_fallidos = intentos_fallidos + 1
    WHERE id_usuario = v_id;
    RETURN NULL;
END
$$;

REVOKE ALL ON FUNCTION public.fn_autenticar(text, text) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. fn_resetear_password (RF-09)
-- Única vía para escribir password_hash: fuerza bcrypt (costo 8). No registra
-- ni devuelve la clave. No actúa sobre usuarios eliminados.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_resetear_password(
    p_id_usuario bigint, p_nueva_password text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_nueva_password IS NULL OR p_nueva_password = '' THEN
        RAISE EXCEPTION 'La nueva contraseña no puede ser vacía';
    END IF;

    UPDATE public.usuario
    SET password_hash     = crypt(p_nueva_password, gen_salt('bf', 8)),
        intentos_fallidos = 0
    WHERE id_usuario = p_id_usuario
      AND eliminado = FALSE;

    RETURN FOUND;
END
$$;

REVOKE ALL ON FUNCTION public.fn_resetear_password(bigint, text) FROM PUBLIC;

COMMIT;

-- Verificación sugerida (como postgres):
-- \d usuario
-- \df+ fn_*
-- SELECT count(*) AS usuarios, count(DISTINCT email) AS emails,
--        count(*) FILTER (WHERE rol = 'admin') AS admins,
--        count(*) FILTER (WHERE password_hash IS NOT NULL) AS con_clave
-- FROM usuario;
-- SELECT date_trunc('month', fecha_alta) AS mes, count(*)
-- FROM usuario GROUP BY 1 ORDER BY 1;
