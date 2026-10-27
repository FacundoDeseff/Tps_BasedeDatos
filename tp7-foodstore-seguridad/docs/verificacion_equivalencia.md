# Verificación de equivalencia de agregados

## Preparación

Ejecutar primero `sql/usuario_anon.sql`. La transformación es determinista:
cada `id_usuario` conserva su correspondencia estable, mientras que nombre y
apellido se reemplazan por etiquetas sintéticas. No se copian datos
identificables al artefacto anonimizado.

## Consultas comparadas

```sql
SELECT eliminado, count(*) AS cantidad
FROM public.usuario
GROUP BY eliminado
ORDER BY eliminado;

SELECT eliminado, count(*) AS cantidad
FROM public.usuario_anon
GROUP BY eliminado
ORDER BY eliminado;
```

## Criterio de aceptación

Las dos salidas deben tener los mismos grupos (`eliminado`) y el mismo valor
de `cantidad` para cada grupo. Una comprobación automática equivalente es:

```sql
WITH real AS (
  SELECT eliminado, count(*) AS cantidad
  FROM public.usuario GROUP BY eliminado
),
anon AS (
  SELECT eliminado, count(*) AS cantidad
  FROM public.usuario_anon GROUP BY eliminado
)
SELECT COALESCE(real.eliminado, anon.eliminado) AS eliminado,
       real.cantidad AS cantidad_real,
       anon.cantidad AS cantidad_anon,
       real.cantidad IS NOT DISTINCT FROM anon.cantidad AS coincide
FROM real
FULL JOIN anon USING (eliminado)
ORDER BY eliminado;
```

La tabla anonimizada no debe compartirse con nombres, apellidos, correos,
teléfonos, contraseñas, tokens, direcciones ni logs sin anonimizar. Esos datos
concretos de Food Store sólo deben permanecer en el entorno controlado y con
acceso restringido.