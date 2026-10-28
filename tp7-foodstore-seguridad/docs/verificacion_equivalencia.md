# Verificación de equivalencia de agregados (Parte D)

Base `copia_trabajo`, PostgreSQL 17.11, 2026-10-27 18:33 UTC-3.
Script: `sql/usuario_anon.sql`. Consultas generadas con asistencia de IA y
validadas por el equipo (ver `BITACORA.md`).

## 1. Transformación aplicada

| Origen (`usuario`) | Destino (`usuario_anon`) | Criterio |
|---|---|---|
| `id_usuario` | `id_usuario_anon` | se conserva como surrogate interno para verificar fila por fila |
| `nombre` | `nombre_anon` = `Usuario_NNNNNNNN` | reemplazo sintético determinista |
| `apellido` | `apellido_anon` = `Apellido_NNNNNNNN` | reemplazo sintético determinista |
| `email` | `email_anon` = `anon_NNNNNNNN@anon.invalid` | dominio reservado: no enrutable, no corresponde a personas |
| `fecha_alta` | `mes_alta` (date) | se descarta el instante exacto (cuasi-identificador) y se conserva el mes |
| `rol`, `eliminado` | `rol`, `eliminado` | no identifican y son necesarios para agregar |
| `password_hash`, `intentos_fallidos` | — | **no se copian**: credenciales y señales de seguridad |

Determinismo: cada valor se deriva del `id_usuario`, nunca del azar. La misma
fila produce siempre el mismo resultado.

## 2. Consultas comparadas

Se agregó por `rol` y por mes de alta, tal como pide la consigna (D.2).

```sql
-- A) sobre la tabla real
SELECT u.rol,
       (date_trunc('month', u.fecha_alta AT TIME ZONE 'UTC'))::date AS mes_alta,
       count(*) AS cantidad
FROM public.usuario AS u
GROUP BY 1, 2
ORDER BY 1, 2;

-- B) sobre la tabla anonimizada
SELECT a.rol, a.mes_alta, count(*) AS cantidad
FROM public.usuario_anon AS a
GROUP BY 1, 2
ORDER BY 1, 2;
```

El mes se calcula **en UTC en las dos consultas** para que el resultado no
dependa del `TimeZone` de la sesión: si se usara `date_trunc` a secas, la
equivalencia podría romperse al correr cada consulta en una sesión distinta.

## 3. Resultado: las dos salidas, una al lado de la otra

Comprobación automática con `FULL JOIN`: `coincide = t` en todos los grupos.

La tabla de abajo se genera con esta consulta, que es el chequeo C del script sin
el filtro de diferencias y con la columna `coincide`. Se deja acá para que el
resultado sea reproducible:

```sql
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
       r.cantidad                       AS real,
       a.cantidad                       AS anon,
       (r.cantidad IS NOT DISTINCT FROM a.cantidad) AS coincide
FROM real AS r
FULL JOIN anon AS a USING (rol, mes_alta)
ORDER BY 1, 2;
```

```text
   rol   |  mes_alta  | real | anon | coincide
---------+------------+------+------+----------
 admin   | 2024-01-01 |   33 |   33 | t
 admin   | 2024-03-01 |   34 |   34 | t
 admin   | 2024-05-01 |   34 |   34 | t
 admin   | 2024-07-01 |   34 |   34 | t
 admin   | 2024-09-01 |   34 |   34 | t
 admin   | 2024-11-01 |   33 |   33 | t
 admin   | 2025-01-01 |   33 |   33 | t
 admin   | 2025-03-01 |   33 |   33 | t
 admin   | 2025-05-01 |   33 |   33 | t
 admin   | 2025-07-01 |   33 |   33 | t
 admin   | 2025-09-01 |   33 |   33 | t
 admin   | 2025-11-01 |   33 |   33 | t
 cliente | 2024-01-01 |  800 |  800 | t
 cliente | 2024-02-01 |  834 |  834 | t
 cliente | 2024-03-01 |  800 |  800 | t
 cliente | 2024-04-01 |  834 |  834 | t
 cliente | 2024-05-01 |  800 |  800 | t
 cliente | 2024-06-01 |  834 |  834 | t
 cliente | 2024-07-01 |  800 |  800 | t
 cliente | 2024-08-01 |  834 |  834 | t
 cliente | 2024-09-01 |  800 |  800 | t
 cliente | 2024-10-01 |  833 |  833 | t
 cliente | 2024-11-01 |  800 |  800 | t
 cliente | 2024-12-01 |  833 |  833 | t
 cliente | 2025-01-01 |  800 |  800 | t
 cliente | 2025-02-01 |  833 |  833 | t
 cliente | 2025-03-01 |  800 |  800 | t
 cliente | 2025-04-01 |  833 |  833 | t
 cliente | 2025-05-01 |  800 |  800 | t
 cliente | 2025-06-01 |  833 |  833 | t
 cliente | 2025-07-01 |  800 |  800 | t
 cliente | 2025-08-01 |  833 |  833 | t
 cliente | 2025-09-01 |  800 |  800 | t
 cliente | 2025-10-01 |  833 |  833 | t
 cliente | 2025-11-01 |  800 |  800 | t
 cliente | 2025-12-01 |  833 |  833 | t
 cliente | 2026-10-01 |    1 |    1 | t
(37 filas)
```

Chequeo de diferencias del propio script (debe devolver 0 filas):

```text
 rol | mes_alta | cantidad_real | cantidad_anon
-----+----------+---------------+---------------
(0 filas)
```

Cardinalidad:

```text
 filas_usuario | filas_anon
---------------+------------
         20001 |      20001
(1 fila)
```

## 4. Verificación de que la anonimización es efectiva

No alcanza con que los conteos coincidan: hay que comprobar que no sobrevivió
ningún dato identificable.

```sql
SELECT count(*) AS filas,
       count(*) FILTER (WHERE nombre_anon !~ '^Usuario_[0-9]{8}$')   AS nombre_fuera_patron,
       count(*) FILTER (WHERE email_anon  !~ '^anon_[0-9]{8}@anon\.invalid$') AS email_fuera_patron,
       count(*) FILTER (WHERE email_anon LIKE '%@example.invalid')   AS emails_reales,
       count(*) FILTER (WHERE mes_alta <> date_trunc('month', mes_alta)::date) AS meses_invalidos
FROM public.usuario_anon;
```

```text
 filas | nombre_fuera_patron | email_fuera_patron | emails_reales | meses_invalidos
-------+---------------------+--------------------+---------------+-----------------
 20001 |                   0 |                  0 |             0 |               0
(1 fila)
```

Muestra del resultado:

```text
 id_usuario_anon |   nombre_anon    |   apellido_anon   |         email_anon         |   rol   |  mes_alta  | eliminado
-----------------+------------------+-------------------+----------------------------+---------+------------+-----------
               1 | Usuario_00000001 | Apellido_00000001 | anon_00000001@anon.invalid | cliente | 2024-02-01 | t
               2 | Usuario_00000002 | Apellido_00000002 | anon_00000002@anon.invalid | cliente | 2024-03-01 | f
               3 | Usuario_00000003 | Apellido_00000003 | anon_00000003@anon.invalid | cliente | 2024-04-01 | t
```

## 5. Nota de reproducibilidad (hallazgo real)

`usuario_anon` es una **copia** y no se actualiza sola. En la primera corrida de
esta comprobación la tabla se había generado antes de dar de alta la cuenta
sintética del simulacro: el `FULL JOIN` devolvió exactamente **una** diferencia
(`cliente | 2026-10-01 | real = 1 | anon = NULL`). No era un error de la
transformación sino un desfasaje de origen, y la comprobación lo detectó.

Conclusión operativa: después de cualquier alta o baja en `usuario`, hay que
volver a ejecutar `sql/usuario_anon.sql` antes de reportar. El chequeo con
`FULL JOIN` es el que avisa.

## 6. Qué no debería salir hacia un asistente de IA sin anonimizar (D.4)

No deberían salir nunca nombres, apellidos, correos electrónicos, teléfonos,
hashes de contraseña ni claves en claro de Food Store, porque identifican
directamente a una persona. Tampoco deberían enviarse logs sin anonimizar: el
logueo nativo con `log_statement = 'all'` escribe el texto completo de cada
sentencia, con sus literales, y en este mismo trabajo dejó claves de prueba en
claro dentro del archivo de log. La regla que aplicamos es que sólo se comparten
agregados (conteos por rol y mes) o registros construidos sobre
`usuario_anon`, nunca filas de `usuario`.
