# Declaración de Uso de IA - Parte 2

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Kiro Agent (Integrado en VS Code) |
| **Spec o prompt utilizado** | "Explicame por qué sucede la lectura no repetible, la lectura fantasma y el bloqueo por SELECT FOR UPDATE en PostgreSQL, y qué nivel de aislamiento evita cada uno." |
| **Qué generó** | Explicaciones teóricas sobre Row-Level Locking, READ COMMITTED y el uso de MVCC en niveles superiores. |
| **Qué se aceptó** | Los conceptos teóricos de aislamiento y bloqueos. |
| **Qué se modificó o descartó** | Se ajustó el formato para integrarlo al informe de escenarios. |
| **Verificación realizada** | Se forzaron los escenarios en dos sesiones reales concurrentes de PostgreSQL modificando el isolation level y se comprobó que el motor reaccionaba tal cual explicó la IA. |