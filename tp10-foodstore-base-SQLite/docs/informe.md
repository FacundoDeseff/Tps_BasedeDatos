# INFORME Trabajo Práctico
- Base de Datos II
- Unidad 8: Base de Datos para Dispositivos Móviles e Integración
- Integrantes: Ramirez, Deseff, Vargas, Godoy

## 1.a Qué datos viajan a la tablet

Durante la feria, la tablet necesita almacenar una copia parcial del sistema. Sin señal, la información que viaja desde la base principal en PostgreSQL hacia la tabla local producto_cache en SQLite y los datos que se dejaron afuera son los siguientes:

| Columna en PostgreSQL | ¿Viaja? | En la tablet | Por qué |
|---|---|---|---|
| `id_producto` | Sí | `id` | Identifica el producto en los borradores y en la sincronización. |
| `nombre` | Sí | `nombre` | Para mostrar el catálogo en pantalla. |
| `precio_lista` (NUMERIC 10,2) | Sí | `precio_centavos` (INTEGER) | Se convierte a centavos enteros para evitar errores de redondeo con decimales. |
| `stock` | Sí | `stock_visto` | Solo orientativo: es el stock que se vio al hacer la copia. |
| `eliminado` | Sí | `eliminado` | Lápida de baja lógica: la tablet debe enterarse de que un producto se dio de baja. |
| *(derivada)* `stock > 0 AND NOT eliminado` | Sí | `disponible` | Permite filtrar el catálogo sin recalcular. |
| *(generada en la tablet)* | — | `fecha_copia` | Indica qué tan vieja es la copia. |
| `id_categoria` | No | — | No hace falta para vender en la feria; se puede sumar si se muestra por categoría. |
| Tabla `usuario` (nombre, apellido) | No | — | Datos personales: no tienen por qué estar en un dispositivo que se puede perder. La tablet solo guarda un alias en `pedido_borrador.usuario`. |
| Tablas `pedido` y `detalle_pedido` | No | — | Son las ventas confirmadas; las decide el servidor. La tablet solo tiene borradores. |



**¿Por qué se decidió esto y quién manda?** 

A la tablet viaja solo lo mínimo para mostrar el catálogo y armar borradores sin conexión; cuanto menos datos sensibles hayan en la tablet, menos riesgo se corre si se extravía. Acá, la fuente de verdad es PostgreSQL ya que el precio, el stock y las ventas los decide el servidor (la copia de la tablet puede estar vieja) por eso lo que la tablet arma es solo una propuesta  para que el servidor la valide al sincronizarla con la Base original.


**Nota sobre el índice único parcial 'ux_cola_una_pendiente'**

Al realizar las pruebas del reenvío, se observó que SQLite prioriza la validación del índica frente a un envío que sigue 'PENDIENTE' (se arroja un error sobre id_local). Una vez que la solicitud se procesa y deja de estar pendiente, actúa la clave primaria de solicitud_uuid, garantizando la idempotencia del sistema.