# TP5 - Food Store

Repositorio del Trabajo Practico 5 sobre indices, vistas y vista materializada.

Los datos base (`schema.sql` y `data.sql`) provienen de la base de datos masiva
del TP3. No se duplicaron como una nueva fuente de datos del TP5: se reutilizan
para reproducir las pruebas con el mismo esquema y volumen de trabajo.

## Estructura

- `schema.sql`: Se utilizó el de TPs anteriores.
- `data.sql`: Se utilizó el de TPs anteriores.
- `queries.sql`: consultas utilizadas en el trabajo.
- `indices.sql`: Parte A, optimizacion con indices.
- `views.sql`: Partes B y C, vistas y vista materializada.
- `duia.md`: Declaracion de Uso de IA.
- `informe_mediciones.md`: mediciones y justificaciones.
- `specs/`: especificaciones de cada parte.

## Guía de Reproducción de Pruebas

Las siguientes instrucciones usan PostgreSQL 16+ y una base de datos de prueba.
Los scripts base pueden cargarse desde la carpeta del TP3; luego se ejecutan los
scripts propios de este TP5.

1. Cargar el esquema base del TP3 y su carga masiva:

```text
\i ../tp3-foodstore-optimizacion/schema.sql
\i ../tp3-foodstore-optimizacion/carga_masiva.sql
```

2. Ejecutar `queries.sql` para medir las tres consultas con `EXPLAIN ANALYZE`
antes de crear los índices.

3. Ejecutar `indices.sql` y volver a ejecutar las tres consultas de
`queries.sql` con `EXPLAIN ANALYZE` para comparar el plan y el tiempo antes y
después.

4. Ejecutar `views.sql` para crear las cuatro vistas simples, la vista
materializada y su índice único. Verificar las equivalencias de las vistas con
las ocho sentencias `EXCEPT` en ambos sentidos documentadas en
`informe_mediciones.md`.

5. Para actualizar la vista materializada sin bloquear las lecturas, ejecutar:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;
```

La carga de varios cientos de `INSERT` sobre `detalle_pedido` y la comparación
del costo de escritura con y sin índices están documentadas en
`informe_mediciones.md`.

