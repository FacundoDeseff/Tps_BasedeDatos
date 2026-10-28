# AGENTS.md - Reglas de Operación y Seguridad para OpenCode (Unidad 6) 
## Entorno y Proyecto 
- Motor de base de datos objetivo: PostgreSQL 16 o superior. 
- Base de datos productiva de referencia: \`foodstore\`. 
- Base de datos exclusiva para simulacros y pruebas de restauración: \`foodstore\_restore\_test\`. 
## Reglas Estrictas de Seguridad 
- Queda totalmente PROHIBIDO ejecutar \`DROP DATABASE foodstore\` o cualquier comando destructivo sobre la base productiva. 
- Las pruebas destructivas y los ensayos de recuperación se deben ejecutar EXCLUSIVAMENTE sobre la base descartable \`foodstore\_restore\_test\`. 
- NUNCA incluir contraseñas en texto plano dentro de los scripts ni versionarlas en el repositorio. 
La autenticación se debe resolver mediante el archivo de contraseñas de PostgreSQL (\`.pgpass\` en Linux/macOS o \`%APPDATA%\\postgresql\\pgpass.conf\` en Windows). 
## Requisitos para Scripts y Mantenimiento 
- Los respaldos deben generarse obligatoriamente en formato personalizado (\`-Fc\`) mediante \`pg\_dump\` para permitir la inspección y restauración selectiva con \`pg\_restore\`. 
- Todo script de respaldo debe generar un nombre de archivo con fecha y hora (\`foodstore\_YYYYMMDD\_HHMM.dump\`) y escribir primero en un archivo temporal (\`.parcial\`), renombrándolo únicamente al finalizar exitosamente. 
- Los scripts deben detenerse inmediatamente ante cualquier error (usar \`set -euo pipefail\` en Bash o \`$ErrorActionPreference = 'Stop'\` en PowerShell) y registrar el resultado (OK o ERROR) en los archivos de log o bitácora. 
- NO utilizar \`VACUUM FULL\` como rutina diaria periódica, ya que genera un bloqueo exclusivo sobre las tablas. 
Para mantenimiento rutinario se debe emplear \`VACUUM (ANALYZE)\` sobre las tablas operativas. 
- Todo código generado por la IA debe ser probado manualmente en un entorno descartable antes de su programación automática.