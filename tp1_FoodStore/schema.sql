-- Creacion del tipo enumerado para la forma de pago
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- Tabla categoria
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla cliente
CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(30),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla producto
CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    precio_lista NUMERIC(10,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    id_categoria BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    CONSTRAINT chk_producto_precio CHECK (precio_lista >= 0),
    CONSTRAINT chk_producto_stock CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria (id_categoria) ON DELETE RESTRICT
);

-- Tabla pedido
CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    id_cliente BIGINT NOT NULL,
    
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON DELETE RESTRICT
);

-- Tabla intermedia linea_pedido
CREATE TABLE linea_pedido (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    
    CONSTRAINT pk_linea_pedido PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT chk_linea_pedido_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_linea_pedido_precio CHECK (precio_unitario >= 0),
    CONSTRAINT fk_linea_pedido_pedido FOREIGN KEY (id_pedido)
        REFERENCES pedido (id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_linea_pedido_producto FOREIGN KEY (id_producto)
        REFERENCES producto (id_producto) ON DELETE RESTRICT
);

-- Indices para acelerar consultas comunes
-- Acelera buscar los pedidos de un cliente
CREATE INDEX idx_pedido_cliente ON pedido (id_cliente);

-- Acelera listar productos activos por categoria
CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo);