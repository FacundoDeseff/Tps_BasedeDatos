# Protocolo de Seguridad (Regla de 3 Pasos)

Este protocolo se aplica obligatoriamente antes de ejecutar cualquier script generado por un agente de IA sobre la base de datos.

## 1. Copia
* **Qué significa:** Se trabaja sobre una base de desarrollo, nunca sobre la que contiene datos que importan.
* **Comando concreto:** createdb -T pizzeria_test pizzeria_trabajo
* **Cuándo se salta:** Nunca. Siempre hay copia.

## 2. Transacción
* **Qué significa:** Todo script que escribe corre primero dentro de BEGIN; y ROLLBACK; para inspeccionar el efecto antes de confirmar nada.
* **Comando concreto:** 
BEGIN;
-- [Script de IA acá]
ROLLBACK; -- (O COMMIT si todo está bien)
* **Cuándo se salta:** Nunca. Siempre BEGIN antes de escribir.

## 3. Respaldo
* **Qué significa:** Se realiza un pg_dump de la copia de trabajo antes de aplicar un cambio estructural (ALTER, DROP, migración).
* **Comando concreto:** pg_dump -Fc pizzeria_trabajo > backup.dump
* **Cuándo se salta:** Nunca. Siempre respaldo antes de DDL.