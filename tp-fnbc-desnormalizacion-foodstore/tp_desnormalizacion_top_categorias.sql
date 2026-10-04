-- =========================================================================
-- TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN - UTN
-- ASIGNATURA: Base de Datos II
-- TRABAJO PRÁCTICO UNIDAD 4: Desnormalización Controlada
-- Archivo: tp_desnormalizacion_top_categorias.sql
-- Dominio: Reporte Top 5 Categorías por Monto Vendido (Food Store)
-- =========================================================================

-- 1. Consulta original analizada (Lenta por JOINs masivos y filtros en caliente)
/*
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
*/

-- 2. Elección del patrón: Tabla de resumen diario con sincronización por Trigger
CREATE TABLE resumen_ventas_categoria_diario (
    categoria_id BIGINT PRIMARY KEY,
    categoria_nombre VARCHAR(100) NOT NULL,
    fecha DATE NOT NULL,
    total_vendido NUMERIC(12,2) NOT NULL DEFAULT 0.00
);

-- Índice para acelerar la consulta final directa
CREATE INDEX idx_resumen_ventas_fecha_total 
ON resumen_ventas_categoria_diario(fecha, total_vendido DESC);

-- 3. Mecanismo de Sincronización (Trigger en tiempo real)
CREATE OR REPLACE FUNCTION fn_actualizar_resumen_ventas()
RETURNS TRIGGER AS $$
DECLARE
    v_categoria_id BIGINT;
    v_categoria_nombre VARCHAR(100);
    v_fecha DATE;
BEGIN
    SELECT p.categoria_id, c.nombre, ped.fecha
    INTO v_categoria_id, v_categoria_nombre, v_fecha
    FROM producto p
    JOIN categoria c ON c.id = p.categoria_id
    JOIN pedido ped ON ped.id = NEW.pedido_id
    WHERE p.id = NEW.producto_id;

    INSERT INTO resumen_ventas_categoria_diario (categoria_id, categoria_nombre, fecha, total_vendido)
    VALUES (v_categoria_id, v_categoria_nombre, v_fecha, NEW.subtotal)
    ON CONFLICT (categoria_id) 
    DO UPDATE SET total_vendido = resumen_ventas_categoria_diario.total_vendido + NEW.subtotal;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sincronizar_ventas_categoria
AFTER INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_resumen_ventas();

-- 4. Consulta optimizada leyendo directamente de la estructura desnormalizada
EXPLAIN ANALYZE
SELECT categoria_nombre AS categoria,
       total_vendido
FROM resumen_ventas_categoria_diario
WHERE fecha = CURRENT_DATE
ORDER BY total_vendido DESC
LIMIT 5;

-- 5. Script de Auditoría (Debe retornar 0 filas si la sincronización es perfecta)
SELECT 
    rc.categoria_id,
    rc.total_vendido AS total_desnormalizado,
    COALESCE(SUM(dp.subtotal), 0) AS total_fuente_verdad
FROM resumen_ventas_categoria_diario rc
LEFT JOIN producto pr ON pr.categoria_id = rc.categoria_id
LEFT JOIN detalle_pedido dp ON dp.producto_id = pr.id
LEFT JOIN pedido ped ON ped.id = dp.pedido_id AND ped.fecha = rc.fecha AND ped.eliminado = FALSE AND dp.eliminado = FALSE
GROUP BY rc.categoria_id, rc.total_vendido
HAVING rc.total_vendido <> COALESCE(SUM(dp.subtotal), 0);