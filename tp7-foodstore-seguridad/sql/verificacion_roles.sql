-- Verificación de roles.sql contra la matriz de docs/kiro_roles_spec/design.md
-- Ejecutar como postgres. Guardar la salida en docs/verificacion_roles.txt:
--   psql -U postgres -h localhost -d copia_trabajo -f verificacion_roles.sql -o ../docs/verificacion_roles.txt

\echo '== 1. Roles y atributos (\du) =='
\du

\echo '== 2. Atributos exactos =='
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolinherit, rolcanlogin
FROM pg_roles
WHERE rolname IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte',
                  'rol_reportes', 'app_web', 'admin_datos')
ORDER BY rolname;

\echo '== 3. Membresías (app_web NO debe ser miembro de admin_datos) =='
SELECT member::regrole AS miembro, roleid::regrole AS miembro_de
FROM pg_auth_members
WHERE member::regrole::text IN ('app_web', 'admin_datos')
   OR roleid::regrole::text IN ('admin_datos')
ORDER BY 1, 2;

\echo '== 4. Privilegios por tabla (information_schema.role_table_grants) =='
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte',
                  'rol_reportes', 'app_web', 'admin_datos')
  AND table_schema = 'public'
ORDER BY grantee, table_name, privilege_type;

\echo '== 5. Privilegios por columna (information_schema.column_privileges) =='
SELECT grantee, table_name, column_name, privilege_type
FROM information_schema.column_privileges
WHERE grantee IN ('rol_soporte', 'rol_app_escritura', 'admin_datos')
  AND table_schema = 'public'
  AND table_name IN ('usuario', 'pedido', 'detalle_pedido')
  AND NOT EXISTS (   -- se omiten las columnas que ya figuran por privilegio de tabla
      SELECT 1 FROM information_schema.role_table_grants t
      WHERE t.grantee = column_privileges.grantee
        AND t.table_name = column_privileges.table_name
        AND t.privilege_type = column_privileges.privilege_type)
ORDER BY grantee, table_name, column_name, privilege_type;

\echo '== 6. EXECUTE en funciones (no debe aparecer PUBLIC) =='
SELECT grantee, routine_name, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN ('fn_autenticar', 'fn_resetear_password')
ORDER BY routine_name, grantee;

\echo '== 7. Secuencias y vistas materializadas (ACL cruda) =='
SELECT c.relname, c.relkind, c.relacl
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('S', 'm')
ORDER BY c.relkind, c.relname;

\echo '== 8. Defaults (ALTER DEFAULT PRIVILEGES) =='
SELECT pg_get_userbyid(d.defaclrole) AS propietario,
       n.nspname AS esquema,
       d.defaclobjtype AS tipo,
       d.defaclacl
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
ORDER BY 1, 2, 3;
