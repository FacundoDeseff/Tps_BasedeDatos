# TP9 - Parte 2: consultas y verificación

Scripts: `consultas_mongodb.js` (Consigna 4, a-d) y `consultas_postgresql.sql` (Consigna 5, b y c).
Todos los resultados provienen de una ejecución real sobre MongoDB 9.0.4 y PostgreSQL 17 (`foodstore`).

## Consigna 4 - Consultas en MongoDB

| Consulta | Filtro | Cantidad | IDs |
|---|---|---|---|
| a) Todos los pedidos | `{}` con proyección `_id`, `estado` | 6 | 1, 2, 3, 4, 5, 6 |
| b) Por estado | `{ estado: "ENTREGADO" }` | 5 | 1, 2, 4, 5, 6 |
| c) Por producto | `{ "items.id_producto": 5829 }` | 1 | 1 |
| d) Total mayor a umbral | `{ total: { $gt: 5000 } }` | 3 | 2, 4, 5 |

**Justificación del umbral (d):** los totales migrados van de 3283.34 a 7208.54 y su promedio es 4949.64. Se eligió 5000, cercano al promedio, porque separa los pedidos de mayor importe (2, 4 y 5) de los de menor importe (1, 3 y 6), con 3 resultados de cada lado.

**Sobre (c):** al filtrar por una sola condición sobre el arreglo alcanza la notación de punto. `$elemMatch` sería necesario solo para combinar varias condiciones sobre la misma línea.

## Consigna 5 - Comparación con PostgreSQL

Equivalencias usadas en PostgreSQL:

- Estado ENTREGADO equivale a `pedido.eliminado = false`, porque `pedido` no tiene columna `estado` (regla definida en el modelo documental).
- Producto 5829 equivale a `EXISTS` sobre `detalle_pedido.producto_id = 5829`.
- Ambas consultas se acotan a `id_pedido IN (1..6)`, que es el universo migrado.

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
|---|---|---|---|
| Estado seleccionado (ENTREGADO) | 5 (1, 2, 4, 5, 6) | 5 (1, 2, 4, 5, 6) | Sí |
| Producto seleccionado (5829) | 1 (1) | 1 (1) | Sí |

## Diferencias detectadas y explicación

1. **Universo distinto.** `foodstore` tiene 200000 pedidos y MongoDB solo 6. Sin acotar a `id_pedido IN (1..6)`, PostgreSQL devuelve:
   - ENTREGADO: 194094 pedidos.
   - Producto 5829: 3 pedidos (1, 33138 y 132374).

   La diferencia no es un error del modelo ni de la consulta: los pedidos 33138 y 132374 existen en el origen pero no fueron migrados. Por eso la comparación se hace sobre el subconjunto migrado.
2. **Estado derivado.** El estado de MongoDB se calcula desde `eliminado`. Los IDs coinciden porque la regla es la misma en ambos lados (el pedido 3 con `eliminado = true` queda fuera de ENTREGADO en los dos motores).
3. **Líneas eliminadas.** `detalle_pedido.eliminado` es `false` en todo el origen (0 filas en `true`), por lo que no hace falta filtrar por ese campo en ninguno de los dos motores.
4. **Fechas.** Las fechas de los 6 pedidos en MongoDB no coinciden con las de PostgreSQL (diferencia de aproximadamente 2 días). No afecta a ninguna consulta de esta parte, y se decidió no corregirlo.

No fue necesario modificar el modelo ni las consultas.
