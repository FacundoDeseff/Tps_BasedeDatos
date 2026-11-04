#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Consigna 2 del TP10 - Sincronizar y resolver.

Este simulador hace de punta a punta lo que pide la consigna:
  2.a  exporta v_snapshot_movil de PostgreSQL a CSV y la importa en SQLite,
  2.b  corre el semáforo (semaforo.sql) sobre las solicitudes PENDIENTE,
  2.c  prepara y muestra los casos C2, C3, C4, C5 y C6.

Requisitos:
  * PostgreSQL 17 en localhost:5433, usuario postgres (autenticación por pgpass).
  * La base de pruebas foodstore_u8 debe existir. Si no existe, se crea como
    copia de foodstore con:
        CREATE DATABASE foodstore_u8 TEMPLATE foodstore;
  * Python 3.10+ (usa sqlite3 de la biblioteca estándar).

Uso:
    python movil/simulador.py

Genera:
    movil/servidor_snapshot.csv        instantánea base
    movil/casos/snapshot_C2..C6.csv    instantánea usada en cada caso
    movil/foodstore_movil.db           base SQLite final
    docs/evidencia_consigna2.txt       salida completa de la ejecución
"""

from __future__ import annotations

import csv
import os
import sqlite3
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# ----------------------------------------------------------------------------
# Configuración
# ----------------------------------------------------------------------------
MOVIL = Path(__file__).resolve().parent
TP = MOVIL.parent
DOCS = TP / "docs"
CASOS = MOVIL / "casos"

SERVIDOR_SNAPSHOT = MOVIL / "servidor_snapshot.sql"
SCHEMA = MOVIL / "schema_sqlite.sql"
IMPORTAR = MOVIL / "importar_snapshot.sql"
CARGAR_CACHE = MOVIL / "cargar_cache.sql"
SEMAFORO = MOVIL / "semaforo.sql"
BASE_CSV = MOVIL / "servidor_snapshot.csv"
DB = MOVIL / "foodstore_movil.db"
EVIDENCIA = DOCS / "evidencia_consigna2.txt"

PSQL = r"C:\Program Files\PostgreSQL\17\bin\psql.exe"
PG = {
    "host": "localhost",
    "port": "5433",
    "user": "postgres",
    "db": "foodstore_u8",
}
PG_ORIGINAL = "foodstore"

# Productos que forman el catálogo de la feria (los mismos que usa la vista).
# precio_lista / stock / eliminado de la COPIA de pruebas.
BASE_PRODUCTOS = {
    1: ("1259.45", 152, False),
    3: ("3913.03", 142, False),
    4: ("3629.12", 84, False),
    5: ("584.50", 113, False),
    6: ("2514.07", 150, False),
    7: ("2756.60", 163, False),
    8: ("630.88", 198, False),
    10: ("3277.67", 183, False),
}
FERIA_IDS = tuple(BASE_PRODUCTOS)

# UUIDs inventados (formato válido, sin datos personales)
DRAFTS = {
    "C2": "c2c2c2c2-0000-4000-8000-000000000002",
    "C3": "c3c3c3c3-0000-4000-8000-000000000003",
    "C4": "c4c4c4c4-0000-4000-8000-000000000004",
    "C5": "c5c5c5c5-0000-4000-8000-000000000005",
    "C6": "c6c6c6c6-0000-4000-8000-000000000006",
}
SOLICITUDES = {
    "C2_1": "a2a2a2a2-0001-4000-8000-000000000021",
    "C2_2": "a2a2a2a2-0002-4000-8000-000000000022",
    "C3": "a3a3a3a3-0000-4000-8000-000000000003",
    "C4": "a4a4a4a4-0000-4000-8000-000000000004",
    "C5": "a5a5a5a5-0000-4000-8000-000000000005",
    "C6": "a6a6a6a6-0000-4000-8000-000000000006",
}

LINEAS: list[str] = []


def log(texto: str = "") -> None:
    print(texto)
    LINEAS.append(texto)


def fallar(mensaje: str) -> None:
    raise AssertionError(mensaje)


def esperar(condicion: bool, mensaje: str) -> None:
    if not condicion:
        fallar(mensaje)


# ----------------------------------------------------------------------------
# PostgreSQL
# ----------------------------------------------------------------------------
def _base_cmd(db: str) -> list[str]:
    return [
        PSQL,
        "-h",
        PG["host"],
        "-p",
        PG["port"],
        "-U",
        PG["user"],
        "-d",
        db,
        "-v",
        "ON_ERROR_STOP=1",
        "-X",
        "-q",
    ]


def _env() -> dict[str, str]:
    env = os.environ.copy()
    env["PGCLIENTENCODING"] = "UTF8"
    return env


def psql(sql: str, db: str | None = None) -> str:
    cmd = _base_cmd(db or PG["db"]) + ["-c", sql]
    res = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=_env()
    )
    if res.returncode != 0:
        raise RuntimeError(f"psql falló:\n{res.stderr}\n--- SQL ---\n{sql}")
    return res.stdout


def psql_file(ruta: Path, db: str | None = None) -> str:
    cmd = _base_cmd(db or PG["db"]) + ["-f", str(ruta)]
    res = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=_env()
    )
    if res.returncode != 0:
        raise RuntimeError(f"psql falló con {ruta}:\n{res.stderr}")
    return res.stdout


def pg_query(sql: str, db: str | None = None) -> list[str]:
    cmd = _base_cmd(db or PG["db"]) + ["-tA", "-F", "|", "-c", sql]
    res = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=_env()
    )
    if res.returncode != 0:
        raise RuntimeError(f"psql falló:\n{res.stderr}\n--- SQL ---\n{sql}")
    return [ln for ln in res.stdout.strip().splitlines() if ln.strip()]


def reset_servidor() -> str:
    """Devuelve los 8 productos de la feria al estado base de la copia."""
    sentencias = []
    for pid, (precio, stock, eliminado) in BASE_PRODUCTOS.items():
        sentencias.append(
            "UPDATE producto SET "
            f"precio_lista = {precio}, stock = {stock}, "
            f"eliminado = {'true' if eliminado else 'false'} "
            f"WHERE id_producto = {pid};"
        )
    sql = "\n".join(sentencias)
    psql(sql)
    return sql


def exportar_snapshot(destino: Path) -> None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    ruta = destino.as_posix()
    psql(f"\\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO '{ruta}' CSV HEADER")


def invariantes(db: str | None = None) -> dict[str, int]:
    ids = ",".join(str(i) for i in FERIA_IDS)
    sql = (
        "SELECT "
        "(SELECT count(*) FROM pedido), "
        "(SELECT coalesce(sum(stock), 0) FROM producto), "
        f"(SELECT count(*) FROM producto WHERE id_producto IN ({ids}));"
    )
    fila = pg_query(sql, db)[0]
    pedidos, stock, feria = (int(x) for x in fila.split("|"))
    return {"pedidos": pedidos, "stock": stock, "feria": feria}


def comparar_invariantes(caso: str, antes: dict[str, int], despues: dict[str, int]) -> None:
    esperar(
        antes["pedidos"] == despues["pedidos"],
        f"{caso}: cambió la cantidad de pedidos ({antes['pedidos']} -> {despues['pedidos']})",
    )
    esperar(
        antes["stock"] == despues["stock"],
        f"{caso}: cambió el stock total ({antes['stock']} -> {despues['stock']})",
    )
    log(
        f"[invariante] pedidos={despues['pedidos']} sin cambios | "
        f"stock_total={despues['stock']} sin cambios | "
        f"productos_feria={despues['feria']}"
    )


# ----------------------------------------------------------------------------
# SQLite
# ----------------------------------------------------------------------------
def leer_csv(ruta: Path) -> list[dict[str, str]]:
    with open(ruta, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        esperadas = [
            "id",
            "nombre",
            "precio_centavos",
            "stock",
            "disponible",
            "eliminado",
            "fecha_copia",
        ]
        esperar(
            reader.fieldnames == esperadas,
            f"{ruta.name}: encabezado inesperado: {reader.fieldnames}",
        )
        filas = list(reader)
    for fila in filas:
        esperar(fila["disponible"] in ("t", "f"), f"disponible inválido: {fila}")
        esperar(fila["eliminado"] in ("t", "f"), f"eliminado inválido: {fila}")
    return filas


def importar_csv(conn: sqlite3.Connection, ruta: Path) -> None:
    filas = leer_csv(ruta)
    conn.executemany(
        "INSERT INTO snapshot_servidor "
        "(id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        [
            (
                int(f["id"]),
                f["nombre"],
                int(f["precio_centavos"]),
                int(f["stock"]),
                f["disponible"],
                f["eliminado"],
                f["fecha_copia"],
            )
            for f in filas
        ],
    )
    conn.commit()


def crear_db(csv_path: Path) -> sqlite3.Connection:
    if DB.exists():
        DB.unlink()
    conn = sqlite3.connect(DB)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))
    conn.executescript(IMPORTAR.read_text(encoding="utf-8"))
    importar_csv(conn, csv_path)
    conn.executescript(CARGAR_CACHE.read_text(encoding="utf-8"))
    conn.commit()
    return conn


def refrescar_snapshot(conn: sqlite3.Connection, csv_path: Path) -> None:
    conn.execute("DELETE FROM snapshot_servidor")
    conn.commit()
    importar_csv(conn, csv_path)
    conn.executescript(CARGAR_CACHE.read_text(encoding="utf-8"))
    conn.commit()


def correr_semaforo(conn: sqlite3.Connection) -> None:
    conn.executescript(SEMAFORO.read_text(encoding="utf-8"))
    conn.commit()


def sembrar(
    conn: sqlite3.Connection,
    id_local: str,
    usuario: str,
    forma_pago: str,
    items: list[tuple[int, int, int]],
    solicitud_uuid: str,
) -> str:
    sql = (
        "INSERT INTO pedido_borrador (id_local, usuario, forma_pago) VALUES "
        f"('{id_local}', '{usuario}', '{forma_pago}');\n"
        "INSERT INTO item_borrador "
        "(id_local, producto_id, cantidad, precio_centavos_visto) VALUES "
        + ", ".join(f"('{id_local}', {p}, {c}, {pr})" for p, c, pr in items)
        + ";\n"
        f"INSERT INTO cola_sync (solicitud_uuid, id_local) "
        f"VALUES ('{solicitud_uuid}', '{id_local}');"
    )
    conn.execute(
        "INSERT INTO pedido_borrador (id_local, usuario, forma_pago) VALUES (?, ?, ?)",
        (id_local, usuario, forma_pago),
    )
    conn.executemany(
        "INSERT INTO item_borrador "
        "(id_local, producto_id, cantidad, precio_centavos_visto) VALUES (?, ?, ?, ?)",
        [(id_local, p, c, pr) for p, c, pr in items],
    )
    conn.execute(
        "INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES (?, ?)",
        (solicitud_uuid, id_local),
    )
    conn.commit()
    return sql


def solicitud(conn: sqlite3.Connection, uuid: str) -> tuple[str, str]:
    fila = conn.execute(
        "SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = ?", (uuid,)
    ).fetchone()
    esperar(fila is not None, f"no existe la solicitud {uuid}")
    return fila[0], fila[1]


def catalogo_disponible(conn: sqlite3.Connection) -> list[tuple[int, str]]:
    return conn.execute(
        "SELECT id, nombre FROM producto_cache "
        "WHERE disponible = 1 AND eliminado = 0 ORDER BY id"
    ).fetchall()


def contar_cola(conn: sqlite3.Connection) -> int:
    return conn.execute("SELECT count(*) FROM cola_sync").fetchone()[0]


# ----------------------------------------------------------------------------
# Casos
# ----------------------------------------------------------------------------
def caso_c2() -> None:
    log()
    log("=" * 78)
    log("CASO C2 - Un borrador; después sube el precio en el servidor")
    log("=" * 78)
    antes = invariantes()

    reset_servidor()
    base = leer_csv(BASE_CSV)
    precio1 = {int(f["id"]): int(f["precio_centavos"]) for f in base}[1]

    conn = crear_db(BASE_CSV)
    log(f"[SQLite] borrador {DRAFTS['C2']} con producto 1 x2 a {precio1} centavos")
    log(sembrar(conn, DRAFTS["C2"], "cliente_c2", "EFECTIVO", [(1, 2, precio1)], SOLICITUDES["C2_1"]))

    log("[PostgreSQL] UPDATE producto SET precio_lista = precio_lista + 100.00 WHERE id_producto = 1;")
    psql("UPDATE producto SET precio_lista = precio_lista + 100.00 WHERE id_producto = 1;")
    exportar_snapshot(CASOS / "snapshot_C2.csv")
    fecha = leer_csv(CASOS / "snapshot_C2.csv")[0]["fecha_copia"]
    log(f"[instantánea] movil/casos/snapshot_C2.csv | fecha_copia = {fecha}")
    refrescar_snapshot(conn, CASOS / "snapshot_C2.csv")

    correr_semaforo(conn)
    estado, motivo = solicitud(conn, SOLICITUDES["C2_1"])
    log(f"[resultado] {estado} | {motivo}")
    esperar(estado == "CONFLICTO", f"C2: se esperaba CONFLICTO y dio {estado}")
    esperar("125945" in motivo and "135945" in motivo, f"C2: motivo inesperado: {motivo}")

    log("[cliente acepta] actualiza el precio del borrador y crea una solicitud nueva")
    conn.execute(
        "UPDATE item_borrador SET precio_centavos_visto = ? "
        "WHERE id_local = ? AND producto_id = 1",
        (precio1 + 10000, DRAFTS["C2"]),
    )
    conn.execute(
        "INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES (?, ?)",
        (SOLICITUDES["C2_2"], DRAFTS["C2"]),
    )
    conn.commit()
    correr_semaforo(conn)
    estado2, motivo2 = solicitud(conn, SOLICITUDES["C2_2"])
    log(f"[resultado] {estado2} | {motivo2}")
    esperar(
        estado2 == "SIMULADO_APROBADO",
        f"C2: la solicitud nueva debía ser SIMULADO_APROBADO y dio {estado2}",
    )
    estado_viejo, _ = solicitud(conn, SOLICITUDES["C2_1"])
    esperar(
        estado_viejo == "CONFLICTO",
        "C2: la solicitud vieja debe quedar en CONFLICTO para la revisión",
    )
    log(f"[solicitud vieja] {estado_viejo} (queda para revisión, no se reevalúa)")

    comparar_invariantes("C2", antes, invariantes())
    conn.close()


def caso_c3() -> None:
    log()
    log("=" * 78)
    log("CASO C3 - Un borrador por más unidades de las que quedan")
    log("=" * 78)
    antes = invariantes()

    reset_servidor()
    exportar_snapshot(CASOS / "snapshot_C3.csv")
    filas = leer_csv(CASOS / "snapshot_C3.csv")
    stock3 = {int(f["id"]): int(f["stock"]) for f in filas}[3]
    precio3 = {int(f["id"]): int(f["precio_centavos"]) for f in filas}[3]
    pedido = stock3 + 50
    fecha = filas[0]["fecha_copia"]
    log(f"[instantánea] movil/casos/snapshot_C3.csv | fecha_copia = {fecha}")
    log(f"[stock del servidor] producto 3 = {stock3}; el borrador pide {pedido}")

    conn = crear_db(CASOS / "snapshot_C3.csv")
    log(sembrar(conn, DRAFTS["C3"], "cliente_c3", "TARJETA", [(3, pedido, precio3)], SOLICITUDES["C3"]))
    correr_semaforo(conn)
    estado, motivo = solicitud(conn, SOLICITUDES["C3"])
    log(f"[resultado] {estado} | {motivo}")
    esperar(estado == "RECHAZADO", f"C3: se esperaba RECHAZADO y dio {estado}")
    esperar("stock" in motivo, f"C3: motivo inesperado: {motivo}")

    comparar_invariantes("C3", antes, invariantes())
    conn.close()


def caso_c4() -> None:
    log()
    log("=" * 78)
    log("CASO C4 - Un borrador con un producto que después se da de baja")
    log("=" * 78)
    antes = invariantes()

    reset_servidor()
    filas = leer_csv(BASE_CSV)
    precio4 = {int(f["id"]): int(f["precio_centavos"]) for f in filas}[4]

    conn = crear_db(BASE_CSV)
    log(sembrar(conn, DRAFTS["C4"], "cliente_c4", "TRANSFERENCIA", [(4, 1, precio4)], SOLICITUDES["C4"]))

    log("[PostgreSQL] UPDATE producto SET eliminado = true WHERE id_producto = 4;")
    psql("UPDATE producto SET eliminado = true WHERE id_producto = 4;")
    exportar_snapshot(CASOS / "snapshot_C4.csv")
    fecha = leer_csv(CASOS / "snapshot_C4.csv")[0]["fecha_copia"]
    log(f"[instantánea] movil/casos/snapshot_C4.csv | fecha_copia = {fecha}")
    refrescar_snapshot(conn, CASOS / "snapshot_C4.csv")

    correr_semaforo(conn)
    estado, motivo = solicitud(conn, SOLICITUDES["C4"])
    log(f"[resultado] {estado} | {motivo}")
    esperar(estado == "RECHAZADO", f"C4: se esperaba RECHAZADO y dio {estado}")
    esperar("dado de baja" in motivo, f"C4: motivo inesperado: {motivo}")

    disponibles = {pid for pid, _ in catalogo_disponible(conn)}
    fila_cache = conn.execute("SELECT eliminado FROM producto_cache WHERE id = 4").fetchone()
    log(f"[catálogo recargado] ids disponibles = {sorted(disponibles)}")
    log(f"[lápida] producto_cache id=4 eliminado={fila_cache[0] if fila_cache else 'AUSENTE'}")
    esperar(4 not in disponibles, "C4: el producto dado de baja no debe aparecer como disponible")
    esperar(fila_cache == (1,), "C4: la fila del producto debe quedar como lápida en product_cache")

    comparar_invariantes("C4", antes, invariantes())
    conn.close()


def caso_c5() -> None:
    log()
    log("=" * 78)
    log("CASO C5 - Un borrador sin cambios")
    log("=" * 78)
    antes = invariantes()

    reset_servidor()
    exportar_snapshot(CASOS / "snapshot_C5.csv")
    filas = leer_csv(CASOS / "snapshot_C5.csv")
    precio5 = {int(f["id"]): int(f["precio_centavos"]) for f in filas}[5]
    fecha = filas[0]["fecha_copia"]
    log(f"[instantánea] movil/casos/snapshot_C5.csv | fecha_copia = {fecha}")

    conn = crear_db(CASOS / "snapshot_C5.csv")
    log(sembrar(conn, DRAFTS["C5"], "cliente_c5", "EFECTIVO", [(5, 1, precio5)], SOLICITUDES["C5"]))
    correr_semaforo(conn)
    estado, motivo = solicitud(conn, SOLICITUDES["C5"])
    log(f"[resultado] {estado} | {motivo}")
    esperar(estado == "SIMULADO_APROBADO", f"C5: se esperaba SIMULADO_APROBADO y dio {estado}")

    # Repetir la simulación no debe reevaluar: sigue igual.
    correr_semaforo(conn)
    estado2, motivo2 = solicitud(conn, SOLICITUDES["C5"])
    log(f"[repetir semáforo] {estado2} | {motivo2} | solicitudes = {contar_cola(conn)}")
    esperar(estado2 == estado and motivo2 == motivo, "C5: repetir el semáforo cambió el resultado")

    comparar_invariantes("C5", antes, invariantes())
    conn.close()


def caso_c6() -> None:
    log()
    log("=" * 78)
    log("CASO C6 - Reenviar la misma solicitud (mismo UUID)")
    log("=" * 78)
    antes = invariantes()

    reset_servidor()
    exportar_snapshot(CASOS / "snapshot_C6.csv")
    filas = leer_csv(CASOS / "snapshot_C6.csv")
    precio6 = {int(f["id"]): int(f["precio_centavos"]) for f in filas}[6]
    fecha = filas[0]["fecha_copia"]
    log(f"[instantánea] movil/casos/snapshot_C6.csv | fecha_copia = {fecha}")

    conn = crear_db(CASOS / "snapshot_C6.csv")
    log(sembrar(conn, DRAFTS["C6"], "cliente_c6", "EFECTIVO", [(6, 1, precio6)], SOLICITUDES["C6"]))
    correr_semaforo(conn)
    estado, motivo = solicitud(conn, SOLICITUDES["C6"])
    log(f"[primer envío] {estado} | {motivo}")

    antes_cola = contar_cola(conn)
    try:
        conn.execute(
            "INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES (?, ?)",
            (SOLICITUDES["C6"], DRAFTS["C6"]),
        )
        conn.commit()
        fallar("C6: el UUID repetido debía dar error de clave primaria")
    except sqlite3.IntegrityError as exc:
        conn.rollback()
        log(f"[reenvío mismo UUID] error esperado: {exc}")
        esperar("UNIQUE" in str(exc), f"C6: error inesperado: {exc}")

    despues_cola = contar_cola(conn)
    log(f"[cola] antes={antes_cola} despues={despues_cola} (no se duplica)")
    esperar(antes_cola == despues_cola, "C6: el reenvío duplicó la solicitud")

    correr_semaforo(conn)
    estado2, motivo2 = solicitud(conn, SOLICITUDES["C6"])
    log(f"[repetir simulación] {estado2} | {motivo2} | solicitudes = {contar_cola(conn)}")
    esperar(
        (estado2, motivo2) == (estado, motivo),
        "C6: repetir la simulación reevaluó la solicitud ya resuelta",
    )
    log(
        "[defensa real] En un sistema de verdad la protección va en el SERVIDOR: "
        "recibe solicitud_uuid como clave de idempotencia, la registra en una tabla "
        "de solicitudes procesadas (o usa una restricción UNIQUE) dentro de la "
        "misma transacción que crea el pedido, y si el UUID ya existe responde OK "
        "sin volver a vender."
    )

    comparar_invariantes("C6", antes, invariantes())
    conn.close()


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    DOCS.mkdir(parents=True, exist_ok=True)
    CASOS.mkdir(parents=True, exist_ok=True)

    log("=" * 78)
    log("EVIDENCIA CONSIGNA 2 - TP10 Food Store (SQLite)")
    log(f"Ejecución: {datetime.now():%Y-%m-%d %H:%M:%S}")
    log(f"PostgreSQL de pruebas (copia): {PG['db']} en {PG['host']}:{PG['port']}")
    log(f"SQLite: {sqlite3.sqlite_version} | archivo: movil/foodstore_movil.db")
    log("=" * 78)

    # Estado inicial de la copia y de la base original
    psql_file(SERVIDOR_SNAPSHOT)
    log("[PostgreSQL] vista v_snapshot_movil creada/actualizada (movil/servidor_snapshot.sql)")
    reset_servidor()
    exportar_snapshot(BASE_CSV)
    filas = leer_csv(BASE_CSV)
    log(f"[instantánea base] movil/servidor_snapshot.csv | filas={len(filas)} | "
        f"fecha_copia={filas[0]['fecha_copia']}")
    log(f"[copia PostgreSQL] {invariantes()}")
    log(f"[original PostgreSQL] {invariantes(PG_ORIGINAL)} (no se toca)")

    caso_c2()
    caso_c3()
    caso_c4()
    caso_c5()
    caso_c6()

    log()
    log("=" * 78)
    log("RESUMEN")
    log("=" * 78)
    log("C2 OK: precio cambiado -> CONFLICTO; precio aceptado -> SIMULADO_APROBADO")
    log("C3 OK: más unidades que el stock -> RECHAZADO")
    log("C4 OK: producto dado de baja -> RECHAZADO; lápida en producto_cache")
    log("C5 OK: sin cambios -> SIMULADO_APROBADO")
    log("C6 OK: UUID repetido -> error de clave primaria; no se duplica")
    log()
    log("[verificación final en PostgreSQL]")
    log(f"  copia foodstore_u8: {invariantes()}")
    log(f"  original foodstore: {invariantes(PG_ORIGINAL)}")
    log("  Los pedidos y el stock no cambiaron por la simulación.")

    EVIDENCIA.write_text("\n".join(LINEAS) + "\n", encoding="utf-8")
    log()
    log(f"[evidencia escrita] {EVIDENCIA.relative_to(TP)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"\nERROR: {exc}", file=sys.stderr)
        raise
