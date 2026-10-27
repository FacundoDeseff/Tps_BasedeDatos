-- Food Store - Roles y privilegios de mínimo privilegio
-- PostgreSQL 17 - base copia_trabajo (esquema public)
-- Implementa docs/kiro_roles_spec (requirements.md y design.md).
--
-- Ejecutar conectado como postgres (dueño de los objetos), DESPUÉS de
-- 00_reconstruccion_clase2.sql. Es idempotente: parte de un estado limpio para
-- los seis roles (REVOKE) y vuelve a otorgar exactamente la matriz del diseño.
-- Este script no asigna contraseñas: definirlas fuera del repositorio con
--   \password app_web
--   \password admin_datos

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Precondiciones: falla con un mensaje claro si falta algún objeto
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    faltan text[] := ARRAY[]::text[];
    obj text;
BEGIN
    FOREACH obj IN ARRAY ARRAY[
        'categoria', 'producto', 'usuario', 'pedido', 'detalle_pedido',
        'v_productos_vigentes', 'v_pedidos_usuario', 'v_usuarios_seguros',
        'v_detalle_pedido_producto', 'vm_facturacion_categoria_mes']
    LOOP
        IF to_regclass('public.' || obj) IS NULL THEN
            faltan := array_append(faltan, obj);
        END IF;
    END LOOP;
    IF to_regprocedure('public.fn_autenticar(text,text)') IS NULL THEN
        faltan := array_append(faltan, 'fn_autenticar(text,text)');
    END IF;
    IF to_regprocedure('public.fn_resetear_password(bigint,text)') IS NULL THEN
        faltan := array_append(faltan, 'fn_resetear_password(bigint,text)');
    END IF;
    IF faltan <> ARRAY[]::text[] THEN
        RAISE EXCEPTION 'Faltan objetos requeridos: %. Ejecutar antes TP5/TP6 y 00_reconstruccion_clase2.sql',
            array_to_string(faltan, ', ');
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 1. Roles (RF-01)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    r text;
BEGIN
    FOREACH r IN ARRAY ARRAY['rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes']
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I', r);
        END IF;
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos;
    END IF;
END
$$;

-- Atributos definitivos (también corrige roles que ya existieran distintos).
ALTER ROLE rol_app_lectura   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
ALTER ROLE rol_app_escritura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
ALTER ROLE rol_soporte       NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
ALTER ROLE rol_reportes      NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
ALTER ROLE app_web           LOGIN   NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT;
ALTER ROLE admin_datos       LOGIN   NOSUPERUSER CREATEDB   CREATEROLE   INHERIT;

-- Membresías: la app hereda lectura y escritura; nunca admin_datos (RF-06, RF-12).
GRANT rol_app_lectura, rol_app_escritura TO app_web;
REVOKE admin_datos FROM app_web;

-- ---------------------------------------------------------------------------
-- 2. Estado limpio: se retira todo lo que los seis roles tengan hoy en public
-- (un REVOKE de tabla también retira los permisos de columna).
-- ---------------------------------------------------------------------------
REVOKE ALL ON SCHEMA public FROM rol_app_lectura, rol_app_escritura, rol_soporte,
    rol_reportes, app_web, admin_datos;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, app_web, admin_datos;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, app_web, admin_datos;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, app_web, admin_datos;

-- Desde PG15 PUBLIC ya no recibe CREATE en public; se deja explícito.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. rol_app_lectura: navegar el catálogo (RF-02)
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_app_lectura;
GRANT SELECT ON public.categoria, public.producto, public.v_productos_vigentes
    TO rol_app_lectura;

-- ---------------------------------------------------------------------------
-- 4. rol_app_escritura: registrar compras (RF-03)
-- INSERT ... RETURNING exige SELECT sobre las columnas devueltas: se otorga sólo
-- sobre las PK, a nivel de columna.
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_app_escritura;
GRANT INSERT ON public.pedido, public.detalle_pedido TO rol_app_escritura;
GRANT SELECT (id_pedido)  ON public.pedido         TO rol_app_escritura;
GRANT SELECT (id_detalle) ON public.detalle_pedido TO rol_app_escritura;

DO $$
BEGIN
    EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO rol_app_escritura',
                   pg_get_serial_sequence('public.pedido', 'id_pedido'));
    EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO rol_app_escritura',
                   pg_get_serial_sequence('public.detalle_pedido', 'id_detalle'));
END
$$;

-- ---------------------------------------------------------------------------
-- 5. rol_soporte: atender incidencias de cuentas (RF-04)
-- Lee por vistas; sobre la tabla usuario sólo tiene permisos de columna.
-- SELECT (id_usuario) es necesario para el WHERE de un UPDATE.
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_soporte;
GRANT SELECT ON public.v_usuarios_seguros, public.v_pedidos_usuario,
    public.v_detalle_pedido_producto TO rol_soporte;
GRANT SELECT (id_usuario)              ON public.usuario TO rol_soporte;
GRANT UPDATE (email, intentos_fallidos) ON public.usuario TO rol_soporte;

-- ---------------------------------------------------------------------------
-- 6. rol_reportes: lectura sin datos personales (RF-05)
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_reportes;
GRANT SELECT ON public.categoria, public.producto, public.v_productos_vigentes,
    public.v_detalle_pedido_producto, public.vm_facturacion_categoria_mes
    TO rol_reportes;

-- ---------------------------------------------------------------------------
-- 7. app_web: sólo autentica (el resto lo hereda de los grupos) (RF-06, RF-08)
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.fn_autenticar(text, text) TO app_web;

-- ---------------------------------------------------------------------------
-- 8. admin_datos: administración con privilegios enumerados (RF-07)
-- ---------------------------------------------------------------------------
GRANT USAGE, CREATE ON SCHEMA public TO admin_datos;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON public.categoria, public.producto, public.pedido, public.detalle_pedido
    TO admin_datos;

-- usuario: SELECT e INSERT por columna, sin password_hash, para que la clave
-- sólo pueda escribirse (hasheada) a través de fn_resetear_password.
GRANT SELECT (id_usuario, nombre, apellido, eliminado, email, rol, fecha_alta,
              intentos_fallidos) ON public.usuario TO admin_datos;
GRANT INSERT (nombre, apellido, eliminado, email, rol, fecha_alta,
              intentos_fallidos) ON public.usuario TO admin_datos;
GRANT UPDATE (nombre, apellido, eliminado, email, rol, fecha_alta,
              intentos_fallidos) ON public.usuario TO admin_datos;
GRANT DELETE ON public.usuario TO admin_datos;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO admin_datos;

GRANT SELECT ON public.v_productos_vigentes, public.v_pedidos_usuario,
    public.v_usuarios_seguros, public.v_detalle_pedido_producto,
    public.vm_facturacion_categoria_mes TO admin_datos;
-- PG17: REFRESH de una vista materializada requiere ser dueño o tener MAINTAIN.
GRANT MAINTAIN ON public.vm_facturacion_categoria_mes TO admin_datos;

GRANT EXECUTE ON FUNCTION public.fn_resetear_password(bigint, text) TO admin_datos;

-- ---------------------------------------------------------------------------
-- 9. ALTER DEFAULT PRIVILEGES para objetos futuros creados por postgres (RF-11)
-- Las tablas nuevas nacen sin acceso; no se otorga SELECT/INSERT por defecto.
-- ---------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE ALL ON TABLES FROM rol_app_lectura, rol_app_escritura, rol_soporte,
        rol_reportes, app_web, admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM rol_app_lectura, rol_soporte, rol_reportes,
        app_web, admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;

-- Quitar el EXECUTE de PUBLIC sólo es posible sin IN SCHEMA: aplica a las
-- funciones futuras que cree postgres en cualquier esquema.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

COMMIT;
