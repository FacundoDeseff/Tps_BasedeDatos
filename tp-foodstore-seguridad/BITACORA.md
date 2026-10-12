# Bitácora de uso de IA

| Prompt enviado a la IA | Respuesta relevante (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Diseñar roles Food Store con mínimo privilegio y permiso de columna. | Propuso roles de grupo, dos cuentas de login, permisos puntuales y `ALTER DEFAULT PRIVILEGES`. | Se rechazó cualquier `GRANT ALL`; se conservaron sólo operaciones justificadas y se verificará con `\du` e `information_schema`. |
| Generar una secuencia de auditoría nativa con lectura, inserción, actualización y login fallido. | Indicó `log_connections`, `log_disconnections` y `log_statement = 'mod'`. | Se distinguió el login del servidor de una función que devuelve falso y se evitó guardar contraseñas. |
| Reconstruir el simulacro de incidente y proponer contención. | Identificó fallos de autenticación, lectura masiva y un intento de escalamiento. | Se corrigió toda afirmación sobre intención, causa o identidad humana que el log no puede probar; la contención queda a decisión del equipo. |
| Crear `usuario_anon` y una consulta equivalente sobre datos reales. | Propuso reemplazos deterministas y comparación por grupos. | Se verificó que no se copien PII y que los conteos se comparen con un `FULL JOIN`. |

## Error significativo detectado

Una propuesta inicial de permisos amplia habría habilitado `GRANT ALL` sobre las
tablas operativas. El equipo la detectó al contrastarla con la matriz de Kiro:
permitía borrado y actualización general, operaciones que no son necesarias
para la aplicación. Se reemplazó por `INSERT` puntual, lectura de catálogos y
actualización sólo de columnas de soporte.

## Git y validación

La ejecución final debe registrar un commit por parte del TP (A roles, B
auditoría, C incidente y D anonimización). Antes de entregar se deben adjuntar
las salidas de `\du`, `information_schema.role_table_grants`, los logs
anonimizados y los resultados de equivalencia. Ningún log con datos reales ni
contraseña debe ingresar al repositorio.