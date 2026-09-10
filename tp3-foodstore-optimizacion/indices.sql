-- Índice 1: Para Consulta 1 (índice parcial filtrando por categoría y registros vigentes)
CREATE INDEX idx_producto_categoria_vig ON producto (id_categoria) WHERE eliminado = FALSE;

-- Índice 2: Para Consulta 2 (índice sobre clave foránea usuario_id en pedido)
CREATE INDEX idx_pedido_usuario ON pedido (usuario_id);

-- Índice 3: Para Consulta 3 (cubre el join y agregación sobre detalle_pedido)
CREATE INDEX idx_detalle_producto ON detalle_pedido (producto_id, subtotal) WHERE eliminado = FALSE;

-- Actualizar estadísticas con los nuevos índices
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;