# Declaración de Uso de IA (DUIA) - TP3 Food Store

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | OpenCode / Kiro (Integrado en entorno de desarrollo) |
| **Consigna / Spec** | "Generar script masivo de 50k productos, 20k usuarios y 200k pedidos respetando claves foráneas y soft delete; sugerir índices mínimos para optimizar queries lentas con Seq Scan." |
| **Qué generó la IA** | Script DML con generate_series dentro de una transacción; propuestas de CREATE INDEX sobre id_categoria y usuario_id; análisis de nodos de ejecución. |
| **Qué se aceptó** | Sintaxis de generate_series y estructura BEGIN/COMMIT; índice B-tree sobre usuario_id; transformación del índice de categorías a índice parcial (WHERE eliminado = FALSE). |
| **Qué se modificó o descartó** | Se descartó la sugerencia de indexar columnas sin selectividad; se corrigió la interpretación errónea de la IA que confundía unidades de costo del optimizador con milisegundos reales. |
| **Verificación realizada** | Ejecución en base PostgreSQL local, comprobación de 0 filas con operador EXCEPT entre variantes de consulta, y medición pre/post con EXPLAIN ANALYZE verificando pasaje de Seq Scan a Index Scan. |