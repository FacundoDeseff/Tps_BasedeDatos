# Informe de auditoría nativa (Parte B)

Base `copia_trabajo`, PostgreSQL 17.11, Windows. Prueba ejecutada el 2026-10-27
entre las 15:56 y las 16:00 (UTC-3). Evidencia: `log_auditoria_prueba.txt`.

## 1. Configuración aplicada

Se modificaron cuatro parámetros con `ALTER SYSTEM` (quedan en
`postgresql.auto.conf`) y se aplicaron con `SELECT pg_reload_conf();`:

| Parámetro | Valor previo | Valor nuevo | Motivo |
|---|---|---|---|
| `log_connections` | `off` | `on` | Registrar quién se conecta, desde dónde y con qué método de autenticación |
| `log_disconnections` | `off` | `on` | Registrar el fin de cada sesión y su duración |
| `log_statement` | `none` | `all` | Registrar también las lecturas; ver la nota de abajo |
| `log_line_prefix` | (por defecto) | `%m [%p] user=%u,db=%d,app=%a,client=%h ` | Hora con milisegundos, PID, usuario, base, aplicación y cliente en cada línea |

Ya estaban así y no se tocaron: `logging_collector = on`, `log_destination = stderr`,
`log_directory = log` (dentro de `C:/Program Files/PostgreSQL/17/data`).

Por qué `log_statement = 'all'` y no `'mod'`: `'mod'` sólo registra sentencias
que modifican datos o estructura (`INSERT`, `UPDATE`, `DELETE`, DDL). Con `'mod'`
el simulacro de la Parte C no dejaría rastro de la lectura masiva de `usuario` ni
de las llamadas a `fn_autenticar`, que son `SELECT`. El costo es más volumen de
log y que el texto de cada sentencia, con sus literales, queda escrito (ver el
punto 4).

Verificación en una sesión nueva de `postgres`:

```text
log_connections    -> on
log_disconnections -> on
log_statement      -> all
```

En la misma sesión donde se ejecutó `ALTER SYSTEM`, `SHOW log_connections` y
`SHOW log_disconnections` seguían mostrando `off` después del `pg_reload_conf()`.
No es un fallo: esos dos parámetros se leen al abrir la conexión, por lo que el
nuevo valor sólo rige para las sesiones que se abren después. Se confirmó
abriendo una sesión nueva. `log_statement` y `log_line_prefix` se aplicaron de
inmediato.

## 2. Secuencia de prueba

Se usaron cinco sesiones de `psql` separadas, con los marcadores `INICIO_B` y
`FIN_B` para ubicar el tramo en el archivo:

1. `app_web`: lectura de `categoria` y un `SELECT` sobre `pedido` (denegado).
2. `admin_datos`: `INSERT`, `UPDATE` y `DELETE` sobre `categoria` (con datos de
   prueba que se borran al final).
3. Inicio de sesión fallido con un rol que no existe (`usuario_inexistente`).
4. Inicio de sesión fallido con un rol real (`app_web`) y clave incorrecta.
5. `app_web`: `SELECT 'FIN_B'` para cerrar el tramo.

Se usó `admin_datos` para la inserción y la actualización porque `app_web` no
tiene esos permisos sobre `categoria`.

## 3. Lectura del log: qué sirve para auditar y qué no

### Qué información es útil

| Pregunta | Dónde está | Ejemplo del log |
|---|---|---|
| **Quién** | `user=` del prefijo, y `identidad=` al autenticar | `user=admin_datos` |
| **Qué** | Texto completo de la sentencia | `sentencia: DELETE FROM categoria WHERE nombre = '__AUDITORIA_TEST_ACTUALIZADA__';` |
| **Cuándo** | `%m`, con milisegundos y zona horaria | `2026-10-27 15:57:40.988 -03` |
| **Desde dónde** | `client=` y `host=`/`port=` en la conexión | `client=::1` (IPv6 de la propia máquina), `app=psql` |
| **Resultado** | Una línea `ERROR` o `FATAL` junto a la sentencia | `ERROR: permiso denegado a la tabla pedido` |
| **Duración de la sesión** | Línea `desconexión` | `duración de sesión: 0:00:28.344` |
| **Método de autenticación** | `conexión autenticada` | `método=scram-sha-256 (pg_hba.conf:117)` |

Otras cosas que se aprecian en el fragmento:

- **El PID (`[35616]`) permite reconstruir una sesión entera**, de la conexión a la
  desconexión, aunque haya otras sesiones intercaladas.
- **Una sentencia denegada también queda registrada**: la línea `sentencia:
  SELECT * FROM pedido LIMIT 1;` aparece antes del `ERROR`, porque se registra
  antes de comprobar los permisos. Un intento no autorizado es visible.
- **Los fallos de autenticación se distinguen en el log pero no en el cliente.**
  Para `usuario_inexistente` el `DETALLE` dice `No existe el rol`; para `app_web`
  con clave mala sólo dice que falló la autentificación. El cliente ve el mismo
  mensaje en ambos casos. Esa diferencia permitiría a quien lea el log saber si
  el rol existe.
- **Las conexiones "huérfanas".** Antes de cada sesión válida hay una línea
  `conexión recibida` con `user=[desconocido]` que no tiene sesión asociada:
  es `psql` abriendo una primera conexión para saber que hace falta contraseña
  y reconectándose. No son intentos distintos.

### Qué queda fuera del alcance de este mecanismo nativo

- **Filas afectadas y valores.** El `DELETE` figura, pero el log no dice cuántas
  filas borró ni cuáles, ni el valor anterior y el nuevo de un `UPDATE`.
- **Qué datos devolvió una lectura.** Una consulta que leyó 20.000 usuarios
  ocupa una sola línea igual que una que leyó una fila.
- **Contexto del objeto.** No clasifica la operación (lectura, escritura, DDL,
  rol) ni identifica qué tablas tocó una consulta compleja o una función: hay que
  interpretar el texto.
- **Cambios hechos dentro de funciones o triggers**, que aparecen sólo como la
  llamada externa.

Para esa granularidad se evaluaría `pgaudit` (clasifica por clase de sentencia y
objeto, y registra qué objetos se tocaron) o auditoría por triggers sobre las
tablas críticas, que sí puede guardar valor anterior y nuevo por fila. Aquí se
menciona a nivel de nociones, como pide la consigna: no se instaló.

## 4. ¿El archivo de log es un activo sensible?

Sí. Con `log_statement = 'all'` el log guarda el texto literal de cada sentencia:
si alguien ejecuta `ALTER ROLE ... PASSWORD '...'` o llama a
`fn_autenticar('mail', 'clave')`, la clave queda escrita en claro; además contiene
nombres de roles, direcciones de origen, la estructura de la base, la ruta de
`pg_hba.conf` y la distinción entre rol inexistente y clave incorrecta. Todo eso
sirve a un atacante para reconocer el sistema y a una persona con acceso al
archivo para suplantar o espiar.

Debería poder leerlo sólo la cuenta que ejecuta el servicio PostgreSQL y el
personal de auditoría autorizado, mediante permisos restrictivos del sistema
operativo sobre el directorio de logs (en Windows, una ACL que quite a los
usuarios comunes; en Linux, modo `0600`/`0640` con grupo de auditoría), y no a
los roles de aplicación ni a los usuarios de la base, ni siquiera al de
administración de datos; si se necesita consultarlo desde SQL, hacerlo mediante
un mecanismo controlado y no con acceso al archivo.

**Evidencia en este equipo:** durante la prueba el archivo de log pudo leerse
desde la cuenta de Windows de uso diario, sin elevar privilegios. Para un entorno
de desarrollo personal es aceptable; en un entorno compartido sería un hallazgo
a corregir.

## 5. Conclusión

La configuración quedó activa y el log es legible y pertinente para responder
quién, qué, cuándo y desde dónde, y para detectar intentos denegados y fallos de
autenticación. No sirve para saber cuántos datos se tocaron ni qué valores
cambiaron. Para el simulacro de la Parte C hay que anonimizar el log antes de
mostrárselo a un asistente, porque contiene identificadores y texto de consultas.
