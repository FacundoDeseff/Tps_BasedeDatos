-- Food Store - Roles y privilegios de mínimo privilegio
-- PostgreSQL 16+
--
-- Ejecutar conectado como propietario de la base (o como administrador).
-- Este script no asigna contraseñas: deben gestionarse fuera del repositorio.

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos LOGIN NOSUPERUSER CREATEDB CREATEROLE INHERIT;
    END IF;
END
$$;

GRANT rol_app_lectura, rol_app_escritura TO app_web;
REVOKE admin_datos FROM app_web;

REVOKE ALL ON SCHEMA public FROM rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, app_web;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM app_web;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM app_web;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM app_web;

-- La aplicación sólo puede consultar catálogos públicos.
DO $$
DECLARE
    tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY['categoria', 'producto']
    LOOP
        IF to_regclass(format('public.%I', tabla)) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON TABLE public.%I FROM rol_app_lectura', tabla);
            EXECUTE format('GRANT SELECT ON TABLE public.%I TO rol_app_lectura', tabla);
        END IF;
    END LOOP;
END
$$;

-- Escritura transaccional: no se otorga DELETE ni UPDATE general.
DO $$
DECLARE
    tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY['pedido', 'detalle_pedido', 'linea_pedido']
    LOOP
        IF to_regclass(format('public.%I', tabla)) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON TABLE public.%I FROM rol_app_escritura', tabla);
            EXECUTE format('GRANT INSERT ON TABLE public.%I TO rol_app_escritura', tabla);
        END IF;
    END LOOP;
END
$$;

-- Las tablas con identidad necesitan permisos sobre sus secuencias para INSERT.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_app_escritura;

-- Soporte: consulta de usuarios y actualización exclusivamente de datos de contacto
-- o estado. La lista de columnas se adapta al esquema de la cursada.
DO $$
DECLARE
    cols text[] := ARRAY[]::text[];
    c text;
BEGIN
    IF to_regclass('public.usuario') IS NULL THEN
        RETURN;
    END IF;

    EXECUTE 'REVOKE ALL ON TABLE public.usuario FROM rol_soporte';
    EXECUTE 'GRANT SELECT ON TABLE public.usuario TO rol_soporte';

    FOREACH c IN ARRAY ARRAY['email', 'telefono', 'activo']
    LOOP
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'usuario'
              AND column_name = c
        ) THEN
            cols := array_append(cols, format('%I', c));
        END IF;
    END LOOP;

    IF cardinality(cols) > 0 THEN
        EXECUTE format(
            'GRANT UPDATE (%s) ON TABLE public.usuario TO rol_soporte',
            array_to_string(cols, ', ')
        );
    END IF;
END
$$;

-- Reportes: sólo lectura sobre las relaciones necesarias para agregaciones.
DO $$
DECLARE
    tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY[
        'categoria', 'producto', 'usuario', 'cliente',
        'pedido', 'detalle_pedido', 'linea_pedido'
    ]
    LOOP
        IF to_regclass(format('public.%I', tabla)) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON TABLE public.%I FROM rol_reportes', tabla);
            EXECUTE format('GRANT SELECT ON TABLE public.%I TO rol_reportes', tabla);
        END IF;
    END LOOP;
END
$$;

-- El rol de soporte no puede administrar roles ni modificar la estructura.
REVOKE CREATE ON SCHEMA public FROM rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes;
DO $$
BEGIN
    EXECUTE format(
        'REVOKE ALL ON DATABASE %I FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes',
        current_database()
    );
END
$$;

-- Funciones de autenticación: la aplicación sólo ejecuta la función pública.
DO $$
DECLARE
    funcion regprocedure;
BEGIN
    SELECT p.oid::regprocedure
    INTO funcion
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fn_autenticar'
      AND p.pronargs = 2
    LIMIT 1;

    IF funcion IS NOT NULL THEN
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO app_web', funcion);
    END IF;
END
$$;

-- Política para objetos creados a futuro por el propietario que ejecuta este script.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM rol_app_lectura, rol_app_escritura,
        rol_soporte, rol_reportes;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;

COMMIT;

-- Verificación solicitada por el TP:
-- \du
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee IN ('rol_app_lectura','rol_app_escritura',
--                   'rol_soporte','rol_reportes','app_web','admin_datos')
-- ORDER BY grantee, table_name, privilege_type;