-- PARTE 1: NORMALIZACIÓN BCNF

-- 1. Tabla original e instancia de prueba
CREATE TABLE IF NOT EXISTS control_lote_almacen (
    lote_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    PRIMARY KEY (lote_id, deposito_id)
);

TRUNCATE TABLE control_lote_almacen;

INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- 2. Descomposición en BCNF
CREATE TABLE IF NOT EXISTS responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY,
    deposito_id BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS control_lote (
    lote_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- 3. Migración de datos
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id 
FROM control_lote_almacen;

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id 
FROM control_lote_almacen;

-- 4. Vista de compatibilidad
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT 
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd ON rd.responsable_control_id = cl.responsable_control_id;

-- 5. Verificación (Ambas deben dar 0 filas)
SELECT * FROM control_lote_almacen EXCEPT SELECT * FROM v_control_lote_almacen;
SELECT * FROM v_control_lote_almacen EXCEPT SELECT * FROM control_lote_almacen;