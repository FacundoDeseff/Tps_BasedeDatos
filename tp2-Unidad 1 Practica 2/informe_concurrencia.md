# Informe de Laboratorio: Concurrencia y Aislamiento - Parte 2

## Escenario 1: Espera por Bloqueo (Row-Level Locking con SELECT FOR UPDATE)

* Cómo se reprodujo:
  - Sesión A:
    BEGIN;
    SELECT * FROM producto WHERE id_producto = 1 FOR UPDATE;
    (Mantiene la transacción abierta sin COMMIT)
  - Sesión B:
    BEGIN;
    UPDATE producto SET stock = stock - 1 WHERE id_producto = 1;

* Qué se observó: La Sesión B quedó bloqueada en espera activa (hang). Al ejecutar COMMIT en la Sesión A, la Sesión B se desbloqueó inmediatamente y completó su UPDATE.
* Explicación de la IA: SELECT ... FOR UPDATE adquiere un bloqueo exclusivo a nivel de fila (ExclusiveLock de tupla). Cualquier otra transacción que intente modificar la misma fila es puesta en cola hasta que la transacción bloqueante libere el recurso con COMMIT o ROLLBACK.
* Verificación en el motor: Se verificó consultando pg_locks durante la espera, confirmando el estado granted = false para el PID de la Sesión B.
* Conclusión: Confirmado en el motor. Es el mecanismo estándar para evitar Race Conditions en inventario.

---

## Escenario 2: Lectura No Repetible (Non-Repeatable Read)

* Cómo se reprodujo:
  - Sesión A (Read Committed por defecto):
    BEGIN;
    SELECT precio_lista FROM producto WHERE id_producto = 1; (Devuelve 5000.00)
  - Sesión B:
    BEGIN;
    UPDATE producto SET precio_lista = 6200.00 WHERE id_producto = 1;
    COMMIT;
  - Sesión A:
    SELECT precio_lista FROM producto WHERE id_producto = 1; (Devuelve 6200.00 dentro de la misma TX)
    COMMIT;

* Qué se observó: La misma consulta dentro de la misma transacción en Sesión A devolvió dos valores distintos porque Sesión B commiteó en el medio.
* Explicación de la IA: En READ COMMITTED, cada consulta SQL obtiene una nueva instantánea (snapshot) de la base de datos al ejecutarse, viendo cambios ya confirmados por otras transacciones.
* Verificación en el motor: Se repitió configurando en Sesión A:
  BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  Tras el commit de Sesión B, Sesión A volvió a consultar y el precio se mantuvo inalterable en 5000.00.
* Conclusión: Explicación certera. REPEATABLE READ congela la instantánea al inicio de la transacción mediante MVCC.

---

## Escenario 3: Lectura Fantasma (Phantom Read)

* Cómo se reprodujo:
  - Sesión A:
    BEGIN;
    SELECT COUNT(*) FROM producto WHERE id_categoria = 1; (Devuelve 1)
  - Sesión B:
    BEGIN;
    INSERT INTO producto (nombre, precio_lista, stock, id_categoria) VALUES ('Fugazzeta Especial', 5800, 5, 1);
    COMMIT;
  - Sesión A:
    SELECT COUNT(*) FROM producto WHERE id_categoria = 1; (Devuelve 2)
    COMMIT;

* Qué se observó: Una consulta agregada (COUNT) varió su resultado dentro de la misma transacción tras la inserción concurrente de Sesión B.
* Explicación de la IA: En READ COMMITTED, las filas insertadas que cumplen el filtro se vuelven visibles para lecturas posteriores. En PostgreSQL, tanto REPEATABLE READ como SERIALIZABLE impiden las lecturas fantasma gracias al snapshot de MVCC.
* Verificación en el motor: Se configuró Sesión A con SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; y el segundo COUNT se mantuvo en 1.
* Conclusión: Confirmado en el motor PostgreSQL.|