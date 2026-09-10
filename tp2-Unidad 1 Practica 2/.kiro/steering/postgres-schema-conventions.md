# Convenciones del Esquema PostgreSQL

Este documento establece las convenciones que deben seguirse al escribir o modificar archivos SQL en este proyecto. Se derivan del esquema existente (`schema.sql` y `restricciones.sql`).

## Archivos de referencia

- `schema.sql` — definición de tablas y columnas
- `restricciones.sql` — constraints agregados con `ALTER TABLE`

---

## Nomenclatura

### Tablas
- **snake_case**, en **singular**, en **español**.
- Ejemplos: `categoria`, `producto`, `detalle_orden`.

### Columnas
- **snake_case**, en **español**.
- La clave primaria se llama siempre `id_<nombre_tabla>`.
  - Ejemplo: `id_categoria`, `id_producto`.
- Las claves foráneas siguen el mismo patrón: `id_<tabla_referenciada>`.
  - Ejemplo: `id_categoria` dentro de `producto`.

### Constraints
- Prefijos obligatorios según tipo:

| Tipo          | Prefijo | Ejemplo                        |
|---------------|---------|--------------------------------|
| CHECK         | `ck_`   | `ck_producto_precio_stock`     |
| FOREIGN KEY   | `fk_`   | `fk_producto_categoria`        |
| UNIQUE        | `uq_`   | `uq_categoria_nombre`          |
| NOT NULL      | —       | Se declara inline en la columna|
| PRIMARY KEY   | —       | Se declara inline en la columna|

- El nombre completo del constraint sigue el patrón `<prefijo>_<tabla>_<columna(s)>`.

---

## Tipos de datos

| Uso                          | Tipo recomendado          |
|------------------------------|---------------------------|
| Clave primaria               | `BIGINT GENERATED ALWAYS AS IDENTITY` |
| Texto corto (nombre, label)  | `VARCHAR(n)` con `n` apropiado |
| Precio / importes monetarios | `NUMERIC(10,2)`           |
| Cantidades enteras           | `INTEGER`                 |
| Booleanos                    | `BOOLEAN`                 |
| Timestamps                   | `TIMESTAMPTZ`             |

---

## Claves primarias

- Siempre `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`, declarado inline en la definición de la columna.
- No se usan `SERIAL` ni `SEQUENCE` explícitas.

---

## Valores por defecto

- Se declaran inline en la columna cuando aplica.
- Ejemplo: `stock INTEGER NOT NULL DEFAULT 0`.

---

## Separación schema / constraints

- La **estructura base** (tablas y columnas) va en `schema.sql`.
- Los **constraints de integridad** (CHECK, FK, UNIQUE adicionales) van en `restricciones.sql` usando `ALTER TABLE ... ADD CONSTRAINT`.
- No mezclar lógica de constraints en `schema.sql` salvo `PRIMARY KEY`, `NOT NULL` y `UNIQUE` simples declarados inline.

---

## Comportamiento referencial

- Las claves foráneas usan `ON DELETE RESTRICT` por defecto, salvo que el modelo de negocio justifique `CASCADE` o `SET NULL`.
- Documentar la razón si se elige una opción distinta a `RESTRICT`.

---

## Estilo SQL

- **Palabras reservadas en MAYÚSCULAS**: `CREATE TABLE`, `ALTER TABLE`, `ADD CONSTRAINT`, `NOT NULL`, `DEFAULT`, `REFERENCES`, `CHECK`, etc.
- **Nombres de tablas, columnas y constraints en minúsculas**.
- Indentación con **4 espacios**.
- Una columna por línea dentro de `CREATE TABLE`.
- Punto y coma al final de cada sentencia.

---

## Ejemplo canónico

```sql
-- schema.sql
CREATE TABLE producto (
    id_producto   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(150) NOT NULL,
    precio_lista  NUMERIC(10,2) NOT NULL,
    stock         INTEGER NOT NULL DEFAULT 0,
    id_categoria  BIGINT NOT NULL
);

-- restricciones.sql
ALTER TABLE producto
    ADD CONSTRAINT ck_producto_precio_stock
    CHECK (precio_lista > 0 AND stock >= 0);

ALTER TABLE producto
    ADD CONSTRAINT fk_producto_categoria
    FOREIGN KEY (id_categoria)
    REFERENCES categoria (id_categoria)
    ON DELETE RESTRICT;
```
