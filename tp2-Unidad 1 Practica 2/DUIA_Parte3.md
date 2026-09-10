# Declaración de Uso de IA - Parte 3

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Kiro Agent (Integrado en VS Code) |
| **Spec o prompt utilizado** | "Analizá estos dos scripts SQL defectuosos (un UPDATE sin WHERE y un DELETE con NOT IN). Identificá el efecto real y reescribilos corregidos." |
| **Qué generó** | El análisis del impacto total del UPDATE y la vulnerabilidad ante valores NULL del NOT IN, junto con las sentencias corregidas usando subconsultas y NOT EXISTS. |
| **Qué se aceptó** | La explicación técnica sobre cómo SQL evalúa NOT IN con valores NULL (UNKNOWN). |
| **Qué se modificó o descartó** | Se estructuró la respuesta para separar claramente el efecto real, el motivo del fallo y la versión final. |
| **Verificación realizada** | Se leyó detenidamente la lógica del NOT EXISTS propuesta para comprobar que resolvía la falla original. |