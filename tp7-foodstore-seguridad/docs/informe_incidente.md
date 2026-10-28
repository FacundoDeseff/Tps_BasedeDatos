# Informe del simulacro de incidente (Parte C)

Base `copia_trabajo`, PostgreSQL 17.11, Windows. Ejecución del **2026-10-27
18:31:41 UTC-3**, conectado como `app_web`.
Script: `sql/simulacro_incidente.sql` (preparación: `sql/simulacro_preparacion.sql`).
Evidencia: `docs/log_simulacro_anonimizado.txt` y `docs/pruebas_simulacro.txt`.

## 1. Secuencia ejecutada y resultado real

Todo el simulacro se ejecutó contra la base de desarrollo propia. El escalamiento
se intentó con la identidad de bajo privilegio, que es lo que le da sentido al
ejercicio: si se corre como `postgres`, el `GRANT` final tendría éxito y además
dejaría a `app_web` con membresía en `admin_datos`.

| # | Hora (UTC-3) | Paso | Sentencia | Resultado real |
|---|---|---|---|---|
| 0 | 18:31:41.163 | conexión | `psql -U app_web -d copia_trabajo` | autenticado con `scram-sha-256`, desde `::1` |
| 1 | 18:31:41.180 | inicio | `SELECT 'INICIO_C'` | marca de corte para el log |
| 2 | 18:31:41.180 | intento fallido 1 | `fn_autenticar('cuenta_a@sintetico.example','clave_incorrecta_01')` | `NULL` |
| 3 | 18:31:41.200 | intento fallido 2 | idem, `clave_incorrecta_02` | `NULL` |
| 4 | 18:31:41.211 | intento fallido 3 | idem, `clave_incorrecta_03` | `NULL` |
| 5 | 18:31:41.222 | intento fallido 4 | idem, `clave_incorrecta_04` | `NULL` |
| 6 | 18:31:41.233 | **inicio de sesión exitoso** | `fn_autenticar(..., clave correcta)` | **`cliente`** |
| 7 | 18:31:41.245 | lectura masiva | `SELECT * FROM usuario` | `ERROR: permiso denegado a la tabla usuario` |
| 8 | 18:31:41.245 | lectura masiva (conteo) | `SELECT count(*) FROM usuario` | `ERROR: permiso denegado a la tabla usuario` |
| 9 | 18:31:41.246 | escalamiento 1 | `GRANT admin_datos TO app_web` | `ERROR: se ha denegado el permiso para otorgar el rol «admin_datos»` |
| 10 | 18:31:41.246 | escalamiento 2 | `GRANT admin_datos TO rol_soporte` | mismo error |
| 11 | 18:31:41.246 | fin | `SELECT 'FIN_C'` y desconexión | sesión de 0,092 s |

Cuatro intentos fallidos y un éxito, en ese orden. Son cuatro y no cinco por una
razón de diseño: `fn_autenticar` bloquea la cuenta al llegar a cinco intentos
(`c_umbral = 5`), de modo que un quinto fallo previo haría que el intento
correcto devolviera `'cuenta_bloqueada'` y el escenario quedaría sin login
exitoso. Con cuatro, el contador queda en 4, el acierto entra y además lo
reinicia a 0, así que el script se puede repetir.

**Punto clave para la lectura crítica (C.5):** el log registra la *sentencia*,
no su resultado. La única prueba de que el paso 6 tuvo éxito es la salida de
`psql` guardada en `docs/pruebas_simulacro.txt` (`resultado_login = cliente`).
El log, por sí solo, muestra cinco llamadas iguales y no permite saber cuál
funcionó.

## 2. Verificación del escalamiento (C.2)

El escalamiento **falló**, como debía. El mensaje exacto fue:

```text
ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
```

Se probaron dos variantes —darse el rol a sí mismo (`TO app_web`) y dárselo a
otro rol de bajo privilegio (`TO rol_soporte`)— y las dos fueron rechazadas.

Comprobación de que no quedó rastro, ejecutada como `postgres`:

```sql
SELECT m.rolname AS miembro_de, r.rolname AS miembro
FROM pg_auth_members AS am
JOIN pg_roles AS r ON r.oid = am.member
JOIN pg_roles AS m ON m.oid = am.roleid
WHERE m.rolname = 'admin_datos';
```

```text
 miembro_de | miembro
------------+---------
(0 filas)
```

Es decir: el esquema de la Parte A resistió. No hubo hallazgo que corregir.

## 3. Notas de ejecución

1. **Primer intento descartado (18:31:12, pid 10320).** El paso 6 devolvió `NULL`
   en lugar de `cliente`. Se verificó contra el hash almacenado con
   `crypt(candidata, password_hash) = password_hash` y se comprobó que la clave
   usada tenía un **espacio al final**, introducido por la forma de pasar el
   valor en la línea de comandos. No era un defecto del esquema ni de la
   función. Se repitió con la clave exacta y la corrida válida es la de las
   18:31:41 (pid 9848). El intento descartado también quedó en el log del
   servidor; el fragmento anonimizado incluye sólo la sesión válida y el informe
   lo aclara.
2. **La cuenta de prueba se prepara aparte.** `sql/simulacro_preparacion.sql`
   crea (o desbloquea) `cuenta_a@sintetico.example` y fija su clave por consola,
   para que el escenario parta siempre del mismo estado (`intentos_fallidos = 0`).
   La clave no se escribe en ningún archivo del repositorio.
3. **El log incluye las credenciales en claro.** Con `log_statement = 'all'`, el
   texto de cada sentencia queda escrito con sus literales: en la misma sesión
   de diagnóstico el log registró la clave de prueba en claro. Es evidencia
   directa de por qué el archivo de log es un activo sensible (Parte B, punto 4)
   y de por qué se anonimiza antes de compartirlo (C.3).

## 4. Criterio de anonimización del fragmento (C.3)

Se extrajo del log del servidor únicamente la sesión `app_web` (pid 9848),
delimitada por las marcas `INICIO_C` / `FIN_C` y las líneas de conexión y
desconexión.

| Dato | Acción | Motivo |
|---|---|---|
| clave de la cuenta de prueba | reemplazada por `clave_sintetica_05` | es una credencial; no debe salir del entorno |
| correo de la cuenta | se conserva (ya es sintético: `@sintetico.example`) | dominio reservado, no corresponde a una persona |
| rol, base, origen (`::1`), hora, pid | se conservan | son imprescindibles para reconstruir la secuencia |
| texto de las sentencias | se conserva | es la evidencia del incidente |
| sesiones de `postgres` del mismo archivo | excluidas | contenían literales de credenciales en claro |

El resultado es `docs/log_simulacro_anonimizado.txt`, sin datos personales
reales y sin claves utilizables.

## 5. Reconstrucción con IA (C.4)

Se entregó el fragmento anonimizado a una **sesión nueva** del asistente
(OpenCode), sin contexto previo del trabajo y sin agregar nada más que el prompt
de la consigna:

```text
Este es un fragmento de log de un servidor PostgreSQL. Reconstruí qué ocurrió
y proponé una hipótesis de contención.
```

Se transcribieron sólo las 26 líneas de log. Se omitió la cabecera del archivo
(líneas 1 a 15) porque nombra la Parte C.3, el simulacro y el script: son
metadatos del archivo, no líneas de log, y habrían condicionado la
reconstrucción. La decisión está fundada en `docs/respuesta_ia_simulacro.md`,
donde quedaron el prompt, la entrada enviada y la respuesta **completa y sin
editar**. No se ejecutó ninguna de las acciones que la IA sugirió.

## 6. Contraste entre la reconstrucción y lo ejecutado (C.5)

Para evaluar la respuesta de la IA se parte de separar lo que el log **prueba**
de lo que **no** prueba.

**Lo que el fragmento sí demuestra:**

- la identidad usada fue `app_web`, sobre la base `copia_trabajo`, desde `::1`, a las 18:31:41;
- hubo cinco llamadas a `fn_autenticar` con el mismo correo y claves distintas;
- las dos lecturas de `usuario` fueron denegadas por permisos;
- los dos `GRANT admin_datos` fueron denegados;
- la sesión completa duró 0,092 s y terminó con una desconexión normal.

**Lo que el fragmento no demuestra:**

- cuál de las cinco llamadas tuvo éxito (el log no registra resultados);
- si hubo filtración de datos: las lecturas masivas **fallaron**, no devolvieron filas;
- la intención ni la identidad humana detrás de la cuenta;
- cómo se obtuvo la credencial;
- ninguna fecha distinta de la registrada.

Cualquier afirmación de la IA que complete esos puntos es una hipótesis no
sustentada y debe marcarse como tal.

| Qué acertó | Qué omitió | Qué afirmó sin sustento |
|---|---|---|
| La secuencia completa y su orden. Que la identidad era `app_web`, sobre `copia_trabajo`, desde `::1`, con `psql` y una sesión de 0,092 s. Que las dos lecturas de `usuario` fueron denegadas, es decir que por esa vía **no** hubo lectura de datos. Que los dos `GRANT admin_datos` fueron denegados por falta de `ADMIN OPTION`. El patrón de escalamiento vertical con intento de persistencia vía `rol_soporte`. Que `log_statement = 'all'` deja el literal de las sentencias en el log (activo sensible, Parte B.4). | Que el log **no registra el valor devuelto** por `fn_autenticar`; presenta el quinto intento como exitoso sin aclarar que lo infiere. No distinguió la autenticación de la aplicación (`fn_autenticar`, sobre un usuario de la tabla) de la del motor (`scram-sha-256`, sobre el rol `app_web`). No advirtió que el fragmento ya venía seudonimizado. No señaló que `rol_soporte` es un rol de grupo sin login, con lo cual el "movimiento lateral" es sólo una hipótesis y no un paso consumado. | "Una sola sesión, **83 ms** en total": la sesión duró 0,092 s, o sea 92 ms. "5º intento con `clave_sintetica_05` → **login de aplicación exitoso**": el log no registra resultados; el éxito sólo lo prueba la salida de `psql` de `docs/pruebas_simulacro.txt`, que no se le entregó. "No hay throttling/lockout tras 4 fallos": el log no permite saberlo y, de hecho, `fn_autenticar` bloquea al quinto fallo. "El 'éxito' del 5º login es el caso positivo que el script necesitaba": atribuye diseño e intención a quien escribió el script. "Contraseñas en texto plano": lo que el log prueba es que registra el literal de la sentencia, no que la clave sea utilizable. "Si `copia_trabajo` es un restore de producción…": especulación sobre el origen de la base (queda marcada como condicional, pero el log no lo dice). |

Sobre la hipótesis: la IA se inclinó por "test controlado de seguridad" y ofreció
como alternativa "credencial filtrada de `app_web`". La primera coincide con lo
que realmente ocurrió, pero **el fragmento no la prueba**: los nombres sintéticos,
los marcadores `INICIO_C`/`FIN_C` y la base "copia" también son compatibles con un
atacante que usa un script prearmado. El equipo sabe que fue un simulacro porque
lo ejecutó, no porque el log lo demuestre.

Lo más valioso de la respuesta no es la reconstrucción sino la contención: las
diez medidas propuestas son verificables y no destructivas, y varias —revisar
`pg_auth_members`, los atributos de `app_web`, el origen en `pg_hba.conf`— son
exactamente las que el equipo adopta en la sección 7. La respuesta también acierta
en algo que el equipo no había anotado: el umbral de bloqueo no se puede evaluar
desde el log, hace falta mirar `intentos_fallidos`.

## 7. Decisión de contención del equipo (C.6)

**La decisión es del equipo.** Se toma a partir de la evidencia del log y de la
salida de `psql`, no de la sugerencia de la IA. Ninguna de las diez medidas que
propuso el asistente se ejecutó automáticamente: se leyeron, se contrastaron
(sección 6) y recién después el equipo armó su propio orden de intervención, que
coincide en lo esencial pero no lo copia: se descartan por ahora las medidas de
mediano plazo (migrar a `pgaudit`, redactar parámetros del log) por estar fuera
del alcance del TP, y se descarta cualquier acción destructiva, como revertir
roles o borrar datos, sobre una hipótesis.

En un caso real, el orden de intervención sería:

1. **Preservar la evidencia** antes de tocar nada: asegurar el log, sacarlo del
   servidor y guardarlo con permisos restringidos (el log es en sí mismo un
   activo sensible).
2. **Cortar el acceso con la credencial involucrada:** rotar la clave de
   `app_web` y revisar si la cuenta se usó desde otros orígenes. La cuenta
   atacada era la de la aplicación, así que la rotación impacta al servicio y
   debe coordinarse.
3. **Descartar el escalamiento:** verificar que ningún rol tenga membresía en
   `admin_datos` (la consulta de la sección 2, que hoy devuelve 0 filas).
4. **Revisar el rastro de autenticación:** `intentos_fallidos` y las lecturas de
   `usuario` en el período, para medir alcance.
5. **Limitar el origen** a nivel de red (`pg_hba.conf`) si el acceso no debería
   venir de esa dirección.

Lo que **no** haría el equipo es revertir roles o borrar datos a partir de la
hipótesis de la IA: primero se confirma con evidencia propia, después se actúa.
En este simulacro no se aplicó ninguna de estas medidas porque el entorno es de
desarrollo y la evidencia ya quedó preservada en el repositorio.

## 8. Evidencia adjunta

- `sql/simulacro_incidente.sql` — secuencia completa, ejecutable como `app_web`.
- `sql/simulacro_preparacion.sql` — preparación de la cuenta sintética.
- `docs/log_simulacro_anonimizado.txt` — fragmento del log, anonimizado.
- `docs/pruebas_simulacro.txt` — salida de `psql`: prueba del login exitoso y de
  las cuatro denegaciones.
- `docs/respuesta_ia_simulacro.md` — prompt, entrada enviada y respuesta de la IA
  completa y sin editar (C.4).
