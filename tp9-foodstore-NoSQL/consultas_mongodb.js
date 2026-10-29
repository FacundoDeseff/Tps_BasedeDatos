// =====================================================================
// consultas_mongodb.js
// TP9 - Unidad 7: Food Store en MongoDB
// Parte 2 - Consigna 4: consultas a), b), c) y d)
//
// Uso:
//   mongosh "mongodb://localhost:27017/foodstore_nosql" --file consultas_mongodb.js
//
// Requiere haber ejecutado antes 03_migracion_pedidos.js.
// =====================================================================

const pedidos = db.getSiblingDB("foodstore_nosql").getCollection("pedidos");
const ids = (docs) => docs.map((d) => d._id);

// ---------------------------------------------------------------------
// a) Todos los pedidos, con identificador y estado
// ---------------------------------------------------------------------
print("a) Todos los pedidos (_id y estado)");
printjson(pedidos.find({}, { _id: 1, estado: 1 }).sort({ _id: 1 }).toArray());
print(`Cantidad: ${pedidos.countDocuments({})}`);
print("");

// ---------------------------------------------------------------------
// b) Pedidos por estado. ENTREGADO existe en los datos migrados (5 pedidos).
// ---------------------------------------------------------------------
const ESTADO = "ENTREGADO";
print(`b) Pedidos con estado ${ESTADO}`);
const porEstado = pedidos
  .find({ estado: ESTADO }, { _id: 1, estado: 1, total: 1 })
  .sort({ _id: 1 })
  .toArray();
printjson(porEstado);
print(`Cantidad: ${pedidos.countDocuments({ estado: ESTADO })}`);
print(`IDs: [${ids(porEstado).join(", ")}]`);
print("");

// ---------------------------------------------------------------------
// c) Pedidos que contienen un producto dentro del arreglo items[].
//    Con una sola condicion sobre el arreglo alcanza la notacion de punto
//    ("items.id_producto"); $elemMatch solo es necesario cuando se combinan
//    varias condiciones sobre la MISMA linea (ej. producto y cantidad).
// ---------------------------------------------------------------------
const PRODUCTO = 5829;
print(`c) Pedidos que contienen el producto ${PRODUCTO}`);
const porProducto = pedidos
  .find({ "items.id_producto": PRODUCTO }, { _id: 1, estado: 1, "items.id_producto": 1 })
  .sort({ _id: 1 })
  .toArray();
printjson(porProducto);
print(`Cantidad: ${pedidos.countDocuments({ "items.id_producto": PRODUCTO })}`);
print(`IDs: [${ids(porProducto).join(", ")}]`);
print("");

// ---------------------------------------------------------------------
// d) Pedidos con total superior a un umbral.
//    Umbral = 5000: los totales migrados van de 3283.34 a 7208.54 y su
//    promedio es 4949.64; 5000 queda cerca del promedio y separa los pedidos
//    "grandes" (2, 4 y 5) de los "chicos" (1, 3 y 6).
// ---------------------------------------------------------------------
const UMBRAL = 5000;
print(`d) Pedidos con total > ${UMBRAL}`);
const porTotal = pedidos
  .find({ total: { $gt: UMBRAL } }, { _id: 1, estado: 1, total: 1 })
  .sort({ _id: 1 })
  .toArray();
printjson(porTotal);
print(`Cantidad: ${pedidos.countDocuments({ total: { $gt: UMBRAL } })}`);
print(`IDs: [${ids(porTotal).join(", ")}]`);
