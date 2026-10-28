\# STATE.md - Estado del Proyecto y Hoja de Ruta 
## Estado Actual 
- \*\*Fase activa\*\*: Paso 1 de 4\. 
- \*\*Próximo Integrante a trabajar\*\*: Integrante 1 (Setup inicial). 
--- ## Registro de Tareas y Commits 
- [x] \*\*Tarea 1 (Integrante 1 - Vos)\*\*: 
- \*\*Archivos\*\*: 
\`AGENTS.md\`, \`SPEC\_U6.md\`, \`STATE.md\`. 
- \*\*Estado\*\*: COMPLETADO. 
- \*\*Instrucción para el Siguiente Integrante (Integrante 2)\*\*: &gt; "OpenCode, leé \`SPEC\_U6.md\` y \`AGENTS.md\`. Generá el script de respaldo en PowerShell \`backup\_foodstore.ps1\` para Windows. Debe usar \`pg\_dump -Fc\`, fecha/hora en el nombre, guardar logs en \`logs/\` y verificar la salida de error. Probá ejecutarlo manualmente." 
- [ ] \*\*Tarea 2 (Integrante 2)\*\*: - \*\*Archivos\*\*: \`backup\_foodstore.ps1\`, evidencia en \`logs/\`. 
- \*\*Estado\*\*: PENDIENTE. 
- \*\*Instrucción para el Siguiente Integrante (Integrante 3)\*\*: &gt; "OpenCode, leé \`SPEC\_U6.md\` y \`AGENTS.md\`. Generá \`health\_check.sql\` con los 4 controles de monitoreo (tamaño, conexiones, tuplas muertas, consultas activas) y \`maintenance.sql\` con una acción de ANALYZE/autovacuum justificada sin VACUUM FULL." 
- [ ] \*\*Tarea 3 (Integrante 3)\*\*: 
- \*\*Archivos\*\*: \`health\_check.sql\`, \`maintenance.sql\`. 
- \*\*Estado\*\*: PENDIENTE. 
- \*\*Instrucción para el Siguiente Integrante (Integrante 4)\*\*: &gt; "OpenCode, leé \`SPEC\_U6.md\` y \`AGENTS.md\`. Generá \`restore\_test.ps1\` para PowerShell que cree la base descartable \`foodstore\_restore\_test\`, restaure el archivo \`.dump\` más reciente con \`pg\_restore\` y corra las validaciones de conteo e integridad. Con eso armaremos el informe final." 
- [ ] \*\*Tarea 4 (Integrante 4)\*\*: 
- \*\*Archivos\*\*: \`restore\_test.ps1\`, \`informe\_u6.md\`. 
- \*\*Estado\*\*: PENDIENTE.