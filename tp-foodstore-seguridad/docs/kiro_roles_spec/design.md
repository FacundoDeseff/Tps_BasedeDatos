# Diseño de autorización

## Matriz de permisos

| Rol | Tablas/objetos | Privilegios | Justificación |
|---|---|---|---|
| `rol_app_lectura` | `categoria`, `producto` | `SELECT` | Renderiza el catálogo sin exponer operaciones de escritura. |
| `rol_app_escritura` | `pedido`, `detalle_pedido`, `linea_pedido` | `INSERT`; `USAGE, SELECT` en secuencias | Registra una compra y obtiene IDs generados, sin permitir borrado o cambios retroactivos. |
| `rol_soporte` | `usuario` | `SELECT`; `UPDATE` sólo en columnas de contacto/estado | Resuelve incidencias sin cambiar la identidad del cliente ni sus datos estructurales. |
| `rol_reportes` | relaciones de negocio | `SELECT` | Construye reportes reproducibles sin modificar la operación. |
| `app_web` | función de autenticación | `EXECUTE` puntual; hereda los dos roles web | Separa la identidad de conexión de las capacidades reutilizables. |
| `admin_datos` | administración | `CREATEDB`, `CREATEROLE` y administración explícita | Se reserva para mantenimiento; no se entrega a la aplicación. |

## Decisiones de implementación

- Los roles de grupo tienen `NOLOGIN`, `NOSUPERUSER`, `NOCREATEDB` y
  `NOCREATEROLE`. La aplicación tiene `INHERIT`, por lo que no necesita
  `SET ROLE` para trabajar.
- No se usan `GRANT ALL`, permisos sobre el esquema completo ni permisos
  `DELETE`/`UPDATE` generales. Las sentencias dinámicas sólo otorgan permisos
  a tablas que realmente existen.
- La concesión de columnas se construye a partir de las columnas presentes en
  `usuario`, evitando que un esquema que use `telefono`/`activo` falle si no
  tiene `email`.
- `ALTER DEFAULT PRIVILEGES` se refiere al propietario que ejecuta el script;
  si hay varios propietarios, cada uno debe ejecutar su propia política.
- Los intentos de escalamiento deben fallar porque `app_web` no tiene
  `CREATEROLE` ni es miembro de `admin_datos`. `admin_datos` es una cuenta
  administrativa independiente y nunca una membresía de la aplicación.

## Verificación

```sql
\du
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN (
  'rol_app_lectura', 'rol_app_escritura', 'rol_soporte',
  'rol_reportes', 'app_web', 'admin_datos'
)
ORDER BY grantee, table_name, privilege_type;
```

La salida esperada debe coincidir con la matriz y no debe contener `DELETE`,
`TRUNCATE`, `REFERENCES`, `TRIGGER` o `UPDATE` general para los roles web.