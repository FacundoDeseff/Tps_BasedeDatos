# Declaración de Uso de IA (DUIA) - Parte 1

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Kiro Agent (Integrado en VS Code) |
| **Spec o prompt utilizado** | "Analizá schema.sql. Necesito generar un archivo restricciones.sql para PostgreSQL con las siguientes reglas de negocio: 1. Restricción CHECK en producto para que precio_lista > 0 y stock >= 0. 2. Clave foránea fk_producto_categoria en producto referenciando a categoria(id_categoria) con ON DELETE RESTRICT." |
| **Qué generó** | Archivo restricciones.sql con sentencias ALTER TABLE para incorporar constraints chk_producto_precio_stock y fk_producto_categoria. |
| **Qué se aceptó** | La totalidad de la sintaxis ALTER TABLE, la combinación del CHECK de precio/stock y el ON DELETE RESTRICT. |
| **Qué se modificó o descartó** | Se validó que el CHECK de precio_lista mantenga la condición de ser estrictamente positivo (> 0). |
| **Verificación realizada** | "Se ejecutó el script dentro de una transacción. Se probó un INSERT válido que fue aceptado, y un INSERT inválido con precio negativo (-100) que fue rechazado correctamente por el motor con el error 23514 por violar la restricción check." |