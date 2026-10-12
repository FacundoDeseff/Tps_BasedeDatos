# Especificación de roles y permisos - Food Store

## Alcance y supuestos

La política se aplica al esquema `public` de PostgreSQL 16 y parte del modelo
Food Store con `categoria`, `producto`, `usuario`, `pedido` y
`detalle_pedido`. El script admite también `cliente` y `linea_pedido`, nombres
presentes en otras versiones del modelo. Los roles de grupo son `NOLOGIN`; las
identidades operativas son `app_web` y `admin_datos`.

## Requisitos funcionales

1. **Lectura web:** `rol_app_lectura` puede consultar únicamente los catálogos
   públicos (`categoria` y `producto`), sin insertar, modificar ni eliminar.
2. **Escritura web:** `rol_app_escritura` puede insertar pedidos y sus detalles
   (o líneas), además de usar las secuencias necesarias. No puede borrar,
   actualizar libremente ni alterar el esquema.
3. **Soporte:** `rol_soporte` puede leer `usuario` y actualizar sólo columnas
   de contacto/estado (`email`, `telefono` y/o `activo`, según existan). No
   puede modificar identidad, contraseñas ni relaciones de negocio.
4. **Reportes:** `rol_reportes` puede leer las tablas necesarias para
   agregaciones, pero no modificar datos, ejecutar funciones arbitrarias ni
   administrar roles.
5. **Aplicación:** `app_web` hereda lectura y escritura y puede ejecutar
   `fn_autenticar(text,text)` si la función existe. No tiene `CREATEROLE`,
   `CREATEDB` ni `SUPERUSER`.
6. **Administración:** `admin_datos` es una identidad separada para tareas
   administrativas. Su uso es explícito y no se hereda desde `app_web`.
7. **Futuras tablas:** los objetos creados por el propietario deben heredar la
   política mínima mediante `ALTER DEFAULT PRIVILEGES`.
8. **Verificabilidad:** los privilegios deben poder comprobarse con `\du` y
   `information_schema.role_table_grants`.