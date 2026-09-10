# Ejercicio de Lectura Crítica - Parte 3

## Análisis del Script 1

### Script Original
UPDATE funcion
SET activa = FALSE;

* Qué filas afectaría realmente: Afecta a todas las filas de la tabla funcion sin excepción.
* Por qué no coincide con la consigna: La consigna pedía dar de baja solo las funciones de películas retiradas. Al no tener cláusula WHERE, desactiva todas las funciones del cine.
* Versión Corregida:
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id 
    FROM pelicula 
    WHERE estado = 'RETIRADA'
);

---

## Análisis del Script 2

### Script Original
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);

* Qué filas afectaría realmente: Si hay algún valor NULL en categoria_id de la tabla producto, la condición NOT IN evalúa a UNKNOWN y no borra ninguna fila (0 filas afectadas).
* Por qué no coincide con la consigna: No garantiza borrar las categorías huérfanas si existen nulos en la columna foránea.
* Versión Corregida:
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 
    FROM producto p 
    WHERE p.categoria_id = c.id
);