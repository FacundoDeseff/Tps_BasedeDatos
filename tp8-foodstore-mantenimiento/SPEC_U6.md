\# SPEC\_U6.md - Especificación del Plan de Mantenimiento y Respaldo 
## Requisitos Generales 
- Motor: PostgreSQL 16+. 
- Base de datos principal: \`foodstore\`. 
- Base descartable para pruebas: \`foodstore\_restore\_test\`. 
- Autenticación: mediante archivo de contraseñas de PostgreSQL (\`.pgpass\` / \`pgpass.conf\`), sin credenciales en texto plano. 
## Tareas Automatizables y Entregables 
1\. \*\*Respaldo Automatizable (\`backup\_foodstore\`)\*\* 
- Formato: Personalizado (\`-Fc\`) usando \`pg\_dump\`. 
- Nombre de archivo: \`foodstore\_YYYYMMDD\_HHMM.dump\`. 
- Requisito: Escribir primero en un archivo \`.parcial\` y renombrar únicamente si la ejecución fue exitosa. 
- Detención ante fallas: Salir con código de error si \`pg\_dump\` falla y dejar log en la carpeta \`logs/\`. 
2\. \*\*Monitoreo de Salud (\`health\_check.sql\`)\*\* 
- Debe incluir al menos 4 consultas clave: 
1\. Tamaño total de la base de datos \`foodstore\`. 
2\. Conexiones activas y métricas de transacciones (\`pg\_stat\_database\`). 
3\. Estado de tablas, tuplas muertas y fechas de autovacuum/autoanalyze (\`pg\_stat\_user\_tables\`). 
4\. Consultas activas en ejecución no inactivas (\`pg\_stat\_activity\`). 3\. \*\*Mantenimiento Seguro (\`maintenance.sql\`)\*\* 
- Incluir revisión de autovacuum y ejecución de \`ANALYZE\` sobre las tablas principales (\`pedido\`, \`detalle\_pedido\`, \`producto\`). 
- Criterio estricto: Prohibido incluir \`VACUUM FULL\` como rutina automática periódica. 
4\. \*\*Ensayo de Restauración (\`restore\_test\`)\*\* 
- Crear la base descartable \`foodstore\_restore\_test\`. 
- Restaurar el último archivo \`.dump\` utilizando \`pg\_restore\` con \`--no-owner --no-privileges\`. 
- Validar conteos de filas e integridad (verificar que no existan precios/stocks/cantidades negativas). 
- Registrar el tiempo transcurrido como el RTO observado.