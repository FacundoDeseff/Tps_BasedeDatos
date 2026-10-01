# Trabajo Práctico N° 6: Normalización FNBC y Desnormalización Controlada

**Asignatura:** Base de Datos  
**Alumno:** Facundo Deseff  
**Proyecto:** Food Store  

---

## Parte 1: Normalización en Forma Normal de Boyce-Codd (FNBC)

### 1. Diagnóstico del Esquema Original
En la tabla control_lote_almacen se identificó la siguiente Dependencia Funcional (DF):

ResponsableControlID -> DepositoID

Violación de BCNF: La clave primaria compuesta es (LoteID, DepositoID). Dado que ResponsableControlID determina a DepositoID pero no es una superclave, la tabla viola la Forma Normal de Boyce-Codd (FNBC), introduciendo redundancia y anomalías de actualización.

### 2. Descomposición BCNF
Se descompuso la tabla original en dos nuevas relaciones:

1. responsable_deposito:
   - Clave Primaria: responsable_control_id
   - Atributos: deposito_id

2. control_lote:
   - Clave Primaria Compuesta: (lote_id, responsable_control_id)
   - Clave Foránea: responsable_control_id -> responsable_deposito

### 3. Vista de Compatibilidad
Para mantener la compatibilidad con consultas existentes se creó la vista:

CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT 
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd ON rd.responsable_control_id = cl.responsable_control_id;

### 4. Verificación de Pérdida de Datos (Auditoría)
Se ejecutaron consultas de diferencia de conjuntos (EXCEPT) entre la tabla original y la vista reconstruida:

SELECT * FROM control_lote_almacen EXCEPT SELECT * FROM v_control_lote_almacen;
SELECT * FROM v_control_lote_almacen EXCEPT SELECT * FROM control_lote_almacen;

Resultado: Se obtuvieron 0 filas en ambas consultas, lo que garantiza formalmente una descomposición sin pérdida de datos (lossless-join decomposition).

![Verificación BCNF sin pérdida de datos](./captura1.jpeg)

---

## Parte 2: Desnormalización Controlada para Optimización

### 1. Justificación del Negocio
El reporte diario de las Top 5 Categorías más vendidas registraba alta latencia debido a la ejecución continua de un JOIN entre cuatro tablas transaccionales masivas (detalle_pedido, producto, categoria, pedido) con agrupamientos de agregación (SUM, GROUP BY).

### 2. Solución Implementada
Se optó por una Vista Materializada (mv_top_categorias_diarias) pre-calculando las ventas agregadas por categoría y fecha, complementada con un índice en la columna de filtrado temporal:

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_top_categorias_diarias AS
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido,
       ped.fecha
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.pedido_id
WHERE dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre, ped.fecha;

CREATE INDEX IF NOT EXISTS idx_mv_top_cat_fecha ON mv_top_categorias_diarias(fecha);

### 3. Comparativa de Rendimiento (EXPLAIN ANALYZE)

| Estrategia | Tiempo de Ejecución (Execution Time) | Tipo de Acceso |
| :--- | :--- | :--- |
| Consulta Original (3NF) | ~136 - 898 ms | Sequential Scan + Hash Join + HashAggregate |
| Vista Materializada + Índice | 0.019 ms | Index Scan (idx_mv_top_cat_fecha) |

Mejora lograda: Reducción drástica del tiempo de respuesta (más del 99% de optimización), pasando de procesar un JOIN complejo a una lectura indexada directa.

![Planes de ejecución EXPLAIN ANALYZE](./captura2.jpeg)

### 4. Estrategia de Sincronización y Auditoría
Dado que las Vistas Materializadas no se actualizan automáticamente en PostgreSQL, se definió refrescar la vista mediante tareas programadas (cron / pg_cron) al cierre de cada jornada de ventas:

REFRESH MATERIALIZED VIEW mv_top_categorias_diarias;

Para verificar que la vista desnormalizada no presente diferencias con las tablas OLTP transaccionales, se ejecutó la siguiente consulta de auditoría:

SELECT 
    c.nombre AS categoria,
    SUM(dp.subtotal) AS total_calculado,
    mv.total_vendido AS total_registrado
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = dp.pedido_id
LEFT JOIN mv_top_categorias_diarias mv ON mv.categoria = c.nombre AND mv.fecha = ped.fecha
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre, ped.fecha, mv.total_vendido
HAVING SUM(dp.subtotal) IS DISTINCT FROM mv.total_vendido;

Resultado: 0 filas devueltas, confirmando la consistencia total de saldos entre el modelo normalizado y el desnormalizado.

![Resultado de auditoría 0 filas](./captura3.jpeg)