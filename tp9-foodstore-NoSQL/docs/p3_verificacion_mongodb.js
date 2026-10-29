// =====================================================================
// p3_verificacion_mongodb.js
// TP9 - Unidad 7 - Parte 3: verificacion de las afirmaciones de IA
//
// Uso:
//   mongosh "mongodb://localhost:27017/foodstore_nosql" --quiet --file docs/p3_verificacion_mongodb.js
//
// Requiere haber ejecutado antes 03_migracion_pedidos.js.
// Inserta documentos de prueba (_id 997, 998 y 999) y los elimina al final.
// =====================================================================

const dbn = db.getSiblingDB("foodstore_nosql");
const c = dbn.pedidos;

print("================================================================");
print("A) PEDIDO COMPLETO EN UNA SOLA LECTURA (findOne)");
print("================================================================");
const p1 = c.findOne({ _id: 1 });
printjson({
  _id: p1._id,
  id_pedido: p1.id_pedido,
  estado: p1.estado,
  total: p1.total,
  cliente: p1.cliente,
  lineas: p1.items.length,
  items: p1.items,
});
print(`Documentos devueltos por la lectura: 1`);
print(`Lineas incluidas en el documento: ${p1.items.length}`);

print("");
print("================================================================");
print("B) COHERENCIA ARITMETICA DE LOS 6 PEDIDOS MIGRADOS");
print("================================================================");
const docs = c.find({ _id: { $in: [1, 2, 3, 4, 5, 6] } }).sort({ _id: 1 }).toArray();
let malosTotal = 0;
let malosLinea = 0;
for (const d of docs) {
  const suma = Math.round(d.items.reduce((a, i) => a + i.subtotal, 0) * 100) / 100;
  if (Math.abs(suma - d.total) > 0.001) malosTotal++;
  for (const it of d.items) {
    const calc = Math.round(it.cantidad * it.precio_unitario_historico * 100) / 100;
    if (Math.abs(calc - it.subtotal) > 0.001) malosLinea++;
  }
}
print(`Pedidos revisados: ${docs.length}`);
print(`Pedidos con total != suma de subtotales: ${malosTotal}`);
print(`Lineas con subtotal != cantidad * precio_unitario_historico: ${malosLinea}`);

print("");
print("================================================================");
print("C) PRUEBA: el validador $jsonSchema ACEPTA un total incoherente");
print("   Documento con total=1.00 y una linea con subtotal=100.00");
print("================================================================");
const incoherente = {
  _id: NumberInt(999),
  id_pedido: NumberInt(999),
  fecha: new Date(),
  estado: "ENTREGADO",
  total: 1.0,
  cliente: { id_usuario: NumberInt(2578), nombre: "Prueba", apellido: "Incoherente" },
  items: [
    {
      id_detalle: NumberInt(9901),
      id_producto: NumberInt(5829),
      nombre_producto: "Producto_5829",
      id_categoria: NumberInt(7),
      categoria: "Pastas",
      cantidad: NumberInt(1),
      precio_unitario_historico: 100.0,
      subtotal: 100.0,
      eliminado: false,
    },
  ],
  lineas_count: NumberInt(1),
  moneda: "ARS",
  origen: { sistema: "PostgreSQL", base: "foodstore", tabla: "pedido", eliminado: false },
  migrado_en: new Date(),
  schema_version: NumberInt(1),
};
try {
  const r = c.insertOne(incoherente);
  print(`insertOne -> acknowledged=${r.acknowledged}, insertedId=${r.insertedId}`);
  const guardado = c.findOne({ _id: 999 });
  const suma = guardado.items.reduce((a, i) => a + i.subtotal, 0);
  print(`Documento guardado: total=${guardado.total}, suma_subtotales=${suma}`);
  print("RESULTADO: ACEPTADO. El validador no compara campos entre si.");
} catch (e) {
  print(`RESULTADO: RECHAZADO (${e.codeName || e.name}: ${e.message})`);
} finally {
  const limpio = c.deleteOne({ _id: 999 });
  print(`Limpieza: documentos eliminados=${limpio.deletedCount}`);
}

print("");
print("================================================================");
print("D) PRUEBA: el validador RECHAZA un documento sin items");
print("================================================================");
const sinItems = Object.assign({}, incoherente, { _id: NumberInt(998), id_pedido: NumberInt(998) });
delete sinItems.items;
delete sinItems.lineas_count;
try {
  c.insertOne(sinItems);
  print("RESULTADO: ACEPTADO (inesperado)");
} catch (e) {
  print(`RESULTADO: RECHAZADO (${e.codeName || e.name}: ${e.message})`);
} finally {
  c.deleteOne({ _id: 998 });
}

print("");
print("================================================================");
print("E) PRUEBA: indice unico RECHAZA un id_detalle duplicado entre pedidos");
print("   (id_detalle=1 ya existe en el pedido 1)");
print("================================================================");
const dup = {
  _id: NumberInt(997),
  id_pedido: NumberInt(997),
  fecha: new Date(),
  estado: "ENTREGADO",
  total: 100.0,
  cliente: { id_usuario: NumberInt(2578), nombre: "Prueba", apellido: "Duplicado" },
  items: [
    {
      id_detalle: NumberInt(1),
      id_producto: NumberInt(5829),
      nombre_producto: "Producto_5829",
      id_categoria: NumberInt(7),
      categoria: "Pastas",
      cantidad: NumberInt(1),
      precio_unitario_historico: 100.0,
      subtotal: 100.0,
      eliminado: false,
    },
  ],
  lineas_count: NumberInt(1),
  moneda: "ARS",
  origen: { sistema: "PostgreSQL", base: "foodstore", tabla: "pedido", eliminado: false },
  migrado_en: new Date(),
  schema_version: NumberInt(1),
};
try {
  c.insertOne(dup);
  print("RESULTADO: ACEPTADO (inesperado)");
} catch (e) {
  print(`RESULTADO: RECHAZADO (code=${e.code}, ${e.codeName || e.name}: ${e.message.split("\n")[0]})`);
} finally {
  c.deleteOne({ _id: 997 });
}

print("");
print("================================================================");
print("F) INDICES DE LA COLECCION");
print("================================================================");
printjson(c.getIndexes().map((i) => ({ name: i.name, key: i.key, unique: !!i.unique })));

print("");
print("================================================================");
print("G) ESTADO FINAL: documentos en la coleccion");
print("================================================================");
print(`countDocuments({}) = ${c.countDocuments({})}`);
printjson(c.find({}, { _id: 1 }).sort({ _id: 1 }).toArray());
