# TP9 - Parte 3: Evaluación de la tecnología e IA

## Consigna 6 - Comparación PostgreSQL / MongoDB realizada con IA

### Herramienta y consulta

- **Herramienta:** opencode (agente de IA), modelo declarado `deepseek-v4.1-flash-free`.
- **Fecha:** 29/10/2026.
- **Consulta realizada (textual):**

> Compará PostgreSQL y MongoDB para almacenar y consultar los pedidos de Food Store. El modelo actual es relacional: `pedido`, `detalle_pedido`, `usuario`, `producto` y `categoria`, con claves foráneas y tipos `NUMERIC(12,2)` para los importes. El acceso más frecuente es leer el pedido completo (cabecera, cliente y líneas). Se necesita conservar la coherencia de cantidades y precios: `total = suma de subtotales`, `subtotal = cantidad × precio histórico` y `cantidad > 0`. Indicá ventajas y limitaciones de cada motor y si conviene mantener PostgreSQL, migrar ese subconjunto a MongoDB o combinar ambos.

La consulta menciona los tres elementos pedidos: el **modelo actual**, el **acceso frecuente a pedidos completos** y la **necesidad de conservar la coherencia de cantidades y precios**.

### Respuesta de la IA (textual)

> Para Food Store, el modelo actual es relacional: `pedido` y `detalle_pedido` están separados, con claves foráneas a `usuario` y `producto` y tipos `NUMERIC(12,2)` para los importes. Si el acceso más frecuente es leer el pedido completo (cabecera, cliente y líneas), MongoDB tiene una ventaja estructural: al embeber las líneas en `items[]`, **un pedido completo se recupera con una sola lectura, sin `JOIN` ni `$lookup`, lo que lo hace más adecuado que PostgreSQL para ese acceso frecuente**. Además, el documento conserva un snapshot del cliente y del producto, de modo que un cambio posterior en el maestro no altera pedidos ya cerrados.
>
> En el otro extremo, **PostgreSQL garantiza mejor la coherencia de cantidades y precios porque es relacional: las claves foráneas impiden líneas huérfanas, los `CHECK` impiden cantidades no positivas y subtotales negativos, y las transacciones ACID permiten actualizar cabecera y detalle juntas; MongoDB, en cambio, no puede garantizar que `total = suma de subtotales`**. `$jsonSchema` valida tipos, campos obligatorios y rangos, pero no relaciones aritméticas entre campos.
>
> Por eso, para este subconjunto conviene un enfoque híbrido: mantener PostgreSQL como fuente de verdad transaccional y usar MongoDB como modelo de lectura de pedidos completos, sincronizado y verificado desde PostgreSQL. Migrar todo a MongoDB obligaría a reimplementar controles de integridad; mantener solo PostgreSQL desaprovecha la lectura denormalizada. La decisión final debería validarse midiendo latencia y volumen reales.

## Consigna 7 - Contraste de dos afirmaciones concretas

### Afirmación 1

> "Al embeber las líneas en `items[]`, un pedido completo se recupera con una sola lectura, sin `JOIN` ni `$lookup`, lo que lo hace más adecuado que PostgreSQL para ese acceso frecuente."

**Contraste con documentación oficial (MongoDB).** La guía de modelado recomienda embeber en relaciones 1:N cuando la aplicación consulta los datos juntos: *"Embedding connected data in a single document reduces the number of read operations required to retrieve data. Structure your schema so your application receives all required information in a single read operation"* y *"Embedding related data lets your application query the data it needs with a single read operation and avoid slow `$lookup` operations"* (MongoDB Manual, *Model One-to-Many Relationships with Embedded Documents* y *Map Schema Relationships*). Es exactamente la decisión tomada en `01_modelo_documental.md`: el pedido es el agregado y las líneas se embeben.

**Contraste con el laboratorio.** En `foodstore_nosql`, `findOne({ _id: 1 })` devolvió **un solo documento** con la cabecera, el cliente y las **2 líneas** del pedido (ver `docs/p3_evidencia_mongodb.txt`, sección A). La migración insertó los 6 pedidos completos con un solo `insertMany()` y la consulta (a) de la Parte 2 devolvió los 6 documentos en una sola operación. En PostgreSQL, en cambio, obtener lo mismo exige unir `pedido` con `detalle_pedido` (y `usuario`/`producto` si se quieren los nombres), como muestran `02_extraccion_origen.sql` y `consultas_postgresql.sql`.

**Veredicto: CONFIRMADA en lo estructural, con un alcance acotado.** Es cierto que el modelo embebido elimina el `JOIN` y resuelve la lectura con una sola operación. No se verificó que sea "más rápido" a escala: con 6 documentos no hay una medición representativa y el laboratorio no comparó latencias con 200.000 pedidos. La ventaja comprobada es de **forma de acceso**, no de rendimiento medido.

### Afirmación 2

> "PostgreSQL garantiza mejor la coherencia de cantidades y precios porque es relacional: las claves foráneas impiden líneas huérfanas, los `CHECK` impiden cantidades no positivas y subtotales negativos, y las transacciones ACID permiten actualizar cabecera y detalle juntas; MongoDB, en cambio, no puede garantizar que `total = suma de subtotales`."

**Contraste con documentación oficial.** MongoDB implementa un subconjunto de JSON Schema: `$jsonSchema` permite `bsonType`, `required`, `enum`, `minimum`/`maximum`, `items`, `minItems`, `pattern`, etc., pero no ofrece una comparación aritmética entre dos campos del documento (MongoDB Manual, *$jsonSchema*). PostgreSQL, por su parte, tampoco puede expresar esa igualdad con un `CHECK`: *"PostgreSQL does not support `CHECK` constraints that reference table data other than the new or updated row being checked"* y *"`CHECK` expressions cannot contain subqueries nor refer to variables other than columns of the current row"*. Para validar contra otras filas, la documentación indica usar un **trigger** (PostgreSQL Manual, *Check Constraints*).

**Contraste con el laboratorio.**

- MongoDB: un documento con `total = 1.00` y una línea con `subtotal = 100.00` fue **aceptado** por el validador `$jsonSchema`; en cambio, el validador **rechazó** un documento sin `items` y el índice único **rechazó** un `id_detalle` duplicado. Es decir, controla estructura, tipos y unicidad, pero no la igualdad aritmética (ver `docs/p3_evidencia_mongodb.txt`, secciones C, D y E).
- PostgreSQL: en una transacción con `ROLLBACK`, se insertó un `pedido` con `total = 1.00` y un `detalle_pedido` con `subtotal = 100.00` **sin error**; la clave foránea sí rechazó un detalle huérfano y los `CHECK` rechazaron `cantidad = 0` y `subtotal = -10.00` (ver `docs/p3_evidencia_postgresql.txt`, secciones B a E). Es decir, PostgreSQL controla referencias, tipos, cantidades no positivas y atomicidad, pero **tampoco** la igualdad `total = suma de subtotales` con restricciones declarativas.

**Veredicto: PARCIAL.** Son verdaderas las partes verificables: PostgreSQL impide líneas huérfanas con claves foráneas, rechaza cantidades no positivas y subtotales negativos con `CHECK`, y permite actualizar cabecera y detalle en una transacción ACID; MongoDB no puede expresar `total = suma de subtotales` con `$jsonSchema`. Pero la conclusión implícita —que PostgreSQL garantiza esa igualdad— es **falsa** si se limita a restricciones declarativas: también requiere un trigger, una regla de aplicación o una verificación posterior a la escritura. El laboratorio lo demuestra: ambos motores aceptaron el mismo total incoherente. La afirmación es engañosa como criterio para elegir uno u otro motor.

## Conclusión (máximo 200 palabras)

Para el subconjunto de pedidos de Food Store conviene **combinar** ambos motores, no reemplazar uno por el otro. PostgreSQL debe seguir siendo la fuente de verdad: garantiza claves foráneas, tipos `NUMERIC`, cantidades positivas, transacciones ACID y ya sostiene las 200.000 órdenes y la analítica del sistema. MongoDB aporta valor como modelo de lectura del pedido completo: al embeber cliente e ítems en un solo documento, resuelve el acceso frecuente con una única lectura y conserva el snapshot histórico de precios y nombres. La coherencia aritmética (`total = suma de subtotales` y `subtotal = cantidad × precio histórico`) no la garantiza ninguno de los dos solo con validaciones declarativas: debe reforzarse en la migración, en la aplicación o con un trigger en PostgreSQL. Migrar todo a MongoDB perdería garantías y obligaría a reimplementar controles; mantener solo PostgreSQL desaprovecha la lectura denormalizada. La arquitectura recomendada es PostgreSQL como sistema de registro y MongoDB como réplica de lectura sincronizada y verificada, con métricas de latencia antes de ampliar el subconjunto.

**Recuento:** 167 palabras.

## Fuentes oficiales consultadas

- MongoDB Manual, *Model One-to-Many Relationships with Embedded Documents*: <https://www.mongodb.com/docs/manual/tutorial/model-embedded-one-to-many-relationships-between-documents/>
- MongoDB Manual, *Map Schema Relationships*: <https://www.mongodb.com/docs/manual/data-modeling/schema-design-process/map-relationships/>
- MongoDB Manual, *$jsonSchema*: <https://www.mongodb.com/docs/manual/reference/operator/query/jsonSchema/>
- PostgreSQL 17 Manual, *Check Constraints*: <https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS>

## Evidencia y trazabilidad

| Archivo | Contenido |
|---|---|
| `docs/p3_evidencia_mongodb.txt` | Salida real de `mongosh`: lectura completa, control aritmético, validador que acepta un total incoherente, rechazo de documento sin `items`, rechazo de `id_detalle` duplicado e índices. |
| `docs/p3_evidencia_postgresql.txt` | Salida real de `psql`: restricciones declarativas, total incoherente aceptado con `ROLLBACK`, rechazo de detalle huérfano y de `cantidad`/`subtotal` inválidos. |
| `docs/p3_verificacion_mongodb.js` | Script que genera la evidencia de MongoDB. |
| `docs/p3_verificacion_postgresql.sql` | Script que genera la evidencia de PostgreSQL (usa `ROLLBACK`, no deja datos). |
| `03_migracion_pedidos.js` | Migración de los 6 pedidos y verificaciones previas/posteriores. |
| `consultas_mongodb.js` / `consultas_postgresql.sql` | Consultas de la Parte 2 usadas para comparar resultados. |

Los resultados de la Parte 2 (`05_comparacion_resultados.md`) se obtuvieron sobre MongoDB 9.0.4 y PostgreSQL 17. La evidencia de esta parte se regeneró en el entorno local con MongoDB 9.0 y PostgreSQL 17, partiendo de la base `foodstore` y del script de migración versionado.
