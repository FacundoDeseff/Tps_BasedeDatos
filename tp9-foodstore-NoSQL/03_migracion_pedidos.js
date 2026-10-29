// =====================================================================
// 03_migracion_pedidos.js
// TP9 - Unidad 7: Food Store en MongoDB
// Parte 1: creacion de la base/coleccion y migracion de 6 pedidos existentes
//
// Requisitos:
//   * MongoDB 6.0 o superior con mongosh.
//   * Base de origen PostgreSQL "foodstore" (esquema canonico TP3/TP5/TP8).
//
// Uso:
//   mongosh "mongodb://localhost:27017/foodstore_nosql" --file 03_migracion_pedidos.js
//
// El script es idempotente para los 6 pedidos migrados: elimina solo esos
// _id antes de volver a insertarlos. No borra otros documentos de la coleccion.
// =====================================================================

const NOMBRE_BASE = "foodstore_nosql";
const NOMBRE_COLECCION = "pedidos";
const IDS_MIGRADOS = [1, 2, 3, 4, 5, 6];
const MIGRADO_EN = new Date();

const destino = db.getSiblingDB(NOMBRE_BASE);
const pedidos = destino.getCollection(NOMBRE_COLECCION);

// ---------------------------------------------------------------------
// 1. Validador de esquema
// ---------------------------------------------------------------------
const validadorPedidos = {
  $jsonSchema: {
    bsonType: "object",
    required: [
      "_id",
      "id_pedido",
      "fecha",
      "estado",
      "total",
      "cliente",
      "items",
      "lineas_count",
      "moneda",
      "origen",
      "migrado_en",
      "schema_version",
    ],
    additionalProperties: false,
    properties: {
      _id: {
        bsonType: "int",
        description: "id_pedido original conservado como clave natural",
      },
      id_pedido: {
        bsonType: "int",
        description: "Identificador de origen conservado explicitamente",
      },
      fecha: { bsonType: "date" },
      estado: {
        bsonType: "string",
        enum: ["PENDIENTE", "EN_PREPARACION", "ENTREGADO", "CANCELADO"],
      },
      total: { bsonType: "number", minimum: 0 },
      cliente: {
        bsonType: "object",
        required: ["id_usuario", "nombre", "apellido"],
        additionalProperties: false,
        properties: {
          id_usuario: { bsonType: "int" },
          nombre: { bsonType: "string" },
          apellido: { bsonType: "string" },
        },
      },
      items: {
        bsonType: "array",
        minItems: 1,
        items: {
          bsonType: "object",
          required: [
            "id_detalle",
            "id_producto",
            "nombre_producto",
            "id_categoria",
            "categoria",
            "cantidad",
            "precio_unitario_historico",
            "subtotal",
            "eliminado",
          ],
          additionalProperties: false,
          properties: {
            id_detalle: { bsonType: "int" },
            id_producto: { bsonType: "int" },
            nombre_producto: { bsonType: "string" },
            id_categoria: { bsonType: "int" },
            categoria: { bsonType: "string" },
            cantidad: { bsonType: "int", minimum: 1 },
            precio_unitario_historico: { bsonType: "number", minimum: 0 },
            subtotal: { bsonType: "number", minimum: 0 },
            eliminado: { bsonType: "bool" },
          },
        },
      },
      lineas_count: { bsonType: "int", minimum: 1 },
      moneda: { bsonType: "string", enum: ["ARS"] },
      origen: {
        bsonType: "object",
        required: ["sistema", "base", "tabla", "eliminado"],
        additionalProperties: false,
        properties: {
          sistema: { bsonType: "string", enum: ["PostgreSQL"] },
          base: { bsonType: "string" },
          tabla: { bsonType: "string", enum: ["pedido"] },
          eliminado: { bsonType: "bool" },
        },
      },
      migrado_en: { bsonType: "date" },
      schema_version: { bsonType: "int", minimum: 1 },
    },
  },
};

// ---------------------------------------------------------------------
// 2. Crear la coleccion o actualizar su validador
// ---------------------------------------------------------------------
const colecciones = destino.getCollectionNames();
if (colecciones.includes(NOMBRE_COLECCION)) {
  destino.runCommand({
    collMod: NOMBRE_COLECCION,
    validator: validadorPedidos,
    validationLevel: "strict",
    validationAction: "error",
  });
  print(`Validador actualizado en ${NOMBRE_BASE}.${NOMBRE_COLECCION}`);
} else {
  destino.createCollection(NOMBRE_COLECCION, {
    validator: validadorPedidos,
    validationLevel: "strict",
    validationAction: "error",
  });
  print(`Coleccion creada: ${NOMBRE_BASE}.${NOMBRE_COLECCION}`);
}

// ---------------------------------------------------------------------
// 3. Indices de consulta
// ---------------------------------------------------------------------
pedidos.createIndex({ id_pedido: 1 }, { unique: true });
pedidos.createIndex({ estado: 1 });
pedidos.createIndex({ "cliente.id_usuario": 1 });
pedidos.createIndex({ "items.id_producto": 1 });
pedidos.createIndex({ "items.id_detalle": 1 }, { unique: true });
pedidos.createIndex({ total: 1 });
pedidos.createIndex({ fecha: -1 });

// ---------------------------------------------------------------------
// 4. Datos a migrar
//    Proceden de foodstore (PostgreSQL), pedidos 1 a 6.
//    Los importes y cantidades se copian sin alterar.
//    precio_unitario_historico = subtotal / cantidad.
// ---------------------------------------------------------------------
const linea = (
  idDetalle,
  idProducto,
  nombreProducto,
  idCategoria,
  categoria,
  cantidad,
  precioUnitarioHistorico,
  subtotal,
  eliminado = false
) => ({
  id_detalle: NumberInt(idDetalle),
  id_producto: NumberInt(idProducto),
  nombre_producto: nombreProducto,
  id_categoria: NumberInt(idCategoria),
  categoria: categoria,
  cantidad: NumberInt(cantidad),
  precio_unitario_historico: precioUnitarioHistorico,
  subtotal: subtotal,
  eliminado: eliminado,
});

const pedidosData = [
  {
    _id: NumberInt(1),
    id_pedido: NumberInt(1),
    fecha: new Date("2026-09-29T13:30:21.757-03:00"),
    estado: "ENTREGADO",
    total: 4606.71,
    cliente: {
      id_usuario: NumberInt(2578),
      nombre: "Usuario_2578",
      apellido: "Apellido_2578",
    },
    items: [
      linea(1, 5829, "Producto_5829", 7, "Pastas", 2, 1580.345, 3160.69),
      linea(2, 32828, "Producto_32828", 7, "Pastas", 2, 723.01, 1446.02),
    ],
    lineas_count: NumberInt(2),
    moneda: "ARS",
    origen: {
      sistema: "PostgreSQL",
      base: "foodstore",
      tabla: "pedido",
      eliminado: false,
    },
    migrado_en: MIGRADO_EN,
    schema_version: NumberInt(1),
  },
  {
    _id: NumberInt(2),
    id_pedido: NumberInt(2),
    fecha: new Date("2026-01-07T09:32:05.857-03:00"),
    estado: "ENTREGADO",
    total: 7208.54,
    cliente: {
      id_usuario: NumberInt(7439),
      nombre: "Usuario_7439",
      apellido: "Apellido_7439",
    },
    items: [
      linea(3, 9639, "Producto_9639", 7, "Pastas", 2, 1571.065, 3142.13),
      linea(4, 48030, "Producto_48030", 7, "Pastas", 2, 2033.205, 4066.41),
    ],
    lineas_count: NumberInt(2),
    moneda: "ARS",
    origen: {
      sistema: "PostgreSQL",
      base: "foodstore",
      tabla: "pedido",
      eliminado: false,
    },
    migrado_en: MIGRADO_EN,
    schema_version: NumberInt(1),
  },
  {
    _id: NumberInt(3),
    id_pedido: NumberInt(3),
    fecha: new Date("2026-07-23T05:03:01.150-03:00"),
    estado: "CANCELADO",
    total: 3885.17,
    cliente: {
      id_usuario: NumberInt(3430),
      nombre: "Usuario_3430",
      apellido: "Apellido_3430",
    },
    items: [
      linea(5, 46972, "Producto_46972", 7, "Pastas", 2, 838.725, 1677.45),
      linea(6, 29728, "Producto_29728", 7, "Pastas", 2, 1103.86, 2207.72),
    ],
    lineas_count: NumberInt(2),
    moneda: "ARS",
    origen: {
      sistema: "PostgreSQL",
      base: "foodstore",
      tabla: "pedido",
      eliminado: true,
    },
    migrado_en: MIGRADO_EN,
    schema_version: NumberInt(1),
  },
  {
    _id: NumberInt(4),
    id_pedido: NumberInt(4),
    fecha: new Date("2026-03-05T13:11:03.812-03:00"),
    estado: "ENTREGADO",
    total: 5515.37,
    cliente: {
      id_usuario: NumberInt(352),
      nombre: "Usuario_352",
      apellido: "Apellido_352",
    },
    items: [
      linea(7, 34755, "Producto_34755", 7, "Pastas", 2, 2245.635, 4491.27),
      linea(8, 40246, "Producto_40246", 7, "Pastas", 2, 512.05, 1024.1),
    ],
    lineas_count: NumberInt(2),
    moneda: "ARS",
    origen: {
      sistema: "PostgreSQL",
      base: "foodstore",
      tabla: "pedido",
      eliminado: false,
    },
    migrado_en: MIGRADO_EN,
    schema_version: NumberInt(1),
  },
  {
    _id: NumberInt(5),
    id_pedido: NumberInt(5),
    fecha: new Date("2026-08-20T14:31:58.482-03:00"),
    estado: "ENTREGADO",
    total: 5198.69,
    cliente: {
      id_usuario: NumberInt(7773),
      nombre: "Usuario_7773",
      apellido: "Apellido_7773",
    },
    items: [
      linea(9, 25871, "Producto_25871", 7, "Pastas", 2, 1722.735, 3445.47),
      linea(10, 14267, "Producto_14267", 7, "Pastas", 2, 876.61, 1753.22),
    ],
    lineas_count: NumberInt(2),
    moneda: "ARS",
    origen: {
      sistema: "PostgreSQL",
      base: "foodstore",
      tabla: "pedido",
      eliminado: false,
    },
    migrado_en: MIGRADO_EN,
    schema_version: NumberInt(1),
  },
  {
    _id: NumberInt(6),
    id_pedido: NumberInt(6),
    fecha: new Date("2026-05-26T10:52:46.523-03:00"),
    estado: "ENTREGADO",
    total: 3283.34,
    cliente: {
      id_usuario: NumberInt(6009),
      nombre: "Usuario_6009",
      apellido: "Apellido_6009",
    },
    items: [
      linea(11, 13058, "Producto_13058", 7, "Pastas", 2, 723.255, 1446.51),
      linea(12, 19714, "Producto_19714", 7, "Pastas", 2, 918.415, 1836.83),
    ],
    lineas_count: NumberInt(2),
    moneda: "ARS",
    origen: {
      sistema: "PostgreSQL",
      base: "foodstore",
      tabla: "pedido",
      eliminado: false,
    },
    migrado_en: MIGRADO_EN,
    schema_version: NumberInt(1),
  },
];

// ---------------------------------------------------------------------
// 5. Validacion previa a la insercion
//    Si algo no cumple, se aborta antes de escribir en la coleccion.
// ---------------------------------------------------------------------
const validarPedidos = (documentos) => {
  const errores = [];

  if (documentos.length !== IDS_MIGRADOS.length) {
    errores.push(
      `Se esperaban ${IDS_MIGRADOS.length} documentos y se encontraron ${documentos.length}`
    );
  }

  for (const pedido of documentos) {
    if (Number(pedido._id) !== Number(pedido.id_pedido)) {
      errores.push(
        `Pedido ${pedido.id_pedido}: _id ${pedido._id} != id_pedido ${pedido.id_pedido}`
      );
    }

    const sumaSubtotales = pedido.items.reduce(
      (acumulado, item) => acumulado + item.subtotal,
      0
    );
    const sumaRedondeada = Math.round(sumaSubtotales * 100) / 100;

    if (Math.abs(sumaRedondeada - pedido.total) > 0.001) {
      errores.push(
        `Pedido ${pedido.id_pedido}: total ${pedido.total} != suma de subtotales ${sumaRedondeada}`
      );
    }

    if (Number(pedido.lineas_count) !== pedido.items.length) {
      errores.push(
        `Pedido ${pedido.id_pedido}: lineas_count ${pedido.lineas_count} != items.length ${pedido.items.length}`
      );
    }

    const idsDetalle = new Set();
    for (const item of pedido.items) {
      const idDetalle = Number(item.id_detalle);
      if (idsDetalle.has(idDetalle)) {
        errores.push(
          `Pedido ${pedido.id_pedido}: id_detalle duplicado ${item.id_detalle}`
        );
      }
      idsDetalle.add(idDetalle);

      const subtotalCalculado =
        Math.round(Number(item.cantidad) * item.precio_unitario_historico * 100) / 100;
      if (Math.abs(subtotalCalculado - item.subtotal) > 0.001) {
        errores.push(
          `Pedido ${pedido.id_pedido}, detalle ${item.id_detalle}: cantidad * precio_unitario_historico = ${subtotalCalculado} != subtotal ${item.subtotal}`
        );
      }
    }
  }

  return errores;
};

const erroresPrevios = validarPedidos(pedidosData);
if (erroresPrevios.length > 0) {
  erroresPrevios.forEach((error) => print(`ERROR: ${error}`));
  throw new Error(
    "La migracion no paso las verificaciones previas. No se inserto ningun documento."
  );
}

// ---------------------------------------------------------------------
// 6. Migracion: se eliminan solo los _id de esta carga y se insertan
//    todos los documentos en una sola operacion (insertMany).
// ---------------------------------------------------------------------
const ids = IDS_MIGRADOS.map((id) => NumberInt(id));
const eliminados = pedidos.deleteMany({ _id: { $in: ids } });
print(`Documentos previos eliminados para reinsertar: ${eliminados.deletedCount}`);

let resultado;
try {
  resultado = pedidos.insertMany(pedidosData, { ordered: true });
} catch (error) {
  const limpieza = pedidos.deleteMany({ _id: { $in: ids } });
  print(`ERROR al insertar: ${error.message}`);
  print(`Documentos eliminados por falla de insercion: ${limpieza.deletedCount}`);
  throw error;
}
print(`Documentos insertados: ${Object.keys(resultado.insertedIds).length}`);

// ---------------------------------------------------------------------
// 7. Verificacion de integridad del resultado migrado
// ---------------------------------------------------------------------
const documentos = pedidos
  .find({ _id: { $in: ids } })
  .sort({ _id: 1 })
  .toArray();

const errores = validarPedidos(documentos);

if (errores.length > 0) {
  errores.forEach((error) => print(`ERROR: ${error}`));
  const limpieza = pedidos.deleteMany({ _id: { $in: ids } });
  print(`Documentos eliminados por falla de integridad: ${limpieza.deletedCount}`);
  throw new Error("La migracion no paso las verificaciones de integridad.");
}

print("");
print("Integridad OK:");
print("  - 6 pedidos migrados");
print("  - total = suma de subtotales en todos los pedidos");
print("  - subtotal = cantidad * precio_unitario_historico en todas las lineas");
print("  - lineas_count coincide con items.length");
print("");

// ---------------------------------------------------------------------
// 8. Evidencia para el informe
// ---------------------------------------------------------------------
print("Resumen de pedidos migrados:");
printjson(
  pedidos
    .find(
      { _id: { $in: ids } },
      {
        _id: 1,
        estado: 1,
        "cliente.nombre": 1,
        total: 1,
        lineas_count: 1,
      }
    )
    .sort({ _id: 1 })
    .toArray()
);

print("Cantidad por estado:");
printjson(
  pedidos
    .aggregate([
      { $match: { _id: { $in: ids } } },
      { $group: { _id: "$estado", cantidad: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ])
    .toArray()
);
