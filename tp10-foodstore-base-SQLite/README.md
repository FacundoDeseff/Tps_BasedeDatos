# TP10 · Food Store en la feria (SQLite)

Trabajo Práctico N.º 8 / Unidad 8 · Base de Datos II.
La tablet guarda una copia parcial del catálogo, arma borradores sin conexión y
simula la sincronización con PostgreSQL. **El móvil propone, el servidor dispone.**

## Requisitos

- PostgreSQL 17 en `localhost:5433`, usuario `postgres` (autenticación por
  `%APPDATA%\postgresql\pgpass.conf`).
- Python 3.10+ (usa el módulo `sqlite3` de la biblioteca estándar).
- Opcional: `sqlite3` o DB Browser for SQLite para ejecutar los scripts a mano.

## Orden para crear todo desde cero

### 0. Copia de la base de pruebas en PostgreSQL

La consigna pide trabajar sobre una copia. Desde `psql`:

```sql
CREATE DATABASE foodstore_u8 TEMPLATE foodstore;
```

### 1. Base de la tablet (consigna 1)

```bash
sqlite3 movil/foodstore_movil.db < movil/schema_sqlite.sql
sqlite3 movil/foodstore_movil.db < movil/pruebas_sqlite.sql
```

Si no tenés `sqlite3`, abrí `movil/schema_sqlite.sql` y
`movil/pruebas_sqlite.sql` con DB Browser for SQLite en el mismo archivo `.db`.

### 2. Sincronizar y resolver (consigna 2)

La forma automática (recomendada) es:

```bash
python movil/simulador.py
```

El simulador:

1. ejecuta `movil/servidor_snapshot.sql` sobre `foodstore_u8` (crea la vista
   `v_snapshot_movil`),
2. exporta `movil/servidor_snapshot.csv`,
3. crea `movil/foodstore_movil.db` con `schema_sqlite.sql`,
   `importar_snapshot.sql` y `cargar_cache.sql`,
4. corre `semaforo.sql` para los casos C2, C3, C4, C5 y C6,
5. deja la evidencia completa en `docs/evidencia_consigna2.txt`.

Forma manual, en tres pasos:

```sql
-- 1) En psql, sobre foodstore_u8
\i movil/servidor_snapshot.sql
\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'movil/servidor_snapshot.csv' CSV HEADER
```

```sql
-- 2) En SQLite, después de crear el esquema
.read movil/importar_snapshot.sql
.import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor
.read movil/cargar_cache.sql
```

```sql
-- 3) Cada vez que llegue una instantánea nueva
.read movil/semaforo.sql
SELECT solicitud_uuid, estado, motivo FROM cola_sync;
```

### 3. Consignas 3 y 4

Pendientes: mapa de los tres motores, plan de mantenimiento, code review con IA,
spec de Kiro, bitácora, DUIA y ensayo de defensa.

## Archivos

```
movil/
├── schema_sqlite.sql          tablas de la tablet (consigna 1.b)
├── pruebas_sqlite.sql         pruebas de transacciones y CHECK (consigna 1.c)
├── servidor_snapshot.sql      vista v_snapshot_movil (consigna 2.a)
├── servidor_snapshot.csv      instantánea base exportada de PostgreSQL
├── importar_snapshot.sql      tabla snapshot_servidor en SQLite
├── cargar_cache.sql           carga producto_cache desde la instantánea
├── semaforo.sql               semáforo RECHAZADO / CONFLICTO / SIMULADO_APROBADO
├── simulador.py               ejecuta y documenta los casos C2 a C6
├── casos/                     instantáneas usadas en cada caso
└── foodstore_movil.db         base SQLite resultante

docs/
├── informe.md                 informe de la cursada
└── evidencia_consigna2.txt    salida real de la simulación
```
