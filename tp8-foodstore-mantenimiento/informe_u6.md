# Informe post-incidente — TP Unidad 6
## Food Store · Mantenimiento, respaldo y recuperación

**Estado:** plantilla a cargo de Matías (I1). Se completa y se exporta a PDF cuando Santi (I2), Facu Deseff (I3) y Facu Ramirez (I4) entreguen sus evidencias `docs/i2_*`, `docs/i3_*` y `docs/i4_*`. Generar el PDF con `python scripts/generar_informe_pdf.py`.

**Entorno.** PostgreSQL 17.11 en `localhost:5433`; base `foodstore` de 105 MB (11 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos y 400.000 detalles). Base de ensayo `foodstore_restore_test`. Autenticación por `pgpass.conf`; ninguna contraseña en scripts ni en el repositorio. Evidencia de la reconstrucción: `docs/i1_reconstruccion_*.txt`.

**Respaldo utilizado.** «Completar con lo que informe I2 y el simulacro de I4: nombre del `.dump`, fecha y hora de creación, tamaño, SHA-256 y resultado de `pg_restore -l`.»

**Simulacro.** «Completar con `docs/i4_simulacro_*.txt`: hora de inicio y de fin, comando de restauración y base usada.»

**RTO y RPO.**
- RTO previsto: «completar»; observado: «completar con I4».
- RPO previsto: «completar»; observado: «completar con I4».
- Aclarar que el RPO observado depende del momento del simulacro: si se corre inmediatamente después del respaldo, el valor no representa el peor caso del plan.

**Validaciones.** «Completar con I4: conteos por tabla contra el respaldo, productos y detalles inválidos, claves foráneas huérfanas, consistencia de totales y secuencias restauradas.»

**Problema real encontrado.** «Cada integrante aporta el error o imprevisto de su corrida (I4 tiene que documentar el suyo sí o sí). No se acepta un informe sin un problema real y su corrección.»

**Mejora concreta.** «Acordar entre los cuatro. Propuesta base: programar el respaldo diario y el ensayo semanal, definir retención y evaluar archivado WAL + PITR para bajar el RPO de 24 h a minutos.»

**Intervención de OpenCode.** «Resumir qué generó la IA en cada parte y cómo se verificó antes de aceptarla. El detalle va en `BITACORA.md`; acá va el resumen de una o dos líneas por integrante.»

**Evidencias.** «Enlazar `docs/i1_*`, `docs/i2_*`, `docs/i3_*` y `docs/i4_*` cuando estén generadas.»
