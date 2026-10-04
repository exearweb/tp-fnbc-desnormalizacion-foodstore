-- =========================================================================
-- TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN - UTN
-- ASIGNATURA: Base de Datos II
-- TRABAJO PRÁCTICO UNIDAD 4: Forma Normal de Boyce-Codd (FNBC)
-- Archivo: tp_fnbc_control_lote.sql
-- Dominio: ControlLoteAlmacen (Food Store)
-- =========================================================================

-- 1. Esquema original y carga de datos de ejemplo (con violación a FNBC)
CREATE TABLE control_lote_almacen_original (
    lote_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen_original VALUES
(501, 30, 801),
(502, 30, 801),
(503, 31, 802);

-- 2. Tablas descompuestas aplicando el algoritmo sin pérdida
-- Tabla 1: Asocia al responsable directamente con su depósito único maestro
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY,
    deposito_id BIGINT NOT NULL
);

-- Tabla 2: Relaciona el lote con el responsable de control asignado
CREATE TABLE lote_responsable_control (
    lote_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    PRIMARY KEY (lote_id, responsable_control_id),
    FOREIGN KEY (responsable_control_id) REFERENCES responsable_deposito(responsable_control_id)
);

-- 3. Migración de datos desde la instancia original hacia las tablas descompuestas
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id 
FROM control_lote_almacen_original;

INSERT INTO lote_responsable_control (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id 
FROM control_lote_almacen_original;

-- 4. Vista de compatibilidad que reconstruye la relación original (Reunión natural)
CREATE OR REPLACE VIEW vw_control_lote_almacen AS
SELECT 
    lrc.lote_id,
    rd.deposito_id,
    lrc.responsable_control_id
FROM lote_responsable_control lrc
JOIN responsable_deposito rd ON lrc.responsable_control_id = rd.responsable_control_id;

-- Verificación de equivalencia (Debe retornar exactamente los datos originales):
-- SELECT * FROM vw_control_lote_almacen;