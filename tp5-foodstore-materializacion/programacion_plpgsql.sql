-- ============================================================================
-- OBJETOS PROGRAMABLES EN PL/pgSQL (Puntos 6 y 7 del TPI)
-- ============================================================================

-- 1. FUNCIÓN Y TRIGGER: Validación y Descuento Automático de Stock
-- Regla de negocio: Al insertar un ítem en detalle_pedido, verifica que haya stock suficiente
-- y lo descuenta automáticamente de la tabla producto.
CREATE OR REPLACE FUNCTION fn_trg_descontar_stock()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_actual INTEGER;
BEGIN
    -- Obtener el stock actual del producto con bloqueo de fila
    SELECT stock INTO v_stock_actual
    FROM producto
    WHERE id_producto = NEW.producto_id
    FOR UPDATE;

    -- Validar que haya suficiente stock
    IF v_stock_actual < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto ID %. Stock disponible: %, Cantidad solicitada: %',
            NEW.producto_id, v_stock_actual, NEW.cantidad
            USING ERRCODE = '23514'; -- Check violation
    END IF;

    -- Descontar el stock
    UPDATE producto
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.producto_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger asociado a la tabla detalle_pedido
DROP TRIGGER IF EXISTS trg_descontar_stock ON detalle_pedido;
CREATE TRIGGER trg_descontar_stock
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_trg_descontar_stock();


-- 2. PROCEDIMIENTO ALMACENADO: Cancelación / Borrado Lógico de un Pedido (Soft Delete)
-- Procedimiento invocado con CALL para cancelar un pedido y devolver el stock
CREATE OR REPLACE PROCEDURE sp_cancelar_pedido(p_id_pedido BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    r_item RECORD;
BEGIN
    -- Verificar si el pedido existe y no está ya eliminado
    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = p_id_pedido AND eliminado = FALSE) THEN
        RAISE NOTICE 'El pedido ID % no existe o ya se encuentra cancelado.', p_id_pedido;
        RETURN;
    END IF;

    -- Devolver el stock a los productos pertenecientes al pedido
    FOR r_item IN 
        SELECT producto_id, cantidad 
        FROM detalle_pedido 
        WHERE pedido_id = p_id_pedido AND eliminado = FALSE
    LOOP
        UPDATE producto
        SET stock = stock + r_item.cantidad
        WHERE id_producto = r_item.producto_id;
    END LOOP;

    -- Marcar como eliminados lógicamente el pedido y sus detalles (Soft Delete)
    UPDATE detalle_pedido SET eliminado = TRUE WHERE pedido_id = p_id_pedido;
    UPDATE pedido SET eliminado = TRUE WHERE id_pedido = p_id_pedido;

    RAISE NOTICE 'Pedido ID % cancelado exitosamente y stock devuelto.', p_id_pedido;
END;
$$;