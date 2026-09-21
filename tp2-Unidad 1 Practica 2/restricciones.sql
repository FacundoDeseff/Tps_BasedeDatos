ALTER TABLE producto
    ADD CONSTRAINT ck_producto_precio_stock
    CHECK (precio_lista > 0 AND stock >= 0);

ALTER TABLE producto
    ADD CONSTRAINT fk_producto_categoria
    FOREIGN KEY (id_categoria)
    REFERENCES categoria (id_categoria)
    ON DELETE RESTRICT;
