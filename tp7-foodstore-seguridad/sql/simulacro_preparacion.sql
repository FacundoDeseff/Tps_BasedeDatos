-- ============================================================================
-- Food Store - Preparacion del simulacro de incidente (Parte C)
-- PostgreSQL 17 - base copia_trabajo (esquema public)
--
-- Ejecutar SOLO si la cuenta de prueba del simulacro no existe, o si quedo con
-- intentos_fallidos acumulados (bloqueada) por una corrida anterior que se
-- corto a mitad de camino.
--
-- Se ejecuta como postgres, ANTES de sql/simulacro_incidente.sql:
--
--   psql -U postgres -d copia_trabajo -f sql/simulacro_preparacion.sql
--
-- La clave se pide por consola y no queda en este archivo, en el repositorio ni
-- en el historial del shell.
-- ============================================================================

-- Se pide la clave antes de abrir la transaccion.
\prompt 'Clave sintetica para cuenta_a@sintetico.example: ' clave_prueba

BEGIN;

-- Cuenta sintetica dedicada, en un dominio reservado (.example): no corresponde
-- a ninguna persona real. El id de la fila lo asigna la secuencia.
INSERT INTO public.usuario (
    nombre, apellido, email, rol, fecha_alta, eliminado, intentos_fallidos
)
VALUES (
    'Cuenta', 'Sintetica', 'cuenta_a@sintetico.example', 'cliente',
    now(), FALSE, 0
)
ON CONFLICT (email) DO UPDATE
    SET eliminado         = FALSE,
        intentos_fallidos = 0;

-- Unica via para escribir password_hash: fuerza bcrypt y no registra la clave.
SELECT public.fn_resetear_password(
           (SELECT id_usuario
              FROM public.usuario
             WHERE email = 'cuenta_a@sintetico.example'),
           :'clave_prueba'
       ) AS clave_definida;

-- Estado de partida del escenario. Debe verse: eliminado = f,
-- intentos_fallidos = 0, tiene_clave = t.
SELECT id_usuario, email, rol, eliminado, intentos_fallidos,
       password_hash IS NOT NULL AS tiene_clave
FROM public.usuario
WHERE email = 'cuenta_a@sintetico.example';

COMMIT;
