# Respuesta de la IA al log del simulacro (Parte C.4)

## Cómo se hizo esta interacción

- **Herramienta:** OpenCode.
- **Modalidad:** sesión nueva, **sin contexto previo** del trabajo. El asistente no
  recibió el repositorio, ni la consigna, ni el informe, ni ninguna explicación
  del escenario: sólo el prompt y las líneas de log que se transcriben abajo.
- **Qué se envió:** el prompt de la consigna, textual, seguido de las líneas de
  log (17 a 42 de `docs/log_simulacro_anonimizado.txt`).
- **Qué se omitió y por qué:** la cabecera del archivo (líneas 1 a 15). Esa
  cabecera dice que se trata de la "Parte C.3", de un "simulacro" y del script
  `sql/simulacro_incidente.sql`; entregarla habría condicionado la reconstrucción
  y el ejercicio de lectura crítica pierde sentido si la IA sabe de antemano qué
  pasó. Lo omitido son metadatos del archivo, no líneas de log.
- **Qué se hizo con la respuesta:** nada de lo que sugiere se ejecutó. Se la
  contrasta en `docs/informe_incidente.md`, sección 6.

## Prompt enviado (textual)

```text
Este es un fragmento de log de un servidor PostgreSQL. Reconstruí qué ocurrió
y proponé una hipótesis de contención.
```

## Entrada enviada (textual, 26 líneas de log)

```text
2026-10-27 18:31:41.163 -03 [9848] user=[desconocido],db=[desconocido],app=[desconocido],client=::1 LOG:  conexión recibida: host=::1 port=59450
2026-10-27 18:31:41.172 -03 [9848] user=app_web,db=copia_trabajo,app=[desconocido],client=::1 LOG:  conexión autenticada: identidad=«app_web» método=scram-sha-256 (C:/Program Files/PostgreSQL/17/data/pg_hba.conf:117)
2026-10-27 18:31:41.172 -03 [9848] user=app_web,db=copia_trabajo,app=[desconocido],client=::1 LOG:  conexión autorizada: usuario=app_web base_de_datos=copia_trabajo nombre_de_aplicación=psql
2026-10-27 18:31:41.180 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT current_user AS identidad, session_user AS usuario_de_sesion;
2026-10-27 18:31:41.180 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT 'INICIO_C' AS marcador;
2026-10-27 18:31:41.180 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT public.fn_autenticar('cuenta_a@sintetico.example', 'clave_incorrecta_01') AS intento_1;
2026-10-27 18:31:41.200 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT public.fn_autenticar('cuenta_a@sintetico.example', 'clave_incorrecta_02') AS intento_2;
2026-10-27 18:31:41.211 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT public.fn_autenticar('cuenta_a@sintetico.example', 'clave_incorrecta_03') AS intento_3;
2026-10-27 18:31:41.222 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT public.fn_autenticar('cuenta_a@sintetico.example', 'clave_incorrecta_04') AS intento_4;
2026-10-27 18:31:41.233 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT public.fn_autenticar('cuenta_a@sintetico.example', 'clave_sintetica_05') AS resultado_login;
2026-10-27 18:31:41.245 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT * FROM public.usuario;
2026-10-27 18:31:41.245 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 ERROR:  permiso denegado a la tabla usuario
2026-10-27 18:31:41.245 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 SENTENCIA:  SELECT * FROM public.usuario;
2026-10-27 18:31:41.245 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT count(*) FROM public.usuario;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 ERROR:  permiso denegado a la tabla usuario
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 SENTENCIA:  SELECT count(*) FROM public.usuario;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: GRANT admin_datos TO app_web;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 SENTENCIA:  GRANT admin_datos TO app_web;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: GRANT admin_datos TO rol_soporte;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 SENTENCIA:  GRANT admin_datos TO rol_soporte;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  sentencia: SELECT 'FIN_C' AS marcador;
2026-10-27 18:31:41.246 -03 [9848] user=app_web,db=copia_trabajo,app=psql,client=::1 LOG:  desconexión: duración de sesión: 0:00:00.092 usuario=app_web base=copia_trabajo host=::1 port=59450
```

## Respuesta completa de la IA (sin editar)

> ## Reconstrucción
>
> Una sola sesión, **83 ms en total**, desde `::1` (loopback), con `psql` — no con la app web. Es automatización, no una persona: los 5 intentos van a ~11 ms de distancia.
>
> | Hora (.180–.246) | Acción | Resultado |
> |---|---|---|
> | .172 | `app_web` autentica contra Postgres (scram, `pg_hba.conf:117`) | OK |
> | .180 | `current_user`, `session_user`, marcador `INICIO_C` | OK |
> | .180–.233 | `fn_autenticar('cuenta_a@sintetico.example', ...)` ×4 con clave incorrecta | (sin error en log → la función devuelve fallo, no lanza excepción) |
> | .233 | 5º intento con `clave_sintetica_05` → `resultado_login` | login de aplicación exitoso |
> | .245 | `SELECT * FROM public.usuario` | **permiso denegado** |
> | .245 | `SELECT count(*) FROM public.usuario` | **permiso denegado** (sigue probando) |
> | .246 | `GRANT admin_datos TO app_web` | **denegado** — falta ADMIN OPTION |
> | .246 | `GRANT admin_datos TO rol_soporte` | **denegado** — mismo motivo |
> | .246 | marcador `FIN_C`, desconexión limpia | — |
>
> Lectura: hubo **reconocimiento + intento de escalada de privilegios** por un rol de aplicación de bajo privilegio. `app_web` no puede leer `usuario` (correcto, mínimo privilegio) y no puede otorgarse ni otorgar a un tercero (`rol_soporte`) el rol `admin_datos`. Los `GRANT` fallidos son el patrón clásico de escalada vertical + movimiento lateral/persistencia vía un rol de soporte.
>
> ## Hipótesis principal
>
> **Test controlado de seguridad (QA/red-team), no ataque real.** Evidencia a favor: cuentas `@sintetico.example`, claves `clave_sintetica_*`, marcadores `INICIO_C`/`FIN_C` (escenario "C"), cliente `psql` local, base `copia_trabajo` ("copia"), duración de script y desconexión limpia tras el último marcador. El "éxito" del 5º login es el caso positivo que el script necesitaba para pasar a la fase de escalada.
>
> **Hipótesis alternativa que no se puede descartar:** actor con credenciales de `app_web` filtradas ejecutando un playbook automatizado. Los marcadores y nombres sintéticos también son compatibles con un atacante que usa un script prearmado.
>
> No se puede decidir con este fragmento. Lo que **sí** es seguro: (1) `app_web` conoce una credencial válida de aplicación; (2) `log_statement=all` está escribiendo **contraseñas en texto plano** en el log; (3) si `copia_trabajo` es un restore de producción, el entorno de pruebas expone datos reales.
>
> ## Contención propuesta
>
> **Inmediato (no destructivo, la sesión ya terminó):**
> 1. Preservar: archivos de log completos, `pg_authid`/`pg_auth_members`, `pg_roles`, `pg_stat_activity`, `pg_hba.conf` línea 117, `%APPDATA%\postgresql\psql_history`, historial de shell del host.
> 2. Verificar persistencia: ¿hay filas nuevas en `pg_auth_members`? ¿`app_web` ganó atributos (`CREATEROLE`, `CREATEDB`, `SUPERUSER`, `BYPASSRLS`)? ¿roles nuevos, `ALTER ROLE`, `CREATE FUNCTION`, event triggers, extensiones, `ALTER DEFAULT PRIVILEGES`?
> 3. Confirmar que ningún `GRANT` de los rechazados quedó aplicado (el log dice denegado, pero verificar estado real).
>
> **Corto plazo:**
> 4. Tratar `app_web` como comprometido: rotar contraseña, revisar `.pgpass`, y confirmar que no tiene ADMIN OPTION en ningún rol ni ownership de objetos.
> 5. Auditar `fn_autenticar`: ¿es `SECURITY DEFINER`? ¿quién es el owner? ¿valida en SQL dinámico (inyección)? ¿por qué acepta texto plano y no hay throttling/lockout tras 4 fallos?
> 6. Revisar logs de la aplicación para `cuenta_a` en la ventana 18:31:41 — ¿se emitió sesión/token?
> 7. Acotar `pg_hba.conf:117`: si `app_web` puede conectar desde fuera de loopback, restringirlo.
>
> **Mediano plazo:**
> 8. Sacar `log_statement=all` de producción o redactar parámetros; migrar a `pgaudit` para tener auditoría sin filtrar credenciales.
> 9. Si fue un test: identificar al dueño del arnés, convertirlo en test de regresión, y garantizar que los scripts de prueba no apunten a bases con datos reales.
> 10. Revisar si `copia_trabajo` contiene datos personales reales; si sí, es un hallazgo aparte (exposición en entorno de pruebas).

---

El contraste de esta respuesta contra lo que realmente se ejecutó está en
`docs/informe_incidente.md`, sección 6.
